import 'package:all_observer_lint/src/localization/diagnostic_message_key.dart';
import 'package:all_observer_lint/src/localization/diagnostic_messages.dart';
import 'package:test/test.dart';

void main() {
  group('DiagnosticMessages', () {
    test('every message key has non-empty English and pt-BR text', () {
      final en = DiagnosticMessages.forLocale(AllObserverLintLocale.en);
      final ptBr = DiagnosticMessages.forLocale(AllObserverLintLocale.ptBr);

      for (final key in DiagnosticMessageKey.values) {
        expect(en.message(key), isNotEmpty, reason: '$key (en)');
        expect(ptBr.message(key), isNotEmpty, reason: '$key (pt-BR)');
        expect(
          en.message(key),
          isNot(equals(ptBr.message(key))),
          reason: '$key should not be identical between locales',
        );
      }
    });

    test('AllObserverLintLocale.fromTag falls back to English', () {
      expect(AllObserverLintLocale.fromTag(null), AllObserverLintLocale.en);
      expect(
        AllObserverLintLocale.fromTag('klingon'),
        AllObserverLintLocale.en,
      );
      expect(
        AllObserverLintLocale.fromTag('pt-BR'),
        AllObserverLintLocale.ptBr,
      );
      expect(
        AllObserverLintLocale.fromTag('pt-br'),
        AllObserverLintLocale.ptBr,
      );
    });
  });
}
