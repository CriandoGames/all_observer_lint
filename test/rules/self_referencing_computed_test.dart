import 'package:all_observer_lint/src/utils/all_observer_type_checker.dart';
import 'package:all_observer_lint/src/utils/self_referencing_computed_detector.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:test/test.dart';

import '../support/resolve_fixture.dart';

void main() {
  final checker = AllObserverTypeChecker();
  final detector = SelfReferencingComputedDetector(checker);

  int countOffenses(CompilationUnit unit) {
    var count = 0;
    unit.accept(_Visitor(detector, () => count++));
    return count;
  }

  group('self_referencing_computed', () {
    test('flags direct self references in Computed callbacks', () async {
      final result = await resolveFixture(
        'self_referencing_computed_invalid.dart',
      );
      expect(countOffenses(result.unit), 3);
    });

    test('does not flag other values, shadowed names, or homonyms', () async {
      final result = await resolveFixture(
        'self_referencing_computed_valid.dart',
      );
      expect(countOffenses(result.unit), 0);
    });
  });
}

class _Visitor extends RecursiveAstVisitor<void> {
  _Visitor(this._detector, this._onOffense);

  final SelfReferencingComputedDetector _detector;
  final void Function() _onOffense;

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (_detector.isSelfReferencingComputed(node)) {
      _onOffense();
    }
    super.visitInstanceCreationExpression(node);
  }
}
