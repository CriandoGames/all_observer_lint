import 'dart:io';

import 'package:all_observer_lint/src/assists/wrap_with_observer_assist.dart';
import 'package:analyzer/source/source_range.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../support/custom_lint_test_support.dart';
import '../support/resolve_fixture.dart';

/// Runs the assist for [fixture] with the cursor at the first occurrence of
/// [marker] found at or after [anchor] (or from the start of the file if
/// [anchor] is `null`), applies the resulting change, formats it, and
/// compares against [goldenName]. Also re-runs the assist on the transformed
/// file — locating the same logical spot via [anchor] again, since import
/// insertion shifts raw offsets — to confirm idempotency (no further change
/// is offered).
Future<void> _expectGoldenWrap({
  required String fixture,
  required String marker,
  required String goldenName,
  String? anchor,
}) async {
  final result = await resolveFixture(fixture);
  final source = File(result.path).readAsStringSync();
  final offset = source.indexOf(marker, _anchorOffset(source, anchor));
  expect(offset, isNonNegative, reason: 'marker not found: $marker');
  final selection = SourceRange(offset, 0);
  final changes = await WrapWithObserverAssist().testRun(result, selection);
  expect(changes, hasLength(1));

  final transformed = applyPrioritizedChange(source, changes.single);
  final tempName = '_assist_$fixture';
  final tempFile = File(p.join(consumerFixtureRoot, 'lib', tempName));
  addTearDown(() {
    if (tempFile.existsSync()) tempFile.deleteSync();
  });
  tempFile.writeAsStringSync(transformed);
  final format = await Process.run('dart', ['format', tempFile.path]);
  expect(format.exitCode, 0, reason: '${format.stdout}\n${format.stderr}');

  final golden = File(
    p.join(Directory.current.path, 'test', 'goldens', goldenName),
  ).readAsStringSync();
  expect(tempFile.readAsStringSync(), golden);

  await resolveFixture(tempName);
  final transformedSource = tempFile.readAsStringSync();
  final rerun = await WrapWithObserverAssist().testRun(
    await resolveFixture(tempName),
    SourceRange(
      transformedSource.indexOf(
        marker,
        _anchorOffset(transformedSource, anchor),
      ),
      0,
    ),
  );
  expect(rerun, isEmpty, reason: 'the assist must be idempotent');
}

int _anchorOffset(String source, String? anchor) {
  if (anchor == null) return 0;
  final offset = source.indexOf(anchor);
  return offset < 0 ? 0 : offset;
}

