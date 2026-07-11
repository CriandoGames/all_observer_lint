import 'diagnostic_message_key.dart';
import 'diagnostic_messages_en.dart';
import 'diagnostic_messages_pt_br.dart';

/// A supported locale for `all_observer_lint` diagnostics.
///
/// Only the locales listed here may be selected through the
/// `all_observer.language` option. Unknown values fall back to [en].
enum AllObserverLintLocale {
  en('en'),
  ptBr('pt-BR');

  const AllObserverLintLocale(this.tag);

  /// The tag as written in `analysis_options.yaml`.
  final String tag;

  static AllObserverLintLocale fromTag(String? tag) {
    for (final locale in AllObserverLintLocale.values) {
      if (locale.tag.toLowerCase() == tag?.toLowerCase()) {
        return locale;
      }
    }
    return AllObserverLintLocale.en;
  }
}

/// Centralized, localized diagnostic text.
///
/// English (`en`) is the default and canonical locale of the package, kept
/// in sync with the upstream Dart/Flutter ecosystem convention. Brazilian
/// Portuguese (`pt-BR`) is opt-in via the `all_observer.language` option in
/// `analysis_options.yaml`.
///
/// The two locales must convey the same technical meaning; translations are
/// not literal, they use terminology familiar to Brazilian developers.
abstract interface class DiagnosticMessages {
  String message(DiagnosticMessageKey key);

  factory DiagnosticMessages.forLocale(AllObserverLintLocale locale) {
    switch (locale) {
      case AllObserverLintLocale.en:
        return const DiagnosticMessagesEn();
      case AllObserverLintLocale.ptBr:
        return const DiagnosticMessagesPtBr();
    }
  }
}
