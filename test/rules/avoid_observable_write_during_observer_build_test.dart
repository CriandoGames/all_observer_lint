import 'package:all_observer_lint/src/utils/all_observer_type_checker.dart';
import 'package:all_observer_lint/src/utils/reactive_write_detector.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:test/test.dart';

import '../support/resolve_fixture.dart';

void main() {
  final checker = AllObserverTypeChecker();
  final writeDetector = ReactiveWriteDetector(checker);

  int countOffenses(CompilationUnit unit) {
    var count = 0;
    unit.accept(
      _Visitor(checker, (callback) {
        count += writeDetector
            .findIn(callback, includeNestedFunctions: false)
            .length;
      }),
    );
    return count;
  }

  group('avoid_observable_write_during_observer_build', () {
    test(
      'flags conditional and unconditional writes inside Observer',
      () async {
        final result = await resolveFixture('observer_write_invalid.dart');
        expect(countOffenses(result.unit), 2);
      },
    );

    test('does not flag reads, or writes deferred to an event-handler '
        'closure declared inside Observer', () async {
      final result = await resolveFixture('observer_write_valid.dart');
      expect(countOffenses(result.unit), 0);
    });

    test(
      'flags ObservableList mutations and replacements inside Observer '
      'build',
      () async {
        final result = await resolveFixture(
          'observer_write_collection_invalid.dart',
        );
        // MutatesListDuringObserverBuild: items.add(0) (1)
        // ReplacesListDuringObserverBuild: items.assignAll([1, 2]) (1)
        expect(countOffenses(result.unit), 2);
      },
    );

    test(
      'does not flag reactive-collection reads, or a mutation deferred to '
      'an event-handler closure declared inside Observer',
      () async {
        final result = await resolveFixture(
          'observer_write_collection_valid.dart',
        );
        expect(countOffenses(result.unit), 0);
      },
    );
  });
}

class _Visitor extends RecursiveAstVisitor<void> {
  _Visitor(this._checker, this._onCallback);

  final AllObserverTypeChecker _checker;
  final void Function(FunctionExpression) _onCallback;

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (_checker.isObserverWidgetCreation(node)) {
      for (final argument in node.argumentList.arguments) {
        final value = argument is NamedExpression
            ? argument.expression
            : argument;
        if (value is FunctionExpression) {
          _onCallback(value);
          break;
        }
      }
    }
    super.visitInstanceCreationExpression(node);
  }
}
