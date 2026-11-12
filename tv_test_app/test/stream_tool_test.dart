import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The streaming session tool (M15) is a developer script, but it is the only
/// way a person starts a stream, and it runs commands as root inside a Linux
/// distro: its guard rails are tested here like any other rule.
void main() {
  // `flutter test` runs in tv_test_app, where the tests live.
  const script = '../tools/stream.sh';

  Future<ProcessResult> run(List<String> arguments) => Process.run('bash', [script, ...arguments]);

  test('the tool refuses a distro whose name does not start with tp-', () async {
    final result = await run(['--distro', 'minecraft', 'up']);

    expect(result.exitCode, 2, reason: 'a bad distro is bad use, and nothing runs');
    expect(result.stderr, contains('the distro name must start with "tp-"'));
  });

  test('the tool prints its usage when it is not told what to do', () async {
    final result = await run([]);

    expect(result.exitCode, 2);
    expect(result.stdout, contains('tools/stream.sh build'));
    expect(result.stdout, contains('tools/stream.sh up'));
    expect(result.stdout, contains('tools/stream.sh bench'), reason: 'the benchmark is one of its commands');
    expect(result.stdout, contains('tools/stream.sh stats'), reason: 'and the report it prints');
  });

  test('a benchmark refuses a label that is not lower-case', () async {
    final result = await run(['bench', '--label', 'BAD']);

    expect(result.exitCode, 1, reason: 'the label names files in docs/, so it is checked first');
    expect(result.stderr, contains('the label is lower-case letters, digits and dashes'));
  });

  test('the report refuses a folder that is not there', () async {
    final result = await run(['stats', '--results', 'docs/nope']);

    expect(result.exitCode, 1);
    expect(result.stderr, contains('no results at docs/nope'));
  });

  test('the streaming scripts are valid bash', () async {
    for (final file in ['../streaming/entrypoint.sh', '../streaming/bench.sh', '../tools/stream.sh']) {
      final result = await Process.run('bash', ['-n', file]);

      expect(result.exitCode, 0, reason: '$file: ${result.stderr}');
    }
  });
}
