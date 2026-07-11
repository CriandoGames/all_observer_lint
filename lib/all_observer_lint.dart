/// Official lint rules and automated fixes for safe, predictable, and
/// efficient development with `all_observer`.
///
/// This library only exposes the [createPlugin] entrypoint required by
/// `custom_lint`. Consumers configure the rules through `analysis_options.yaml`
/// (typically by including one of the bundled presets: `recommended.yaml`,
/// `strict.yaml`, or `all.yaml`) instead of importing Dart symbols directly.
library all_observer_lint;

import 'package:custom_lint_builder/custom_lint_builder.dart';

import 'src/plugin.dart';

/// Entrypoint used by the `custom_lint` runner to load this plugin.
///
/// Do not call this from application code. It is invoked by the
/// `custom_lint` process, in its own isolate, when a consumer project runs
/// `dart analyze` (via `analyzer: plugins: [custom_lint]`) or
/// `dart run custom_lint`.
PluginBase createPlugin() => AllObserverLintPlugin();
