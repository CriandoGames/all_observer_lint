import 'package:all_observer_lint/src/utils/all_observer_type_checker.dart';
import 'package:all_observer_lint/src/utils/reactive_collection_operation_classifier.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:test/test.dart';

import '../support/resolve_fixture.dart';

void main() {
  group('ReactiveCollectionOperationClassifier', () {
    late ReactiveCollectionOperationClassifier classifier;

    setUp(() {
      classifier = ReactiveCollectionOperationClassifier(
        AllObserverTypeChecker(),
      );
    });

    test('classifies ObservableList reads', () async {
      final invocations = await _methodInvocationsIn(
        'reactive_collection_operation_classifier_fixture.dart',
        'listReads',
      );
      // `list.length` is a property read, not a `MethodInvocation` — only
      // `elementAt`/`where`/`contains`/`toList` are collected here.
      expect(invocations, hasLength(4));
      for (final invocation in invocations) {
        expect(
          classifier.classifyMethodInvocation(invocation),
          ReactiveCollectionOperationKind.read,
          reason: invocation.toString(),
        );
      }
    });

    test('classifies ObservableList mutations', () async {
      final invocations = await _methodInvocationsIn(
        'reactive_collection_operation_classifier_fixture.dart',
        'listMutations',
      );
      expect(invocations, hasLength(9));
      for (final invocation in invocations) {
        expect(
          classifier.classifyMethodInvocation(invocation),
          ReactiveCollectionOperationKind.mutation,
          reason: invocation.toString(),
        );
      }
    });

    test('classifies ObservableList replacements (assign/assignAll)', () async {
      final invocations = await _methodInvocationsIn(
        'reactive_collection_operation_classifier_fixture.dart',
        'listReplacements',
      );
      expect(invocations, hasLength(2));
      for (final invocation in invocations) {
        expect(
          classifier.classifyMethodInvocation(invocation),
          ReactiveCollectionOperationKind.replacement,
          reason: invocation.toString(),
        );
      }
    });

    test('never guesses mutation for an unrecognized resolved method', () async {
      final invocations = await _methodInvocationsIn(
        'reactive_collection_operation_classifier_fixture.dart',
        'listUnknown',
      );
      expect(invocations, hasLength(1));
      expect(
        classifier.classifyMethodInvocation(invocations.single),
        ReactiveCollectionOperationKind.unknown,
      );
    });

    test('classifies ObservableList index read/write', () async {
      final readIndex = await _indexExpressionsIn(
        'reactive_collection_operation_classifier_fixture.dart',
        'listIndexRead',
      );
      expect(readIndex, hasLength(1));
      expect(
        classifier.classifyIndexExpression(readIndex.single),
        ReactiveCollectionOperationKind.read,
      );

      final writeIndex = await _indexExpressionsIn(
        'reactive_collection_operation_classifier_fixture.dart',
        'listIndexWrite',
      );
      expect(writeIndex, hasLength(1));
      expect(
        classifier.classifyIndexExpression(writeIndex.single),
        ReactiveCollectionOperationKind.mutation,
      );
    });

    test('classifies ObservableMap reads/mutations/index', () async {
      final reads = await _methodInvocationsIn(
        'reactive_collection_operation_classifier_fixture.dart',
        'mapReads',
      );
      // Only `containsKey` is a `MethodInvocation` — `length` and `keys`
      // are property reads.
      expect(reads, hasLength(1));
      for (final invocation in reads) {
        expect(
          classifier.classifyMethodInvocation(invocation),
          ReactiveCollectionOperationKind.read,
        );
      }

      final mutations = await _methodInvocationsIn(
        'reactive_collection_operation_classifier_fixture.dart',
        'mapMutations',
      );
      expect(mutations, hasLength(7));
      for (final invocation in mutations) {
        expect(
          classifier.classifyMethodInvocation(invocation),
          ReactiveCollectionOperationKind.mutation,
          reason: invocation.toString(),
        );
      }

      final readIndex = await _indexExpressionsIn(
        'reactive_collection_operation_classifier_fixture.dart',
        'mapIndexRead',
      );
      expect(
        classifier.classifyIndexExpression(readIndex.single),
        ReactiveCollectionOperationKind.read,
      );

      final writeIndex = await _indexExpressionsIn(
        'reactive_collection_operation_classifier_fixture.dart',
        'mapIndexWrite',
      );
      expect(
        classifier.classifyIndexExpression(writeIndex.single),
        ReactiveCollectionOperationKind.mutation,
      );
    });

    test('classifies list.length read vs. list.length = write', () async {
      final read = await _propertyAccessIn(
        'reactive_collection_operation_classifier_fixture.dart',
        'listReads',
        'length',
      );
      expect(
        classifier.classifyPropertyAccess(
          read.target,
          propertyName: 'length',
          isWrite: false,
        ),
        ReactiveCollectionOperationKind.read,
      );

      final write = await _propertyAccessIn(
        'reactive_collection_operation_classifier_fixture.dart',
        'listLengthWrite',
        'length',
      );
      expect(
        classifier.classifyPropertyAccess(
          write.target,
          propertyName: 'length',
          isWrite: true,
        ),
        ReactiveCollectionOperationKind.mutation,
      );
    });

    test('classifies ObservableSet reads/mutations', () async {
      final reads = await _methodInvocationsIn(
        'reactive_collection_operation_classifier_fixture.dart',
        'setReads',
      );
      expect(reads, hasLength(2)); // contains, toSet (length is a property)
      for (final invocation in reads) {
        expect(
          classifier.classifyMethodInvocation(invocation),
          ReactiveCollectionOperationKind.read,
        );
      }

      final mutations = await _methodInvocationsIn(
        'reactive_collection_operation_classifier_fixture.dart',
        'setMutations',
      );
      expect(mutations, hasLength(5));
      for (final invocation in mutations) {
        expect(
          classifier.classifyMethodInvocation(invocation),
          ReactiveCollectionOperationKind.mutation,
          reason: invocation.toString(),
        );
      }
    });
  });
}

