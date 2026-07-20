// ignore_for_file: experimental_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';

import '../utils/all_observer_type_checker.dart';
import '../utils/migration_safety_result.dart';
import '../utils/semantic_reference_index.dart';

/// Evaluates whether a single private field of a class extending Flutter's
/// `ChangeNotifier` is safe to convert to a plain `Observable<T>` field, per
/// the project brief's Part 1 ("Conversão de `ChangeNotifier`"), implemented
/// as Etapa F.
///
/// ## Scope (first version)
///
/// The project brief explicitly asks for smaller, independent assists
/// instead of one whole-class transform in the first version:
///
/// 1. convert one private field + its getter to `Observable<T>` — this
///    class, paired with `ConvertChangeNotifierFieldAssist`;
/// 2. remove a redundant `notifyListeners()` call once every change in
///    that method already notifies via `Observable` — deferred, see
///    `documentation/backlog.md`;
/// 3. remove `extends ChangeNotifier` once nothing depends on it anymore —
///    deferred;
/// 4. add the `all_observer` import — handled inline by the assist through
///    `AllObserverSymbolImportResolver`, same as Etapa D/E.
///
/// This analyzer only proves (1) is safe. It deliberately never touches any
/// `notifyListeners()` call: every one of them is left exactly where it is,
/// so the class keeps calling the *inherited*
/// `ChangeNotifier.notifyListeners()` after this one field's conversion —
/// fully behavior-preserving, if momentarily redundant for this field until
/// a later, separate `notifyListeners` cleanup pass (2) lands.
///
/// ## Class-level gates
///
/// A field is only ever considered if its enclosing class:
///
/// - is itself private (its name starts with `_`) — this analyzer never
///   attempts to prove "all necessary references are in the same file" for
///   a *public* class across other files it cannot see in a single-file
///   `custom_lint` pass, so it narrows to the one case it safely can prove:
///   privacy makes the class inaccessible outside this library;
/// - extends Flutter's real `ChangeNotifier` **directly** — its own
///   `extends` clause resolves straight to `ChangeNotifier`, not to some
///   other, intermediate class that itself happens to extend it further
///   up;
/// - has no `with` clause and no `implements` clause at all;
/// - does not override `addListener`, `removeListener`, `hasListeners`, or
///   `notifyListeners`;
/// - never tears off `notifyListeners` — every reference to it must be the
///   direct target of a call (`notifyListeners()`/`super.notifyListeners()`);
///   passing it as a callback (`api.addListener(notifyListeners)`) blocks
///   the whole class;
/// - never returns `this` from a getter/method whose return type is
///   `Listenable`-shaped (`Listenable get listenable => this;`);
/// - never passes `this` as an argument anywhere in its own body (covers
///   `AnimatedBuilder(animation: this)`-style exposure written from inside
///   a method of the class itself).
///
/// ## Field-level gates
///
/// - a private, non-static, non-`late` instance field with an initializer,
///   whose declared type is not itself `Observable`/`Computed`/any other
///   reactive or `Listenable`-shaped type (nothing to convert there);
/// - exactly one getter exists, named after the field with its leading `_`
///   stripped, whose body is a pure passthrough (`=> _field;` or
///   `{ return _field; }`) — and no setter, method, or field sharing that
///   same derived name;
/// - every occurrence of *both* the field's element and the getter's
///   element anywhere in the compilation unit falls inside the enclosing
///   class's own source range — an occurrence reaching outside (another
///   class in the same file touching the getter, or the field leaking
///   somehow) stays silent rather than attempting a same-file, cross-class
///   rewrite;
/// - the field is never assigned through a constructor initializer list
///   (`: _field = value`) — `Observable`'s `.value` setter cannot be the
///   target of a constructor field initializer, so this shape is left
///   completely alone.
class ChangeNotifierFieldMigrationAnalyzer {
  const ChangeNotifierFieldMigrationAnalyzer(this._checker);

  final AllObserverTypeChecker _checker;

  static const Set<String> _reservedOverrideNames = {
    'addListener',
    'removeListener',
    'hasListeners',
    'notifyListeners',
  };

  /// Evaluates [field] (already known to be a private field/top-level
  /// declaration, i.e. a value from [index].declarations) against [index],
  /// built once for the whole compilation unit.
  MigrationSafetyResult evaluate(
    VariableDeclaration field,
    UnitSemanticIndex index,
  ) {
    final classNode = field.thisOrAncestorOfType<ClassDeclaration>();
    if (classNode == null) {
      return MigrationSafetyResult.silent(['field is not inside a class']);
    }

    final classBlockReason = _classBlockReason(classNode);
    if (classBlockReason != null) {
      return MigrationSafetyResult.silent([classBlockReason]);
    }

    return _evaluateField(field, classNode, index);
  }

