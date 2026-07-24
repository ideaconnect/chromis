// Turns `flutter test --file-reporter json:<file>` output into a human report:
// a console summary + build/e2e-report/index.html + build/e2e-report/report.md,
// grouped by feature -> scenario with pass/fail and timing.
//
// Usage: dart run tool/e2e_report.dart <results.json> [deviceLabel]
import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln(
      'usage: dart run tool/e2e_report.dart <results.json> [device]',
    );
    exit(64);
  }
  final resultsFile = File(args[0]);
  if (!resultsFile.existsSync()) {
    stderr.writeln('E2E results file not found: ${args[0]}');
    stderr.writeln('(did the test run produce it?)');
    exit(66);
  }
  final device = args.length > 1 && args[1].isNotEmpty
      ? args[1]
      : 'connected device';

  final suites = <int, String>{}; // suiteID -> feature file path
  final groups = <int, String>{}; // groupID -> group (feature) name
  final tests = <int, _Scenario>{}; // testID -> scenario

  for (final line in resultsFile.readAsLinesSync()) {
    if (line.trim().isEmpty) continue;
    Object? decoded;
    try {
      decoded = jsonDecode(line);
    } catch (_) {
      continue; // ignore any non-JSON console noise
    }
    if (decoded is! Map) continue;
    switch (decoded['type']) {
      case 'suite':
        final s = decoded['suite'] as Map;
        suites[s['id'] as int] = (s['path'] as String?) ?? '';
      case 'group':
        final g = decoded['group'] as Map;
        groups[g['id'] as int] = (g['name'] as String?) ?? '';
      case 'testStart':
        final t = decoded['test'] as Map;
        final id = t['id'] as int;
        tests[id] = _Scenario(
          id: id,
          name: (t['name'] as String?) ?? '',
          suiteId: t['suiteID'] as int?,
          groupIds: (t['groupIDs'] as List?)?.cast<int>() ?? const [],
          startMs: (decoded['time'] as num?)?.toInt() ?? 0,
        );
      case 'testDone':
        final t = tests[decoded['testID'] as int];
        if (t == null) break;
        t.hidden = decoded['hidden'] == true;
        t.skipped = decoded['skipped'] == true;
        t.result = (decoded['result'] as String?) ?? 'unknown';
        t.endMs = (decoded['time'] as num?)?.toInt() ?? t.startMs;
      case 'error':
        final t = tests[decoded['testID'] as int];
        if (t == null) break;
        final err = (decoded['error'] as String?) ?? '';
        final st = (decoded['stackTrace'] as String?) ?? '';
        t.errors.add(st.isEmpty ? err : '$err\n$st');
    }
  }

  // Real scenarios only (drop the hidden "loading <path>" framework tests).
  final scenarios = tests.values.where((t) => !t.hidden).toList()
    ..sort((a, b) => a.id.compareTo(b.id));

  // Group scenarios under their feature (the named group; fall back to file).
  final features = <String, List<_Scenario>>{};
  for (final s in scenarios) {
    final feature = _featureName(s, groups, suites);
    (features[feature] ??= []).add(s);
    s.feature = feature;
    s.shortName = _stripPrefix(s.name, feature);
  }

  final total = scenarios.length;
  final passed = scenarios.where((s) => s.passed).length;
  final skipped = scenarios.where((s) => s.skipped).length;
  final failed = total - passed - skipped;
  final durationMs = scenarios.fold<int>(0, (a, s) => a + s.durationMs);
  final generatedAt = DateTime.now();

  // ---- console summary ----
  final bar = '=' * 60;
  stdout.writeln('\n$bar');
  stdout.writeln('  E2E RESULTS  ($device)');
  stdout.writeln(bar);
  for (final entry in features.entries) {
    stdout.writeln('\n  Feature: ${entry.key}');
    for (final s in entry.value) {
      final mark = s.skipped ? '~' : (s.passed ? 'PASS' : 'FAIL');
      stdout.writeln('    [$mark] ${s.shortName}  (${s.durationMs} ms)');
    }
  }
  stdout.writeln('\n$bar');
  stdout.writeln(
    '  $passed passed, $failed failed, $skipped skipped '
    'of $total scenarios in ${(durationMs / 1000).toStringAsFixed(1)}s',
  );
  stdout.writeln(bar);

  // ---- write reports ----
  final outDir = Directory('build/e2e-report')..createSync(recursive: true);
  File('${outDir.path}/index.html').writeAsStringSync(
    _html(
      features,
      device,
      generatedAt,
      total,
      passed,
      failed,
      skipped,
      durationMs,
    ),
  );
  File('${outDir.path}/report.md').writeAsStringSync(
    _markdown(
      features,
      device,
      generatedAt,
      total,
      passed,
      failed,
      skipped,
      durationMs,
    ),
  );
  stdout.writeln('\n  HTML report:     build/e2e-report/index.html');
  stdout.writeln('  Markdown report: build/e2e-report/report.md\n');
}

