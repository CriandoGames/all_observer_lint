import 'dart:io';

import 'package:all_observer_lint/src/localization/diagnostic_message_key.dart';
import 'package:all_observer_lint/src/localization/diagnostic_messages.dart';
import 'package:all_observer_lint/src/localization/locale_resolver.dart';
import 'package:all_observer_lint/src/plugin.dart';
import 'package:all_observer_lint/src/rules/prefer_batch_for_multiple_related_writes.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'package:path/path.dart' as p;
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

  group('resolveLocale', () {
    test(
      'reads pt-BR from the all_observer custom_lint option bucket',
      () async {
        final configs = await _ptBrConfigs();

        expect(resolveLocale(configs), AllObserverLintLocale.ptBr);
      },
    );

    test(
      'documents that top-level all_observer is not exposed by custom_lint',
      () async {
        final configs = await _parseCustomLintConfigs('''
all_observer:
  language: pt-BR
''');

        expect(resolveLocale(configs), AllObserverLintLocale.en);
      },
    );

    test('falls back to English when no language option is provided', () async {
      final configs = await _parseCustomLintConfigs('''
custom_lint:
  rules: []
''');

      expect(resolveLocale(configs), AllObserverLintLocale.en);
    });
  });

  group('localized lint codes', () {
    test(
      'prefer_batch_for_multiple_related_writes exposes pt-BR text',
      () async {
        final rule = PreferBatchForMultipleRelatedWrites(
          configs: await _ptBrConfigs(),
        );

        expect(
          rule.code.problemMessage,
          contains('Observable.batch(() { ... })'),
        );
        expect(rule.code.problemMessage, contains('escritas reativas'));
        expect(rule.code.problemMessage, isNot(contains('Multiple related')));
      },
    );

    test('plugin wires pt-BR text into registered rules', () async {
      final rules = AllObserverLintPlugin().getLintRules(await _ptBrConfigs());
      final rule = rules.singleWhere(
        (rule) =>
            rule.code.name == PreferBatchForMultipleRelatedWrites.ruleName,
      );

      expect(
        rule.code.problemMessage,
        contains('Observable.batch(() { ... })'),
      );
      expect(rule.code.problemMessage, contains('escritas reativas'));
      expect(rule.code.problemMessage, isNot(contains('Multiple related')));
    });
  });

  group('presets', () {
    test('recommended enables only recommended rules by default', () async {
      final configs = await _parseCustomLintConfigs('''
include: package:all_observer_lint/recommended.yaml
''');

      final ruleNames = _enabledRuleNames(configs);

      expect(ruleNames, contains('avoid_reactive_creation_in_build'));
      expect(ruleNames, contains('self_referencing_computed'));
      expect(
        ruleNames,
        isNot(contains('prefer_batch_for_multiple_related_writes')),
      );
    });

    test('strict adds experimental rules on top of recommended', () async {
      final configs = await _parseCustomLintConfigs('''
include: package:all_observer_lint/strict.yaml
''');

      final ruleNames = _enabledRuleNames(configs);

      expect(ruleNames, contains('avoid_reactive_creation_in_build'));
      expect(ruleNames, contains('prefer_batch_for_multiple_related_writes'));
      expect(
        ruleNames,
        contains('prefer_assign_all_for_reactive_list_replace'),
      );
    });

    test('locale override keeps included recommended rules enabled', () async {
      final configs = await _parseCustomLintConfigs('''
include: package:all_observer_lint/recommended.yaml

custom_lint:
  rules:
    - all_observer:
      language: pt-BR
''');

      expect(resolveLocale(configs), AllObserverLintLocale.ptBr);
      expect(_enabledRuleNames(configs), contains('self_referencing_computed'));
    });
  });
}

Future<CustomLintConfigs> _ptBrConfigs() {
  return _parseCustomLintConfigs('''
custom_lint:
  rules:
    - all_observer:
      language: pt-BR
''');
}

Future<CustomLintConfigs> _parseCustomLintConfigs(String content) async {
  final tempDir = Directory.systemTemp.createTempSync(
    'all_observer_lint_config_test_',
  );
  addTearDown(() => tempDir.delete(recursive: true));

  final analysisOptions = File(p.join(tempDir.path, 'analysis_options.yaml'))
    ..writeAsStringSync(content);
  final packageConfig = await parsePackageConfig(Directory.current);
  return CustomLintConfigs.parse(
    PhysicalResourceProvider.INSTANCE.getFile(analysisOptions.path),
    packageConfig,
  );
}

Set<String> _enabledRuleNames(CustomLintConfigs configs) {
  return AllObserverLintPlugin()
      .getLintRules(configs)
      .where((rule) => rule.isEnabled(configs))
      .map((rule) => rule.code.name)
      .toSet();
}
