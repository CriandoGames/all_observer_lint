import 'package:all_observer_lint/all_observer_lint.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'package:test/test.dart';

void main() {
  test('createPlugin() returns a PluginBase', () {
    // A full "every preset rule name matches a registered rule" check
    // requires constructing a real CustomLintConfigs, which in turn
    // requires the custom_lint toolchain wired up (see
    // documentation/backlog.md, "Plugin wiring smoke test"). This is the
    // minimal entrypoint smoke test that doesn't depend on that.
    expect(createPlugin(), isA<PluginBase>());
  });
}