  String? _classBlockReason(ClassDeclaration classNode) {
    final className = classNode.name.lexeme;
    if (!className.startsWith('_')) {
      return 'enclosing class is not private';
    }

    final superclass = classNode.extendsClause?.superclass;
    final superElement = superclass?.element;
    if (superElement?.name != 'ChangeNotifier' ||
        !_checker.isFlutterFrameworkElement(superElement)) {
      return 'enclosing class does not extend Flutter ChangeNotifier directly';
    }

    if (classNode.withClause != null) {
      return 'enclosing class has a mixin (with clause)';
    }
    if (classNode.implementsClause != null) {
      return 'enclosing class has an implements clause';
    }

    for (final member in classNode.members) {
      if (member is MethodDeclaration &&
          _reservedOverrideNames.contains(member.name.lexeme)) {
        return 'enclosing class overrides ${member.name.lexeme}';
      }
    }

    final tearOffFinder = _NotifyListenersTearOffFinder();
    classNode.accept(tearOffFinder);
    if (tearOffFinder.found) {
      return 'notifyListeners is torn off (used as a callback) somewhere '
          'in the class';
    }

    final listenableExposureFinder = _ThisAsListenableFinder(_checker);
    classNode.accept(listenableExposureFinder);
    if (listenableExposureFinder.found) {
      return 'a member exposes `this` as a Listenable-shaped return value';
    }

    final thisArgumentFinder = _ThisArgumentFinder();
    classNode.accept(thisArgumentFinder);
    if (thisArgumentFinder.found) {
      return '`this` is passed as an argument somewhere in the class';
    }

    return null;
  }

  MigrationSafetyResult _evaluateField(
    VariableDeclaration field,
    ClassDeclaration classNode,
    UnitSemanticIndex index,
  ) {
    final declaredElement = field.declaredFragment?.element;
    if (declaredElement == null) {
      return MigrationSafetyResult.silent(['unresolved declared element']);
    }

    final variableList = field.parent;
    if (variableList is! VariableDeclarationList) {
      return MigrationSafetyResult.silent(['not a variable declaration list']);
    }
    final fieldDeclaration = variableList.parent;
    if (fieldDeclaration is! FieldDeclaration) {
      return MigrationSafetyResult.silent(['not a field declaration']);
    }
    if (fieldDeclaration.isStatic) {
      return MigrationSafetyResult.silent(['field is static']);
    }
    if (variableList.lateKeyword != null) {
      return MigrationSafetyResult.silent(['field is late']);
    }
    if (field.initializer == null) {
      return MigrationSafetyResult.silent(['field has no initializer']);
    }

    final fieldType = declaredElement.type;
    if (_checker.isReactiveValueType(fieldType) ||
        _checker.isFlutterListenableType(fieldType)) {
      return MigrationSafetyResult.silent([
        'field is already a reactive/Listenable-shaped type',
      ]);
    }

    final privateName = field.name.lexeme;
    if (privateName.length < 2 || !privateName.startsWith('_')) {
      return MigrationSafetyResult.silent(['field is not private']);
    }
    final publicName = privateName.substring(1);
    if (publicName.startsWith('_')) {
      return MigrationSafetyResult.silent([
        'derived public name is not a plain identifier',
      ]);
    }

    MethodDeclaration? getter;
    for (final member in classNode.members) {
      if (member is FieldDeclaration) {
        for (final variable in member.fields.variables) {
          if (variable.name.lexeme == publicName) {
            return MigrationSafetyResult.silent([
              'a field named $publicName already exists',
            ]);
          }
        }
        continue;
      }
      if (member is MethodDeclaration && member.name.lexeme == publicName) {
        if (member.isGetter) {
          if (getter != null) {
            return MigrationSafetyResult.silent([
              'multiple getters named $publicName',
            ]);
          }
          getter = member;
        } else {
          return MigrationSafetyResult.silent([
            'a conflicting member named $publicName exists (not a pure '
            'getter)',
          ]);
        }
      }
    }
    if (getter == null) {
      return MigrationSafetyResult.silent([
        'no matching getter named $publicName',
      ]);
    }
    if (!_isPureFieldPassthrough(getter, declaredElement)) {
      return MigrationSafetyResult.silent([
        'getter is not a pure passthrough of the field',
      ]);
    }

    final fieldElement = _canonicalElement(declaredElement);
    final getterElement = _canonicalElement(getter.declaredFragment?.element);
    if (fieldElement == null || getterElement == null) {
      return MigrationSafetyResult.silent([
        'unresolved field/getter element',
      ]);
    }

    // The field is already indexed (`UnitSemanticIndex.declarations` covers
    // every private field/top-level variable), so its occurrences are
    // reused from [index] rather than re-walked. The getter is *not*
    // indexed there (only variable declarations are), so it needs its own,
    // dedicated whole-unit scan.
    for (final occurrence in index.references[fieldElement] ?? const []) {
      final node = occurrence.node;
      if (node is! SimpleIdentifier) {
        return MigrationSafetyResult.silent([
          'occurrence at ${occurrence.node.offset} is not a simple '
          'identifier reference',
        ]);
      }
      if (node.offset < classNode.offset || node.end > classNode.end) {
        return MigrationSafetyResult.silent([
          'field is referenced outside the enclosing class',
        ]);
      }
      final parent = node.parent;
      if (parent is ConstructorFieldInitializer &&
          identical(parent.fieldName, node)) {
        return MigrationSafetyResult.silent([
          'field is assigned through a constructor initializer list',
        ]);
      }
    }

    final unit = classNode.root;
    if (unit is! CompilationUnit) {
      return MigrationSafetyResult.silent(['unresolved compilation unit']);
    }
    for (final node in _occurrencesOf(unit, getterElement)) {
      if (node.offset < classNode.offset || node.end > classNode.end) {
        return MigrationSafetyResult.silent([
          'getter is referenced outside the enclosing class',
        ]);
      }
    }

    return MigrationSafetyResult.safe(MigrationCapability.assist);
  }

