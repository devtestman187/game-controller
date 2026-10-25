import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:protocol/protocol.dart';
import 'package:share_plus/share_plus.dart';

import '../device_status.dart';
import '../gyro.dart';
import '../local_network.dart';
import '../providers.dart';
import 'labels.dart';

/// Basic Diagnostics (PRD C10): connection state, discovered TVs, local
/// network permission and recent log lines, with a share button. This is how
/// iOS problems get debugged without Xcode.
class DiagnosticsScreen extends ConsumerWidget {
  const DiagnosticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.watch(clientStateProvider);
    final discovery = ref.watch(discoveryStateProvider);
    final network = ref.watch(localNetworkStatusProvider);
    final identity = ref.watch(identityProvider);
    final lines = ref.watch(logLinesProvider);
    final caps = ref.watch(hapticsCapabilitiesProvider).value;
    final haptics = ref.watch(hapticSettingsProvider);
    final player = ref.read(hapticsPlayerProvider);
    final tvHaptics = ref.watch(tvHapticsProvider);
    final input = ref.watch(padProvider);
    final gyro = ref.watch(gyroProvider);
    final gyroSettings = ref.watch(gyroSettingsProvider);
    final stickSettings = ref.watch(stickSettingsProvider);
    final outages = ref.watch(outagesProvider);
    final session = ref.watch(sessionStatsProvider);
    final text = Theme.of(context).textTheme;
    final mono = text.bodySmall?.copyWith(fontFamily: 'monospace', height: 1.3);
    final target = client.target;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagnostics'),
        actions: [
          IconButton(
            tooltip: 'Copy report',
            icon: const Icon(Icons.copy),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: buildReport(ref)));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report copied')));
              }
            },
          ),
          Builder(
            builder: (buttonContext) => IconButton(
              tooltip: 'Share log',
              icon: const Icon(Icons.share),
              onPressed: () => _share(buttonContext, ref),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _Section('Connection', [
              ('Status', statusLabel(client)),
              ('TV', client.hostLabel.isEmpty ? '–' : client.hostLabel),
              ('Address', target?.ordered.map((a) => target.copyWith(addresses: [a]).display).join(', ') ?? '–'),
              ('TV ID', target?.hostId ?? '–'),
              if (client.player != null) ('Player', 'P${client.player} on the TV'),
              ('Ping', client.rttMs == null ? '–' : '${client.rttMs} ms'),
              if (client.rttStats != null) ('Ping, last 30 s', '${client.rttStats}, p95 ${client.rttStats!.p95Ms} ms'),
              if (client.problem != null) ('Problem', client.problem!.name),
              if (client.detail != null) ('Detail', client.detail!),
              if (client.osErrorCode != null) ('OS error', '${client.osErrorCode}'),
              if (client.attempt > 0) ('Reconnect attempt', '${client.attempt}'),
            ]),
            _Section('Local network permission', [
              ('Status', network.label),
              ('', network.explanation),
            ], highlight: network.access == LocalNetworkAccess.probablyDenied),
            _Section('Discovery ($serviceType)', [
              ('Running', discovery.running ? 'Yes' : 'No'),
              if (discovery.error != null) ('Error', discovery.error!),
              ('TVs found', '${discovery.hosts.length}'),
              for (final h in discovery.hosts)
                (
                  h.name,
                  '${h.address.addresses.join(', ')} port ${h.address.port} · ID ${h.address.hostId ?? '?'} · '
                      'protocol v${h.advertisedVersion ?? '?'}',
                ),
            ]),
            _Section('Haptics', [
              ('Supported', caps == null ? 'Checking…' : (caps.supported ? 'Yes' : 'No')),
              ('Engine', caps?.engine ?? '–'),
              ('Intensity control', caps == null ? '–' : (caps.intensityControl ? 'Yes' : 'No (on/off only)')),
              ('Setting', haptics.enabled ? 'On, tick ${(haptics.intensity * 100).round()}%' : 'Off'),
              (
                'TV event strengths',
                HapticEvent.values.map((e) => '${e.name} ${(haptics.eventIntensity(e) * 100).round()}%').join(', '),
              ),
              ('Ticks played', '${player.played}'),
              ('TV events', '${tvHaptics.received} received, ${tvHaptics.played} played'),
              if (tvHaptics.last case final last?)
                ('Last TV event', '${last.event.name}, ${(last.intensity * 100).round()}%, ${last.durationMs} ms'),
              if (player.lastError != null) ('Last error', player.lastError!),
              if (caps?.detail != null) ('Native detail', caps!.detail!),
            ]),
            _Section('Input', [
              ('Now', input.isNeutral ? 'Nothing pressed' : '$input'),
              ('States sent', '${ref.read(clientProvider).inputsSent}'),
              (
                'Stick settings',
                '${stickSettings.floating ? 'floating' : 'fixed'}, dead zone ${(stickSettings.deadZone * 100).round()}%, '
                    'sensitivity ${stickSettings.sensitivity.toStringAsFixed(2)}',
              ),
            ]),
            _Section('Gyro', [
              (
                'Mode',
                switch (gyro.mode) {
                  PadMode.dpad => 'D-pad',
                  PadMode.gyro => 'Gyro',
                  PadMode.sticks => 'Sticks',
                },
              ),
              (
                'Gyroscope',
                switch (gyro.availability) {
                  GyroAvailability.unknown => 'Not checked yet (switch to Gyro)',
                  GyroAvailability.checking => 'Checking…',
                  GyroAvailability.available => 'Working',
                  GyroAvailability.unavailable => 'Not available',
                },
              ),
              if (gyro.problem != null) ('Problem', gyro.problem!),
              if (gyro.side != null) ('Screen locked to', 'landscape ${gyro.side!.name}'),
              ('Stick', 'x ${gyro.x.toStringAsFixed(3)}  y ${gyro.y.toStringAsFixed(3)}'),
              if (gyro.up != null) ('Up direction', '${gyro.up}'),
              ('Updates', '${gyro.updates}'),
              (
                'Settings',
                'sensitivity ${gyroSettings.sensitivity.toStringAsFixed(2)}, dead zone ${(gyroSettings.deadZone * 100).round()}%, '
                    'smoothing ${(gyroSettings.smoothing * 100).round()}%',
              ),
            ]),
            _Section('Reconnects', [
              if (outages.isEmpty) ('', 'No drops since the app started.'),
              for (final o in outages)
                (
                  _clock(o.from),
                  o.length == null
                      ? 'Dropped (${o.reason}), reconnecting…'
                      : 'Dropped (${o.reason}), back after ${(o.length!.inMilliseconds / 1000).toStringAsFixed(1)} s',
                ),
            ]),
            _Section('Session (battery and CPU)', [
              if (session == null)
                ('', 'Measuring… (this phone build may not report it)')
              else ...[
                ('Running for', _duration(session.length)),
                (
                  'CPU',
                  '${_pct(session.recentCpuPercent)} of one core (last minute), ${_pct(session.cpuPercent)} since launch',
                ),
                (
                  'Battery',
                  '${_pct(session.latest.status.battery == null ? null : session.latest.status.battery! * 100)}'
                      '${session.latest.status.charging ? ', charging' : ''}'
                      '${session.latest.status.lowPower ? ', Low Power Mode' : ''}'
                      ' (${_pct(session.first.status.battery == null ? null : session.first.status.battery! * 100)} at launch)',
                ),
                (
                  'Battery use',
                  session.batteryPerHour == null
                      ? 'shown after 5 min on battery'
                      : '${session.batteryPerHour!.toStringAsFixed(1)}% per hour',
                ),
                ('Heat', session.latest.status.thermal),
                ('Input sent', '${session.sendRate.toStringAsFixed(0)} states/s (last minute)'),
              ],
            ]),
            _Section('This phone', [
              ('Name', identity.name),
              ('Controller ID', identity.controllerId),
              ('Platform', identity.platform),
              ('App version', identity.appVersion),
              ('Protocol', 'v$protocolVersion'),
            ]),
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Text('Log (newest last, ${lines.length} lines)', style: text.titleMedium),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: SelectableText(
                  lines.length > 200 ? lines.sublist(lines.length - 200).join('\n') : lines.join('\n'),
                  style: mono,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _share(BuildContext context, WidgetRef ref) async {
    final box = context.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(
      ShareParams(
        text: buildReport(ref),
        subject: 'Controller diagnostics',
        // Needed on iPad, harmless on iPhone.
        sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  }
}

/// The whole Diagnostics screen plus the full log, as plain text to share.
String buildReport(WidgetRef ref) {
  final client = ref.read(clientStateProvider);
  final discovery = ref.read(discoveryStateProvider);
  final network = ref.read(localNetworkStatusProvider);
  final identity = ref.read(identityProvider);
  final log = ref.read(logProvider);
  final b = StringBuffer()
    ..writeln('Controller diagnostics, ${DateTime.now().toIso8601String()}')
    ..writeln('Phone: ${identity.name} (${identity.platform}), app ${identity.appVersion}, protocol v$protocolVersion')
    ..writeln('Controller ID: ${identity.controllerId}')
    ..writeln(
      'Connection: ${client.status.name}, TV ${client.hostLabel}, ${client.target?.addresses.join(', ')} '
      'port ${client.target?.port}, ping ${client.rttMs ?? '-'} ms',
    )
    ..writeln('Problem: ${client.problem?.name ?? '-'} ${client.detail ?? ''} (OS error ${client.osErrorCode ?? '-'})')
    ..writeln('Local network: ${network.label}. ${network.explanation}')
    ..writeln(
      'Haptics: ${ref.read(hapticsPlayerProvider).capabilities.engine}, setting ${ref.read(hapticSettingsProvider).enabled ? 'on' : 'off'} ${ref.read(hapticSettingsProvider).intensity}, played ${ref.read(hapticsPlayerProvider).played}, TV events ${ref.read(tvHapticsProvider).received} received ${ref.read(tvHapticsProvider).played} played (last ${ref.read(tvHapticsProvider).last ?? '-'}), error ${ref.read(hapticsPlayerProvider).lastError ?? '-'}',
    )
    ..writeln(
      'Ping, last 30 s: ${client.rttStats ?? '-'}${client.rttStats == null ? '' : ', p95 ${client.rttStats!.p95Ms} ms'}',
    )
    ..writeln('Player: ${client.player == null ? '-' : 'P${client.player}'}')
    ..writeln(
      'TV event strengths: ${HapticEvent.values.map((e) => '${e.name} ${(ref.read(hapticSettingsProvider).eventIntensity(e) * 100).round()}%').join(', ')}',
    )
    ..writeln('Session: ${_sessionLine(ref.read(sessionStatsProvider))}')
    ..writeln('Reconnects (newest first): ${ref.read(outagesProvider).isEmpty ? 'none' : ''}')
    ..writeAll(
      ref
          .read(outagesProvider)
          .map(
            (o) =>
                '  ${o.from.toIso8601String()} ${o.reason}: '
                '${o.length == null ? 'not back yet' : 'back after ${o.length!.inMilliseconds} ms'}\n',
          ),
    )
    ..writeln(
      'Gyro: ${ref.read(gyroProvider).mode.name}, ${ref.read(gyroProvider).availability.name}, side ${ref.read(gyroProvider).side?.name ?? '-'}, x ${ref.read(gyroProvider).x.toStringAsFixed(3)} y ${ref.read(gyroProvider).y.toStringAsFixed(3)}, up ${ref.read(gyroProvider).up ?? '-'}, ${ref.read(gyroProvider).problem ?? ''}',
    )
    ..writeln(
      'Discovery: running ${discovery.running}, error ${discovery.error ?? '-'}, ${discovery.hosts.length} found',
    )
    ..writeAll(discovery.hosts.map((h) => '  ${h.name}: ${h.address.addresses.join(', ')} port ${h.address.port}\n'))
    ..writeln()
    ..writeln(log.export());
  return b.toString();
}

String _sessionLine(SessionStats? s) {
  if (s == null) return 'not measured';
  final battery = s.latest.status.battery;
  return '${_duration(s.length)}, CPU ${_pct(s.recentCpuPercent)} (last minute) ${_pct(s.cpuPercent)} (session), '
      'battery ${_pct(battery == null ? null : battery * 100)}${s.latest.status.charging ? ' charging' : ''}, '
      '${s.batteryPerHour == null ? 'drain -' : 'drain ${s.batteryPerHour!.toStringAsFixed(1)}%/h'}, '
      'heat ${s.latest.status.thermal}, ${s.sendRate.toStringAsFixed(0)} inputs/s';
}

String _pct(double? v) => v == null ? '–' : '${v.toStringAsFixed(v < 10 ? 1 : 0)}%';

String _duration(Duration d) => d.inHours > 0
    ? '${d.inHours} h ${d.inMinutes % 60} min'
    : d.inMinutes > 0
    ? '${d.inMinutes} min ${d.inSeconds % 60} s'
    : '${d.inSeconds} s';

String _clock(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';

class _Section extends StatelessWidget {
  const _Section(this.title, this.rows, {this.highlight = false});

  final String title;
  final List<(String, String)> rows;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: highlight ? scheme.errorContainer : null,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: text.titleMedium),
            const SizedBox(height: 4),
            for (final (label, value) in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: label.isEmpty
                    ? Text(value, style: text.bodyMedium)
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 150,
                            child: Text(label, style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
                          ),
                          Expanded(child: SelectableText(value, style: text.bodyMedium)),
                        ],
                      ),
              ),
          ],
        ),
      ),
    );
  }
}
