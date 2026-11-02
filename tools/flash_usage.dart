// Reads the JSON result of a headless Claude Code run (tools/flash.sh), so
// how much work goes to the worker can be measured over time.
//
//   dart tools/flash_usage.dart print <result.json>
//       prints the worker's answer and a line with its token use
//   dart tools/flash_usage.dart record <result.json> <usage-log.tsv> <result code> <files changed> <task file>
//       appends one line for the job to the usage log
//
// The log is tab-separated: time, result code, turns, seconds, input tokens,
// cache-read tokens, cache-write tokens, output tokens, files changed, and
// the task's first line (read from <task file>). The run's own cost figure is left out: it's worked
// out at Anthropic's prices, not DeepSeek's.
import 'dart:convert';
import 'dart:io';

Map<String, Object?>? _read(String path) {
  final file = File(path);
  if (!file.existsSync()) return null;
  try {
    final decoded = jsonDecode(file.readAsStringSync().trim());
    return decoded is Map<String, Object?> ? decoded : null;
  } on FormatException {
    return null;
  }
}

({
  int turns,
  double seconds,
  int input,
  int cacheRead,
  int cacheWrite,
  int output,
})
_usage(Map<String, Object?> r) {
  final usage = (r['usage'] as Map?) ?? const {};
  int n(String key) => (usage[key] as num?)?.toInt() ?? 0;
  return (
    turns: (r['num_turns'] as num?)?.toInt() ?? 0,
    seconds: ((r['duration_ms'] as num?) ?? 0) / 1000,
    input: n('input_tokens'),
    cacheRead: n('cache_read_input_tokens'),
    cacheWrite: n('cache_creation_input_tokens'),
    output: n('output_tokens'),
  );
}

void main(List<String> args) {
  final mode = args.firstOrNull;
  if (mode == 'print' && args.length == 2) {
    final r = _read(args[1]);
    if (r == null) {
      // Not JSON (the run failed before answering): show what there is.
      final file = File(args[1]);
      if (file.existsSync()) stdout.writeln(file.readAsStringSync());
      stdout.writeln('---- flash usage: not available (no JSON result)');
      return;
    }
    stdout.writeln(r['result'] ?? '(no answer)');
    final u = _usage(r);
    stdout.writeln(
      '---- flash usage: ${u.turns} turns, ${u.seconds.toStringAsFixed(0)} s, input ${u.input} '
      '+ cache read ${u.cacheRead} + cache write ${u.cacheWrite}, output ${u.output} tokens',
    );
    return;
  }
  if (mode == 'record' && args.length == 6) {
    final [_, path, logPath, code, files, taskFile] = args;
    final task = File(taskFile).existsSync() ? File(taskFile).readAsStringSync() : '';
    final r = _read(path);
    final u = r == null ? null : _usage(r);
    final firstLine = task.split('\n').first.replaceAll('\t', ' ');
    final title = firstLine.length > 100
        ? '${firstLine.substring(0, 100)}…'
        : firstLine;
    final log = File(logPath);
    if (!log.existsSync()) {
      log.createSync(recursive: true);
      log.writeAsStringSync(
        'time\tresult\tturns\tseconds\tinput\tcache_read\tcache_write\toutput\tfiles\ttask\n',
      );
    }
    final cells = u == null
        ? ['', '', '', '', '', '']
        : [
            u.turns,
            u.seconds.toStringAsFixed(0),
            u.input,
            u.cacheRead,
            u.cacheWrite,
            u.output,
          ];
    log.writeAsStringSync(
      '${[DateTime.now().toIso8601String().substring(0, 19), code, ...cells, files, title].join('\t')}\n',
      mode: FileMode.append,
    );
    return;
  }
  stderr.writeln(
    'usage: dart tools/flash_usage.dart print <result.json>\n'
    '       dart tools/flash_usage.dart record <result.json> <usage-log.tsv> <result code> <files> <task file>',
  );
  exit(64);
}
