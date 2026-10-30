import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:bonsoir/bonsoir.dart';
import 'package:connection/connection.dart';
import 'package:protocol/protocol.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_info.dart';

enum AdvertiseState { starting, advertising, failed }

/// An IPv4 address of this device, to show for manual entry on the phone.
final class LocalAddress {
  const LocalAddress(this.address, this.interfaceName);

  final String address;
  final String interfaceName;

  @override
  bool operator ==(Object other) =>
      other is LocalAddress && other.address == address && other.interfaceName == interfaceName;

  @override
  int get hashCode => Object.hash(address, interfaceName);
}

/// Everything the TV screen shows.
final class HostViewState {
  const HostViewState({
    required this.hostName,
    required this.host,
    this.addresses = const [],
    this.advertise = AdvertiseState.starting,
    this.advertisedName,
    this.advertiseError,
    this.serverError,
    this.sim,
  });

  final String hostName;
  final HostSnapshot host;
  final List<LocalAddress> addresses;
  final AdvertiseState advertise;

  /// The mDNS name phones see (it can change if the name is taken).
  final String? advertisedName;
  final String? advertiseError;

  /// Set if the server couldn't start at all.
  final String? serverError;

  /// The built-in simulated controller, or null when it's off.
  final ClientSnapshot? sim;

  /// Connected controllers by player number (PRD T9).
  List<ControllerInfo> get players =>
      host.connected.toList()..sort((a, b) => (a.player ?? 99).compareTo(b.player ?? 99));
}

/// What the TV screen needs from the host. A fake implements it in tests.
abstract class HostController {
  HostViewState get state;
  Stream<HostViewState> get changes;
  void newPairingCode();
  void toggleSimulatedController();
  void dropAllConnections();

  /// Forgets paired phones that aren't connected, so they need the code
  /// again. Returns how many were forgotten.
  int forgetPairings();

  /// Saves the log (with a latency summary on top) to a file and returns its
  /// path (PRD T8).
  Future<String> exportLog();

  /// Sends a haptic event to one controller, or to every connected one when
  /// [controllerId] is null. Returns how many it reached.
  int sendHaptic(HapticEventMessage message, {String? controllerId});

  Future<void> dispose();
}

/// Runs the server, advertises it with mDNS and drives the built-in
/// simulated controller.
class LiveHostController implements HostController {
  LiveHostController({required SharedPreferences prefs, required LogBuffer log})
    : _log = log.sink('tv'),
      _logBuffer = log {
    var id = prefs.getString(_hostIdKey);
    if (id == null) {
      id = _randomHex(16);
      prefs.setString(_hostIdKey, id);
    }
    _hostId = id;
    _hostName = _defaultHostName();
    final saved = loadPairings(prefs);
    _server = HostServer(
      hostId: id,
      hostName: _hostName,
      appVersion: appVersion,
      // Saved, so phones reconnect without a code after the app restarts.
      pairings: saved,
      onPairingsChanged: (p) => savePairings(prefs, p),
      log: log.sink('host'),
    );
    if (saved.isNotEmpty) {
      _log('Remembered ${saved.length} paired controller${saved.length == 1 ? '' : 's'}');
    }
    _serverSub = _server.changes.listen((_) => _emit());
  }

  static const _hostIdKey = 'hostId';

  final LogSink _log;
  final LogBuffer _logBuffer;
  late final String _hostId;
  late final String _hostName;
  late final HostServer _server;
  late final StreamSubscription<HostSnapshot> _serverSub;
  final _changes = StreamController<HostViewState>.broadcast();

  List<LocalAddress> _addresses = const [];
  AdvertiseState _advertise = AdvertiseState.starting;
  String? _advertisedName;
  String? _advertiseError;
  String? _serverError;
  BonsoirBroadcast? _broadcast;
  StreamSubscription<BonsoirBroadcastEvent>? _broadcastSub;
  Timer? _addressTimer;
  ControllerClient? _sim;
  StreamSubscription<ClientSnapshot>? _simSub;
  StreamSubscription<HapticEventMessage>? _simHapticsSub;
  Timer? _demo;
  bool _disposed = false;

