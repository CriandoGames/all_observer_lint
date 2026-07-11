import 'package:all_observer_lint/src/utils/all_observer_type_checker.dart';
import 'package:all_observer_lint/src/utils/build_context_detector.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:test/test.dart';

import '../support/resolve_fixture.dart';

void main() {
  const checker = AllObserverTypeChecker();
  final finder = RebuildScopeFinder(checker);

  int countOffenses(CompilationUnit unit) {
    var count = 0;
    unit.accept(
      _Visitor(
        (node) =>
            checker.isEffectOrWorkerInvocation(node) &&
            finder.isInsideRebuildScope(node),
        () => count++,
      ),
    );
    return count;
  }

  group('avoid_effect_creation_in_build', () {
    test(
      'flags effect/ever/debounce registered in build or Observer',
      () async {
        final result = await resolveFixture(
          'effect_creation_in_build_invalid.dart',
        );
        expect(countOffenses(result.unit), 3);
      },
    );

    test(
      'does not flag workers registered in initState or event handlers',
      () async {
        final result = await resolveFixture(
          'effect_creation_in_build_valid.dart',
        );
        expect(countOffenses(result.unit), 0);
      },
    );
  });
}

class _Visitor extends RecursiveAstVisitor<void> {
  _Visitor(this._matches, this._onOffense);

  final bool Function(MethodInvocation) _matches;
  final void Function() _onOffense;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (_matches(node)) _onOffense();
    super.visitMethodInvocation(node);
  }
}
