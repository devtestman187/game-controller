// Simulated controller: pairs with the TV app and exchanges heartbeats,
// without a phone (PRD T3).
//
//   cd packages/connection
//   dart run connection:sim_controller --host 192.168.1.50 --code 1234
//
// Options: --host (default 127.0.0.1), --port (default 45780), --code (asked
// for if missing), --name, --seconds (run time, default: until Ctrl+C),
// --demo (press every button and D-pad direction in a loop).
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:connection/connection.dart';

const _usage = '''
Simulated controller: pairs with the TV app and keeps the connection alive.

Usage: dart run connection:sim_controller [options]
  --host <address>   TV or laptop address (default 127.0.0.1)
  --port <port>      Port shown on the TV (default 45780)
  --code <code>      Pairing code shown on the TV (asked for if missing)
  --name <name>      Name shown on the TV (default "Simulated controller")
  --demo             Once connected, press every button and D-pad direction in a loop
  --seconds <n>      Disconnect and exit after n seconds (default: run until Ctrl+C)''';

Future<void> main(List<String> args) async {
  final Map<String, String> options;
  try {
    options = _parse(args);
  } on FormatException catch (e) {
    stderr.writeln('${e.message}\n\n$_usage');
    exit(64);
  }
  if (options.containsKey('help')) {
    stdout.writeln(_usage);
    return;
  }

  final HostAddress target;
  try {
    final host = options['host'] ?? '127.0.0.1';
    target = HostAddress.parse(options.containsKey('port') ? '$host:${options['port']}' : host);
  } on FormatException catch (e) {
    stderr.writeln(e.message);
    exit(64);
  }
  final seconds = int.tryParse(options['seconds'] ?? '');
  final random = Random.secure();
  final id = 'sim-${List.generate(6, (_) => random.nextInt(16).toRadixString(16)).join()}';

  final client = ControllerClient(
    identity: ControllerIdentity(
      controllerId: id,
      name: options['name'] ?? 'Simulated controller',
      platform: 'sim',
      appVersion: '0.3.0',
    ),
    log: (m) => stdout.writeln('  · $m'),
  );

  final lines = stdin.transform(utf8.decoder).transform(const LineSplitter()).asBroadcastStream();
  var wasConnected = false;
  Timer? demo;
  var lastStatus = client.snapshot.status;
  final done = Completer<int>();

  client.changes.listen((s) {
    if (s.status == lastStatus) return;
    lastStatus = s.status;
    final problem = s.problem == null ? '' : ' (${s.problem!.name}${s.detail == null ? '' : ': ${s.detail}'})';
    stdout.writeln('${s.status.name.toUpperCase()}$problem');
    switch (s.status) {
      case ClientStatus.connected:
        wasConnected = true;
        if (options.containsKey('demo') && demo == null) demo = runDemoInput(client);
      case ClientStatus.waitingForCode:
        stdout.write('Pairing code shown on the TV: ');
        lines.first.then((code) => client.submitCode(code.trim()), onError: (_) {});
      case ClientStatus.failed:
        if (!done.isCompleted) done.complete(2);
      default:
    }
  });

  final pingReport = Timer.periodic(const Duration(seconds: 5), (_) {
    final rtt = client.snapshot.rttMs;
    final stats = client.snapshot.rttStats;
    if (client.snapshot.isConnected && rtt != null) stdout.writeln('ping $rtt ms (last 30 s: ${stats ?? '-'})');
  });
  if (seconds != null) {
    Timer(Duration(seconds: seconds), () {
      if (!done.isCompleted) done.complete(wasConnected ? 0 : 1);
    });
  }
  ProcessSignal.sigint.watch().first.then((_) {
    if (!done.isCompleted) done.complete(wasConnected ? 0 : 1);
  });

  stdout.writeln('Simulated controller $id → ${target.display}');
  client.connect(target, code: options['code']);

  final code = await done.future;
  pingReport.cancel();
  demo?.cancel();
  await client.dispose();
  // Let the close handshake reach the TV, so it logs a clean disconnect.
  await Future<void>.delayed(const Duration(milliseconds: 300));
  exit(code);
}

Map<String, String> _parse(List<String> args) {
  final result = <String, String>{};
  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg == '--help' || arg == '-h' || arg == '--demo') {
      result[arg == '--demo' ? 'demo' : 'help'] = '';
      continue;
    }
    if (!arg.startsWith('--')) throw FormatException('Unexpected argument "$arg"');
    final eq = arg.indexOf('=');
    if (eq > 0) {
      result[arg.substring(2, eq)] = arg.substring(eq + 1);
    } else if (i + 1 < args.length) {
      result[arg.substring(2)] = args[++i];
    } else {
      throw FormatException('Missing value for $arg');
    }
  }
  const known = {'host', 'port', 'code', 'name', 'seconds', 'help', 'demo'};
  final unknown = result.keys.where((k) => !known.contains(k));
  if (unknown.isNotEmpty) throw FormatException('Unknown option --${unknown.first}');
  return result;
}
