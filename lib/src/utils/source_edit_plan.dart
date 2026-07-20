import 'package:analyzer/source/source_range.dart';

/// A single text replacement: replace [length] characters starting at
/// [offset] with [replacement].
class SourceTextEdit {
  const SourceTextEdit({
    required this.offset,
    required this.length,
    required this.replacement,
  });

  final int offset;
  final int length;
  final String replacement;

  int get end => offset + length;

  SourceRange get range => SourceRange(offset, length);
}

/// An ordered, non-overlapping set of [SourceTextEdit]s plus an optional
/// single import edit, generalizing the single-replacement shape of
/// `ObserverWrapEdit`/`ObserverWrapEditBuilder` (`lib/src/utils/
/// observer_wrap_edit_builder.dart`) to migrations that touch more than
/// one source range of the same file at once — e.g. a field's declaration
/// plus every `.value` read of it, or a class's `extends ChangeNotifier`
/// clause plus a handful of `notifyListeners()` call sites.
///
/// Building a [SourceEditPlan] never decides *whether* a transformation is
/// appropriate — that judgment stays entirely in the calling migration
/// analyzer/assist/fix. This class only assembles the edits and refuses
/// (via [ArgumentError] at construction) to represent an internally
/// inconsistent plan: overlapping edits would corrupt the file if applied
/// naively in source order, so it is caught here once, centrally, instead
/// of trusting every call site to sort/validate its own edit list.
class SourceEditPlan {
  /// Creates a plan from [edits] (order does not matter; they are sorted
  /// by offset here) plus an optional [importOffset]/[importSource] pair
  /// (both must be provided together, or neither).
  ///
  /// Throws [ArgumentError] if any two edits overlap — a migration analyzer
  /// producing overlapping edits has a bug in its own range computation,
  /// and applying them anyway would silently corrupt the file.
  SourceEditPlan({
    required List<SourceTextEdit> edits,
    this.importOffset,
    this.importSource,
  }) : edits = List.unmodifiable(
         List<SourceTextEdit>.of(edits)
           ..sort((a, b) => a.offset.compareTo(b.offset)),
       ) {
    assert(
      (importOffset == null) == (importSource == null),
      'importOffset and importSource must both be null or both be set',
    );
    for (var i = 1; i < this.edits.length; i++) {
      final previous = this.edits[i - 1];
      final current = this.edits[i];
      if (current.offset < previous.end) {
        throw ArgumentError(
          'Overlapping source edits at offsets ${previous.offset}'
          '-${previous.end} and ${current.offset}-${current.end}',
        );
      }
    }
  }

  /// Every text replacement in this plan, sorted by ascending [SourceTextEdit.offset]
  /// and guaranteed non-overlapping.
  final List<SourceTextEdit> edits;

  /// Offset at which [importSource] must be inserted, if a new import
  /// directive is required. `null` when no import edit is needed.
  final int? importOffset;

  /// The import directive source to insert at [importOffset], if any.
  final String? importSource;

  /// Whether this plan has no effect at all (defensive convenience for
  /// callers that build a plan conditionally and want to bail out instead
  /// of registering a no-op change).
  bool get isEmpty => edits.isEmpty && importSource == null;

  /// Applies every edit in this plan via [replace], then the import edit
  /// (if any) via [insert]. Kept as plain callbacks — rather than coupling
  /// this file to a specific `custom_lint_builder`/`analyzer_plugin`
  /// builder type — so this class only depends on
  /// `package:analyzer/source/source_range.dart`, already used elsewhere
  /// in this package's assists.
  void addTo(
    void Function(SourceRange range, String replacement) replace,
    void Function(int offset, String source)? insert,
  ) {
    for (final edit in edits) {
      replace(edit.range, edit.replacement);
    }
    final offset = importOffset;
    final source = importSource;
    if (offset != null && source != null) {
      insert?.call(offset, source);
    }
  }
}
