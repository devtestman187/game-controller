import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:connection/connection.dart';
import 'package:metrics/metrics.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'session_recorder.dart';
import 'session_store.dart';
import 'session_uploader.dart';
import 'stats_service.dart';
import 'stats_state.dart';

/// Collects analytics on the host (PRD v2 T17 to T19): joins every phone's
/// metrics batches, ratings and latency with the game's records into one
/// [SessionCollector] per play session, saves it (every minute and at the
/// end), asks for ratings after games, and with consent uploads finished
/// sessions, queued while offline.
///
/// A session starts when the first player joins and ends after [sessionGap]
/// with nobody connected. The record translation (messages, rounds, ratings)
/// lives in `src/session_recorder.dart`.
class LiveStats implements StatsService {
  /// Everything it needs is supplied by the host service; [exportDirectory]
  /// and [uploader] come from the shell's storage and build constants, so
  /// this class has no platform code and no secrets (S-e, M12 design §2.6).
  ///
  /// [sessionGap] is how long nobody may be connected before the session
  /// ends (two minutes); [checkpoint] is how often the running session is
  /// saved (one minute). [clock] and [random] are injected so tests are
  /// deterministic.
  LiveStats({
    required this.server,
    required this.host,
    required this.prefs,
    required this.exportDirectory,
    required this.hostType,
    required this.hostApp,
    this.hostOs,
    LogSink? log,
    this.sessionGap = const Duration(minutes: 2),
    this.checkpoint = const Duration(minutes: 1),
    this.uploader,
    DateTime Function()? clock,
    Random? random,
  }) : _log = log ?? ((_) {}),
       _clock = clock ?? DateTime.now,
       _random = random ?? Random.secure() {
    final consent = prefs.getBool(_consentKey);
    _state = StatsState(consent: consent, uploadConfigured: uploader != null, uploaded: _uploadedIds.length);
    _recorder = SessionRecorder(host: host, session: () => _session, log: _log, random: _random);
    _files = SessionStore(exportDirectory: exportDirectory, now: _clock, log: _log);
    _subs.addAll([
      server.changes.listen((_) => _checkPlayers()),
      host.playersChanged.listen((_) => _checkPlayers()),
      server.messages.listen(_recorder.onMessage),
      host.stages.listen((s) => _session?.stage(s.playerId, s.stage, s.ms)),
      host.records.listen(_recorder.onRecord),
    ]);
    _pingTimer = Timer.periodic(const Duration(seconds: 5), (_) => _samplePings());
  }

  /// The server whose controllers' messages and heartbeats it records.
  final HostServer server;

  /// The game host whose players, records and stages it records.
  final ServerGameHost host;

  /// Where the consent and the uploaded IDs are kept.
  final SharedPreferences prefs;

  /// Where Export copies the session files.
  final Future<Directory> Function() exportDirectory;

  /// The host type in the summary, e.g. `windows` (PRD v2 M9).
  final String hostType;

  /// The host app's version, e.g. `0.11.0`.
  final String hostApp;

  /// The host's operating system, for a local player's record.
  final String? hostOs;

  /// How long the session stays open with nobody connected.
  final Duration sessionGap;

  /// How often the running session is saved.
  final Duration checkpoint;

  /// Sends one session to the cloud store, or null when this build has none.
  final SessionUploader? uploader;
  final LogSink _log;
  final DateTime Function() _clock;
  final Random _random;

  static const _consentKey = 'statsConsent';
  static const _uploadedKey = 'uploadedSessions';

  final _subs = <StreamSubscription<Object?>>[];
  final _changes = StreamController<StatsState>.broadcast();
  late StatsState _state;
  late final Timer _pingTimer;
  late final SessionRecorder _recorder;
  late final SessionStore _files;
  SessionCollector? _session;
  String? _sessionPath;
  Timer? _endTimer;
  Timer? _checkpointTimer;
  final _present = <String>{};
  bool _uploading = false;
  Timer? _retry;

  /// The live session's collector, for tests.
  SessionCollector? get session => _session;

  /// Where session files are kept, once [start] has run.
  Directory? get directory => _directory;
  Directory? _directory;

  @override
  StatsState get state => _state;

  @override
  Stream<StatsState> get changes => _changes.stream;

  Set<String> get _uploadedIds => (prefs.getStringList(_uploadedKey) ?? const []).toSet();

  /// Starts saving in [dir]: counts the saved sessions and uploads any left
  /// from earlier.
  Future<void> start(Directory dir) async {
    await dir.create(recursive: true);
    _directory = dir;
    await _refreshCounts();
    unawaited(uploadNow());
  }

  @override
  void setConsent(bool share) {
    unawaited(prefs.setBool(_consentKey, share));
    _log(share ? 'Stats sharing turned on' : 'Stats sharing turned off');
    _set(_state.copyWith(consent: share));
    if (share) unawaited(uploadNow());
  }

