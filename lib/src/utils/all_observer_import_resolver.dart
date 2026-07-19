// ignore_for_file: experimental_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

class AllObserverImportPlan {
  const AllObserverImportPlan({
    required this.observerExpression,
    this.insertionOffset,
    this.importSource,
  });

  final String observerExpression;
  final int? insertionOffset;
  final String? importSource;
}

/// Resolves how to reference `Observer` at a given point in a file, and
/// what import edit (if any) must accompany it.
///
/// This never assumes `Observer` is safe to use unqualified just because an
/// unprefixed `package:all_observer/all_observer.dart` import exists or can
/// be added: a same-named top-level declaration, a locally-shadowing
/// parameter/variable, or another unprefixed import that also exposes an
/// `Observer` name can all make a bare `Observer(...)` reference resolve to
/// the wrong thing (or become ambiguous). When any such risk is detected,
/// this resolver falls back to a freshly generated, uniquely-named prefixed
/// import (e.g. `allObserver.Observer`) instead of reusing or adding a bare
/// `Observer` reference. A prefixed import can never be shadowed or made
/// ambiguous by anything else in the file, so `resolve` always returns a
/// usable plan.
class AllObserverImportResolver {
  static const uri = 'package:all_observer/all_observer.dart';
  static const _observerName = 'Observer';
  static const _defaultPrefixBase = 'allObserver';

  const AllObserverImportResolver();

  /// [targetNode] is the AST node the assist is about to wrap; it is used
  /// to determine whether `Observer` is shadowed at that specific point in
  /// the file (e.g. by an enclosing parameter or local variable), not just
  /// anywhere in the compilation unit.
  AllObserverImportPlan? resolve(CompilationUnit unit, {AstNode? targetNode}) {
    final matching = unit.directives
        .whereType<ImportDirective>()
        .where((directive) => directive.uri.stringValue == uri)
        .toList();

    // 1. A prefixed import exposing Observer is always safe: `prefix.Observer`
    //    can never be shadowed by a local declaration.
    for (final directive in matching) {
      if (!_exposesObserver(directive)) continue;
      final prefix = directive.prefix?.name;
      if (prefix != null) {
        return AllObserverImportPlan(observerExpression: '$prefix.Observer');
      }
    }

    // 2. An unprefixed import exposing Observer is only safe to reuse when
    //    nothing at (or above) targetNode shadows the name.
    final hasUnprefixedImport = matching.any(
      (directive) => directive.prefix == null && _exposesObserver(directive),
    );
    final hasCollision = _hasObserverCollision(unit, targetNode);
    if (hasUnprefixedImport && !hasCollision) {
      return const AllObserverImportPlan(observerExpression: _observerName);
    }

    // 3. No usable import exists yet. If the bare name is safe at this
    //    point, keep the existing (unprefixed) behavior of adding a plain
    //    `import '...';` and using bare `Observer`.
    if (!hasUnprefixedImport && !hasCollision) {
      final insertion = _buildImportInsertion(unit, null);
      return AllObserverImportPlan(
        observerExpression: _observerName,
        insertionOffset: insertion.offset,
        importSource: insertion.source,
      );
    }

    // 4. Either an unprefixed import exists but is shadowed/ambiguous here,
    //    or there's no import and the bare name is otherwise unsafe
    //    (declared at top level in this file, shadowed locally, or another
    //    unprefixed import may also expose it). A freshly, uniquely
    //    prefixed import resolves all of these safely: `prefix.Observer`
    //    cannot be shadowed or made ambiguous by anything else in the file,
    //    so there is no case left where the assist must give up entirely.
    final prefix = _uniquePrefix(unit);
    final insertion = _buildImportInsertion(unit, prefix);
    return AllObserverImportPlan(
      observerExpression: '$prefix.$_observerName',
      insertionOffset: insertion.offset,
      importSource: insertion.source,
    );
  }

  /// Whether `Observer` unqualified is unsafe to use: either declared at
  /// top level in this file, shadowed by an enclosing parameter/local
  /// declaration reachable from [targetNode], or potentially exposed by
  /// another unprefixed import (which the analyzer cannot always prove is
  /// harmless without full resolution, so it is treated conservatively).
  bool _hasObserverCollision(CompilationUnit unit, AstNode? targetNode) {
    if (_declaresTopLevelName(unit, _observerName)) return true;
    if (targetNode != null &&
        _isNameDeclaredInEnclosingScopes(targetNode, _observerName)) {
      return true;
    }
    if (_anotherUnprefixedImportMayExposeObserver(unit)) return true;
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
  /// source of an `Observer` name: without resolving its exported
  /// namespace we cannot prove it does *not* also expose `Observer`, and a
  /// false "safe" here could generate an ambiguous-import error, so this is
  /// intentionally conservative.
  bool _anotherUnprefixedImportMayExposeObserver(CompilationUnit unit) {
    for (final directive in unit.directives.whereType<ImportDirective>()) {
      if (directive.uri.stringValue == uri) continue;
      if (directive.prefix != null) continue;
      final libraryImport = directive.libraryImport;
      if (libraryImport == null) return true;
      final exported = libraryImport.namespace.get2(_observerName);
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

  bool _exposesObserver(ImportDirective directive) {
    var shown = true;
    for (final combinator in directive.combinators) {
      if (combinator is ShowCombinator) {
        shown = combinator.shownNames.any((name) => name.name == _observerName);
      } else if (combinator is HideCombinator &&
          combinator.hiddenNames.any((name) => name.name == _observerName)) {
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
