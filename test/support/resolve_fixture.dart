import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/error/error.dart';
import 'package:path/path.dart' as p;

/// Resolves a Dart file under `test/fixtures/consumer/lib/` and returns its
/// fully type-resolved [ResolvedUnitResult].
///
/// This lets rule tests exercise the exact same semantic checks
/// ([AllObserverTypeChecker] and friends) that the shipped lint rules use,
/// against a local Flutter fixture project that depends only on
/// `test/fixtures/fake_all_observer` and `test/fixtures/another_package` —
/// never on the real `all_observer` package or the network (see
/// `documentation/architecture.md`, "Testing strategy").
///
/// Prerequisite: `flutter pub get` must have been run once inside
/// `test/fixtures/consumer` (CI does this automatically; see
/// `.github/workflows/ci.yml`). If dependencies haven't been fetched yet,
/// this throws with a message pointing at that command.
Future<ResolvedUnitResult> resolveFixture(
  String fileName, {
  bool allowErrors = false,
}) async {
  final packageConfig = File(
    p.join(consumerFixtureRoot, '.dart_tool', 'package_config.json'),
  );
  if (!packageConfig.existsSync()) {
    throw StateError(
      'Fixture dependencies are not resolved yet. Run:\n'
      '  cd test/fixtures/consumer && flutter pub get\n'
      'then re-run the tests.',
    );
  }

  final collection = _collection ??= AnalysisContextCollection(
    includedPaths: [consumerFixtureRoot],
  );
  final path = p.normalize(p.join(consumerFixtureRoot, 'lib', fileName));
  final context = collection.contextFor(path);
  final result = await context.currentSession.getResolvedUnit(path);
  if (result is! ResolvedUnitResult) {
    throw StateError('Could not resolve $path: $result');
  }
  final errors = result.errors
      .where((error) => error.errorCode.errorSeverity == ErrorSeverity.ERROR)
      .toList();
  if (!allowErrors && errors.isNotEmpty) {
    throw StateError(
      'Fixture $fileName has analysis errors, results would be unreliable:\n'
      '${errors.join('\n')}',
    );
  }
  return result;
}

AnalysisContextCollection? _collection;

final String consumerFixtureRoot = p.normalize(
  p.join(Directory.current.path, 'test', 'fixtures', 'consumer'),
);
