import 'package:all_observer_lint/src/utils/source_edit_plan.dart';
import 'package:analyzer/source/source_range.dart';
import 'package:test/test.dart';

void main() {
  group('SourceEditPlan', () {
    test('sorts edits by offset regardless of input order', () {
      final plan = SourceEditPlan(
        edits: [
          const SourceTextEdit(offset: 10, length: 2, replacement: 'b'),
          const SourceTextEdit(offset: 0, length: 2, replacement: 'a'),
        ],
      );

      expect(plan.edits.map((edit) => edit.offset), [0, 10]);
    });

    test('throws on overlapping edits', () {
      expect(
        () => SourceEditPlan(
          edits: [
            const SourceTextEdit(offset: 0, length: 5, replacement: 'a'),
            const SourceTextEdit(offset: 3, length: 5, replacement: 'b'),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('adjacent (non-overlapping) edits are allowed', () {
      final plan = SourceEditPlan(
        edits: [
          const SourceTextEdit(offset: 0, length: 5, replacement: 'a'),
          const SourceTextEdit(offset: 5, length: 5, replacement: 'b'),
        ],
      );

      expect(plan.edits, hasLength(2));
    });

    test('isEmpty is true only when there are no edits and no import', () {
      expect(SourceEditPlan(edits: const []).isEmpty, isTrue);
      expect(
        SourceEditPlan(
          edits: const [
            SourceTextEdit(offset: 0, length: 1, replacement: 'x'),
          ],
        ).isEmpty,
        isFalse,
      );
    });

    test('addTo applies every edit and the import edit', () {
      final plan = SourceEditPlan(
        edits: const [
          SourceTextEdit(offset: 10, length: 2, replacement: 'b'),
          SourceTextEdit(offset: 0, length: 2, replacement: 'a'),
        ],
        importOffset: 100,
        importSource: "import 'x.dart';",
      );

      final replaced = <SourceRange>[];
      final replacements = <String>[];
      int? insertedOffset;
      String? insertedSource;

      plan.addTo(
        (range, replacement) {
          replaced.add(range);
          replacements.add(replacement);
        },
        (offset, source) {
          insertedOffset = offset;
          insertedSource = source;
        },
      );

      expect(replaced, [const SourceRange(0, 2), const SourceRange(10, 2)]);
      expect(replacements, ['a', 'b']);
      expect(insertedOffset, 100);
      expect(insertedSource, "import 'x.dart';");
    });
  });
}
