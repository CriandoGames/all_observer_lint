import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' hide LintCode;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../localization/diagnostic_message_key.dart';
import '../localization/diagnostic_messages.dart';
import '../localization/locale_resolver.dart';
import '../utils/all_observer_type_checker.dart';
import '../utils/reactive_read_collector.dart';
import '../utils/tracking_callback_resolver.dart';

abstract class TrackingScopeWithoutReactiveRead extends DartLintRule {
  TrackingScopeWithoutReactiveRead({
    required CustomLintConfigs configs,
    required String name,
    required DiagnosticMessageKey messageKey,
  }) : super(code: _buildCode(configs, name, messageKey));

  static LintCode _buildCode(
    CustomLintConfigs configs,
    String name,
    DiagnosticMessageKey messageKey,
  ) {
    final messages = DiagnosticMessages.forLocale(resolveLocale(configs));
    return LintCode(
      name: name,
      problemMessage: messages.message(messageKey),
      errorSeverity: ErrorSeverity.INFO,
    );
  }

  void reportIfEmpty(
    FunctionExpression callback,
    ErrorReporter reporter,
    ReactiveReadCollector collector,
  ) {
    final result = collector.collect(
      callback,
      primaryClosure: callback,
      flagPotentialHiddenReads: true,
    );
    if (result.reads.isEmpty &&
        !result.hasWatchRead &&
        !result.hasUnresolvedNode &&
        !result.hasPotentialHiddenRead) {
      reporter.atNode(callback, code);
    }
  }
}

class ObserverWithoutReactiveRead extends TrackingScopeWithoutReactiveRead {
  // ignore: use_super_parameters
  ObserverWithoutReactiveRead({required CustomLintConfigs configs})
    : super(
        configs: configs,
        name: ruleName,
        messageKey: DiagnosticMessageKey.observerWithoutReactiveRead,
      );

  static const ruleName = 'observer_without_reactive_read';

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    const checker = AllObserverTypeChecker();
    const callbacks = TrackingCallbackResolver(checker);
    const collector = ReactiveReadCollector(checker);
    context.registry.addInstanceCreationExpression((node) {
      final callback = callbacks.observerBuilder(node);
      if (callback != null) reportIfEmpty(callback, reporter, collector);
    });
  }
}

class ComputedWithoutReactiveRead extends TrackingScopeWithoutReactiveRead {
  // ignore: use_super_parameters
  ComputedWithoutReactiveRead({required CustomLintConfigs configs})
    : super(
        configs: configs,
        name: ruleName,
        messageKey: DiagnosticMessageKey.computedWithoutReactiveRead,
      );

  static const ruleName = 'computed_without_reactive_read';

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    const checker = AllObserverTypeChecker();
    const callbacks = TrackingCallbackResolver(checker);
    const collector = ReactiveReadCollector(checker);
    context.registry.addInstanceCreationExpression((node) {
      final callback = callbacks.computedBuilder(node);
      if (callback != null) reportIfEmpty(callback, reporter, collector);
    });
  }
}

class EffectWithoutReactiveRead extends TrackingScopeWithoutReactiveRead {
  // ignore: use_super_parameters
  EffectWithoutReactiveRead({required CustomLintConfigs configs})
    : super(
        configs: configs,
        name: ruleName,
        messageKey: DiagnosticMessageKey.effectWithoutReactiveRead,
      );

  static const ruleName = 'effect_without_reactive_read';

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    const checker = AllObserverTypeChecker();
    const callbacks = TrackingCallbackResolver(checker);
    const collector = ReactiveReadCollector(checker);
    context.registry.addMethodInvocation((node) {
      final callback = callbacks.effectBuilder(node);
      if (callback != null) reportIfEmpty(callback, reporter, collector);
    });
  }
}
