import 'dart:io';

import 'package:all_observer_lint/src/assists/extract_to_computed_assist.dart';
import 'package:analyzer/source/source_range.dart';
import 'package:test/test.dart';

import '../support/custom_lint_test_support.dart';
import '../support/resolve_fixture.dart';

void main() {
  group('ExtractReactiveExpressionToComputedAssist — available', () {
    test(
      'extracts a binary expression reading two distinct reactive values',
      () async {
        final result = await resolveFixture(
          'extract_to_computed_available.dart',
        );
        final source = File(result.path).readAsStringSync();
        final offset = source.indexOf('price.value * quantity.value');
        final changes = await ExtractReactiveExpressionToComputedAssist()
            .testRun(result, SourceRange(offset, 0));

        expect(changes, hasLength(1));
        final transformed = applyPrioritizedChange(source, changes.single);

        expect(
          transformed,
          contains(
            'late final computedValue = '
            'Computed(() => price.value * quantity.value);',
          ),
        );
        expect(transformed, contains(r"Text('${computedValue.value}')"));
        expect(
          transformed,
          contains('computedValue.close();\n    super.dispose();'),
        );
      },
    );

    test(
      'extracts a whole string interpolation when neither half alone reads '
      'two distinct values',
      () async {
        final result = await resolveFixture(
          'extract_to_computed_available.dart',
        );
        final source = File(result.path).readAsStringSync();
        final offset = source.indexOf(
          'first.value',
          source.indexOf('NameWidget'),
        );
        final changes = await ExtractReactiveExpressionToComputedAssist()
            .testRun(result, SourceRange(offset, 0));

        expect(changes, hasLength(1));
        final transformed = applyPrioritizedChange(source, changes.single);

        expect(
          transformed,
          contains(
            "late final computedValue = Computed(() => '"
            r"${first.value} ${last.value}"
            "');",
          ),
        );
        expect(transformed, contains('Text(computedValue.value)'));
      },
    );

    test('falls back to computedValue2 when computedValue is already '
        'declared', () async {
      final result = await resolveFixture(
        'extract_to_computed_available.dart',
      );
      final source = File(result.path).readAsStringSync();
      final offset = source.indexOf(
        'price.value * quantity.value',
        source.indexOf('CollisionWidget'),
      );
      final changes = await ExtractReactiveExpressionToComputedAssist()
          .testRun(result, SourceRange(offset, 0));

      expect(changes, hasLength(1));
      final transformed = applyPrioritizedChange(source, changes.single);

      expect(
        transformed,
        contains(
          'late final computedValue2 = '
          'Computed(() => price.value * quantity.value);',
        ),
      );
      expect(transformed, contains(r"Text('${computedValue2.value}')"));
      expect(
        transformed,
        contains('computedValue2.close();\n    super.dispose();'),
      );
    });

    test(
      'a named-argument label is never mistaken for a local/parameter '
      'dependency',
      () async {
        final result = await resolveFixture(
          'extract_to_computed_available.dart',
        );
        final source = File(result.path).readAsStringSync();
        final offset = source.indexOf(
          'width.value',
          source.indexOf('BoxWidget'),
        );
        final changes = await ExtractReactiveExpressionToComputedAssist()
            .testRun(result, SourceRange(offset, 0));

        expect(changes, hasLength(1));
        final transformed = applyPrioritizedChange(source, changes.single);

        expect(
          transformed,
          contains(
            'late final computedValue = Computed(() => '
            'SizedBox(width: width.value, height: height.value));',
          ),
        );
        expect(transformed, contains('() => computedValue.value'));
      },
    );

    test(
      'falls back to a uniquely prefixed import when a local Computed '
      'homonym exists in the file',
      () async {
        final result = await resolveFixture(
          'extract_to_computed_import_collision.dart',
        );
        final source = File(result.path).readAsStringSync();
        final offset = source.indexOf('price.value * quantity.value');
        final changes = await ExtractReactiveExpressionToComputedAssist()
            .testRun(result, SourceRange(offset, 0));

        expect(changes, hasLength(1));
        final transformed = applyPrioritizedChange(source, changes.single);

        expect(
          transformed,
          contains(
            "import 'package:all_observer/all_observer.dart' as allObserver;",
          ),
        );
        expect(
          transformed,
          contains(
            'late final computedValue = allObserver.Computed(() => '
            'price.value * quantity.value);',
          ),
        );
        expect(transformed, contains(r"Text('${computedValue.value}')"));
        // The local `Computed` homonym class itself must be left untouched.
        expect(transformed, contains('class Computed {'));
      },
    );
  });

  group('ExtractReactiveExpressionToComputedAssist — unavailable', () {
    Future<void> expectUnavailable(String fileName, int Function(String source) locate) async {
      final result = await resolveFixture(fileName);
      final source = File(result.path).readAsStringSync();
      final offset = locate(source);
      final changes = await ExtractReactiveExpressionToComputedAssist()
          .testRun(result, SourceRange(offset, 0));
      expect(changes, isEmpty);
    }

    test('only one distinct reactive value is read', () async {
      await expectUnavailable(
        'extract_to_computed_unavailable.dart',
        (source) => source.indexOf('count.value'),
      );
    });

    test('a method call sits between the two reads', () async {
      await expectUnavailable(
        'extract_to_computed_unavailable.dart',
        (source) =>
            source.indexOf('price.value', source.indexOf('ImpureCallWidget')),
      );
    });

    test('one of the two reactive values is a local variable, not a field', () async {
      await expectUnavailable(
        'extract_to_computed_unavailable.dart',
        (source) => source.indexOf(
          'price.value * quantity.value',
          source.indexOf('LocalDependencyWidget'),
        ),
      );
    });

    test('one of the two reads is reached through widget.', () async {
      await expectUnavailable(
        'extract_to_computed_unavailable.dart',
        (source) => source.indexOf(
          'widget.price.value',
          source.indexOf('WidgetDependencyWidget'),
        ),
      );
    });

    test('the candidate expression references BuildContext', () async {
      await expectUnavailable(
        'extract_to_computed_unavailable.dart',
        (source) => source.indexOf(
          'context.mounted',
          source.indexOf('ContextAccessWidget'),
        ),
      );
    });

    test('the owner is a StatelessWidget with no dispose()', () async {
      await expectUnavailable(
        'extract_to_computed_unavailable.dart',
        (source) => source.indexOf(
          'price.value * quantity.value',
          source.indexOf('StatelessPriceWidget'),
        ),
      );
    });
  });
}
