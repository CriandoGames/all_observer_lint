// ignore_for_file: experimental_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

/// How to reference a given `all_observer` top-level symbol (e.g.
/// `Computed`) at a specific point in a file, plus the import edit (if any)
/// that must accompany it.
class SymbolImportPlan {
  const SymbolImportPlan({
    required this.expression,
    this.insertionOffset,
    this.importSource,
  });

  /// The expression to use in place of the bare symbol name — either the
  /// symbol itself (`Computed`) or a uniquely-prefixed reference
  /// (`allObserver.Computed`).
  final String expression;
  final int? insertionOffset;
  final String? importSource;
}

/// Generalizes `AllObserverImportResolver` (which is hard-coded to
/// `Observer`, and deliberately left untouched — see
/// `documentation/backlog.md` for why this is a separate file rather than a
/// refactor of that already-tested one) to *any* top-level `all_observer`
/// symbol: `Computed`, `Observable`, `effect`, `ReactiveScope`, and so on.
///
/// Never assumes a bare symbol reference is safe just because an unprefixed
/// `package:all_observer/all_observer.dart` import exists or can be added: a
/// same-named top-level declaration in the file, a locally-shadowing
/// parameter/variable at the point of use, or any other unprefixed import
/// that might also expose the same name, all make a bare reference unsafe.
/// When any such risk is detected, this resolver falls back to a freshly
/// generated, uniquely-named prefixed import (e.g. `allObserver.Computed`)
/// instead — a prefixed import can never be shadowed or made ambiguous by
/// anything else in the file, so [resolve] always returns a usable plan.
class AllObserverSymbolImportResolver {
  static const uri = 'package:all_observer/all_observer.dart';
  static const _defaultPrefixBase = 'allObserver';

  const AllObserverSymbolImportResolver();

  /// [targetNode] is the AST node the assist is about to insert a reference
  /// near; it is used to determine whether [symbolName] is shadowed at that
  /// specific point in the file (e.g. by an enclosing parameter or local
  /// variable), not just anywhere in the compilation unit.
  SymbolImportPlan resolve(
    CompilationUnit unit, {
    required String symbolName,
    AstNode? targetNode,
  }) {
    final matching = unit.directives
        .whereType<ImportDirective>()
        .where((directive) => directive.uri.stringValue == uri)
        .toList();

    // 1. A prefixed import exposing the symbol is always safe:
    //    `prefix.Symbol` can never be shadowed by a local declaration.
    for (final directive in matching) {
      if (!_exposesSymbol(directive, symbolName)) continue;
      final prefix = directive.prefix?.name;
      if (prefix != null) {
        return SymbolImportPlan(expression: '$prefix.$symbolName');
      }
    }

    // 2. An unprefixed import exposing the symbol is only safe to reuse
    //    when nothing at (or above) targetNode shadows the name.
    final hasUnprefixedImport = matching.any(
      (directive) =>
          directive.prefix == null && _exposesSymbol(directive, symbolName),
    );
    final hasCollision = _hasCollision(unit, targetNode, symbolName);
    if (hasUnprefixedImport && !hasCollision) {
      return SymbolImportPlan(expression: symbolName);
    }

    // 3. No usable import exists yet. If the bare name is safe at this
    //    point, keep the existing (unprefixed) behavior of adding a plain
    //    `import '...';` and using the bare symbol name.
    if (!hasUnprefixedImport && !hasCollision) {
      final insertion = _buildImportInsertion(unit, null);
      return SymbolImportPlan(
        expression: symbolName,
        insertionOffset: insertion.offset,
        importSource: insertion.source,
      );
    }

    // 4. Either an unprefixed import exists but is shadowed/ambiguous here,
    //    or there's no import and the bare name is otherwise unsafe. A
    //    freshly, uniquely prefixed import resolves all of these safely.
    final prefix = _uniquePrefix(unit);
    final insertion = _buildImportInsertion(unit, prefix);
    return SymbolImportPlan(
      expression: '$prefix.$symbolName',
      insertionOffset: insertion.offset,
      importSource: insertion.source,
    );
  }

  /// Whether [symbolName] unqualified is unsafe to use: either declared at
  /// top level in this file, shadowed by an enclosing parameter/local
  /// declaration reachable from [targetNode], or potentially exposed by
  /// another unprefixed import (which the analyzer cannot always prove is
  /// harmless without full resolution, so it is treated conservatively).
  bool _hasCollision(
    CompilationUnit unit,
    AstNode? targetNode,
    String symbolName,
  ) {
    if (_declaresTopLevelName(unit, symbolName)) return true;
    if (targetNode != null &&
        _isNameDeclaredInEnclosingScopes(targetNode, symbolName)) {
      return true;
    }
    if (_anotherUnprefixedImportMayExpose(unit, symbolName)) return true;
    return false;
  }

  bool _declaresTopLevelName(CompilationUnit unit, String name) {
    return unit.declarations.any(
      (declaration) =>
          declaration is NamedCompilationUnitMember &&
          declaration.name.lexeme == name,
    );
  }

