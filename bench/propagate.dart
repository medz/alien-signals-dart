import 'dart:math' as math;
import 'package:alien_signals/preset.dart';

Future<List<int>> runBenchmark(String title, int w, int h) async {
  final values = <int>[];
  final stopwatch = Stopwatch();

  await warmup(w, h);

  print('Running benchmark $title...');
  for (int i = 0; i < 1000; i++) {
    stopwatch.start();
    runTest(w, h);
    stopwatch.stop();

    final ns =
        (stopwatch.elapsedTicks * 1000000000 / stopwatch.frequency).round();
    values.add(ns);
    stopwatch.reset();
  }

  values.sort();
  return values;
}

Future<void> warmup(int w, int h) async {
  final endTime = DateTime.now().add(Duration(milliseconds: 500));
  while (DateTime.now().isBefore(endTime)) {
    runTest(w, h);
  }
  await Future.delayed(Duration(milliseconds: 100));
}

void runTest(int w, int h) {
  final src = signal(1);
  for (int j = 0; j < w; j++) {
    Signal last = src;
    for (int k = 0; k < h; k++) {
      final prev = last;
      last = computed((_) => prev() + 1);
    }
    effect(() => last());
  }
  src(src() + 1);
}

Map<String, num> calculateStats(List<int> values) {
  return {
    'avg': values.reduce((a, b) => a + b) / values.length,
    'min': values.reduce((a, b) => a < b ? a : b),
    'max': values.reduce((a, b) => a > b ? a : b),
    'p75': percentile(values, 75),
    'p99': percentile(values, 99),
  };
}

void printResults(Map<String, List<int>> results) {
  final headers = ["benchmark", "avg", "min", "max", "p75", "p99"];
  final stats = <String, Map<String, num>>{};

  for (final entry in results.entries) {
    stats[entry.key] = calculateStats(entry.value);
  }

  final allRows = results.keys.map((title) => [
        title,
        '`${formatElapse(stats[title]!['avg']!.toInt())}/iter`',
        '`${formatElapse(stats[title]!['min']!.toInt())}`',
        '`${formatElapse(stats[title]!['max']!.toInt())}`',
        '`${formatElapse(stats[title]!['p75']!.toInt())}`',
        '`${formatElapse(stats[title]!['p99']!.toInt())}`',
      ]);

  printTable(headers, allRows.toList());
}

void printTable(List<String> headers, List<List<String>> rows) {
  final colWidths = List.filled(headers.length, 0);

  for (var i = 0; i < headers.length; i++) {
    colWidths[i] = headers[i].length;
    for (var row in rows) {
      colWidths[i] = math.max(colWidths[i], row[i].length);
    }
  }

  print(headers
      .map((h) => h.padRight(colWidths[headers.indexOf(h)]))
      .join(' | '));
  print(colWidths.map((w) => '-' * w).join(' | '));

  for (final row in rows) {
    print(row
        .map((cell) => cell.padRight(colWidths[row.indexOf(cell)]))
        .join(' | '));
  }
}

main() async {
  const spec = [1, 10, 100];
  final result = <String, List<int>>{};

  for (final w in spec) {
    for (final h in spec) {
      final title = 'Propagate $w x $h';
      result[title] = await runBenchmark(title, w, h);
    }
  }

  printResults(result);
}

String formatElapse(int elapsedNs) {
  if (elapsedNs >= 1000000000) {
    return '${(elapsedNs / 1000000000).toStringAsFixed(3)} s';
  } else if (elapsedNs >= 1000000) {
    return '${(elapsedNs / 1000000).toStringAsFixed(3)} ms';
  } else if (elapsedNs >= 1000) {
    return '${(elapsedNs / 1000).toStringAsFixed(3)} µs';
  }
  return '$elapsedNs ns';
}

int percentile(List<int> sortedValues, int p) {
  if (sortedValues.isEmpty) {
    throw ArgumentError('List cannot be empty');
  }

  final count =
      (sortedValues.length * p / 100).ceil().clamp(1, sortedValues.length);

  return sortedValues[count - 1];
}
