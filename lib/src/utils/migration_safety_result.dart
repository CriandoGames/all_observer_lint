/// The three levels of transformation offering used throughout the
/// assisted-migrations phase (`lib/src/migrations/`, `lib/src/assists/
/// convert_*`), per the project brief's "Separar diagnóstico de
/// transformação" principle:
///
/// - [rule]: only a diagnostic is safe to emit; no transformation is
///   offered at all for this candidate.
/// - [assist]: a manually-triggered transformation can be offered (the
///   developer opts in explicitly, e.g. via the IDE's assist/refactor
///   menu, not tied to any diagnostic).
/// - [quickFix]: the diagnostic carries enough proven information to also
///   offer an automatic, local, compilable fix tied to that specific
///   diagnostic.
///
/// Levels are cumulative in capability, not in required proof: a
/// candidate proven safe for [quickFix] is by construction also safe for
/// [assist] (see [MigrationSafetyResult.allowsAssist]) — an analyzer never
/// needs to separately re-derive assist-level safety once quick-fix-level
/// safety is established.
enum MigrationCapability { rule, assist, quickFix }

/// The result of evaluating whether a migration/transformation candidate
/// (a `ChangeNotifier` class, a `ValueNotifier` field, an `Observable`
/// that looks redundant, an `addListener`/`removeListener` pair, a group
/// of async-flag fields, a group of reactive resources for
/// `ReactiveScope`, ...) is safe to surface, and at which
/// [MigrationCapability] level.
///
/// This is the shared "should I say anything, and how strongly" model
/// referenced by the project brief's "Permanecer silencioso em caso de
/// dúvida" principle: a migration analyzer builds one of these per
/// candidate from its own evidence, and the corresponding rule/assist/fix
/// only ever consults [capability]/[allowsRule]/[allowsAssist]/
/// [allowsQuickFix] — it never re-derives safety from scattered booleans
/// of its own.
///
/// [blockReasons] is diagnostic-quality metadata, not user-facing text: it
/// exists so tests (and the phase's final report, see the project brief's
/// Part 18) can assert *why* a given candidate stayed silent or capped at
/// a lower capability, without the IDE ever showing a reason for
/// unavailability (an assist that cannot fire simply does not appear).
class MigrationSafetyResult {
  const MigrationSafetyResult._({
    required this.capability,
    required this.blockReasons,
  });

  /// The highest capability level this candidate has been proven safe
  /// for. `null` means no evidence was strong enough to say anything at
  /// all — callers must stay completely silent: no diagnostic, no assist,
  /// no fix.
  final MigrationCapability? capability;

  /// Human-readable reasons the candidate could not reach a higher
  /// capability level (or any level at all). Empty when [capability] is
  /// already [MigrationCapability.quickFix] (the maximum) or when
  /// [isSilent] and the analyzer chose not to enumerate every blocking
  /// condition it stopped checking after the first one found.
  final List<String> blockReasons;

  /// Whether this candidate must be treated as invisible: no rule
  /// diagnostic, no assist, no quick fix.
  bool get isSilent => capability == null;

  /// Whether at least a diagnostic (any [MigrationCapability]) is safe to
  /// emit.
  bool get allowsRule => capability != null;

  /// Whether a manually-triggered transformation is safe to offer.
  bool get allowsAssist =>
      capability == MigrationCapability.assist ||
      capability == MigrationCapability.quickFix;

  /// Whether an automatic, diagnostic-attached fix is safe to offer.
  bool get allowsQuickFix => capability == MigrationCapability.quickFix;

  /// No evidence is strong enough to say anything about this candidate.
  /// [reasons] documents why, for tests/reporting — never surfaced to the
  /// IDE, since a silent candidate produces no diagnostic to attach a
  /// reason to.
  factory MigrationSafetyResult.silent(List<String> reasons) =>
      MigrationSafetyResult._(capability: null, blockReasons: reasons);

  /// Safe to reach [capability]. [blockedFromHigherReasons] documents why
  /// a higher level was not reached (leave empty when [capability] is
  /// already [MigrationCapability.quickFix]).
  factory MigrationSafetyResult.safe(
    MigrationCapability capability, {
    List<String> blockedFromHigherReasons = const [],
  }) => MigrationSafetyResult._(
    capability: capability,
    blockReasons: blockedFromHigherReasons,
  );

  @override
  String toString() =>
      'MigrationSafetyResult(capability: $capability, '
      'blockReasons: $blockReasons)';
}
