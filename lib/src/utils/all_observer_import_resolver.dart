import 'package:analyzer/dart/ast/ast.dart';

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

class AllObserverImportResolver {
  static const uri = 'package:all_observer/all_observer.dart';

  const AllObserverImportResolver();

  AllObserverImportPlan? resolve(CompilationUnit unit) {
    final matching = unit.directives
        .whereType<ImportDirective>()
        .where((directive) => directive.uri.stringValue == uri)
        .toList();

    for (final directive in matching) {
      if (!_exposesObserver(directive)) continue;
      final prefix = directive.prefix?.name;
      return AllObserverImportPlan(
        observerExpression: prefix == null ? 'Observer' : '$prefix.Observer',
      );
    }

    if (_declaresObserver(unit)) return null;

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
    late final int offset;
    late final String source;
    if (matching.isNotEmpty) {
      offset = matching.last.end;
      source = "\nimport '$uri';";
    } else if (packageImports.isNotEmpty) {
      offset = packageImports.last.end;
      source = "\nimport '$uri';";
    } else if (dartImports.isNotEmpty) {
      offset = dartImports.last.end;
      source = "\n\nimport '$uri';";
    } else if (imports.isNotEmpty) {
      offset = imports.first.offset;
      source = "import '$uri';\n\n";
    } else {
      offset = unit.directives.isNotEmpty ? unit.directives.last.end : 0;
      source = offset == 0 ? "import '$uri';\n\n" : "\nimport '$uri';";
    }
    return AllObserverImportPlan(
      observerExpression: 'Observer',
      insertionOffset: offset,
      importSource: source,
    );
  }

  bool _exposesObserver(ImportDirective directive) {
    var shown = true;
    for (final combinator in directive.combinators) {
      if (combinator is ShowCombinator) {
        shown = combinator.shownNames.any((name) => name.name == 'Observer');
      } else if (combinator is HideCombinator &&
          combinator.hiddenNames.any((name) => name.name == 'Observer')) {
        shown = false;
      }
    }
    return shown;
  }

  bool _declaresObserver(CompilationUnit unit) => unit.declarations.any(
    (declaration) =>
        declaration is NamedCompilationUnitMember &&
        declaration.name.lexeme == 'Observer',
  );
}
