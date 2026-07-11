import 'package:all_observer_lint/src/utils/all_observer_type_checker.dart';
import 'package:all_observer_lint/src/utils/build_context_detector.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:test/test.dart';

import '../support/resolve_fixture.dart';

/// This test reimplements the rule's decision logic directly against
/// resolved fixtures rather than driving the `custom_lint` runner, but
/// mirrors `WatchOnlyInsideBuild.run` exactly (see that file) so a
/// divergence between the two would be a bug in one of them.
void main() {
  const checker = AllObserverTypeChecker();
  final finder = RebuildScopeFinder(checker);

  int countOffenses(CompilationUnit unit) {
    var count = 0;
    unit.accept(_Visitor(checker, finder, () => count++));
    return count;
  }

  group('watch_only_inside_build', () {
    test(
      'flags watch(context) called from a non-build method using an '
      'ambient context (e.g. State.context)',
      () async {
        final result =
            await resolveFixture('watch_only_inside_build_invalid.dart');
        expect(countOffenses(result.unit), 1);
      },
    );

    test(
      'does not flag watch(context) inside build, inside Observer, or in a '
      'method that itself only accepts BuildContext (ambiguous, skipped)',
      () async {
        final result =
            await resolveFixture('watch_only_inside_build_valid.dart');
        expect(countOffenses(result.unit), 0);
      },
    );
  });
}

class _Visitor extends RecursiveAstVisitor<void> {
  _Visitor(this._checker, this._finder, this._onOffense);

  final AllObserverTypeChecker _checker;
  final RebuildScopeFinder _finder;
  final void Function() _onOffense;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (_checker.isWatchInvocation(node)) {
      final boundary = _enclosingMethodBoundary(node);
      final insideRebuildScope = _finder.isInsideRebuildScope(node);
      if (boundary != null &&
          !insideRebuildScope &&
          !_looksAmbiguous(boundary)) {
        _onOffense();
      }
    }
    super.visitMethodInvocation(node);
  }

  MethodDeclaration? _enclosingMethodBoundary(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is MethodDeclaration) return current;
      if (current is FunctionExpression || current is FunctionDeclaration) {
        return null;
      }
      current = current.parent;
    }
    return null;
  }

  bool _looksAmbiguous(MethodDeclaration method) {
    if (method.name.lexeme == 'build') return false;
    for (final parameter in method.parameters?.parameters ?? const []) {
      if (parameter.declaredElement?.type.element?.name == 'BuildContext') {
        return true;
      }
    }
    return false;
  }
}
