// ignore_for_file: experimental_member_use

import 'package:analyzer/dart/ast/ast.dart';

import 'all_observer_import_resolver.dart';

/// A fully-computed text edit for wrapping a Widget expression with
/// `Observer(() => ...)`, plus the optional import edit that must
/// accompany it.
///
/// This is a plain data holder. It never decides *whether* wrapping a
/// given node is appropriate (that judgment belongs entirely to
/// `WrapWithObserverAssist`) and never re-derives *how* to reference
/// `Observer` safely (that stays inside `AllObserverImportResolver`, see
/// `all_observer_import_resolver.dart`).
class ObserverWrapEdit {
  const ObserverWrapEdit({
    required this.replacement,
    this.importOffset,
    this.importSource,
  });

  /// The full `Observer(() => <original>)` (or `prefix.Observer(...)`)
  /// source that should replace the wrapped node.
  final String replacement;

  /// Offset at which [importSource] must be inserted, if a new import
  /// directive is required. `null` when no import edit is needed.
  final int? importOffset;

  /// The import directive source to insert at [importOffset], if any.
  final String? importSource;
}

/// Builds the [ObserverWrapEdit] for wrapping a Widget expression with
/// `Observer`.
///
/// Delegates all import-safety decisions (shadowing, collisions, prefixed
/// vs. unprefixed imports, ambiguous imports) to [AllObserverImportResolver]
/// and only assembles the resulting text edit.
class ObserverWrapEditBuilder {
  const ObserverWrapEditBuilder({
    this.importResolver = const AllObserverImportResolver(),
  });

  final AllObserverImportResolver importResolver;

  /// Returns `null` when [AllObserverImportResolver] cannot resolve a safe
  /// import plan for [node] within [unit].
  ObserverWrapEdit? build({
    required CompilationUnit unit,
    required Expression node,
    required String originalSource,
  }) {
    final importPlan = importResolver.resolve(unit, targetNode: node);
    if (importPlan == null) return null;

    final replacement =
        '${importPlan.observerExpression}(\n'
        '  () => $originalSource,\n'
        ')';

    return ObserverWrapEdit(
      replacement: replacement,
      importOffset: importPlan.insertionOffset,
      importSource: importPlan.importSource,
    );
  }
}
