import 'package:all_observer_lint/src/utils/all_observer_type_checker.dart';
import 'package:all_observer_lint/src/utils/semantic_reference_index.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:test/test.dart';

import '../support/resolve_fixture.dart';

void main() {
  group('UnitSemanticIndex', () {
    late UnitSemanticIndex index;

    setUp(() async {
      final result = await resolveFixture('semantic_reference_index_fixture.dart');
      index = UnitSemanticIndex.build(result.unit, AllObserverTypeChecker());
    });

    test('declarations contains every private field, keyed by element', () {
      final names = index.declarations.values
          .map((declaration) => declaration.name.lexeme)
          .toSet();
      expect(
        names,
        containsAll(<String>{
          '_count',
          '_items',
          '_legacyCount',
          '_legacyCounter',
          '_unused',
        }),
      );
    });

    test('references tracks occurrences outside the declaration, per element', () {
      final unusedElement = _elementNamed(index, '_unused');
      expect(index.isReferencedOutsideDeclaration(unusedElement), isFalse);

      final countElement = _elementNamed(index, '_count');
      expect(index.isReferencedOutsideDeclaration(countElement), isTrue);
      expect(index.references[countElement], isNotEmpty);
    });

    test('reactiveReads records the .value read and the collection read', () {
      final countElement = _elementNamed(index, '_count');
      final itemsElement = _elementNamed(index, '_items');

      expect(index.reactiveReads[countElement], hasLength(1));
      expect(index.reactiveReads[itemsElement], hasLength(1));
    });

    test('reactiveMutations records the .value write and the collection add', () {
      final countElement = _elementNamed(index, '_count');
      final itemsElement = _elementNamed(index, '_items');

      expect(index.reactiveMutations[countElement], hasLength(1));
      expect(index.reactiveMutations[itemsElement], hasLength(1));
    });

    test('listenerRegistrations/listenerRemovals track Listenable targets', () {
      final legacyCountElement = _elementNamed(index, '_legacyCount');
      final legacyCounterElement = _elementNamed(index, '_legacyCounter');

      expect(index.listenerRegistrations[legacyCountElement], hasLength(1));
      expect(index.listenerRegistrations[legacyCounterElement], hasLength(1));
      expect(index.listenerRemovals[legacyCountElement], hasLength(1));
      expect(index.listenerRemovals[legacyCounterElement], hasLength(1));
    });

    test('a plain Observable is never indexed as a listener target', () {
      final countElement = _elementNamed(index, '_count');
      expect(index.listenerRegistrations[countElement], isNull);
      expect(index.listenerRemovals[countElement], isNull);
    });
  });
}

Element _elementNamed(UnitSemanticIndex index, String name) {
  for (final entry in index.declarations.entries) {
    if (entry.value.name.lexeme == name) return entry.key;
  }
  throw StateError('No declaration named $name in the index');
}
