import 'dart:io';

import 'package:all_observer_lint/src/rules/copied_reactive_collection_outside_tracking.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'package:test/test.dart';

import '../support/resolve_fixture.dart';

void main() {
  group('copied_reactive_collection_outside_tracking', () {
    test(
      'flags a reactive collection copied to a plain snapshot before an '
      'Observer that only reads the snapshot',
      () async {
        final result = await resolveFixture(
          'copied_reactive_collection_outside_tracking_invalid.dart',
        );
        final rule = CopiedReactiveCollectionOutsideTracking(
          configs: await _configs(),
        );

        final errors = await rule.testRun(result);

        // VisibleItemsWidget, FilteredTagsWidget, MapKeysWidget.
        expect(errors, hasLength(3));
        expect(
          errors.map((error) => error.errorCode.name),
          everyElement(rule.code.name),
        );

        // Assert each individual class is the one actually flagged (not
        // just that *some* 3 diagnostics were produced) — a count-only
        // assertion previously let a real gap slip through undetected: two
        // classes fired twice while a third (`MapKeysWidget`, snapshotting
        // via `counters.keys.toList()`) never fired at all, yet the total
        // still happened to read 3 in a stale version of this test.
        final source = File(result.path).readAsStringSync();
        void expectFlaggedNear(String needle) {
          final offset = source.indexOf(needle);
          expect(offset, greaterThanOrEqualTo(0), reason: '"$needle" not found in fixture');
          expect(
            errors.any((e) => e.offset <= offset && e.offset + e.length >= 0 && (offset - e.offset).abs() < 200),
            isTrue,
            reason: 'no diagnostic near "$needle" (offset $offset)',
          );
        }

        expectFlaggedNear('visibleItems = items.toList()');
        expectFlaggedNear('snapshot = tags.toSet()');
        expectFlaggedNear('keySnapshot = counters.keys.toList()');
      },
    );

    test(
      'does not flag when the original is also read in the same tracking '
      'scope, the snapshot is reassigned, the source is a plain List, the '
      'snapshot is unused, or the reference was kept (not copied)',
      () async {
        final result = await resolveFixture(
          'copied_reactive_collection_outside_tracking_valid.dart',
        );
        final rule = CopiedReactiveCollectionOutsideTracking(
          configs: await _configs(),
        );

        final errors = await rule.testRun(result);

        expect(errors, isEmpty);
      },
    );
  });
}

Future<CustomLintConfigs> _configs() async {
  final packageConfig = await parsePackageConfig(Directory.current);
  return CustomLintConfigs.parse(null, packageConfig);
}