String _featureName(
  _Scenario s,
  Map<int, String> groups,
  Map<int, String> suites,
) {
  for (final gid in s.groupIds.reversed) {
    final name = groups[gid];
    if (name != null && name.trim().isNotEmpty) return name;
  }
  final path = suites[s.suiteId] ?? '';
  return path.isEmpty ? 'Ungrouped' : path.split(RegExp(r'[\\/]')).last;
}

String _stripPrefix(String name, String feature) {
  final trimmed = name.startsWith(feature)
      ? name.substring(feature.length)
      : name;
  return trimmed.trim().isEmpty ? name : trimmed.trim();
}

String _esc(String s) =>
    s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');

String _html(
  Map<String, List<_Scenario>> features,
  String device,
  DateTime at,
  int total,
  int passed,
  int failed,
  int skipped,
  int durationMs,
) {
  final ok = failed == 0;
  final b = StringBuffer();
  b.writeln('<!doctype html><html lang="en"><head><meta charset="utf-8">');
  b.writeln(
    '<meta name="viewport" content="width=device-width,initial-scale=1">',
  );
  b.writeln('<title>Chromis — E2E report</title><style>');
  b.writeln('''
:root{color-scheme:dark}
*{box-sizing:border-box}
body{margin:0;font:15px/1.5 -apple-system,Segoe UI,Roboto,sans-serif;background:#0a1826;color:#e6edf5}
.wrap{max-width:900px;margin:0 auto;padding:28px 20px 60px}
h1{font-size:22px;margin:0 0 4px}
.sub{color:#8aa0b6;font-size:13px;margin-bottom:22px}
.cards{display:flex;gap:12px;flex-wrap:wrap;margin-bottom:26px}
.card{flex:1;min-width:120px;background:#0e1c2c;border:1px solid #1b2c40;border-radius:14px;padding:14px 16px}
.card .n{font-size:26px;font-weight:800}
.card .l{font-size:11px;letter-spacing:.06em;text-transform:uppercase;color:#8aa0b6}
.banner{border-radius:12px;padding:12px 16px;font-weight:700;margin-bottom:24px}
.pass{background:rgba(46,204,113,.14);border:1px solid #2ecc71;color:#8ef0b6}
.fail{background:rgba(231,76,60,.14);border:1px solid #e74c3c;color:#f7b0a8}
.feature{background:#0e1c2c;border:1px solid #1b2c40;border-radius:14px;margin-bottom:16px;overflow:hidden}
.feature>h2{font-size:15px;margin:0;padding:14px 16px;background:#12233a;border-bottom:1px solid #1b2c40}
.row{display:flex;align-items:center;gap:10px;padding:11px 16px;border-top:1px solid #14263a}
.row:first-of-type{border-top:none}
.badge{flex:none;width:52px;text-align:center;font-size:11px;font-weight:800;padding:3px 0;border-radius:6px}
.b-pass{background:rgba(46,204,113,.16);color:#7fe6a6}
.b-fail{background:rgba(231,76,60,.16);color:#f19a90}
.b-skip{background:rgba(160,160,160,.16);color:#b8c4d0}
.name{flex:1}
.time{color:#8aa0b6;font-size:12px;flex:none}
pre{margin:0 16px 14px;padding:12px;background:#08131f;border:1px solid #24384f;border-radius:8px;color:#f7b0a8;font-size:12px;overflow-x:auto;white-space:pre-wrap}
''');
  b.writeln('</style></head><body><div class="wrap">');
  b.writeln('<h1>Chromis — E2E report</h1>');
  b.writeln('<div class="sub">${_esc(device)} · ${at.toIso8601String()}</div>');
  b.writeln(
    '<div class="cards">'
    '<div class="card"><div class="n">$total</div><div class="l">Scenarios</div></div>'
    '<div class="card"><div class="n" style="color:#2ecc71">$passed</div><div class="l">Passed</div></div>'
    '<div class="card"><div class="n" style="color:${failed > 0 ? "#e74c3c" : "#8aa0b6"}">$failed</div><div class="l">Failed</div></div>'
    '<div class="card"><div class="n">${(durationMs / 1000).toStringAsFixed(1)}s</div><div class="l">Duration</div></div>'
    '</div>',
  );
  b.writeln(
    '<div class="banner ${ok ? "pass" : "fail"}">'
    '${ok ? "✓ All $total scenarios passed" : "✗ $failed of $total scenarios failed"}</div>',
  );
  for (final entry in features.entries) {
    b.writeln('<div class="feature"><h2>${_esc(entry.key)}</h2>');
    for (final s in entry.value) {
      final cls = s.skipped ? 'b-skip' : (s.passed ? 'b-pass' : 'b-fail');
      final label = s.skipped ? 'SKIP' : (s.passed ? 'PASS' : 'FAIL');
      b.writeln(
        '<div class="row"><span class="badge $cls">$label</span>'
        '<span class="name">${_esc(s.shortName)}</span>'
        '<span class="time">${s.durationMs} ms</span></div>',
      );
      if (!s.passed && s.errors.isNotEmpty) {
        b.writeln('<pre>${_esc(s.errors.join("\n\n"))}</pre>');
      }
    }
    b.writeln('</div>');
  }
  b.writeln('</div></body></html>');
  return b.toString();
}

