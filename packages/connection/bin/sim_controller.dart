// Simulated controller: pairs with the TV app and exchanges heartbeats,
// without a phone (PRD T3).
//
//   cd packages/connection
//   dart run connection:sim_controller --host 192.168.1.50 --code 1234
//
// Options: --host (default 127.0.0.1), --port (default 45780), --code (asked
// for if missing), --name, --seconds (run time, default: until Ctrl+C),
// --demo (press every button and D-pad direction in a loop), --stream (send a
// gyro-like tilt 60 times a second, for long-session tests). Haptic events
// from the TV (M5) and the player number (M6) are printed as they arrive,
// and a summary (drops, ping) at the end. --metrics (M9) lists the metrics
// and rating capabilities, sends a made-up metrics batch every 10 s and
// answers every rating prompt with "good", so the TV's Stats screen fills
// without a phone. --token-file <path> saves the pairing after the first
// connect (this controller's id, the host's id and the token the host gave),
// so a later run with the same file gets in without the code. --view (M12)
// lists the view capability, "draws" the game's frames on a 60 Hz timer and
// prints the touch-to-frame, jitter and frame counts when the run ends.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:connection/connection.dart';
import 'package:protocol/protocol.dart';

import 'sim_token_file.dart';
import 'sim_view.dart';

