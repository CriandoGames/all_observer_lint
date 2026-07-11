import 'dart:io';

import 'package:all_observer_lint/src/fixes/wrap_in_observable_batch_fix.dart';
import 'package:all_observer_lint/src/rules/prefer_batch_for_multiple_related_writes.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'package:test/test.dart';

import '../support/resolve_fixture.dart';

void main() {
  group('prefer_batch_for_multiple_related_writes', () {
    test('flags three or more consecutive observable value writes', () async {
      final result = await resolveFixture(
        'multiple_related_writes_invalid.dart',
      );
      final rule = PreferBatchForMultipleRelatedWrites(
        configs: await _configs(),
      );

      final errors = await rule.testRun(result);

      expect(errors, hasLength(1));
      expect(errors.single.errorCode.name, rule.code.name);
    });

    test('does not flag writes already wrapped in Observable.batch', () async {
      final result = await resolveFixture('multiple_related_writes_valid.dart');
      final rule = PreferBatchForMultipleRelatedWrites(
        configs: await _configs(),
      );

      final errors = await rule.testRun(result);

      expect(errors, isEmpty);
    });

    test(
      'quick fix wraps the consecutive writes in Observable.batch',
      () async {
        final result = await resolveFixture(
          'multiple_related_writes_invalid.dart',
        );
        final block = _saveBlock(result.unit);
        final source = File(result.path).readAsStringSync();
        final replacement = WrapInObservableBatchFix.buildBatchReplacement(
          source: source,
          firstStatement: block.statements[0],
          lastStatement: block.statements[3],
          batchExpression: 'Observable.batch',
        );

        expect(replacement, '''
Observable.batch(() {
      state.nameOverride.value = name;
      state.emailOverride.value = email;
      state.phoneOverride.value = phone;
      state.isEditing.value = false;
    });''');
      },
    );
  });
}

Future<CustomLintConfigs> _configs() async {
  final packageConfig = await parsePackageConfig(Directory.current);
  return CustomLintConfigs.parse(null, packageConfig);
}

Block _saveBlock(CompilationUnit unit) {
  final visitor = _SaveBlockVisitor();
  unit.accept(visitor);
  final block = visitor.block;
  if (block == null) {
    throw StateError('Could not find save() block in fixture.');
  }
  return block;
}

class _SaveBlockVisitor extends RecursiveAstVisitor<void> {
  Block? block;

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    if (node.name.lexeme == 'save' && node.body is BlockFunctionBody) {
      block = (node.body as BlockFunctionBody).block;
      return;
    }
    super.visitMethodDeclaration(node);
  }
}