String _markdown(
  Map<String, List<_Scenario>> features,
  String device,
  DateTime at,
  int total,
  int passed,
  int failed,
  int skipped,
  int durationMs,
) {
  final b = StringBuffer();
  b.writeln('# Chromis — E2E report\n');
  b.writeln('- Device: `$device`');
  b.writeln('- Generated: ${at.toIso8601String()}');
  b.writeln(
    '- Result: **$passed passed, $failed failed, $skipped skipped** '
    'of $total scenarios in ${(durationMs / 1000).toStringAsFixed(1)}s\n',
  );
  for (final entry in features.entries) {
    b.writeln('## Feature: ${entry.key}\n');
    for (final s in entry.value) {
      final mark = s.skipped ? '⚪' : (s.passed ? '✅' : '❌');
      b.writeln('- $mark ${s.shortName} _(${s.durationMs} ms)_');
      if (!s.passed && s.errors.isNotEmpty) {
        b.writeln(
          '\n  ```\n${s.errors.join("\n").split("\n").map((l) => "  $l").join("\n")}\n  ```',
        );
      }
    }
    b.writeln();
  }
  return b.toString();
}

class _Scenario {
  _Scenario({
    required this.id,
    required this.name,
    required this.suiteId,
    required this.groupIds,
    required this.startMs,
  });

  final int id;
  final String name;
  final int? suiteId;
  final List<int> groupIds;
  final int startMs;

  int endMs = 0;
  bool hidden = false;
  bool skipped = false;
  String result = 'unknown';
  final List<String> errors = [];

  String feature = '';
  String shortName = '';

  bool get passed => result == 'success' && !skipped;
  int get durationMs => (endMs - startMs).clamp(0, 1 << 31);
}