  /// Walks up from [target] through enclosing function bodies/blocks
  /// looking for a parameter, local variable, or local function declared
  /// with [name] that would shadow a top-level/imported identifier at that
  /// point.
  bool _isNameDeclaredInEnclosingScopes(AstNode target, String name) {
    AstNode? current = target;

    while (current != null) {
      final parameters = _parametersOf(current);
      if (parameters != null) {
        for (final parameter in parameters.parameters) {
          if (_parameterName(parameter) == name) return true;
        }
      }

      if (current is Block) {
        for (final statement in current.statements) {
          if (statement.offset >= target.offset) break;
          if (_statementDeclaresName(statement, name)) return true;
        }
      }

      current = current.parent;
    }

    return false;
  }

  FormalParameterList? _parametersOf(AstNode node) {
    if (node is MethodDeclaration) return node.parameters;
    if (node is FunctionExpression) return node.parameters;
    if (node is FunctionDeclaration) return node.functionExpression.parameters;
    if (node is ConstructorDeclaration) return node.parameters;
    return null;
  }

  String? _parameterName(FormalParameter parameter) {
    if (parameter is DefaultFormalParameter) {
      return _parameterName(parameter.parameter);
    }
    return parameter.name?.lexeme;
  }

  bool _statementDeclaresName(Statement statement, String name) {
    if (statement is VariableDeclarationStatement) {
      return statement.variables.variables.any(
        (variable) => variable.name.lexeme == name,
      );
    }
    if (statement is FunctionDeclarationStatement) {
      return statement.functionDeclaration.name.lexeme == name;
    }
    if (statement is PatternVariableDeclarationStatement) {
      final collector = _PatternVariableNameCollector();
      statement.declaration.pattern.accept(collector);
      return collector.names.contains(name);
    }
    return false;
  }

  /// Any other unprefixed import in this file is treated as a potential
  /// source of [symbolName]: without resolving its exported namespace we
  /// cannot prove it does *not* also expose that name, and a false "safe"
  /// here could generate an ambiguous-import error, so this is intentionally
  /// conservative.
  bool _anotherUnprefixedImportMayExpose(
    CompilationUnit unit,
    String symbolName,
  ) {
    for (final directive in unit.directives.whereType<ImportDirective>()) {
      if (directive.uri.stringValue == uri) continue;
      if (directive.prefix != null) continue;
      final libraryImport = directive.libraryImport;
      if (libraryImport == null) return true;
      final exported = libraryImport.namespace.get2(symbolName);
      if (exported != null) return true;
    }
    return false;
  }

  String _uniquePrefix(CompilationUnit unit) {
    final collector = _IdentifierCollector();
    unit.accept(collector);
    if (!collector.names.contains(_defaultPrefixBase)) {
      return _defaultPrefixBase;
    }

    var suffix = 2;
    while (collector.names.contains('$_defaultPrefixBase$suffix')) {
      suffix++;
    }
    return '$_defaultPrefixBase$suffix';
  }

  ({int offset, String source}) _buildImportInsertion(
    CompilationUnit unit,
    String? prefix,
  ) {
    final importSource = prefix == null
        ? "import '$uri';"
        : "import '$uri' as $prefix;";
    final matching = unit.directives
        .whereType<ImportDirective>()
        .where((directive) => directive.uri.stringValue == uri)
        .toList();
    final imports = unit.directives.whereType<ImportDirective>().toList();
    final packageImports = imports
        .where(
          (directive) =>
              directive.uri.stringValue?.startsWith('package:') ?? false,
        )
        .toList();
    final dartImports = imports
        .where(
          (directive) =>
              directive.uri.stringValue?.startsWith('dart:') ?? false,
        )
        .toList();

    if (matching.isNotEmpty) {
      return (offset: matching.last.end, source: '\n$importSource');
    }
    if (packageImports.isNotEmpty) {
      return (offset: packageImports.last.end, source: '\n$importSource');
    }
    if (dartImports.isNotEmpty) {
      return (offset: dartImports.last.end, source: '\n\n$importSource');
    }
    if (imports.isNotEmpty) {
      return (offset: imports.first.offset, source: '$importSource\n\n');
    }
    final offset = unit.directives.isNotEmpty ? unit.directives.last.end : 0;
    return (
      offset: offset,
      source: offset == 0 ? '$importSource\n\n' : '\n$importSource',
    );
  }

  bool _exposesSymbol(ImportDirective directive, String symbolName) {
    var shown = true;
    for (final combinator in directive.combinators) {
      if (combinator is ShowCombinator) {
        shown = combinator.shownNames.any((name) => name.name == symbolName);
      } else if (combinator is HideCombinator &&
          combinator.hiddenNames.any((name) => name.name == symbolName)) {
        shown = false;
      }
    }
    return shown;
  }
}

class _IdentifierCollector extends RecursiveAstVisitor<void> {
  final Set<String> names = {};

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    names.add(node.name);
    super.visitSimpleIdentifier(node);
  }

  @override
  void visitImportDirective(ImportDirective node) {
    final prefix = node.prefix?.name;
    if (prefix != null) names.add(prefix);
    super.visitImportDirective(node);
  }
}

class _PatternVariableNameCollector extends RecursiveAstVisitor<void> {
  final Set<String> names = {};

  @override
  void visitDeclaredVariablePattern(DeclaredVariablePattern node) {
    names.add(node.name.lexeme);
    super.visitDeclaredVariablePattern(node);
  }
}
