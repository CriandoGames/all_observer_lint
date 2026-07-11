import 'package:custom_lint_builder/custom_lint_builder.dart';

import 'diagnostic_messages.dart';

/// Reads the `all_observer.language` option from `custom_lint.rules`
/// and resolves it to a supported [AllObserverLintLocale].
///
/// Example:
/// ```yaml
/// custom_lint:
///   rules:
///     - all_observer:
///       language: pt-BR
/// ```
///
/// Falls back to [AllObserverLintLocale.en] when the option is absent or
/// unrecognized, per the "English is the default" policy.
AllObserverLintLocale resolveLocale(CustomLintConfigs configs) {
  final pluginConfig = configs.rules['all_observer'];
  final rawLanguage = pluginConfig?.json['language'];
  if (rawLanguage is String) {
    return AllObserverLintLocale.fromTag(rawLanguage);
  }
  return AllObserverLintLocale.en;
}
