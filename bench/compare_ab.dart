// A/B comparison with 5-run statistical validation.
// Usage: First run on optimized code, then stash and run on original.
//        Results are saved to /tmp/ and compared.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

const runs = 5;

Map<String, List<double>> runAndParse(String script) {
  final results = <String, List<double>>{};
  for (var i = 0; i < runs; i++) {
    final out = Process.runSync('dart', ['run', script]).stdout as String;
    final re = RegExp(r'^(.+?)\(RunTime\):\s+([\d.]+)\s+us\.?$', multiLine: true);
    for (final m in re.allMatches(out)) {
      results.putIfAbsent(m.group(1)!.trim(), () => []).add(double.parse(m.group(2)!));
    }
  }
  return results;
}

void main(List<String> args) {
  final mode = args.isNotEmpty ? args[0] : 'run';
  final scripts = ['bench/propagate.dart', 'bench/topology_bench.dart', 'bench/signal_micro.dart'];

  if (mode == 'save_opt') {
    print('Running optimized code ($runs passes)...');
    final all = <String, List<double>>{};
    for (final s in scripts) { all.addAll(runAndParse(s)); }
    final file = File('/tmp/ab_opt.json');
    file.writeAsStringSync(jsonEncode(all));
    print('Saved ${all.length} benchmarks to /tmp/ab_opt.json');
  } else if (mode == 'save_orig') {
    print('Running original code ($runs passes)...');
    final all = <String, List<double>>{};
    for (final s in scripts) { all.addAll(runAndParse(s)); }
    final file = File('/tmp/ab_orig.json');
    file.writeAsStringSync(jsonEncode(all));
    print('Saved ${all.length} benchmarks to /tmp/ab_orig.json');
  } else if (mode == 'compare') {
    final origJson = jsonDecode(File('/tmp/ab_orig.json').readAsStringSync()) as Map<String, dynamic>;
    final optJson = jsonDecode(File('/tmp/ab_opt.json').readAsStringSync()) as Map<String, dynamic>;
    final orig = origJson.map((k, v) => MapEntry(k, (v as List).cast<double>()));
    final opt = optJson.map((k, v) => MapEntry(k, (v as List).cast<double>()));
    print('');
    print('A/B Comparison: Original → Optimized (${runs}-run avg, ±σ)');
    print('');
    print('Benchmark                              Original        Optimized        Δ         σ-ratio');
    print('${"-" * 95}');

    final names = {...orig.keys, ...opt.keys}.toList()..sort();
    var improvs = 0, regrs = 0, neutral = 0;
    for (final name in names) {
      final o = orig[name];
      final p = opt[name];
      if (o == null || p == null) continue;

      final oMean = o.reduce((a, b) => a + b) / o.length;
      final pMean = p.reduce((a, b) => a + b) / p.length;
      final oStd = _stddev(o, oMean);
      final pStd = _stddev(p, pMean);
      final diff = pMean - oMean;
      final pct = oMean > 0 ? (diff / oMean) * 100 : 0;
      final pooled = sqrt(oStd * oStd + pStd * pStd);
      final sigma = pooled > 0 ? diff.abs() / pooled : 0;

      String sym;
      if (pct < -3 && sigma > 1.5) { sym = '✅✅'; improvs++; }
      else if (pct < -1) { sym = '✅'; improvs++; }
      else if (pct > 3 && sigma > 1.5) { sym = '⚠️'; regrs++; }
      else if (pct > 1) { sym = '⚡'; regrs++; }
      else { sym = '➖'; neutral++; }

      print('${sym} ${name.padRight(40)} '
          '${oMean.toStringAsFixed(1).padLeft(8)} µs  '
          '${pMean.toStringAsFixed(1).padLeft(8)} µs  '
          '${pct.toStringAsFixed(1).padLeft(6)}%  '
          '${sigma.toStringAsFixed(1).padLeft(6)}σ');
    }
    print('');
    print('Summary: $improvs improved, $regrs regressed, $neutral within noise');
    print('');
    print('✅✅ = >3% faster, >1.5σ | ✅ = >1% faster | ➖ = noise | ⚡ = >1% slower | ⚠️ = >3% slower, >1.5σ');
  } else {
    print('Usage: dart run bench/compare_ab.dart [save_opt|save_orig|compare]');
  }
}

double _stddev(List<double> vals, double mean) {
  if (vals.length < 2) return 0;
  final variance = vals.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) / (vals.length - 1);
  return sqrt(variance);
}

