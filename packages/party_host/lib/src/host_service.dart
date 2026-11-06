import 'dart:async';
import 'dart:math';

import 'package:connection/connection.dart';
import 'package:protocol/protocol.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'advertiser.dart';
import 'host_directories.dart';
import 'host_identity.dart';
import 'host_log_export.dart';
import 'host_view_state.dart';
import 'live_stats.dart';
import 'network_addresses.dart';
import 'saved_pairings.dart';
import 'session_uploader.dart';
import 'simulated_controllers.dart';
import 'stats_service.dart';

/// What the host screens need from the host: the server, its advertising, the
/// game host and the stats (PRD v2 M12, design B1).
///
/// It was `HostController` in the TV app up to M11; the rename makes room for
/// the phone's own host mode. A fake implements it in tests.
abstract class HostService {
  /// Everything the host screens show.
  HostViewState get state;

  /// Fires whenever [state] changes.
  Stream<HostViewState> get changes;

  /// Makes a new pairing code, so phones need the code again (PRD T5).
  void newPairingCode();

  /// How many simulated controllers can run at once.
  static const maxSims = 3;

  /// Adds a simulated controller (up to [maxSims]): it pairs on its own and
  /// presses every button in a loop (M11).
  void addSimulatedController();

  /// Stops every simulated controller.
  void stopSimulatedControllers();

  /// Drops every controller, so each must enter the pairing code again.
  void dropAllConnections();

  /// Forgets paired phones that aren't connected, so they need the code
  /// again. Returns how many were forgotten.
  int forgetPairings();

  /// Saves the log (with a latency summary on top) to a file and returns its
  /// path (PRD T8).
  Future<String> exportLog();

  /// What every game and test screen uses (PRD v2 P3): players, their
  /// gamepads, haptics, latency and analytics records.
  GameHost get gameHost;

  /// Analytics collection, the session files, consent and upload (M9).
  StatsService get stats;

  /// Sounds the games ask for by name (PRD v2 S5), for the sound player.
  Stream<String> get gameSounds;

  /// Stops everything and releases the port.
  Future<void> dispose();
}

/// Runs the server, advertises it, records the stats and drives the built-in
/// simulated controllers.
///
/// Everything platform-specific comes from the shell through the constructor
/// (S-a, S-b, S-g, M12 design §2.6): the identity, the folders, the
/// advertiser and the stats uploader. Nothing here reads `Platform`, the
/// audio package or a build constant.
class LiveHostService implements HostService {
  /// [identity] names the host and versions its summaries, [directories]
  /// supplies the session and export folders, [advertiser] finds the host on
  /// the network, and [uploader] sends finished sessions (null when the
  /// build knows no cloud store).
  LiveHostService({
    required SharedPreferences prefs,
    required LogBuffer log,
    required HostIdentity identity,
    required HostDirectories directories,
    required Advertiser advertiser,
    SessionUploader? uploader,
  }) : _log = log.sink('tv'),
       _logBuffer = log,
       _identity = identity,
       _directories = directories {
    _advertiser = advertiser;
    var id = prefs.getString(_hostIdKey);
    if (id == null) {
      id = _randomHex(16);
      prefs.setString(_hostIdKey, id);
    }
    _hostId = id;
    _hostName = identity.defaultHostName;
    final saved = loadPairings(prefs);
    _server = HostServer(
      hostId: id,
      hostName: _hostName,
      appVersion: identity.appVersion,
      // Saved, so phones reconnect without a code after the app restarts.
      pairings: saved,
      onPairingsChanged: (p) => savePairings(prefs, p),
      log: log.sink('host'),
      // Touch metrics and the rating prompt (M9).
      capabilities: const [Capability.metrics, Capability.rating],
    );
    _gameHost = ServerGameHost(_server);
    _stats = LiveStats(
      server: _server,
      host: _gameHost,
      prefs: prefs,
      exportDirectory: directories.exports,
      hostType: identity.hostType,
      hostApp: identity.appVersion,
      hostOs: identity.hostOs,
      log: log.sink('stats'),
      uploader: uploader,
    );
    _sims = SimulatedControllers(
      hostId: id,
      appVersion: identity.appVersion,
      log: _log,
      logBuffer: log,
      changed: _emit,
    );
    if (saved.isNotEmpty) {
      _log('Remembered ${saved.length} paired controller${saved.length == 1 ? '' : 's'}');
    }
    _serverSub = _server.changes.listen((_) => _emit());
    _advertiserSub = _advertiser.changes.listen((_) => _emit());
  }