Future<List<MethodInvocation>> _methodInvocationsIn(
  String fileName,
  String methodName,
) async {
  final result = await resolveFixture(fileName);
  final method = _findMethod(result.unit, methodName);
  final collector = _MethodInvocationCollector();
  method.body.accept(collector);
  return collector.invocations;
}

Future<List<IndexExpression>> _indexExpressionsIn(
  String fileName,
  String methodName,
) async {
  final result = await resolveFixture(fileName);
  final method = _findMethod(result.unit, methodName);
  final collector = _IndexExpressionCollector();
  method.body.accept(collector);
  return collector.indexExpressions;
}

MethodDeclaration _findMethod(CompilationUnit unit, String methodName) {
  for (final declaration in unit.declarations) {
    if (declaration is ClassDeclaration) {
      for (final member in declaration.members) {
        if (member is MethodDeclaration && member.name.lexeme == methodName) {
          return member;
        }
      }
    }
  }
  throw StateError('Method $methodName not found');
}

class _MethodInvocationCollector extends RecursiveAstVisitor<void> {
  final List<MethodInvocation> invocations = [];

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.target != null) invocations.add(node);
    super.visitMethodInvocation(node);
  }
}

class _IndexExpressionCollector extends RecursiveAstVisitor<void> {
  final List<IndexExpression> indexExpressions = [];

  @override
  void visitIndexExpression(IndexExpression node) {
    indexExpressions.add(node);
    super.visitIndexExpression(node);
  }
}

/// Finds the single `target.propertyName` access (as either a
/// `PropertyAccess` or a `PrefixedIdentifier` — the analyzer may produce
/// either shape for a plain `identifier.identifier` access) inside
/// [methodName] of [fileName] and returns its `target` expression.
Future<({Expression target})> _propertyAccessIn(
  String fileName,
  String methodName,
  String propertyName,
) async {
  final result = await resolveFixture(fileName);
  final method = _findMethod(result.unit, methodName);
  final collector = _PropertyAccessCollector(propertyName);
  method.body.accept(collector);
  if (collector.targets.isEmpty) {
    throw StateError('No `.$propertyName` access found in $methodName');
  }
  return (target: collector.targets.single);
}

class _PropertyAccessCollector extends RecursiveAstVisitor<void> {
  _PropertyAccessCollector(this.propertyName);

  final String propertyName;
  final List<Expression> targets = [];

  @override
  void visitPropertyAccess(PropertyAccess node) {
    if (node.propertyName.name == propertyName && node.target != null) {
      targets.add(node.target!);
    }
    super.visitPropertyAccess(node);
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    if (node.identifier.name == propertyName) {
      targets.add(node.prefix);
    }
    super.visitPrefixedIdentifier(node);
  }
}
