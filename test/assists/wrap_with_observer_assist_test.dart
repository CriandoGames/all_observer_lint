import 'dart:io';

import 'package:all_observer_lint/src/assists/wrap_with_observer_assist.dart';
import 'package:analyzer/source/source_range.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../support/custom_lint_test_support.dart';
import '../support/resolve_fixture.dart';

void main() {
  final cases = {
    'wrap_observer_unprefixed.dart': 'wrap_observer_unprefixed.golden',
    'wrap_observer_prefixed.dart': 'wrap_observer_prefixed.golden',
    'wrap_observer_missing_import.dart': 'wrap_observer_missing_import.golden',
    'wrap_observer_show.dart': 'wrap_observer_show.golden',
    'wrap_observer_hide.dart': 'wrap_observer_hide.golden',
    'wrap_observer_subclass_alias.dart': 'wrap_observer_subclass_alias.golden',
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
      final result = await resolveFixture(entry.key);
      final source = File(result.path).readAsStringSync();
      final selection = SourceRange(source.indexOf("Text('Total:"), 0);
      final changes = await WrapWithObserverAssist().testRun(result, selection);
      expect(changes, hasLength(1));

      final transformed = applyPrioritizedChange(source, changes.single);
      final tempName = '_assist_${entry.key}';
      final tempFile = File(p.join(consumerFixtureRoot, 'lib', tempName));
      addTearDown(() {
        if (tempFile.existsSync()) tempFile.deleteSync();
      });
      tempFile.writeAsStringSync(transformed);
      final format = await Process.run('dart', ['format', tempFile.path]);
      expect(format.exitCode, 0, reason: '${format.stdout}\n${format.stderr}');

      final golden = File(
        p.join(Directory.current.path, 'test', 'goldens', entry.value),
      ).readAsStringSync();
      expect(tempFile.readAsStringSync(), golden);

      await resolveFixture(tempName);
      final rerun = await WrapWithObserverAssist().testRun(
        await resolveFixture(tempName),
        SourceRange(tempFile.readAsStringSync().indexOf("Text('Total:"), 0),
      );
      expect(rerun, isEmpty, reason: 'the assist must be idempotent');
    });
  }

  test('is unavailable for callbacks, Observer, and watch(context)', () async {
    final result = await resolveFixture('wrap_observer_negative.dart');
    final source = File(result.path).readAsStringSync();
    final assist = WrapWithObserverAssist();

    for (final marker in [
      'TextButton(',
      r"Text('${count.value}')",
      r"Text('${count.watch",
    ]) {
      final offset = source.indexOf(marker);
      expect(offset, isNonNegative, reason: marker);
      expect(await assist.testRun(result, SourceRange(offset, 0)), isEmpty);
    }
  });
}