  static const _hostIdKey = 'hostId';

  /// How often the host re-reads the machine's addresses while it runs: a
  /// Wi-Fi reconnect changes them, and the home screen shows the latest ones
  /// (PRD T5).
  static const addressRefreshInterval = Duration(seconds: 10);

  final LogSink _log;
  final LogBuffer _logBuffer;
  final HostIdentity _identity;
  final HostDirectories _directories;
  late final Advertiser _advertiser;
  late final String _hostId;
  late final String _hostName;
  late final HostServer _server;
  late final ServerGameHost _gameHost;
  late final LiveStats _stats;
  late final SimulatedControllers _sims;
  late final StreamSubscription<HostSnapshot> _serverSub;
  late final StreamSubscription<AdvertiserStatus> _advertiserSub;
  final _changes = StreamController<HostViewState>.broadcast();

  List<LocalAddress> _addresses = const [];
  String? _serverError;
  Timer? _addressTimer;
  bool _disposed = false;

  /// The advertiser's status is read here rather than copied, so it is always
  /// the latest one.
  @override
  HostViewState get state {
    final advert = _advertiser.status;
    return HostViewState(
      hostName: _hostName,
      host: _server.snapshot,
      addresses: _addresses,
      advertise: advert.state,
      advertisedName: advert.advertisedName,
      advertiseError: advert.error,
      serverError: _serverError,
      sims: _sims.snapshots,
    );
  }

  @override
  Stream<HostViewState> get changes => _changes.stream;

  /// Starts the stats, the server and advertising, and keeps the addresses
  /// fresh while it runs.
  Future<void> start() async {
    _log('Thumb Party TV ${_identity.versionLabel} on ${_identity.hostOs}, host ID ${_hostId.substring(0, 6)}');
    // Stats first, so the first phone already counts.
    try {
      await _stats.start(await _directories.sessions());
    } catch (e) {
      _log('Stats are off: $e');
    }
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
    _addressTimer = Timer.periodic(addressRefreshInterval, (_) => _refreshAddresses());
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
    final dir = await _directories.exports();
    final path = await writeLogExport(
      dir: dir,
      state: state,
      log: _logBuffer,
      identity: _identity,
      now: DateTime.now(),
    );
    _log('Log saved to $path');
    return path;
  }

  @override
  GameHost get gameHost => _gameHost;

  @override
  StatsService get stats => _stats;

  @override
  Stream<String> get gameSounds => _gameHost.sounds;

  @override
  void addSimulatedController() {
    final port = _server.port;
    if (port == null || _sims.snapshots.length >= HostService.maxSims) return;
    _sims.add(port: port, pairingCode: _server.pairingCode);
    _emit();
  }

  @override
  void stopSimulatedControllers() {
    if (_sims.snapshots.isEmpty) return;
    _sims.stopAll();
    _emit();
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    _addressTimer?.cancel();
    await _sims.dispose();
    await _advertiserSub.cancel();
    await _advertiser.stop();
    await _stats.dispose();
    await _gameHost.dispose();
    await _serverSub.cancel();
    await _server.dispose();
    await _changes.close();
  }

  Future<void> _startAdvertising() async {
    final port = _server.port;
    if (port == null) return;
    await _advertiser.start(
      serviceName: 'Thumb Party TV ($_hostName)',
      port: port,
      txt: {txtHostId: _hostId, txtProtocolVersion: '$protocolVersion'},
    );
  }

  Future<void> _refreshAddresses() async {
    try {
      final list = await networkAddresses();
      if (!sameAddresses(list, _addresses)) {
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

String _randomHex(int bytes) {
  final r = Random.secure();
  return List.generate(bytes, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
}
