// ignore_for_file: experimental_member_use

import 'package:all_observer_lint/src/utils/all_observer_type_checker.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:test/test.dart';

import '../support/resolve_fixture.dart';

void main() {
  group('AllObserverTypeChecker Listenable/ChangeNotifier/ValueNotifier', () {
    late AllObserverTypeChecker checker;

    setUp(() {
      checker = AllObserverTypeChecker();
    });

    test('recognizes a real Flutter ValueNotifier/ChangeNotifier field', () async {
      final result = await resolveFixture(
        'semantic_reference_index_fixture.dart',
      );
      final fields = _fieldTypesByName(result.unit);

      expect(checker.isValueNotifierType(fields['_legacyCount']), isTrue);
      expect(checker.isFlutterListenableType(fields['_legacyCount']), isTrue);

      expect(checker.isChangeNotifierType(fields['_legacyCounter']), isTrue);
      expect(checker.isFlutterListenableType(fields['_legacyCounter']), isTrue);

      // A plain Observable is not a Flutter ChangeNotifier/ValueNotifier.
      expect(checker.isChangeNotifierType(fields['_count']), isFalse);
      expect(checker.isValueNotifierType(fields['_count']), isFalse);
    });

    test('never matches a local homonym class as ChangeNotifier/ValueNotifier', () async {
      final result = await resolveFixture(
        'change_notifier_homonyms_fixture.dart',
      );
      final fields = _fieldTypesByName(result.unit);

      expect(
        checker.isChangeNotifierType(fields['RealChangeNotifierUser']),
        isFalse,
        reason: 'the homonym ChangeNotifier is declared locally, not in '
            'package:flutter/',
      );
      expect(checker.isValueNotifierType(fields['counter']), isFalse);
      expect(checker.isFlutterListenableType(fields['counter']), isFalse);
    });
  });
}

/// Collects the static type of every field/class declared at top level in
/// [unit], keyed by class name for a class declaration and by field name
/// for a field declaration. Deliberately small and ad-hoc — this test file
/// only needs "what type does this named thing have", not a general
/// utility.
Map<String, DartType?> _fieldTypesByName(CompilationUnit unit) {
  final result = <String, DartType?>{};
  for (final declaration in unit.declarations) {
    if (declaration is ClassDeclaration) {
      result[declaration.name.lexeme] =
          declaration.declaredFragment?.element.thisType;
      for (final member in declaration.members) {
        if (member is FieldDeclaration) {
          for (final variable in member.fields.variables) {
            result[variable.name.lexeme] =
                variable.declaredFragment?.element.type;
          }
        }
      }
    }
  }
  return result;
}