  @override
  HostViewState get state => HostViewState(
    hostName: _hostName,
    host: _server.snapshot,
    addresses: _addresses,
    advertise: _advertise,
    advertisedName: _advertisedName,
    advertiseError: _advertiseError,
    serverError: _serverError,
    sim: _sim?.snapshot,
  );

  @override
  Stream<HostViewState> get changes => _changes.stream;

  Future<void> start() async {
    _log('Thumb Party TV $versionLabel on ${Platform.operatingSystem}, host ID ${_hostId.substring(0, 6)}');
    try {
      await _server.start();
    } catch (e) {
      _serverError = 'The server could not start: $e';
      _log(_serverError!);
      _emit();
      return;
    }
    await _refreshAddresses();
    // Addresses change when Wi-Fi reconnects, so keep them fresh.
    _addressTimer = Timer.periodic(const Duration(seconds: 10), (_) => _refreshAddresses());
    await _startAdvertising();
  }

  @override
  void newPairingCode() => _server.newPairingCode();

  @override
  void dropAllConnections() => _server.dropAllConnections();

  @override
  int forgetPairings() => _server.forgetDisconnected();

  @override
  Future<String> exportLog() async {
    final dir = await logExportDirectory();
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final name =
        'controller-test-log-${now.year}${two(now.month)}${two(now.day)}-${two(now.hour)}${two(now.minute)}${two(now.second)}.txt';
    final file = File('${dir.path}${Platform.pathSeparator}$name');
    await file.writeAsString(buildLogExport(state, _logBuffer, now: now));
    _log('Log saved to ${file.path}');
    return file.path;
  }

  @override
  int sendHaptic(HapticEventMessage message, {String? controllerId}) {
    if (controllerId != null) return _server.send(controllerId, message) ? 1 : 0;
    return _server.sendToAll(message);
  }

  @override
  void toggleSimulatedController() {
    final running = _sim;
    if (running != null) {
      _log('Stopping the simulated controller');
      _demo?.cancel();
      _demo = null;
      _simSub?.cancel();
      _simHapticsSub?.cancel();
      _sim = null;
      running.dispose();
      _emit();
      return;
    }
    final port = _server.port;
    if (port == null) return;
    _log('Starting the simulated controller');
    final sim = ControllerClient(
      identity: ControllerIdentity(
        controllerId: 'sim-${_hostId.substring(0, 6)}',
        name: 'Simulated controller',
        platform: 'sim',
        appVersion: appVersion,
      ),
      log: _logBuffer.sink('sim'),
    );
    _sim = sim;
    _simSub = sim.changes.listen((s) {
      // Once paired, press every button and direction in a loop, so the input
      // display can be checked without a phone.
      if (s.isConnected) _demo ??= runDemoInput(sim);
      _emit();
    });
    // So the log shows what a phone would feel.
    _simHapticsSub = sim.hapticEvents.listen(
      (e) => _logBuffer.add('sim', 'Felt ${e.event.name} (${(e.intensity * 100).round()}%, ${e.durationMs} ms)'),
    );
    sim.connect(
      HostAddress(addresses: ['127.0.0.1'], port: port),
      code: _server.pairingCode,
    );
    _emit();
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    _addressTimer?.cancel();
    _demo?.cancel();
    await _simSub?.cancel();
    await _simHapticsSub?.cancel();
    await _sim?.dispose();
    await _broadcastSub?.cancel();
    try {
      await _broadcast?.stop();
    } catch (_) {}
    await _serverSub.cancel();
    await _server.dispose();
    await _changes.close();
  }

  Future<void> _startAdvertising() async {
    final service = BonsoirService(
      name: 'Thumb Party TV ($_hostName)',
      type: serviceType,
      port: _server.port!,
      attributes: {txtHostId: _hostId, txtProtocolVersion: '$protocolVersion'},
    );
    final broadcast = BonsoirBroadcast(service: service);
    _broadcast = broadcast;
    try {
      await broadcast.initialize();
      _broadcastSub = broadcast.eventStream?.listen((event) {
        switch (event) {
          case BonsoirBroadcastStartedEvent():
            _advertise = AdvertiseState.advertising;
            _advertisedName = event.service.name;
            _advertiseError = null;
            _log('Advertising "${event.service.name}" ($serviceType, port ${event.service.port})');
          case BonsoirBroadcastNameAlreadyExistsEvent():
            _advertisedName = event.service.name;
            _log('Name already taken on the network, now advertising as "${event.service.name}"');
          case BonsoirBroadcastStoppedEvent():
            _log('Advertising stopped');
          default:
        }
        _emit();
      }, onError: (Object e) => _advertiseFailed(e));
      await broadcast.start();
    } catch (e) {
      _advertiseFailed(e);
    }
  }

