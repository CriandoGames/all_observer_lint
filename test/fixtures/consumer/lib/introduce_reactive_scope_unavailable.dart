import 'package:all_observer/all_observer.dart';
import 'package:flutter/material.dart';

/// Fixture for `IntroduceReactiveScopeAssist` — cases where the assist
/// must stay unavailable.

final _a = 1.obs;
final _b = 2.obs;

/// Only one scope-eligible field — no consolidation benefit, so the
/// assist requires at least two.
class SingleFieldWidget extends StatefulWidget {
  const SingleFieldWidget({super.key});

  @override
  State<SingleFieldWidget> createState() => _SingleFieldWidgetState();
}

class _SingleFieldWidgetState extends State<SingleFieldWidget> {
  late final Computed<int> total = Computed(() => _a.value + _b.value);

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) => Text('${total.value}');

  @override
  void dispose() {
    total.close();
    super.dispose();
  }
}

/// An explicit constructor is present — its body would run before
/// `initState()`, so this analyzer does not attempt to prove no unsafe
/// read happens there; it narrows to classes with no custom constructor
/// at all.
class ExplicitConstructorWidget extends StatefulWidget {
  const ExplicitConstructorWidget({super.key});

  @override
  State<ExplicitConstructorWidget> createState() =>
      _ExplicitConstructorWidgetState();
}

class _ExplicitConstructorWidgetState
    extends State<ExplicitConstructorWidget> {
  _ExplicitConstructorWidgetState();

  late final Computed<int> total = Computed(() => _a.value + _b.value);
  late final Computed<int> doubled = Computed(() => total.value * 2);

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) => Text('${doubled.value}');

  @override
  void dispose() {
    total.close();
    doubled.close();
    super.dispose();
  }
}

/// No `initState()` at all.
class NoInitStateWidget extends StatefulWidget {
  const NoInitStateWidget({super.key});

  @override
  State<NoInitStateWidget> createState() => _NoInitStateWidgetState();
}

class _NoInitStateWidgetState extends State<NoInitStateWidget> {
  late final Computed<int> total = Computed(() => _a.value + _b.value);
  late final Computed<int> doubled = Computed(() => total.value * 2);

  @override
  Widget build(BuildContext context) => Text('${doubled.value}');

  @override
  void dispose() {
    total.close();
    doubled.close();
    super.dispose();
  }
}

/// A member named `_scope` already exists.
class ExistingScopeWidget extends StatefulWidget {
  const ExistingScopeWidget({super.key});

  @override
  State<ExistingScopeWidget> createState() => _ExistingScopeWidgetState();
}

class _ExistingScopeWidgetState extends State<ExistingScopeWidget> {
  int _scope = 0;

  late final Computed<int> total = Computed(() => _a.value + _b.value);
  late final Computed<int> doubled = Computed(() => total.value * 2);

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) => Text('${doubled.value + _scope}');

  @override
  void dispose() {
    total.close();
    doubled.close();
    super.dispose();
  }
}

/// One field is an `ObservableFuture` — sharing the `.close()` disposal
/// *method name* with `Computed`, but never auto-captured by
/// `ReactiveScope.run()` (per its own class doc, only `Computed`,
/// `effect()` and the workers are). Only the single remaining `Computed`
/// field is truly scope-eligible — not enough on its own.
class NotAutoCapturedWidget extends StatefulWidget {
  const NotAutoCapturedWidget({super.key});

  @override
  State<NotAutoCapturedWidget> createState() => _NotAutoCapturedWidgetState();
}

class _NotAutoCapturedWidgetState extends State<NotAutoCapturedWidget> {
  late final Computed<int> total = Computed(() => _a.value + _b.value);
  late final ObservableFuture<int> future = ObservableFuture<int>(
    () async => 1,
  );

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) => Text('${total.value}');

  @override
  void dispose() {
    total.close();
    future.close();
    super.dispose();
  }
}

/// A third, non-eligible field reads `total` *immediately* (not inside a
/// closure) — that read runs during construction, before `total` would be
/// assigned inside `initState()` after the rewrite, so `total` is
/// excluded, leaving only one eligible field.
class ImmediateCrossReferenceWidget extends StatefulWidget {
  const ImmediateCrossReferenceWidget({super.key});

  @override
  State<ImmediateCrossReferenceWidget> createState() =>
      _ImmediateCrossReferenceWidgetState();
}

class _ImmediateCrossReferenceWidgetState
    extends State<ImmediateCrossReferenceWidget> {
  late final Computed<int> total = Computed(() => _a.value + _b.value);
  late final Computed<int> doubled = Computed(() => _a.value * 2);
  late final Computed<int> snapshot = total;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) => Text('${snapshot.value}');

  @override
  void dispose() {
    total.close();
    doubled.close();
    super.dispose();
  }
}

/// Disposal is delegated to a helper method instead of appearing directly
/// inside `dispose()`'s own block — `DisposalIndex` would still resolve
/// it, but this analyzer additionally requires the literal statement to
/// edit be found directly in `dispose()`, so a helper-delegated candidate
/// is excluded rather than guessed at.
class HelperDisposalWidget extends StatefulWidget {
  const HelperDisposalWidget({super.key});

  @override
  State<HelperDisposalWidget> createState() => _HelperDisposalWidgetState();
}

class _HelperDisposalWidgetState extends State<HelperDisposalWidget> {
  late final Computed<int> total = Computed(() => _a.value + _b.value);
  late final Computed<int> doubled = Computed(() => total.value * 2);

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) => Text('${doubled.value}');

  void _disposeResources() {
    total.close();
    doubled.close();
  }

  @override
  void dispose() {
    _disposeResources();
    super.dispose();
  }
}
