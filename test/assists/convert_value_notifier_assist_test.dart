import 'dart:io';

import 'package:all_observer_lint/src/assists/convert_value_notifier_assist.dart';
import 'package:analyzer/source/source_range.dart';
import 'package:test/test.dart';

import '../support/custom_lint_test_support.dart';
import '../support/resolve_fixture.dart';

void main() {
  group('ConvertValueNotifierAssist — available', () {
    test(
      'converts an explicitly-typed field, leaving .value untouched and '
      'rewriting .dispose() to .close()',
      () async {
        final result = await resolveFixture(
          'convert_value_notifier_available.dart',
        );
        final source = File(result.path).readAsStringSync();
        final offset = source.indexOf('_count = ValueNotifier(0)');
        final changes = await ConvertValueNotifierAssist().testRun(
          result,
          SourceRange(offset, 0),
        );

        expect(changes, hasLength(1));
        final transformed = applyPrioritizedChange(source, changes.single);

        expect(
          transformed,
          contains('final Observable<int> _count = Observable(0);'),
        );
        expect(transformed, contains('_count.value++;'));
        expect(transformed, contains('_count.close();'));
        expect(transformed, contains('super.dispose();'));
        expect(
          transformed,
          contains("import 'package:all_observer/all_observer.dart';"),
        );
      },
    );

    test(
      'converts an inferred-type field with no dispose() at all',
      () async {
        final result = await resolveFixture(
          'convert_value_notifier_available.dart',
        );
        final source = File(result.path).readAsStringSync();
        final offset = source.indexOf(
          '_flag = ValueNotifier(false)',
          source.indexOf('FlagWidget'),
        );
        final changes = await ConvertValueNotifierAssist().testRun(
          result,
          SourceRange(offset, 0),
        );

        expect(changes, hasLength(1));
        final transformed = applyPrioritizedChange(source, changes.single);

        expect(transformed, contains('final _flag = Observable(false);'));
        expect(transformed, contains('_flag.value = !_flag.value;'));
      },
    );

    test(
      'leaves a balanced addListener/removeListener pair completely '
      'untouched',
      () async {
        final result = await resolveFixture(
          'convert_value_notifier_available.dart',
        );
        final source = File(result.path).readAsStringSync();
        final offset = source.indexOf(
          '_score = ValueNotifier(0)',
          source.indexOf('ScoreWidget'),
        );
        final changes = await ConvertValueNotifierAssist().testRun(
          result,
          SourceRange(offset, 0),
        );

        expect(changes, hasLength(1));
        final transformed = applyPrioritizedChange(source, changes.single);

        expect(
          transformed,
          contains('final Observable<int> _score = Observable(0);'),
        );
        expect(
          transformed,
          contains('_score.addListener(_onScoreChanged);'),
        );
        expect(
          transformed,
          contains('_score.removeListener(_onScoreChanged);'),
        );
        expect(transformed, contains('_score.close();'));
      },
    );
  });

  group('ConvertValueNotifierAssist — unavailable', () {
    Future<void> expectUnavailable(
      String fileName,
      int Function(String source) locate,
    ) async {
      final result = await resolveFixture(fileName);
      final source = File(result.path).readAsStringSync();
      final offset = locate(source);
      final changes = await ConvertValueNotifierAssist().testRun(
        result,
        SourceRange(offset, 0),
      );
      expect(changes, isEmpty);
    }

    test('the field is public', () async {
      await expectUnavailable(
        'convert_value_notifier_unavailable.dart',
        (source) => source.indexOf(
          'count = ValueNotifier(0)',
          source.indexOf('PublicFieldWidget'),
        ),
      );
    });

    test('the field is passed to a ValueListenableBuilder', () async {
      await expectUnavailable(
        'convert_value_notifier_unavailable.dart',
        (source) => source.indexOf(
          '_count = ValueNotifier(0)',
          source.indexOf('BuilderConsumerWidget'),
        ),
      );
    });

    test('addListener has no matching removeListener', () async {
      await expectUnavailable(
        'convert_value_notifier_unavailable.dart',
        (source) => source.indexOf(
          '_count = ValueNotifier(0)',
          source.indexOf('UnbalancedListenerWidget'),
        ),
      );
    });

    test('the initializer is not a direct ValueNotifier(...) construction', () async {
      await expectUnavailable(
        'convert_value_notifier_unavailable.dart',
        (source) => source.indexOf(
          '_count = _makeCounter()',
          source.indexOf('IndirectInitializerWidget'),
        ),
      );
    });
  });
}
