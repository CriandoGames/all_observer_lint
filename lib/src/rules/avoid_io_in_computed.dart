import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/error/error.dart' hide LintCode;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../localization/diagnostic_message_key.dart';
import '../localization/diagnostic_messages.dart';
import '../localization/locale_resolver.dart';
import '../utils/all_observer_type_checker.dart';
import '../utils/computed_callback_finder.dart';

/// `avoid_io_in_computed`
///
/// Flags obvious I/O inside a `Computed` derivation callback: `await`
/// expressions, and calls resolved to `dart:io` (e.g. `File`, `Socket`,
/// `HttpClient`). `Computed` is meant to be a synchronous, repeatable, pure
/// derivation; I/O inside it runs unpredictably often and blocks dependency
/// tracking.
///
/// This is intentionally a best-effort, narrow detector (not a general
/// purity checker): it does not attempt to flag calls into arbitrary
/// third-party networking/database packages, since that would require a
/// registry of known I/O APIs and risks false positives on innocuous
/// method names. See `documentation/backlog.md` for extending coverage.
///
/// See `documentation/en/rules/avoid_io_in_computed.md`.
class AvoidIoInComputed extends DartLintRule {
  AvoidIoInComputed({required CustomLintConfigs configs})
    : super(code: _buildCode(configs));

  static const ruleName = 'avoid_io_in_computed';
  static const String _dartIoUriPrefix = 'dart:io';

  static LintCode _buildCode(CustomLintConfigs configs) {
    final messages = DiagnosticMessages.forLocale(resolveLocale(configs));
    return LintCode(
      name: ruleName,
      problemMessage: messages.message(DiagnosticMessageKey.ioInsideComputed),
      errorSeverity: ErrorSeverity.WARNING,
    );
  }

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    const checker = AllObserverTypeChecker();
    const finder = ComputedCallbackFinder(checker);

    context.registry.addAwaitExpression((node) {
      if (finder.isInsideComputedCallback(node)) {
        reporter.atNode(node, code);
      }
    });

    context.registry.addMethodInvocation((node) {
      if (_isDartIoCall(node) && finder.isInsideComputedCallback(node)) {
        reporter.atNode(node, code);
      }
    });

    context.registry.addInstanceCreationExpression((node) {
      if (_isImmediateTargetOfDartIoMethodInvocation(node)) return;
      if (_isDartIoElement(node.constructorName.type.element) &&
          finder.isInsideComputedCallback(node)) {
        reporter.atNode(node, code);
      }
    });
  }

  bool _isDartIoCall(MethodInvocation node) =>
      _isDartIoElement(node.methodName.element);

  bool _isImmediateTargetOfDartIoMethodInvocation(
    InstanceCreationExpression node,
  ) {
    final parent = node.parent;
    return parent is MethodInvocation &&
        identical(parent.target, node) &&
        _isDartIoCall(parent);
  }

  bool _isDartIoElement(Element? element) {
    final libraryUri = element?.library?.identifier;
    return libraryUri != null && libraryUri.startsWith(_dartIoUriPrefix);
  }
}
