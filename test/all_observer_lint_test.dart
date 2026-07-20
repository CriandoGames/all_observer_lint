import 'package:all_observer_lint/all_observer_lint.dart';
import 'package:all_observer_lint/src/assists/extract_to_computed_assist.dart';
import 'package:all_observer_lint/src/assists/wrap_smallest_reactive_subtree_assist.dart';
import 'package:all_observer_lint/src/assists/wrap_with_observer_assist.dart';
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

  test('plugin registers every assist', () {
    expect(createPlugin().getAssists(), hasLength(3));
  });

  test('plugin registers the permissive, specialized, and extract-to-'
      'Computed wrap-with-Observer assists', () {
    final assists = createPlugin().getAssists();
    expect(assists, contains(isA<WrapWithObserverAssist>()));
    expect(assists, contains(isA<WrapSmallestReactiveSubtreeAssist>()));
    expect(assists, contains(isA<ExtractReactiveExpressionToComputedAssist>()));
  });
}
