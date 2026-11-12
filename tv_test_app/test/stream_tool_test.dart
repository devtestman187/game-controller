import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The streaming session tool (M15) is a developer script, but it is the only
/// way a person starts a stream, and it runs commands as root inside a Linux
/// distro: its guard rails are tested here like any other rule. The player's
/// relay has its own test in the distro (`streaming/player/relay_test.py`,
/// run by `tools/stream.sh selftest`), because Python is what serves it.
void main() {
  // `flutter test` runs in tv_test_app, where the tests live.
  const script = '../tools/stream.sh';

  Future<ProcessResult> run(List<String> arguments, {Map<String, String>? environment}) =>
      Process.run('bash', [script, ...arguments], environment: environment);

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
    expect(result.stdout, contains('tools/stream.sh selftest'), reason: 'and the relay test that runs in the distro');
  });

  test('the usage says a bench can wait for a viewer a person opens', () async {
    final result = await run([]);

    expect(result.stdout, contains('--viewer <kind>'));
    expect(result.stdout, contains('external: no browser is opened'));
  });

  test('a benchmark refuses a viewer it does not know', () async {
    final result = await run(['bench', '--viewer', 'nope']);

    expect(result.exitCode, 2, reason: 'a viewer is picked before any session starts');
    expect(result.stderr, contains('--viewer is chrome or external, got "nope"'));
  });

  test('a benchmark refuses a core list that is not one', () async {
    for (final (option, value) in [('--viewer-cpus', 'x'), ('--session-cpus', '8-')]) {
      final result = await run(['bench', option, value]);

      expect(result.exitCode, 2, reason: '"$value" would reach taskset or docker as a core list');
      expect(result.stderr, contains('$option is a core list like 0-7 or 8-15, got "$value"'));
    }
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

  test('a stale keep-alive pid file is reported, not acted on', () async {
    final folder = Directory.systemTemp.createTempSync('tp-stream-test');
    addTearDown(() => folder.deleteSync(recursive: true));
    final pidFile = File('${folder.path}/keepalive.pid')..writeAsStringSync('999999\n');
    final environment = {'STREAM_KEEPALIVE_FILE': pidFile.path};

    final result = await run(['keep-alive'], environment: environment);

    expect(result.exitCode, 0);
    expect(result.stdout, contains('keep-alive: not running (a stale pid file'));
    final stopped = await run(['keep-alive', '--stop'], environment: environment);
    expect(stopped.exitCode, 0);
    expect(pidFile.existsSync(), isFalse, reason: 'stopping clears the file, whatever it held');
  });

  test('the keep-alive never ends a process that is not its own', () async {
    final folder = Directory.systemTemp.createTempSync('tp-stream-test');
    addTearDown(() => folder.deleteSync(recursive: true));
    // This test process is alive but its command line is not the keep-alive's
    // `sleep infinity`, so the pid check must refuse it.
    final pidFile = File('${folder.path}/keepalive.pid')..writeAsStringSync('$pid\n');

    final result = await run(['keep-alive', '--stop'], environment: {'STREAM_KEEPALIVE_FILE': pidFile.path});

    expect(result.exitCode, 0);
    expect(result.stdout, isNot(contains('keep-alive: stopped')), reason: 'that pid is not the keep-alive');
    expect(pidFile.existsSync(), isFalse);
  });

  test('a benchmark refuses a setting that is not KEY=VALUE', () async {
    for (final setting in ['nope', 'lower=x', 'KEY=two words']) {
      final result = await run(['bench', '--set', setting]);

      expect(result.exitCode, 2, reason: '"$setting" would reach docker run as -e');
      expect(result.stderr, contains('a setting is KEY=VALUE (upper-case name, a plain value)'));
    }
  });
}
