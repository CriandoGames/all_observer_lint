import 'dart:io';

import 'package:all_observer_lint/src/assists/wrap_smallest_reactive_subtree_assist.dart';
import 'package:analyzer/source/source_range.dart';
import 'package:test/test.dart';

import '../support/custom_lint_test_support.dart';
import '../support/resolve_fixture.dart';

void main() {
  group('WrapSmallestReactiveSubtreeAssist — available', () {
    test('wraps only the Text containing the read, not the Column', () async {
      final result = await resolveFixture(
        'wrap_smallest_reactive_subtree_available.dart',
      );
      final source = File(result.path).readAsStringSync();
      final offset = source.indexOf('count.value');
      final changes = await WrapSmallestReactiveSubtreeAssist().testRun(
        result,
        SourceRange(offset, 0),
      );

      expect(changes, hasLength(1));
      final transformed = applyPrioritizedChange(source, changes.single);
      expect(
        transformed,
        contains("Observer(\n  () => Text('\${count.value}'),\n)"),
      );
      // The surrounding Column/Footer must remain untouched, outside the
      // Observer wrap.
      expect(transformed, contains("const Text('Title')"));
      expect(transformed, contains('const Footer()'));
      expect(transformed, isNot(contains('Observer(\n  () => Column(')));
    });

    test('wraps the whole Text when it contains two reads', () async {
      final result = await resolveFixture(
        'wrap_smallest_reactive_subtree_available.dart',
      );
      final source = File(result.path).readAsStringSync();
      final offset = source.indexOf('first.value} \${second');
      final changes = await WrapSmallestReactiveSubtreeAssist().testRun(
        result,
        SourceRange(offset, 0),
      );

      expect(changes, hasLength(1));
      final transformed = applyPrioritizedChange(source, changes.single);
      expect(
        transformed,
        contains(r'Observer(' '\n' r"  () => Text('${first.value} ${second.value}'),"),
      );
    });

    test(
      'triggered on the first of two sibling Texts wraps only that Text',
      () async {
        final result = await resolveFixture(
          'wrap_smallest_reactive_subtree_available.dart',
        );
        final source = File(result.path).readAsStringSync();
        final offset = source.indexOf(r"first.value}'");
        final changes = await WrapSmallestReactiveSubtreeAssist().testRun(
          result,
          SourceRange(offset, 0),
        );

        expect(changes, hasLength(1));
        final transformed = applyPrioritizedChange(source, changes.single);
        expect(
          transformed,
          contains(r'Observer(' '\n' r"  () => Text('${first.value}'),"),
        );
        // The second Text (and the Row) must remain untouched.
        expect(transformed, contains(r"Text('${second.value}')"));
        expect(transformed, isNot(contains('Observer(\n  () => Row(')));
      },
    );

    test(
      'a read inside an itemBuilder (widget-builder closure) still wraps '
      'just the returned Text',
      () async {
        final result = await resolveFixture(
          'wrap_smallest_reactive_subtree_available.dart',
        );
        final source = File(result.path).readAsStringSync();
        final offset = source.indexOf('items[index].value');
        final changes = await WrapSmallestReactiveSubtreeAssist().testRun(
          result,
          SourceRange(offset, 0),
        );

        expect(changes, hasLength(1));
        final transformed = applyPrioritizedChange(source, changes.single);
        expect(
          transformed,
          contains(
            r'Observer(' '\n' r"  () => Text('${items[index].value}'),",
          ),
        );
      },
    );
  });

  group('WrapSmallestReactiveSubtreeAssist — unavailable', () {
    test('read lives inside an event-handler closure', () async {
      final result = await resolveFixture(
        'wrap_smallest_reactive_subtree_unavailable.dart',
      );
      final source = File(result.path).readAsStringSync();
      final offset = source.indexOf('count.value');
      final changes = await WrapSmallestReactiveSubtreeAssist().testRun(
        result,
        SourceRange(offset, 0),
      );
      expect(changes, isEmpty);
    });

    test('Widget is already exactly the root of an Observer builder', () async {
      final result = await resolveFixture(
        'wrap_smallest_reactive_subtree_unavailable.dart',
      );
      final source = File(result.path).readAsStringSync();
      final offset = source.indexOf(
        'count.value',
        source.indexOf('AlreadyWrapped'),
      );
      final changes = await WrapSmallestReactiveSubtreeAssist().testRun(
        result,
        SourceRange(offset, 0),
      );
      expect(changes, isEmpty);
    });

    test('no reactive read anywhere near the selection', () async {
      final result = await resolveFixture(
        'wrap_smallest_reactive_subtree_unavailable.dart',
      );
      final source = File(result.path).readAsStringSync();
      final offset = source.indexOf("Text('Fixed')");
      final changes = await WrapSmallestReactiveSubtreeAssist().testRun(
        result,
        SourceRange(offset, 0),
      );
      expect(changes, isEmpty);
    });
  });
}
