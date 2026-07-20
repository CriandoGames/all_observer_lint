/// Minimal `Stopwatch`-based benchmark harness.
///
/// Deliberately dependency-free (no `package:benchmark_harness` or similar):
/// the plugin's own benchmarks only need warm-up + N repetitions + basic
/// min/median/mean/max reporting, so pulling in an extra package would be
/// unjustified weight (see `documentation/backlog.md`, "no unnecessary
/// benchmark dependency").
library;

class BenchResult {
  const BenchResult({
    required this.label,
    required this.samplesMicros,
  });

  final String label;
  final List<int> samplesMicros;

  int get min => samplesMicros.reduce((a, b) => a < b ? a : b);
  int get max => samplesMicros.reduce((a, b) => a > b ? a : b);

  double get mean =>
      samplesMicros.reduce((a, b) => a + b) / samplesMicros.length;

  double get median {
    final sorted = [...samplesMicros]..sort();
    final mid = sorted.length ~/ 2;
    if (sorted.length.isOdd) return sorted[mid].toDouble();
    return (sorted[mid - 1] + sorted[mid]) / 2;
  }

  String format() {
    String us(num value) => '${value.toStringAsFixed(1)}µs';
    return '$label: n=${samplesMicros.length} '
        'min=${us(min)} median=${us(median)} mean=${us(mean)} max=${us(max)}';
  }
}

/// Runs [body] [warmup] times (discarded) then [repeat] times (measured),
/// returning per-run timings in microseconds.
BenchResult measure({
  required String label,
  required void Function() body,
  int warmup = 5,
  int repeat = 20,
}) {
  for (var i = 0; i < warmup; i++) {
    body();
  }

  final samples = <int>[];
  for (var i = 0; i < repeat; i++) {
    final stopwatch = Stopwatch()..start();
    body();
    stopwatch.stop();
    samples.add(stopwatch.elapsedMicroseconds);
  }

  return BenchResult(label: label, samplesMicros: samples);
}

/// Async variant of [measure], for benchmarks whose body must `await`
/// (e.g. `DartAssist.testRun`).
Future<BenchResult> measureAsync({
  required String label,
  required Future<void> Function() body,
  int warmup = 3,
  int repeat = 10,
}) async {
  for (var i = 0; i < warmup; i++) {
    await body();
  }

  final samples = <int>[];
  for (var i = 0; i < repeat; i++) {
    final stopwatch = Stopwatch()..start();
    await body();
    stopwatch.stop();
    samples.add(stopwatch.elapsedMicroseconds);
  }

  return BenchResult(label: label, samplesMicros: samples);
}