const _usage = '''
Simulated controller: pairs with the TV app and keeps the connection alive.

Usage: dart run connection:sim_controller [options]
  --host <address>   TV or laptop address (default 127.0.0.1)
  --port <port>      Port shown on the TV (default 45780)
  --code <code>      Pairing code shown on the TV (asked for if missing)
  --name <name>      Name shown on the TV (default "Simulated controller")
  --token-file <f>   Where the pairing is saved after the first connect; when the file
                     exists, connect with it instead of the code
  --demo             Once connected, press every button and D-pad direction in a loop
  --stream           Once connected, send a gyro-like tilt 60 times a second (long-session test)
  --metrics          Send metrics batches and answer rating prompts (M9 stats)
  --view             Show the game's frames without a screen and measure them (M12)
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
  final tokenFile = options['token-file'];
  final Pairing? saved;
  try {
    saved = tokenFile == null ? null : readTokenFile(tokenFile);
  } on FormatException catch (e) {
    stderr.writeln(e.message);
    exit(64);
  }
  final random = Random.secure();
  final id = saved?.controllerId ?? 'sim-${List.generate(6, (_) => random.nextInt(16).toRadixString(16)).join()}';

  // The host knows a saved pairing by this controller id and its token, and
  // the client looks the token up by the host's id, so all three go in the
  // file: a later run with it gets in without the code.
  void savePairing(String hostId, String? token) {
    if (token == null || tokenFile == null) return;
    writeTokenFile(tokenFile, (controllerId: id, hostId: hostId, token: token));
    stdout.writeln('  · Saved the pairing to $tokenFile');
  }

  final client = ControllerClient(
    identity: ControllerIdentity(
      controllerId: id,
      name: options['name'] ?? 'Simulated controller',
      platform: 'sim',
      appVersion: '0.11.0',
      capabilities: [
        if (options.containsKey('metrics')) ...[Capability.metrics, Capability.rating],
        if (options.containsKey('view')) Capability.view,
      ],
      device: const DeviceInfo(kind: DeviceInfo.sim),
    ),
    connector: WebSocketConnector(log: (m) => stdout.writeln('  · $m')),
    tokens: saved == null ? const {} : {saved.hostId: saved.token},
    onTokenChanged: tokenFile == null ? null : savePairing,
    log: (m) => stdout.writeln('  · $m'),
  );
  // A viewer that pairs mid-game gets the latest frame (s3a), so drawing can
  // start at once: it does nothing until a frame arrives.
  final view = options.containsKey('view') ? (SimView.of(client, playerId: id)..start()) : null;

  final lines = stdin.transform(utf8.decoder).transform(const LineSplitter()).asBroadcastStream();
  var wasConnected = false;
  var drops = 0;
  final pings = RunningStats();
  final started = DateTime.now();
  Timer? demo;
  var lastStatus = client.snapshot.status;
  int? lastPlayer;
  final done = Completer<int>();

  client.changes.listen((s) {
    if (s.player != null && s.player != lastPlayer) stdout.writeln('player ${s.player}');
    lastPlayer = s.player;
    if (s.status == lastStatus) return;
    lastStatus = s.status;
    final problem = s.problem == null ? '' : ' (${s.problem!.name}${s.detail == null ? '' : ': ${s.detail}'})';
    stdout.writeln('${s.status.name.toUpperCase()}$problem');
    switch (s.status) {
      case ClientStatus.connected:
        wasConnected = true;
        if (options.containsKey('demo') && demo == null) demo = runDemoInput(client);
        if (options.containsKey('stream') && demo == null) demo = runStreamInput(client);
      case ClientStatus.reconnecting:
        drops++;
      case ClientStatus.waitingForCode:
        stdout.write('Pairing code shown on the TV: ');
        lines.first.then((code) => client.submitCode(code.trim()), onError: (_) {});
      case ClientStatus.failed:
        if (!done.isCompleted) done.complete(2);
      default:
    }
  });

  // Made-up metrics: one D-pad segment, its counters growing every 10 s.
  Timer? metrics;
  var batch = 0;
  final segment = '$id-1';
  if (options.containsKey('metrics')) {
    metrics = Timer.periodic(const Duration(seconds: 10), (_) {
      batch++;
      client.sendMetrics(
        MetricsMessage(
          segment: segment,
          index: batch,
          mode: 'dpad',
          durationMs: batch * 10000,
          data: {
            'start': 0,
            'touches': batch * 12,
            'presses': {'a': batch * 8, 'dpad': batch * 3},
            'near': {'b': batch},
            'empty': {'5,1': batch},
          },
        ),
      );
      stdout.writeln('metrics batch $batch (${client.metricsWaiting} waiting)');
    });
    client.ratingAsks.listen((ask) {
      stdout.writeln('rating prompt ${ask.id}: answering "good"');
      client.sendRating(RatingMessage(id: ask.id, face: RatingFace.good));
    });
  }

  client.hapticEvents.listen(
    (e) => stdout.writeln('haptic ${e.event.name} intensity ${e.intensity} ${e.durationMs} ms'),
  );

  final pingReport = Timer.periodic(const Duration(seconds: 5), (_) {
    final rtt = client.snapshot.rttMs;
    final stats = client.snapshot.rttStats;
    if (client.snapshot.isConnected && rtt != null) pings.add(rtt);
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
  // With a saved pairing the code isn't needed; without one, connect as before.
  client.connect(target, code: saved == null ? options['code'] : null);

  final code = await done.future;
  final ran = DateTime.now().difference(started);
  stdout.writeln(
    'Summary: ran ${ran.inMinutes} min ${ran.inSeconds % 60} s, ${client.inputsSent} input states sent, '
    '$drops drop${drops == 1 ? '' : 's'}, ping (every 5 s) $pings',
  );
  view?.stop();
  view?.summary();
  pingReport.cancel();
  metrics?.cancel();
  demo?.cancel();
  await view?.dispose();
  await client.dispose();
  // Let the close handshake reach the TV, so it logs a clean disconnect.
  await Future<void>.delayed(const Duration(milliseconds: 300));
  exit(code);
}

Map<String, String> _parse(List<String> args) {
  final result = <String, String>{};
  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg == '--help' ||
        arg == '-h' ||
        arg == '--demo' ||
        arg == '--stream' ||
        arg == '--metrics' ||
        arg == '--view') {
      result[arg.startsWith('--') && arg != '--help' ? arg.substring(2) : 'help'] = '';
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
  const known = {'host', 'port', 'code', 'name', 'seconds', 'help', 'demo', 'stream', 'metrics', 'view', 'token-file'};
  final unknown = result.keys.where((k) => !known.contains(k));
  if (unknown.isNotEmpty) throw FormatException('Unknown option --${unknown.first}');
  return result;
}
