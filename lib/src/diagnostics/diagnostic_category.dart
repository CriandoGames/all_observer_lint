/// Official categories used to classify `all_observer_lint` diagnostics.
///
/// Categories are purely informational metadata attached to each rule; they
/// do not affect severity. See `documentation/architecture.md`, section
/// "Categories", for the rationale of each bucket.
enum DiagnosticCategory {
  /// Reactive graphs that can cycle, never stabilize, or read/write in ways
  /// that break the dependency-tracking contract (e.g. a `Computed` that
  /// depends on itself, or writes during tracked reads).
  reactiveCycle,

  /// Problems tied to widget/object lifecycle: creating reactive resources
  /// in the wrong place, or in a place that is recreated repeatedly.
  lifecycle,

  /// Violations of the "derive, don't mutate" contract of `Computed`.
  purity,

  /// Misuse specific to Flutter widget rebuilds (`build`, `Observer`).
  widgetLifecycle,

  /// Reactive resources (workers, effects, streams) that require explicit
  /// disposal and are not disposed by their owner.
  resourceManagement,

  /// Patterns that are valid but degrade performance or granularity.
  performance,

  /// Architectural suggestions with no correctness implication.
  architecture,

  /// Concerns specific to `ObservableFuture` / `ObservableStream` and other
  /// asynchronous reactive primitives.
  async,
}