  void _advertiseFailed(Object error) {
    _advertise = AdvertiseState.failed;
    _advertiseError = '$error';
    _log('Advertising failed: $error');
    _emit();
  }

  Future<void> _refreshAddresses() async {
    try {
      final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
      final list = [
        for (final i in interfaces)
          for (final a in i.addresses)
            if (!a.isLoopback && !a.isLinkLocal) LocalAddress(a.address, i.name),
      ]..sort((a, b) => _interfaceRank(a.interfaceName).compareTo(_interfaceRank(b.interfaceName)));
      if (!_sameAddresses(list, _addresses)) {
        _addresses = list;
        _log('Addresses: ${list.map((a) => '${a.address} (${a.interfaceName})').join(', ')}');
        _emit();
      }
    } catch (e) {
      _log('Could not list network addresses: $e');
    }
  }

  void _emit() {
    if (!_disposed && !_changes.isClosed) _changes.add(state);
  }
}

String _defaultHostName() {
  if (Platform.isAndroid) return 'Android TV';
  if (Platform.isWindows) return Platform.localHostname;
  return Platform.localHostname;
}

/// Wi-Fi and Ethernet first, virtual adapters (WSL, Hyper-V, VPNs) last.
int _interfaceRank(String name) {
  final n = name.toLowerCase();
  if (n.contains('vethernet') ||
      n.contains('virtual') ||
      n.contains('vmware') ||
      n.contains('docker') ||
      n.contains('vpn') ||
      n.contains('tun') ||
      n.contains('tailscale')) {
    return 2;
  }
  if (n.contains('wi-fi') || n.contains('wifi') || n.contains('wlan') || n.contains('wireless')) return 0;
  if (n.contains('eth')) return 1;
  return 1;
}

bool _sameAddresses(List<LocalAddress> a, List<LocalAddress> b) =>
    a.length == b.length && Iterable.generate(a.length).every((i) => a[i] == b[i]);

String _randomHex(int bytes) {
  final r = Random.secure();
  return List.generate(bytes, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
}

const _pairingsKey = 'pairings';

/// The pairings saved by [savePairings]. Broken entries are skipped.
List<SavedPairing> loadPairings(SharedPreferences prefs) {
  final raw = prefs.getString(_pairingsKey);
  if (raw == null) return const [];
  try {
    final list = jsonDecode(raw);
    if (list is! List) return const [];
    return [for (final item in list) ?SavedPairing.fromJson(item)];
  } catch (_) {
    return const [];
  }
}

void savePairings(SharedPreferences prefs, List<SavedPairing> pairings) =>
    prefs.setString(_pairingsKey, jsonEncode([for (final p in pairings) p.toJson()]));

/// Where "Save log" puts its file. On Android TV that's the app's own folder
/// on shared storage, which needs no permission and `adb pull` can read:
/// /sdcard/Android/data/com.thumbparty.tv/files. On Windows it's
/// the Downloads folder.
Future<Directory> logExportDirectory() async {
  if (Platform.isAndroid) {
    final external = await getExternalStorageDirectory();
    if (external != null) return external;
  } else {
    final downloads = await getDownloadsDirectory();
    if (downloads != null) return downloads;
  }
  return getApplicationDocumentsDirectory();
}

/// The exported log: a header with the app, the time and each controller's
/// latency (PRD T8), then every log line, oldest first.
String buildLogExport(HostViewState state, LogBuffer log, {required DateTime now}) {
  final b = StringBuffer()
    ..writeln('Thumb Party TV $versionLabel log, ${now.toIso8601String()}')
    ..writeln(
      'Host: ${state.hostName} (${Platform.operatingSystem}), port ${state.host.port ?? '-'}, protocol v$protocolVersion',
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
