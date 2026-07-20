import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/source/source_range.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../utils/all_observer_type_checker.dart';
import '../utils/observer_wrap_edit_builder.dart';

/// `Wrap smallest reactive subtree with Observer` assist.
///
/// A specialized companion to the permissive `Wrap with Observer` assist
/// (`lib/src/assists/wrap_with_observer_assist.dart`, unchanged and still
/// offered on any Widget regardless of reactive content — see
/// `documentation/architecture.md`). This assist is only offered when the
/// selection is on (or inside) a reactive `.value` read of an
/// `Observable`/`Computed`, and it anchors its search on *that specific
/// read* rather than on the raw selection range:
///
/// ```dart
/// Column(
///   children: [
///     const Text('Title'),
///     Text('${count.value}'),
///     const Footer(),
///   ],
/// )
/// ```
///
/// Triggered on `count.value`, this wraps only the `Text` that contains
/// it — never the surrounding `Column` — by walking up from the read to
/// the nearest ancestor expression whose static type is a Flutter
/// `Widget`.
///
/// ## Closure safety
///
/// Walking up from the read may pass through a widget-*builder*-shaped
/// closure (one whose own function type returns a `Widget` — an
/// `itemBuilder`, an `Observer` builder, `MaterialApp.builder`, ...),
/// which is safe: such a closure runs synchronously whenever its host
/// widget is built, so any `Observer` this assist inserts around a Widget
/// reachable through it still tracks correctly. It must **not**, however,
/// pass through an *event*-shaped closure (`onPressed`, `onChanged`, or
/// any other closure whose own return type is not a `Widget`) to reach a
/// Widget further out — a write/read inside an event handler does not run
/// as part of any build, so wrapping something outside that handler with
/// `Observer` would be meaningless. When such a boundary is the first
/// thing found while walking up from the read (i.e. no Widget exists
/// between the read and that event closure), this assist stays
/// unavailable — the permissive `Wrap with Observer` assist remains usable
/// manually if the developer decides a wrap is still appropriate there.
///
/// ## Scope (first version)
///
/// - Only a `.value` read of `Observable`/`Computed` is recognized as the
///   anchoring read. Reactive-collection reads
///   (`items.length`/`items.contains(...)`) and `watch(context)` mixed
///   into the same expression are not yet supported as triggers for this
///   *specialized* action — the permissive assist remains available for
///   those. See `documentation/backlog.md`.
/// - The same `const`-context, already-`Observer`-creation, and
///   already-exactly-an-enclosing-`Observer`-builder-root checks as the
///   permissive assist apply here too (duplicated rather than shared — see
///   `documentation/backlog.md` for why).
class WrapSmallestReactiveSubtreeAssist extends DartAssist {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    SourceRange target,
  ) {
    final checker = AllObserverTypeChecker();
    const editBuilder = ObserverWrapEditBuilder();

    context.registry.addCompilationUnit((unit) {
      final read = _findReactiveValueReadAt(unit, target, checker);
      if (read == null) return;

      final widget = _smallestSafeWidgetContaining(read, checker);
      if (widget == null) return;
      if (widget.inConstantContext) return;
      if (widget is InstanceCreationExpression &&
          checker.isObserverWidgetCreation(widget)) {
        return;
      }
      if (_isAlreadyObserverBuilderRoot(widget, checker)) return;

      final source = resolver.source.contents.data;
      final edit = editBuilder.build(
        unit: unit,
        node: widget,
        originalSource: source.substring(widget.offset, widget.end),
      );
      if (edit == null) return;

      final change = reporter.createChangeBuilder(
        message: 'Wrap smallest reactive subtree with Observer',
        // Just under the permissive assist's priority (80): when both are
        // applicable, the permissive one (which fires for the raw
        // selection regardless of read content) is offered first, this
        // more specific one right after.
        priority: 79,
      );
      change.addDartFileEdit((builder) {
        builder.addSimpleReplacement(
          SourceRange(widget.offset, widget.length),
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

  /// Finds the innermost `.value` read of an `Observable`/`Computed` whose
  /// source range contains [target] (the cursor/selection).
  Expression? _findReactiveValueReadAt(
    CompilationUnit unit,
    SourceRange target,
    AllObserverTypeChecker checker,
  ) {
    final finder = _ReactiveValueReadFinder(target, checker);
    unit.accept(finder);
    return finder.best;
  }

  /// Walks up from [read] looking for the nearest ancestor [Expression]
  /// whose static type is a Flutter `Widget`. Stops (returning `null`,
  /// i.e. "unavailable") if it reaches a closure that is not itself
  /// widget-builder-shaped before ever finding one — see the class doc,
  /// "Closure safety".
  Expression? _smallestSafeWidgetContaining(
    Expression read,
    AllObserverTypeChecker checker,
  ) {
    AstNode? current = read.parent;
    while (current != null) {
      if (current is FunctionExpression &&
          !_isWidgetBuilderClosure(current, checker)) {
        return null;
      }
      if (current is Expression &&
          checker.isFlutterWidgetType(current.staticType)) {
        return current;
      }
      current = current.parent;
    }
    return null;
  }

  /// Whether [closure]'s own function type returns a Flutter `Widget` —
  /// the shape of an `itemBuilder`, an `Observer` builder,
  /// `MaterialApp.builder`, and similar "runs synchronously as part of a
  /// build" closures, as opposed to an event handler (`onPressed`,
  /// `onChanged`, ...), whose return type is not a `Widget`.
  bool _isWidgetBuilderClosure(
    FunctionExpression closure,
    AllObserverTypeChecker checker,
  ) {
    final type = closure.staticType;
    if (type is FunctionType) {
      return checker.isFlutterWidgetType(type.returnType);
    }
    return false;
  }

  /// Whether [node] is exactly the expression an enclosing `Observer(...)`
  /// builder returns as its root — duplicated from
  /// `wrap_with_observer_assist.dart`'s identical, semantically-resolved
  /// check (never based on identifier text) rather than shared, to avoid
  /// touching that already-tested assist for this addition — see
  /// `documentation/backlog.md`.
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

class _ReactiveValueReadFinder extends RecursiveAstVisitor<void> {
  _ReactiveValueReadFinder(this.target, this.checker);

  final SourceRange target;
  final AllObserverTypeChecker checker;
  Expression? best;

  bool _contains(AstNode node) {
    final selectionEnd = target.offset + target.length;
    return node.offset <= target.offset && node.end >= selectionEnd;
  }

  void _consider(Expression node) {
    if (!_contains(node)) return;
    final current = best;
    if (current == null || node.length < current.length) {
      best = node;
    }
  }

  bool _isWriteTarget(Expression expression) {
    final parent = expression.parent;
    if (parent is AssignmentExpression &&
        identical(parent.leftHandSide, expression)) {
      return true;
    }
    if (parent is PrefixExpression && identical(parent.operand, expression)) {
      return parent.operator.lexeme == '++' || parent.operator.lexeme == '--';
    }
    if (parent is PostfixExpression && identical(parent.operand, expression)) {
      return parent.operator.lexeme == '++' || parent.operator.lexeme == '--';
    }
    return false;
  }

  void _checkValueAccess(
    Expression node,
    Expression? valueTarget,
    String propertyName,
  ) {
    if (valueTarget == null || propertyName != 'value') return;
    if (_isWriteTarget(node)) return;
    final type = valueTarget.staticType;
    if (checker.isObservableType(type) || checker.isComputedType(type)) {
      _consider(node);
    }
  }

  @override
  void visitPropertyAccess(PropertyAccess node) {
    _checkValueAccess(node, node.target, node.propertyName.name);
    super.visitPropertyAccess(node);
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    _checkValueAccess(node, node.prefix, node.identifier.name);
    super.visitPrefixedIdentifier(node);
  }
}
