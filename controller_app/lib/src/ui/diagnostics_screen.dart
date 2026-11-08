import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:party_host/party_host.dart' as party;
import 'package:party_host/party_host.dart' show HostText, PhoneText, SettingsText, ToyCard, ToyLookScope, ToySizes;
import 'package:protocol/protocol.dart';
import 'package:share_plus/share_plus.dart';

import '../app_info.dart';
import '../device_status.dart';
import '../gyro.dart';
import '../host/hosting.dart';
import '../local_network.dart';
import '../providers.dart';
import 'diagnostics_view_section.dart';
import 'labels.dart';

part 'diagnostics_screen_widgets.dart';

/// The log lines the screen shows: the tail of a longer log.
const _keptLogLines = 200;

/// The log's line height, tighter than the look's body so more lines fit.
const _logLineHeight = 1.3;

/// Basic Diagnostics (PRD C10): connection state, discovered TVs, local
/// network permission and recent log lines, with a share button. This is how
/// iOS problems get debugged without Xcode.
class DiagnosticsScreen extends ConsumerWidget {
  const DiagnosticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(clientProvider).viewerStats?.summary;
    return Scaffold(
      appBar: AppBar(
        title: const Text(PhoneText.diagnostics),
        actions: [
          IconButton(
            tooltip: SettingsText.copyReport,
            icon: const Icon(Icons.copy),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: buildReport(ref)));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(SettingsText.reportCopied)));
              }
            },
          ),
          Builder(
            builder: (buttonContext) => IconButton(
              tooltip: SettingsText.shareLog,
              icon: const Icon(Icons.share),
              onPressed: () => _share(buttonContext, ref),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(ToySizes.space16),
          children: [
            _connectionSection(ref),
            _networkSection(ref),
            _discoverySection(ref),
            _hapticsSection(ref),
            _inputSection(ref),
            _gyroSection(ref),
            _reconnectsSection(ref),
            _sessionSection(ref),
            _thisPhoneSection(ref),
            if (summary != null && summary.isNotEmpty) DiagnosticsViewSection(summary: summary),
            _logBlock(context, ref),
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
        subject: SettingsText.copySubject,
        // Needed on iPad, harmless on iPhone.
        sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  }
}

/// The connection's group: the state, the TV, where it is, and what went wrong.
Widget _connectionSection(WidgetRef ref) {
  final client = ref.watch(clientStateProvider);
  final target = client.target;
  return _Section(SettingsText.connectionSection, [
    (SettingsText.statusRow, statusLabel(client)),
    (SettingsText.tvRow, client.hostLabel.isEmpty ? HostText.dash : client.hostLabel),
    (
      SettingsText.addressRow,
      target?.ordered.map((a) => target.copyWith(addresses: [a]).display).join(', ') ?? HostText.dash,
    ),
    (SettingsText.tvIdRow, target?.hostId ?? HostText.dash),
    if (client.player != null) (SettingsText.playerRow, SettingsText.playerOnTv(client.player!)),
    (SettingsText.pingRow, SettingsText.milliseconds(client.rttMs)),
    if (client.rttStats != null)
      (SettingsText.pingLast30Row, SettingsText.summaryWithP95('${client.rttStats}', client.rttStats!.p95Ms)),
    if (client.problem != null) (SettingsText.problemRow, client.problem!.name),
    if (client.detail != null) (SettingsText.detailRow, client.detail!),
    if (client.osErrorCode != null) (SettingsText.osErrorRow, '${client.osErrorCode}'),
    if (client.attempt > 0) (SettingsText.reconnectAttemptRow, '${client.attempt}'),
  ]);
}

/// The local network's permission, which a denied one marks bad.
Widget _networkSection(WidgetRef ref) {
  final network = ref.watch(localNetworkStatusProvider);
  return _Section(SettingsText.localNetworkSection, [
    (SettingsText.statusRow, network.label),
    ('', network.explanation),
  ], highlight: network.access == LocalNetworkAccess.probablyDenied);
}

/// The TVs discovery found.
Widget _discoverySection(WidgetRef ref) {
  final discovery = ref.watch(discoveryStateProvider);
  return _Section(SettingsText.discoveryWithType(serviceType), [
    (SettingsText.runningRow, discovery.running ? SettingsText.yes : SettingsText.no),
    if (discovery.error != null) (SettingsText.errorRow, discovery.error!),
    (SettingsText.foundRow, '${discovery.hosts.length}'),
    for (final h in discovery.hosts)
      (
        h.name,
        SettingsText.discovered(
          h.address.addresses.join(', '),
          h.address.port,
          h.address.hostId,
          h.advertisedVersion?.toString(),
        ),
      ),
  ]);
}

/// What the phone's motors are and do.
Widget _hapticsSection(WidgetRef ref) {
  final caps = ref.watch(hapticsCapabilitiesProvider).value;
  final haptics = ref.watch(hapticSettingsProvider);
  final player = ref.read(hapticsPlayerProvider);
  final tvHaptics = ref.watch(tvHapticsProvider);
  return _Section(SettingsText.haptics, [
    (
      SettingsText.supportedRow,
      caps == null ? SettingsText.checking : (caps.supported ? SettingsText.yes : SettingsText.no),
    ),
    (SettingsText.engineRow, caps?.engine ?? HostText.dash),
    (
      SettingsText.intensityControlRow,
      caps == null ? HostText.dash : (caps.intensityControl ? SettingsText.yes : SettingsText.onOffOnly),
    ),
    (SettingsText.settingRow, SettingsText.tickSetting(haptics.enabled, (haptics.intensity * 100).round())),
    (
      SettingsText.eventStrengthsRow,
      HapticEvent.values
          .map((e) => SettingsText.eventStrength(e.name, (haptics.eventIntensity(e) * 100).round()))
          .join(', '),
    ),
    (SettingsText.ticksPlayedRow, '${player.played}'),
    (SettingsText.tvEventsRow, SettingsText.receivedPlayed(tvHaptics.received, tvHaptics.played)),
    if (tvHaptics.last case final last?)
      (
        SettingsText.lastEventRow,
        SettingsText.eventDetail(last.event.name, (last.intensity * 100).round(), last.durationMs),
      ),
    if (player.lastError != null) (SettingsText.lastErrorRow, player.lastError!),
    if (caps?.detail != null) (SettingsText.nativeDetailRow, caps!.detail!),
  ]);
}

/// What the pad is sending now, and how its sticks are set.
Widget _inputSection(WidgetRef ref) {
  final input = ref.watch(padProvider);
  final stickSettings = ref.watch(stickSettingsProvider);
  return _Section(SettingsText.inputSection, [
    (SettingsText.nowRow, input.isNeutral ? SettingsText.nothingPressed : '$input'),
    (SettingsText.statesSentRow, '${ref.read(clientProvider).inputsSent}'),
    (
      SettingsText.stickSettingsRow,
      SettingsText.stickSettingsValue(
        stickSettings.floating ? SettingsText.floating : SettingsText.fixed,
        (stickSettings.deadZone * 100).round(),
        stickSettings.sensitivity,
      ),
    ),
  ]);
}

/// The tilt mode: whether the phone has a gyroscope, and how it reads it.
Widget _gyroSection(WidgetRef ref) {
  final gyro = ref.watch(gyroProvider);
  final gyroSettings = ref.watch(gyroSettingsProvider);
  return _Section(PhoneText.gyro, [
    (SettingsText.modeRow, PhoneText.modeName(gyro.mode.name)),
    (
      SettingsText.gyroscopeRow,
      switch (gyro.availability) {
        GyroAvailability.unknown => SettingsText.gyroNotChecked,
        GyroAvailability.checking => SettingsText.checking,
        GyroAvailability.available => SettingsText.working,
        GyroAvailability.unavailable => SettingsText.notAvailable,
      },
    ),
    if (gyro.problem != null) (SettingsText.problemRow, gyro.problem!),
    if (gyro.side != null) (SettingsText.lockedToRow, SettingsText.landscape(gyro.side!.name)),
    (SettingsText.stickRow, SettingsText.tilt(gyro.x, gyro.y)),
    if (gyro.up != null) (SettingsText.upDirectionRow, '${gyro.up}'),
    (SettingsText.updatesRow, '${gyro.updates}'),
    (
      SettingsText.settingsRow,
      SettingsText.gyroSettingsValue((gyroSettings.deadZone * 100).round(), (gyroSettings.smoothing * 100).round()),
    ),
  ]);
}

/// The drops this session, newest first.
Widget _reconnectsSection(WidgetRef ref) {
  final outages = ref.watch(outagesProvider);
  return _Section(SettingsText.reconnectsSection, [
    if (outages.isEmpty) ('', SettingsText.noDrops),
    for (final o in outages)
      (
        _clock(o.from),
        o.length == null
            ? SettingsText.droppedReconnecting(o.reason)
            : SettingsText.droppedBackAfter(o.reason, (o.length!.inMilliseconds / 1000).toStringAsFixed(1)),
      ),
  ]);
}

/// What the session cost: time, CPU, battery and heat.
Widget _sessionSection(WidgetRef ref) {
  final session = ref.watch(sessionStatsProvider);
  return _Section(SettingsText.sessionSection, [
    if (session == null)
      ('', SettingsText.measuring)
    else ...[
      (SettingsText.runningForRow, _duration(session.length)),
      (SettingsText.cpuRow, SettingsText.cpuValue(_pct(session.recentCpuPercent), _pct(session.cpuPercent))),
      (
        SettingsText.batteryRow,
        SettingsText.batteryValue(
          _pct(session.latest.status.battery == null ? null : session.latest.status.battery! * 100),
          charging: session.latest.status.charging,
          lowPower: session.latest.status.lowPower,
          atLaunch: _pct(session.first.status.battery == null ? null : session.first.status.battery! * 100),
        ),
      ),
      (
        SettingsText.batteryUseRow,
        session.batteryPerHour == null
            ? SettingsText.batteryLater
            : SettingsText.perHour(session.batteryPerHour!.toStringAsFixed(1)),
      ),
      (SettingsText.heatRow, session.latest.status.thermal),
      (SettingsText.inputSentRow, SettingsText.statesPerSecond(session.sendRate.toStringAsFixed(0))),
    ],
  ]);
}

/// Which phone this is, and what it runs.
Widget _thisPhoneSection(WidgetRef ref) {
  final identity = ref.watch(identityProvider);
  return _Section(SettingsText.thisPhoneSection, [
    (SettingsText.nameRow, identity.name),
    (SettingsText.controllerIdRow, identity.controllerId),
    (SettingsText.platformRow, identity.platform),
    (SettingsText.appVersionRow, versionLabel),
    (SettingsText.protocolRow, SettingsText.protocolVersion(protocolVersion)),
  ]);
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
    ..writeln('Phone: ${identity.name} (${identity.platform}), app $versionLabel, protocol v$protocolVersion')
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
    ..write(viewReport(ref.read(clientProvider).viewerStats?.summary))
    ..writeln()
    ..writeln(log.export());
  _writeHostLog(b, ref);
  b.write(sessionReport(lastSessionSummary(ref)));
  return b.toString();
}

/// Adds the host's own log, on a phone that is hosting (s5c): a sound error
/// on this phone can't be seen anywhere else.
void _writeHostLog(StringBuffer b, WidgetRef ref) {
  final host = ref.read(hostingProvider);
  if (host == null || !host.live) return;
  b
    ..writeln()
    ..writeln(SettingsText.hostLogHeading)
    ..writeln(ref.read(party.logProvider).export());
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
