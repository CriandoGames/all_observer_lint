import 'dart:io';

import 'package:all_observer_lint/src/assists/convert_change_notifier_field_assist.dart';
import 'package:analyzer/source/source_range.dart';
import 'package:test/test.dart';

import '../support/custom_lint_test_support.dart';
import '../support/resolve_fixture.dart';

void main() {
  group('ConvertChangeNotifierFieldAssist — available', () {
    test(
      'converts an explicit-type field + getter pair, leaving '
      'notifyListeners() untouched',
      () async {
        final result = await resolveFixture(
          'convert_change_notifier_field_available.dart',
        );
        final source = File(result.path).readAsStringSync();
        final offset = source.indexOf('_count = 0');
        final changes = await ConvertChangeNotifierFieldAssist().testRun(
          result,
          SourceRange(offset, 0),
        );

        expect(changes, hasLength(1));
        final transformed = applyPrioritizedChange(source, changes.single);

        expect(transformed, contains('final count = Observable(0);'));
        expect(transformed, isNot(contains('int get count => _count;')));
        expect(transformed, contains('count.value++;'));
        expect(transformed, contains('notifyListeners();'));
        expect(
          transformed,
          contains("import 'package:all_observer/all_observer.dart';"),
        );
      },
    );

    test('converts an inferred-type field + getter pair', () async {
      final result = await resolveFixture(
        'convert_change_notifier_field_available.dart',
      );
      final source = File(result.path).readAsStringSync();
      final offset = source.indexOf(
        '_enabled = false',
        source.indexOf('_FlagController'),
      );
      final changes = await ConvertChangeNotifierFieldAssist().testRun(
        result,
        SourceRange(offset, 0),
      );

      expect(changes, hasLength(1));
      final transformed = applyPrioritizedChange(source, changes.single);

      expect(transformed, contains('final enabled = Observable(false);'));
      expect(
        transformed,
        contains('enabled.value = !enabled.value;'),
      );
    });

    test(
      'preserves an explicit non-inferred type argument and rewrites a '
      'getter read inside a bare string-interpolation shorthand',
      () async {
        final result = await resolveFixture(
          'convert_change_notifier_field_available.dart',
        );
        final source = File(result.path).readAsStringSync();
        final offset = source.indexOf(
          '_score = 0',
          source.indexOf('_ScoreController'),
        );
        final changes = await ConvertChangeNotifierFieldAssist().testRun(
          result,
          SourceRange(offset, 0),
        );

        expect(changes, hasLength(1));
        final transformed = applyPrioritizedChange(source, changes.single);

        expect(
          transformed,
          contains('final score = Observable<num>(0);'),
        );
        expect(transformed, contains('score.value += amount;'));
        // Bare `$score` interpolation shorthand must gain explicit braces
        // so `.value` is actually evaluated, not appended as literal text.
        expect(transformed, contains(r'score: ${score.value}'));
      },
    );
  });

  group('ConvertChangeNotifierFieldAssist — unavailable', () {
    Future<void> expectUnavailable(
      String fileName,
      int Function(String source) locate,
    ) async {
      final result = await resolveFixture(fileName);
      final source = File(result.path).readAsStringSync();
      final offset = locate(source);
      final changes = await ConvertChangeNotifierFieldAssist().testRun(
        result,
        SourceRange(offset, 0),
      );
      expect(changes, isEmpty);
    }

    const fixture = 'convert_change_notifier_field_unavailable.dart';

    test('the enclosing class is public', () async {
      await expectUnavailable(
        fixture,
        (source) =>
            source.indexOf('_count = 0', source.indexOf('PublicController')),
      );
    });

    test('the class extends ChangeNotifier only indirectly', () async {
      await expectUnavailable(
        fixture,
        (source) => source.indexOf(
          '_count = 0',
          source.indexOf('_IndirectController'),
        ),
      );
    });

    test('the class has a mixin', () async {
      await expectUnavailable(
        fixture,
        (source) =>
            source.indexOf('_count = 0', source.indexOf('_MixinController')),
      );
    });

    test('notifyListeners is torn off as a callback', () async {
      await expectUnavailable(
        fixture,
        (source) => source.indexOf(
          '_count = 0',
          source.indexOf('_TearOffController'),
        ),
      );
    });

    test('this is exposed as a Listenable', () async {
      await expectUnavailable(
        fixture,
        (source) => source.indexOf(
          '_count = 0',
          source.indexOf('_ExposedController'),
        ),
      );
    });

    test('this is passed as an argument from inside the class', () async {
      await expectUnavailable(
        fixture,
        (source) => source.indexOf(
          '_count = 0',
          source.indexOf('_SelfPassingController'),
        ),
      );
    });

    test('the field is public', () async {
      await expectUnavailable(
        fixture,
        (source) => source.indexOf(
          'count = 0',
          source.indexOf('_PublicFieldController'),
        ),
      );
    });

    test('no matching getter exists', () async {
      await expectUnavailable(
        fixture,
        (source) =>
            source.indexOf('_count = 0', source.indexOf('_NoGetterController')),
      );
    });

    test('the getter is not a pure passthrough', () async {
      await expectUnavailable(
        fixture,
        (source) => source.indexOf(
          '_count = 0',
          source.indexOf('_ImpureGetterController'),
        ),
      );
    });

    test('the getter is referenced from outside the class', () async {
      await expectUnavailable(
        fixture,
        (source) =>
            source.indexOf('_count = 0', source.indexOf('_LeakedController')),
      );
    });
  });
}
