/// Synthetic fixture generators for the benchmarks in `benchmark/`.
///
/// Fixtures are generated on demand instead of committed as giant static
/// files: the shapes below (widget count, field count, resource count) are
/// exactly the knobs the benchmarks need to vary between runs.
library;

/// A large widget tree mixing plain widgets, `.value` reads,
/// `watch(context)`, nested builders (`ListView.builder`, `Builder`,
/// `LayoutBuilder`), and both prefixed/unprefixed imports — representative
/// of the shapes `WrapWithObserverAssist` must scan through in a real file.
///
/// Returns the source and the list of marker strings (one per candidate
/// Widget expression) that a benchmark can search for to position the
/// assist's cursor.
({String source, List<String> markers}) generateAssistFixture(int widgetCount) {
  final buffer = StringBuffer()
    ..writeln("import 'package:all_observer/all_observer.dart';")
    ..writeln("import 'package:flutter/widgets.dart';")
    ..writeln()
    ..writeln('class BenchWidget extends StatelessWidget {')
    ..writeln('  const BenchWidget({super.key, required this.count});')
    ..writeln('  final Observable<int> count;')
    ..writeln()
    ..writeln('  @override')
    ..writeln('  Widget build(BuildContext context) {')
    ..writeln('    return Column(')
    ..writeln('      children: [');

  final markers = <String>[];
  for (var i = 0; i < widgetCount; i++) {
    final marker = 'BenchLabel$i';
    markers.add("Text('$marker")
    ;
    switch (i % 4) {
      case 0:
        buffer.writeln("        Text('$marker: plain'),");
      case 1:
        buffer.writeln("        Text('$marker: \${count.value}'),");
      case 2:
        buffer.writeln("        Text('$marker: \${count.watch(context)}'),");
      default:
        buffer.writeln(
          '        Builder(builder: (context) => '
          "Text('$marker: nested')),",
        );
    }
  }

  buffer
    ..writeln('      ],')
    ..writeln('    );')
    ..writeln('  }')
    ..writeln('}');

  return (source: buffer.toString(), markers: markers);
}

/// A class with [fieldCount] private reactive fields, half of them
/// referenced elsewhere in the file and half genuinely unused — exercises
/// `unused_reactive_state`.
String generateUnusedReactiveStateFixture(int fieldCount) {
  final buffer = StringBuffer()
    ..writeln("import 'package:all_observer/all_observer.dart';")
    ..writeln()
    ..writeln('class BenchState {');

  for (var i = 0; i < fieldCount; i++) {
    buffer.writeln('  final _field$i = Observable<int>(0);');
  }

  buffer.writeln();
  buffer.writeln('  void touchHalf() {');
  for (var i = 0; i < fieldCount; i += 2) {
    buffer.writeln('    _field$i.value;');
  }
  buffer.writeln('  }');
  buffer.writeln('}');

  return buffer.toString();
}

/// A class with [resourceCount] disposable reactive resources, disposed
/// through a mix of direct calls and one shared helper — exercises
/// `dispose_reactive_resources`.
String generateDisposeReactiveResourcesFixture(int resourceCount) {
  final buffer = StringBuffer()
    ..writeln("import 'package:all_observer/all_observer.dart';")
    ..writeln()
    ..writeln('class BenchController {');

  for (var i = 0; i < resourceCount; i++) {
    buffer.writeln('  final _worker$i = ever(Observable<int>(0), (_) {});');
  }

  buffer
    ..writeln()
    ..writeln('  void dispose() {')
    ..writeln('    _disposeAll();')
    ..writeln('  }')
    ..writeln()
    ..writeln('  void _disposeAll() {');
  for (var i = 0; i < resourceCount; i++) {
    buffer.writeln('    _worker$i.dispose();');
  }
  buffer
    ..writeln('  }')
    ..writeln('}');

  return buffer.toString();
}

/// A class with a single `ObservableList<int>` field and [operationCount]
/// method calls on it, alternating reads/mutations/replacements/unknown —
/// exercises `ReactiveCollectionOperationClassifier.classifyMethodInvocation`.
String generateReactiveCollectionOperationsFixture(int operationCount) {
  final buffer = StringBuffer()
    ..writeln("import 'package:all_observer/all_observer.dart';")
    ..writeln()
    ..writeln('class BenchCollectionOwner {')
    ..writeln('  final list = ObservableList<int>([1, 2, 3]);')
    ..writeln()
    ..writeln('  void run() {');

  const cycle = [
    'list.length;',
    'list.contains(1);',
    'list.add(1);',
    'list.removeWhere((e) => e == 0);',
    'list.assignAll([1, 2, 3]);',
    'list.toString();',
  ];
  for (var i = 0; i < operationCount; i++) {
    buffer.writeln('    ${cycle[i % cycle.length]}');
  }

  buffer
    ..writeln('  }')
    ..writeln('}');

  return buffer.toString();
}

/// A class with [fieldCount] private `Observable<int>` fields, each read
/// once, mutated once, and — for every other field — listened to via
/// `ValueNotifier`-style `addListener`/`removeListener` on a companion
/// legacy field, exercising every lazily-built capability of
/// `UnitSemanticIndex` (`references`, `reactiveReads`, `reactiveMutations`,
/// `listenerRegistrations`, `listenerRemovals`) at once.
String generateSemanticIndexFixture(int fieldCount) {
  final buffer = StringBuffer()
    ..writeln("import 'package:all_observer/all_observer.dart';")
    ..writeln("import 'package:flutter/foundation.dart';")
    ..writeln()
    ..writeln('class BenchSemanticIndexOwner {');

  for (var i = 0; i < fieldCount; i++) {
    buffer.writeln('  final _field$i = Observable<int>(0);');
    if (i.isEven) {
      buffer.writeln('  final _legacy$i = ValueNotifier<int>(0);');
    }
  }

  buffer
    ..writeln()
    ..writeln('  void _onChanged() {}')
    ..writeln()
    ..writeln('  BenchSemanticIndexOwner() {');
  for (var i = 0; i < fieldCount; i++) {
    if (i.isEven) {
      buffer.writeln('    _legacy$i.addListener(_onChanged);');
    }
  }
  buffer.writeln('  }');

  buffer.writeln();
  buffer.writeln('  void touch() {');
  for (var i = 0; i < fieldCount; i++) {
    buffer.writeln('    _field$i.value;');
    buffer.writeln('    _field$i.value = _field$i.value + 1;');
  }
  buffer.writeln('  }');

  buffer
    ..writeln()
    ..writeln('  void teardown() {');
  for (var i = 0; i < fieldCount; i++) {
    if (i.isEven) {
      buffer.writeln('    _legacy$i.removeListener(_onChanged);');
    }
  }
  buffer
    ..writeln('  }')
    ..writeln('}');

  return buffer.toString();
}
