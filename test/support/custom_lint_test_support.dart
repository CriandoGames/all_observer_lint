import 'dart:io';

import 'package:custom_lint_builder/custom_lint_builder.dart';

Future<CustomLintConfigs> testConfigs() async {
  final packageConfig = await parsePackageConfig(Directory.current);
  return CustomLintConfigs.parse(null, packageConfig);
}

String applyPrioritizedChange(String source, dynamic prioritizedChange) {
  final fileEdits = prioritizedChange.change.edits as List<dynamic>;
  final edits = fileEdits.expand((edit) => edit.edits as List<dynamic>).toList()
    ..sort(
      (left, right) => (right.offset as int).compareTo(left.offset as int),
    );
  var result = source;
  for (final edit in edits) {
    final offset = edit.offset as int;
    final length = edit.length as int;
    result = result.replaceRange(
      offset,
      offset + length,
      edit.replacement as String,
    );
  }
  return result;
}