  bool _isPureFieldPassthrough(MethodDeclaration getter, Element fieldElement) {
    final body = getter.body;
    Expression? returned;
    if (body is ExpressionFunctionBody) {
      returned = body.expression;
    } else if (body is BlockFunctionBody) {
      final statements = body.block.statements;
      if (statements.length != 1) return false;
      final statement = statements.single;
      if (statement is! ReturnStatement) return false;
      returned = statement.expression;
    } else {
      return false;
    }
    if (returned is! SimpleIdentifier) return false;
    return _canonicalElement(returned.element) ==
        _canonicalElement(fieldElement);
  }

  List<SimpleIdentifier> _occurrencesOf(CompilationUnit unit, Element target) {
    final collector = _ElementOccurrenceCollector(target);
    unit.accept(collector);
    return collector.occurrences;
  }
}

class _ElementOccurrenceCollector extends RecursiveAstVisitor<void> {
  _ElementOccurrenceCollector(this.target);

  final Element target;
  final List<SimpleIdentifier> occurrences = [];

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (_canonicalElement(node.element) == target) {
      occurrences.add(node);
    }
    super.visitSimpleIdentifier(node);
  }
}

class _NotifyListenersTearOffFinder extends RecursiveAstVisitor<void> {
  bool found = false;

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (node.name == 'notifyListeners') {
      final parent = node.parent;
      final isDirectCall =
          parent is MethodInvocation && identical(parent.methodName, node);
      if (!isDirectCall) found = true;
    }
    super.visitSimpleIdentifier(node);
  }
}

class _ThisAsListenableFinder extends RecursiveAstVisitor<void> {
  _ThisAsListenableFinder(this._checker);

  final AllObserverTypeChecker _checker;
  bool found = false;

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    if (node.isGetter) {
      final returnType = node.declaredFragment?.element.returnType;
      if (_checker.isFlutterListenableType(returnType) &&
          _bodyReturnsThis(node.body)) {
        found = true;
      }
    }
    super.visitMethodDeclaration(node);
  }

  bool _bodyReturnsThis(FunctionBody body) {
    if (body is ExpressionFunctionBody) {
      return body.expression is ThisExpression;
    }
    if (body is BlockFunctionBody) {
      return body.block.statements.any(
        (statement) =>
            statement is ReturnStatement &&
            statement.expression is ThisExpression,
      );
    }
    return false;
  }
}

class _ThisArgumentFinder extends RecursiveAstVisitor<void> {
  bool found = false;

  @override
  void visitThisExpression(ThisExpression node) {
    if (node.parent is ArgumentList) found = true;
    super.visitThisExpression(node);
  }
}

Element? _canonicalElement(Element? element) {
  if (element == null) return null;
  if (element is PropertyAccessorElement) {
    return element.variable?.baseElement ?? element.baseElement;
  }
  return element.baseElement;
}
