/// Stable identifiers for every localizable diagnostic message.
///
/// Rules never inline message strings. They look up a [DiagnosticMessageKey]
/// through [DiagnosticMessages] (see `diagnostic_messages.dart`) so that
/// English and Brazilian Portuguese text stay centralized and in sync.
enum DiagnosticMessageKey {
  reactiveCreationInsideBuild,
  effectCreationInsideBuild,
  invalidWatchContext,
  reactiveResourceNotDisposed,
  reactiveWriteInsideComputed,
  setStateInsideComputed,
  workerCreationInsideComputed,
  ioInsideComputed,
  observableWriteDuringObserverBuild,
  selfReferencingComputed,
  preferComputedForDerivedState,
  preferBatchForMultipleRelatedWrites,
  preferAssignAllForReactiveListReplace,
}
