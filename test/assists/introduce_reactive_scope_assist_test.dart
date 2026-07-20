import 'dart:io';

import 'package:all_observer_lint/src/assists/introduce_reactive_scope_assist.dart';
import 'package:analyzer/source/source_range.dart';
import 'package:test/test.dart';

import '../support/custom_lint_test_support.dart';
import '../support/resolve_fixture.dart';

void main() {
  group('IntroduceReactiveScopeAssist — available', () {
    test(
      'consolidates two Computed fields disposed directly in dispose()',
      () async {
        final result = await resolveFixture(
          'introduce_reactive_scope_available.dart',
        );
        final source = File(result.path).readAsStringSync();
        final offset = source.indexOf(
          'class _TwoComputedWidgetState',
        );
        final changes = await IntroduceReactiveScopeAssist().testRun(
          result,
          SourceRange(offset, 0),
        );

        expect(changes, hasLength(1));
        final transformed = applyPrioritizedChange(source, changes.single);

        expect(
          transformed,
          contains('late final ReactiveScope _scope = ReactiveScope();'),
        );
        expect(
          transformed,
          contains('late final Computed<int> total;'),
        );
        expect(
          transformed,
          contains('late final Computed<int> doubled;'),
        );
        expect(
          transformed,
          contains(
            '_scope.run(() {\n'
            '      total = Computed(() => _a.value + _b.value);\n'
            '      doubled = Computed(() => total.value * 2);\n'
            '    });',
          ),
        );
        expect(transformed, contains('_scope.dispose();'));
        expect(transformed, contains('super.initState();'));
        expect(transformed, contains('super.dispose();'));

        // `total`/`doubled` are field names reused by the other two
        // fixture classes in this same file (left untouched by this
        // invocation, each still legitimately calling `total.close();`
        // elsewhere) — scope the "old disposal call is gone" check to
        // just this transformed class's own body instead of the whole
        // file.
        final classStart = transformed.indexOf(
          'class _TwoComputedWidgetState',
        );
        final classEnd = transformed.indexOf(
          '\nclass ComputedAndEffectWidget',
          classStart,
        );
        final classBody = transformed.substring(classStart, classEnd);
        expect(classBody, isNot(contains('total.close();')));
        expect(classBody, isNot(contains('doubled.close();')));
      },
    );

    test('consolidates a Computed field and an effect Disposer', () async {
      final result = await resolveFixture(
        'introduce_reactive_scope_available.dart',
      );
      final source = File(result.path).readAsStringSync();
      final offset = source.indexOf('class _ComputedAndEffectWidgetState');
      final changes = await IntroduceReactiveScopeAssist().testRun(
        result,
        SourceRange(offset, 0),
      );

      expect(changes, hasLength(1));
      final transformed = applyPrioritizedChange(source, changes.single);

      expect(
        transformed,
        contains('late final ReactiveScope _scope = ReactiveScope();'),
      );
      expect(transformed, contains('late final Computed<int> total;'));
      expect(transformed, contains('late final Disposer disposeEffect;'));
      expect(transformed, contains('_scope.run(() {'));
      expect(transformed, contains('_scope.dispose();'));
      expect(transformed, isNot(contains('disposeEffect();')));
    });

    test('consolidates a Worker field and a Computed field', () async {
      final result = await resolveFixture(
        'introduce_reactive_scope_available.dart',
      );
      final source = File(result.path).readAsStringSync();
      final offset = source.indexOf('class _WorkerAndComputedWidgetState');
      final changes = await IntroduceReactiveScopeAssist().testRun(
        result,
        SourceRange(offset, 0),
      );

      expect(changes, hasLength(1));
      final transformed = applyPrioritizedChange(source, changes.single);

      expect(
        transformed,
        contains('late final ReactiveScope _scope = ReactiveScope();'),
      );
      expect(transformed, contains('late final Worker watcher;'));
      expect(transformed, contains('late final Computed<int> total;'));
      expect(transformed, contains('_scope.dispose();'));
      expect(transformed, isNot(contains('watcher.dispose();')));
    });
  });

  group('IntroduceReactiveScopeAssist — unavailable', () {
    Future<void> expectUnavailable(int Function(String source) locate) async {
      final result = await resolveFixture(
        'introduce_reactive_scope_unavailable.dart',
      );
      final source = File(result.path).readAsStringSync();
      final offset = locate(source);
      final changes = await IntroduceReactiveScopeAssist().testRun(
        result,
        SourceRange(offset, 0),
      );
      expect(changes, isEmpty);
    }

    test('only one scope-eligible field exists', () async {
      await expectUnavailable(
        (source) => source.indexOf('class _SingleFieldWidgetState'),
      );
    });

    test('the class declares an explicit constructor', () async {
      await expectUnavailable(
        (source) => source.indexOf('class _ExplicitConstructorWidgetState'),
      );
    });

    test('there is no initState()', () async {
      await expectUnavailable(
        (source) => source.indexOf('class _NoInitStateWidgetState'),
      );
    });

    test('a member named _scope already exists', () async {
      await expectUnavailable(
        (source) => source.indexOf('class _ExistingScopeWidgetState'),
      );
    });

    test(
      'a field type is not auto-captured by ReactiveScope (ObservableFuture)',
      () async {
        await expectUnavailable(
          (source) => source.indexOf('class _NotAutoCapturedWidgetState'),
        );
      },
    );

    test(
      'a sibling field reads one candidate immediately (not in a closure)',
      () async {
        await expectUnavailable(
          (source) =>
              source.indexOf('class _ImmediateCrossReferenceWidgetState'),
        );
      },
    );

    test('disposal is delegated to a helper method', () async {
      await expectUnavailable(
        (source) => source.indexOf('class _HelperDisposalWidgetState'),
      );
    });
  });
}
