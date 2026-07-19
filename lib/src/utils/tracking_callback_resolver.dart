import 'package:analyzer/dart/ast/ast.dart';

import 'all_observer_type_checker.dart';

class TrackingCallbackResolver {
  const TrackingCallbackResolver(this._checker);

  final AllObserverTypeChecker _checker;

  FunctionExpression? observerBuilder(InstanceCreationExpression node) {
    if (!_checker.isObserverWidgetCreation(node)) return null;
    if (_checker.isObserverWithChildCreation(node)) {
      return _namedFunction(node.argumentList, 'builder');
    }
    return _firstPositionalFunction(node.argumentList);
  }

  FunctionExpression? computedBuilder(InstanceCreationExpression node) {
    if (!_checker.isComputedCreation(node)) return null;
    return _firstPositionalFunction(node.argumentList);
  }

  FunctionExpression? effectBuilder(MethodInvocation node) {
    if (!_checker.isEffectInvocation(node)) return null;
    return _firstPositionalFunction(node.argumentList);
  }

  FunctionExpression? _firstPositionalFunction(ArgumentList arguments) {
    for (final argument in arguments.arguments) {
      if (argument is NamedExpression) continue;
      return argument is FunctionExpression ? argument : null;
    }
    return null;
  }

  FunctionExpression? _namedFunction(ArgumentList arguments, String name) {
    for (final argument in arguments.arguments.whereType<NamedExpression>()) {
      if (argument.name.label.name == name &&
          argument.expression is FunctionExpression) {
        return argument.expression as FunctionExpression;
      }
    }
    return null;
  }
}
