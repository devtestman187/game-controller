import 'dart:io';

import 'package:connection/connection.dart';
import 'package:path/path.dart' as p;
import 'package:protocol/protocol.dart';

import 'host_identity.dart';
import 'host_view_state.dart';

/// The exported log: a header with the app, the time and each controller's
/// latency (PRD T8), then every log line, oldest first.
///
/// [identity] supplies the app's version label and operating system for the
/// header, so this file has no platform code (S-a). [now] is the time written
/// in the header, so tests can fix it.
String buildLogExport(HostViewState state, LogBuffer log, HostIdentity identity, {required DateTime now}) {
  final b = StringBuffer()
    ..writeln('Thumb Party TV ${identity.versionLabel} log, ${now.toIso8601String()}')
    ..writeln(
      'Host: ${state.hostName} (${identity.hostOs}), port ${state.host.port ?? '-'}, protocol v$protocolVersion',
    )
    ..writeln('Addresses: ${state.addresses.map((a) => '${a.address} (${a.interfaceName})').join(', ')}')
    ..writeln()
    ..writeln('Controllers (latency: last 30 s, and since the controller connected):');
  if (state.host.controllers.isEmpty) b.writeln('  none');
  for (final c in state.host.controllers) {
    b.writeln('  ${c.player == null ? '' : 'P${c.player} '}${c.name} (${c.platform} ${c.appVersion}), ${c.state.name}');
    if (c.state != ControllerState.connected) continue;
    final rtt = c.rttStats;
    b.writeln('    Ping: ${rtt == null ? '-' : '$rtt, p95 ${rtt.p95Ms} ms'}');
    b.writeln('    Input delay (estimated, one way): ${latencyText(c)}');
  }
  b
    ..writeln()
    ..writeln('Log (${log.lines.length} lines, oldest first):')
    ..writeln(log.export());
  return b.toString();
}

/// Saves [state]'s export (see [buildLogExport]) in [dir] under a timestamped
/// name and returns the file's path (PRD T8). [log], [identity] and [now] are
/// passed on, so tests can fix the time.
Future<String> writeLogExport({
  required Directory dir,
  required HostViewState state,
  required LogBuffer log,
  required HostIdentity identity,
  required DateTime now,
}) async {
  String two(int n) => n.toString().padLeft(2, '0');
  final name =
      'controller-test-log-${now.year}${two(now.month)}${two(now.day)}-${now.hour}${two(now.minute)}${two(now.second)}.txt';
  final file = File(p.join(dir.path, name));
  await file.writeAsString(buildLogExport(state, log, identity, now: now));
  return file.path;
}

/// "avg 8 · p95 14 · max 30 ms (± 3 ms); session avg 9 ms", or why it isn't
/// measured.
String latencyText(ControllerInfo c) {
  final l = c.inputLatency;
  if (l == null) {
    return c.latencyErrorMs == null ? 'not measured (phone app older than 0.6.0?)' : 'waiting for input';
  }
  final session = c.inputLatencySession;
  return 'avg ${l.avgMs} · p95 ${l.p95Ms} · max ${l.maxMs} ms (± ${c.latencyErrorMs} ms)'
      '${session == null ? '' : '; session avg ${session.avgMs} ms over ${session.samples} states'}';
}