  void _checkPlayers() {
    final now = host.nowMs;
    final connected = <String, ControllerInfo>{for (final c in server.snapshot.connected) c.controllerId: c};
    final locals = {for (final p in host.players.where((p) => p.local)) p.id: p};
    final here = {...connected.keys, ...locals.keys};
    if (here.isNotEmpty && _session == null) _startSession();
    final s = _session;
    if (s == null) return;
    for (final id in here.difference(_present)) {
      final c = connected[id];
      if (c != null) {
        s.joined(id, number: c.player ?? 0, atMs: now, platform: c.platform, app: c.appVersion, device: c.device);
      } else {
        s.joined(id, number: locals[id]!.number, atMs: now, local: true, platform: hostOs ?? '');
      }
    }
    for (final id in _present.difference(here)) {
      s.left(id, now);
    }
    _present
      ..clear()
      ..addAll(here);
    if (here.isEmpty) {
      _endTimer ??= Timer(sessionGap, () => unawaited(endSession()));
    } else {
      _endTimer?.cancel();
      _endTimer = null;
    }
  }

  void _startSession() {
    final now = _clock();
    final id = List.generate(8, (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
    _session = SessionCollector(
      id: id,
      hostType: hostType,
      hostApp: hostApp,
      hostOs: hostOs,
      startedAt: now,
      startMs: host.nowMs,
    );
    String two(int n) => n.toString().padLeft(2, '0');
    final stamp = '${now.year}${two(now.month)}${two(now.day)}-${two(now.hour)}${two(now.minute)}${two(now.second)}';
    final dir = _directory;
    _sessionPath = dir == null ? null : p.join(dir.path, 'session-$stamp-$id.json');
    _log('Stats: session $id started');
    _checkpointTimer = Timer.periodic(checkpoint, (_) => unawaited(_save()));
  }

  /// Ends the session: saves it, and queues it for upload.
  Future<void> endSession() async {
    final s = _session;
    if (s == null) return;
    _endTimer?.cancel();
    _endTimer = null;
    _checkpointTimer?.cancel();
    _checkpointTimer = null;
    for (final id in _present) {
      s.left(id, host.nowMs);
    }
    _present.clear();
    await _save();
    _log('Stats: session ${s.id} saved (${(s.summary(host.nowMs)['durationS'])} s)');
    _session = null;
    _sessionPath = null;
    _set(_state.copyWith(current: null));
    await _refreshCounts();
    unawaited(uploadNow());
  }

  Future<void> _save() async {
    final s = _session;
    if (s == null) return;
    final summary = s.summary(host.nowMs);
    _set(_state.copyWith(current: summary));
    await _files.save(_sessionPath, summary);
  }

  void _samplePings() {
    final s = _session;
    if (s == null) return;
    for (final c in server.snapshot.connected) {
      final rtt = c.rttMs;
      if (rtt != null) s.ping(c.controllerId, rtt);
    }
  }

  @override
  Future<List<SessionFile>> sessions() => _files.sessions(_directory);

  @override
  Future<String> exportAll() async {
    await _save();
    return _files.exportAll(_directory);
  }

  @override
  Future<void> uploadNow() async {
    final up = uploader;
    if (up == null || _state.consent != true || _uploading) return;
    _uploading = true;
    _retry?.cancel();
    try {
      final done = _uploadedIds;
      final pending = (await sessions()).where((f) => !done.contains(f.id) && f.path != _sessionPath).toList();
      for (final f in pending) {
        if (_state.consent != true) break;
        final error = await up.upload(f.summary);
        if (error != null) {
          _log('Stats: upload failed, trying again later: $error');
          _set(_state.copyWith(lastError: error));
          _retry = Timer(const Duration(minutes: 5), () => unawaited(uploadNow()));
          break;
        }
        done.add(f.id);
        await prefs.setStringList(_uploadedKey, done.toList());
        _set(_state.copyWith(lastError: null));
      }
    } finally {
      _uploading = false;
      await _refreshCounts();
    }
  }

  Future<void> _refreshCounts() async {
    final files = await sessions();
    final done = _uploadedIds;
    final waiting = _state.consent == true
        ? files.where((f) => !done.contains(f.id) && f.path != _sessionPath).length
        : 0;
    _set(_state.copyWith(saved: files.length, waiting: waiting, uploaded: done.length));
  }

  void _set(StatsState s) {
    _state = s;
    if (!_changes.isClosed) _changes.add(s);
  }

  /// Ends the session, stops the timers and closes the streams.
  Future<void> dispose() async {
    await endSession();
    _pingTimer.cancel();
    _retry?.cancel();
    for (final s in _subs) {
      await s.cancel();
    }
    await _changes.close();
  }
}
