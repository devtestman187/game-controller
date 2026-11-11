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
  });

  test('the streaming scripts are valid bash', () async {
    for (final file in ['../streaming/entrypoint.sh', '../tools/stream.sh']) {
      final result = await Process.run('bash', ['-n', file]);

      expect(result.exitCode, 0, reason: '$file: ${result.stderr}');
    }
  });
}
