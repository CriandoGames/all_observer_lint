import 'package:all_observer_lint/src/utils/migration_safety_result.dart';
import 'package:test/test.dart';

void main() {
  group('MigrationSafetyResult', () {
    test('silent() has no capability and is fully unavailable', () {
      final result = MigrationSafetyResult.silent(['unresolved element']);

      expect(result.isSilent, isTrue);
      expect(result.allowsRule, isFalse);
      expect(result.allowsAssist, isFalse);
      expect(result.allowsQuickFix, isFalse);
      expect(result.blockReasons, ['unresolved element']);
    });

    test('safe(rule) only allows a diagnostic, no transformation', () {
      final result = MigrationSafetyResult.safe(MigrationCapability.rule);

      expect(result.isSilent, isFalse);
      expect(result.allowsRule, isTrue);
      expect(result.allowsAssist, isFalse);
      expect(result.allowsQuickFix, isFalse);
    });

    test('safe(assist) allows rule and assist but not quick fix', () {
      final result = MigrationSafetyResult.safe(MigrationCapability.assist);

      expect(result.allowsRule, isTrue);
      expect(result.allowsAssist, isTrue);
      expect(result.allowsQuickFix, isFalse);
    });

    test('safe(quickFix) allows every capability', () {
      final result = MigrationSafetyResult.safe(MigrationCapability.quickFix);

      expect(result.allowsRule, isTrue);
      expect(result.allowsAssist, isTrue);
      expect(result.allowsQuickFix, isTrue);
    });

    test('blockedFromHigherReasons documents why a higher level was not reached', () {
      final result = MigrationSafetyResult.safe(
        MigrationCapability.assist,
        blockedFromHigherReasons: ['stack trace would have to be invented'],
      );

      expect(result.blockReasons, ['stack trace would have to be invented']);
    });
  });
}
