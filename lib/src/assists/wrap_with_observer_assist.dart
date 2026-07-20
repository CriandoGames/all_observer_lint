import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../utils/all_observer_type_checker.dart';
import '../utils/observer_wrap_edit_builder.dart';

/// `Wrap with Observer` assist.
///
/// Offers wrapping *any* expression that resolves to a Flutter `Widget`
/// with `Observer(() => ...)` — regardless of whether it contains a
/// reactive read, a `watch(context)` call, or sits inside a widget's
/// `build` method. Whether wrapping a particular Widget with `Observer` is
/// a *good idea* is left entirely to the opt-in lints
/// (`observer_without_reactive_read`, `unobserved_reactive_read_in_build`),
/// which can look for a hidden read after the fact; this assist only
/// verifies the narrow set of conditions required to produce valid,
/// non-redundant code. See `documentation/architecture.md` for the
/// rationale behind this split.
class WrapWithObserverAssist extends DartAssist {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    SourceRange target,
  ) {
    final checker = AllObserverTypeChecker();
    const editBuilder = ObserverWrapEditBuilder();

    context.registry.addExpression((node) {
      if (!_containsSelection(node, target)) return;
      if (!checker.isFlutterWidgetType(node.staticType)) return;
      if (!_isSmallestWidgetContainingSelection(node, target, checker)) {
        return;
      }
      // The context cannot be constant: there is no safe, general
      // transformation of the surrounding `const` chain in scope for this
      // assist (see `documentation/backlog.md`), so a `const` widget stays
      // untouched rather than emitting invalid code.
      if (node.inConstantContext) return;
      // Wrapping the creation of `Observer` itself is never meaningful.
      if (node is InstanceCreationExpression &&
          checker.isObserverWidgetCreation(node)) {
        return;
      }
      // Wrapping the exact root Widget an enclosing `Observer` builder
      // already returns would just produce a redundant
      // `Observer(() => Observer(() => ...))`.
      if (_isAlreadyObserverBuilderRoot(node, checker)) return;

      final unit = node.thisOrAncestorOfType<CompilationUnit>();
      if (unit == null) return;

      final source = resolver.source.contents.data;
      final edit = editBuilder.build(
        unit: unit,
        node: node,
        originalSource: source.substring(node.offset, node.end),
      );
      if (edit == null) return;

      final change = reporter.createChangeBuilder(
        message: 'Wrap with Observer',
        priority: 80,
      );
      change.addDartFileEdit((builder) {
        builder.addSimpleReplacement(
          SourceRange(node.offset, node.length),
          edit.replacement,
        );
        if (edit case ObserverWrapEdit(
          importOffset: final int offset,
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

  /// Whether [node] is the smallest Widget-typed expression that fully
  /// contains the current cursor/selection.
  ///
  /// Only descends into child AST nodes that themselves fully contain the
  /// selection (see [_hasWidgetDescendantContainingSelection]), so this
  /// never walks subtrees that are completely outside the selection — the
  /// cost is bounded by the depth of the single AST path that contains the
  /// cursor, not by the size of [node]'s whole subtree.
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

  /// Whether [node] is exactly the expression an enclosing `Observer(...)`
  /// builder returns as its root — either the arrow body of
  /// `Observer(() => node)` or the value of a top-level `return` statement
  /// directly inside `Observer(() { return node; })`.
  ///
  /// This check is purely structural/semantic (via [checker]) and never
  /// inspects identifier text, matching requirement #10 in the project
  /// brief. Widgets nested deeper inside the builder — e.g. `node` in
  /// `Observer(() => Column(children: [node]))` — are intentionally *not*
  /// matched: splitting a single `Observer` scope into smaller ones is a
  /// legitimate performance decision, so those remain wrappable.
  bool _isAlreadyObserverBuilderRoot(
    Expression node,
    AllObserverTypeChecker checker,
  ) {
    final closure = _enclosingObserverBuilderClosure(node, checker);
    if (closure == null) return false;

    final body = closure.body;
    if (body is ExpressionFunctionBody) {
      return identical(body.expression, node);
    }
    if (body is BlockFunctionBody) {
      for (final statement in body.block.statements) {
        if (statement is ReturnStatement &&
            identical(statement.expression, node)) {
          return true;
        }
      }
    }
    return false;
  }

  /// Returns the `Observer(...)` builder [FunctionExpression] that directly
  /// owns [node]'s parent (an arrow body, or a `return` statement in that
  /// builder's own block), or `null` if [node] is not in that position.
  FunctionExpression? _enclosingObserverBuilderClosure(
    Expression node,
    AllObserverTypeChecker checker,
  ) {
    final parent = node.parent;
    FunctionExpression? closure;
    if (parent is ExpressionFunctionBody &&
        parent.parent is FunctionExpression) {
      closure = parent.parent as FunctionExpression;
    } else if (parent is ReturnStatement) {
      final block = parent.parent;
      final body = block is Block ? block.parent : null;
      if (body is BlockFunctionBody && body.parent is FunctionExpression) {
        closure = body.parent as FunctionExpression;
      }
    }
    if (closure == null) return null;

    final argumentList = closure.parent;
    final invocation = argumentList is ArgumentList
        ? argumentList.parent
        : argumentList;
    if (invocation is InstanceCreationExpression &&
        checker.isObserverWidgetCreation(invocation)) {
      return closure;
    }
    return null;
  }
}
