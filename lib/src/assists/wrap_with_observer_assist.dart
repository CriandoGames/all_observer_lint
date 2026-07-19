import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../utils/all_observer_import_resolver.dart';
import '../utils/all_observer_type_checker.dart';
import '../utils/build_context_detector.dart';
import '../utils/reactive_read_collector.dart';

class WrapWithObserverAssist extends DartAssist {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    SourceRange target,
  ) {
    const checker = AllObserverTypeChecker();
    const reads = ReactiveReadCollector(checker);
    final rebuildScopes = RebuildScopeFinder(checker);

    context.registry.addExpression((node) {
      if (!_containsSelection(node, target)) return;
      if (!checker.isFlutterWidgetType(node.staticType)) return;
      if (!_isSmallestWidgetContainingSelection(node, target, checker)) return;
      if (node.inConstantContext) return;
      final scope = rebuildScopes.find(node);
      if (scope is! MethodDeclaration) return;

      final result = reads.collect(node);
      if (result.reads.isEmpty ||
          result.hasWatchRead ||
          result.hasUnresolvedNode) {
        return;
      }

      final unit = node.thisOrAncestorOfType<CompilationUnit>();
      if (unit == null) return;
      const importResolver = AllObserverImportResolver();
      final importPlan = importResolver.resolve(unit);
      if (importPlan == null) return;

      final source = resolver.source.contents.data;
      final original = source.substring(node.offset, node.end);
      final replacement =
          '${importPlan.observerExpression}(\n'
          '  () => $original,\n'
          ')';

      final change = reporter.createChangeBuilder(
        message: 'Wrap with Observer',
        priority: 80,
      );
      change.addDartFileEdit((builder) {
        builder.addSimpleReplacement(
          SourceRange(node.offset, node.length),
          replacement,
        );
        if (importPlan case AllObserverImportPlan(
          insertionOffset: final int offset,
          importSource: final String importSource,
        )) {
          builder.addSimpleInsertion(offset, importSource);
        }
      });
    });
  }

  bool _containsSelection(Expression node, SourceRange target) {
    final selectionEnd = target.offset + target.length;
    return node.offset <= target.offset && node.end >= selectionEnd;
  }

  bool _isSmallestWidgetContainingSelection(
    Expression node,
    SourceRange target,
    AllObserverTypeChecker checker,
  ) {
    return !_hasWidgetDescendantContainingSelection(
      node,
      target,
      checker,
      skipRoot: true,
    );
  }

  bool _hasWidgetDescendantContainingSelection(
    AstNode root,
    SourceRange target,
    AllObserverTypeChecker checker, {
    required bool skipRoot,
  }) {
    if (!skipRoot &&
        root is Expression &&
        _containsSelection(root, target) &&
        checker.isFlutterWidgetType(root.staticType)) {
      return true;
    }
    for (final child in root.childEntities.whereType<AstNode>()) {
      final selectionEnd = target.offset + target.length;
      if (child.offset > target.offset || child.end < selectionEnd) continue;
      if (_hasWidgetDescendantContainingSelection(
        child,
        target,
        checker,
        skipRoot: false,
      )) {
        return true;
      }
    }
    return false;
  }
}