void main() {
  group('import resolution / collision handling (unchanged)', () {
    final cases = {
      'wrap_observer_unprefixed.dart': 'wrap_observer_unprefixed.golden',
      'wrap_observer_prefixed.dart': 'wrap_observer_prefixed.golden',
      'wrap_observer_missing_import.dart':
          'wrap_observer_missing_import.golden',
      'wrap_observer_show.dart': 'wrap_observer_show.golden',
      'wrap_observer_hide.dart': 'wrap_observer_hide.golden',
      'wrap_observer_subclass_alias.dart':
          'wrap_observer_subclass_alias.golden',
      // Collision/shadowing cases: the assist must fall back to a uniquely
      // prefixed `all_observer` import instead of reusing/adding a bare
      // `Observer` reference that could resolve to the wrong thing.
      'wrap_observer_local_homonym.dart': 'wrap_observer_local_homonym.golden',
      'wrap_observer_local_shadow.dart': 'wrap_observer_local_shadow.golden',
      'wrap_observer_ambiguous_import.dart':
          'wrap_observer_ambiguous_import.golden',
      'wrap_observer_parameter_shadow.dart':
          'wrap_observer_parameter_shadow.golden',
    };

    for (final entry in cases.entries) {
      test('wraps selected Widget safely: ${entry.key}', () async {
        await _expectGoldenWrap(
          fixture: entry.key,
          marker: "Text('Total:",
          goldenName: entry.value,
        );
      });
    }
  });

  group('now available: permissive Wrap with Observer', () {
    test('Widget with no reactive read at all', () async {
      await _expectGoldenWrap(
        fixture: 'wrap_observer_plain_widget.dart',
        marker: "Text('Olá'",
        goldenName: 'wrap_observer_plain_widget.golden',
      );
    });

    test('Widget with watch(context)', () async {
      await _expectGoldenWrap(
        fixture: 'wrap_observer_watch.dart',
        marker: "Text('Total:",
        goldenName: 'wrap_observer_watch.golden',
      );
    });

    test('Widget inside a ListView.builder itemBuilder', () async {
      await _expectGoldenWrap(
        fixture: 'wrap_observer_list_builder.dart',
        marker: "Text('Item",
        goldenName: 'wrap_observer_list_builder.golden',
      );
    });

    test('Widget inside a Builder callback', () async {
      await _expectGoldenWrap(
        fixture: 'wrap_observer_builder_callback.dart',
        marker: 'MyContent()',
        goldenName: 'wrap_observer_builder_callback.golden',
      );
    });

    test('Widget inside a LayoutBuilder callback', () async {
      await _expectGoldenWrap(
        fixture: 'wrap_observer_layout_builder.dart',
        marker: r"Text('${constraints.maxWidth}",
        goldenName: 'wrap_observer_layout_builder.golden',
      );
    });

    test('Widget inside a dialog builder', () async {
      await _expectGoldenWrap(
        fixture: 'wrap_observer_dialog.dart',
        marker: "Text('Mensagem')",
        goldenName: 'wrap_observer_dialog.golden',
      );
    });

    test(
      'the AlertDialog itself is also wrappable, depending on cursor',
      () async {
        final result = await resolveFixture('wrap_observer_dialog.dart');
        final source = File(result.path).readAsStringSync();
        final offset = source.indexOf('AlertDialog(');
        final changes = await WrapWithObserverAssist().testRun(
          result,
          SourceRange(offset, 0),
        );
        expect(changes, hasLength(1));
      },
    );

    test('Widget assigned to a `final Widget` variable', () async {
      await _expectGoldenWrap(
        fixture: 'wrap_observer_widget_variable.dart',
        marker: 'MyContent()',
        // The fixture has two `MyContent()` occurrences: one inside the
        // `createContent()` helper (covered by the next test) and one
        // inside `HolderView.build`. Anchor past the helper so this test
        // targets the variable-assignment occurrence.
        anchor: 'class HolderView',
        goldenName: 'wrap_observer_widget_variable.golden',
      );
    });

    test('Widget returned by a helper method', () async {
      final result = await resolveFixture(
        'wrap_observer_widget_variable.dart',
      );
      final source = File(result.path).readAsStringSync();
      final offset = source.indexOf(
        'MyContent()',
        source.indexOf('createContent'),
      );
      final changes = await WrapWithObserverAssist().testRun(
        result,
        SourceRange(offset, 0),
      );
      expect(changes, hasLength(1));
    });

    test('Widget inside a Widget collection (Text element)', () async {
      await _expectGoldenWrap(
        fixture: 'wrap_observer_widget_list.dart',
        marker: "Text('A')",
        goldenName: 'wrap_observer_widget_list.golden',
      );
    });

    test('Widget inside a Widget collection (sibling element)', () async {
      final result = await resolveFixture('wrap_observer_widget_list.dart');
      final source = File(result.path).readAsStringSync();
      final offset = source.indexOf('MyCard()');
      final changes = await WrapWithObserverAssist().testRun(
        result,
        SourceRange(offset, 0),
      );
      expect(changes, hasLength(1));
    });

    test(
      'Widget nested inside an existing Observer (splitting scopes)',
      () async {
        await _expectGoldenWrap(
          fixture: 'wrap_observer_inside_observer.dart',
          marker: r"Text('${first.value}')",
          goldenName: 'wrap_observer_inside_observer.golden',
        );
      },
    );

    test(
      'Widget resolved as a Widget even with an unresolved sibling argument',
      () async {
        final result = await resolveFixture(
          'wrap_observer_partially_unresolved.dart',
          allowErrors: true,
        );
        final source = File(result.path).readAsStringSync();
        final offset = source.indexOf('Text(label');
        final changes = await WrapWithObserverAssist().testRun(
          result,
          SourceRange(offset, 0),
        );
        expect(changes, hasLength(1));
      },
    );

    test(
      'a Widget-typed callback previously rejected for having no reads '
      '(TextButton)',
      () async {
        final result = await resolveFixture('wrap_observer_negative.dart');
        final source = File(result.path).readAsStringSync();
        final offset = source.indexOf('TextButton(');
        final changes = await WrapWithObserverAssist().testRun(
          result,
          SourceRange(offset, 0),
        );
        expect(changes, hasLength(1));
      },
    );
  });

  group('still unavailable: conditions required for valid code', () {
    test('expression is not a Widget', () async {
      final result = await resolveFixture('wrap_observer_plain_widget.dart');
      final source = File(result.path).readAsStringSync();
      // `value + 1` is not nested inside any Widget-returning expression at
      // all (unlike a string literal sitting inside `Text(...)`, which
      // *does* resolve to the enclosing Widget via the smallest-widget rule
      // — see the comment on `addOne` in the fixture).
      final offset = source.indexOf('value + 1');
      final changes = await WrapWithObserverAssist().testRun(
        result,
        SourceRange(offset, 0),
      );
      expect(changes, isEmpty);
    });

    test('const context would become invalid', () async {
      final result = await resolveFixture('wrap_observer_const_context.dart');
      final source = File(result.path).readAsStringSync();
      final offset = source.indexOf("Text('Fixed')");
      final changes = await WrapWithObserverAssist().testRun(
        result,
        SourceRange(offset, 0),
      );
      expect(changes, isEmpty);
    });

    test('selected node is the Observer creation itself', () async {
      final result = await resolveFixture('wrap_observer_negative.dart');
      final source = File(result.path).readAsStringSync();
      final offset = source.indexOf('Observer(() => Text');
      final changes = await WrapWithObserverAssist().testRun(
        result,
        SourceRange(offset, 0),
      );
      expect(changes, isEmpty);
    });

    test(
      'Widget is already exactly the root of an Observer builder (arrow body)',
      () async {
        final result = await resolveFixture('wrap_observer_already_root.dart');
        final source = File(result.path).readAsStringSync();
        final offset = source.indexOf(r"Text('${count.value}')");
        final changes = await WrapWithObserverAssist().testRun(
          result,
          SourceRange(offset, 0),
        );
        expect(changes, isEmpty);
      },
    );

    test(
      'Widget is already exactly the root of an Observer builder (block body)',
      () async {
        final result = await resolveFixture(
          'wrap_observer_already_root_block.dart',
        );
        final source = File(result.path).readAsStringSync();
        final offset = source.indexOf(r"Text('${count.value}')");
        final changes = await WrapWithObserverAssist().testRun(
          result,
          SourceRange(offset, 0),
        );
        expect(changes, isEmpty);
      },
    );

    test('type is completely unresolved', () async {
      final result = await resolveFixture(
        'wrap_observer_unresolved_type.dart',
        allowErrors: true,
      );
      final source = File(result.path).readAsStringSync();
      final offset = source.indexOf('UndefinedWidgetThing()');
      final changes = await WrapWithObserverAssist().testRun(
        result,
        SourceRange(offset, 0),
      );
      expect(changes, isEmpty);
    });
  });
}
