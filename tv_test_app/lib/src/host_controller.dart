import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:bonsoir/bonsoir.dart';
import 'package:connection/connection.dart';
import 'package:protocol/protocol.dart';
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
}

/// What the TV screen needs from the host. A fake implements it in tests.
abstract class HostController {
  HostViewState get state;
  Stream<HostViewState> get changes;
  void newPairingCode();
  void toggleSimulatedController();
  void dropAllConnections();
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
    _server = HostServer(hostId: id, hostName: _hostName, appVersion: appVersion, log: log.sink('host'));
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
    _log('Controller Test $appVersion on ${Platform.operatingSystem}, host ID ${_hostId.substring(0, 6)}');
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
  void toggleSimulatedController() {
    final running = _sim;
    if (running != null) {
      _log('Stopping the simulated controller');
      _simSub?.cancel();
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
    _simSub = sim.changes.listen((_) => _emit());
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
    await _simSub?.cancel();
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
      name: 'Controller Test ($_hostName)',
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
