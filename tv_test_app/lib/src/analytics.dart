import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:connection/connection.dart';
import 'package:metrics/metrics.dart';
import 'package:protocol/protocol.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The Firebase project the stats go to, set at build time
/// (`--dart-define=FIRESTORE_PROJECT=...`, from the release workflow). Empty
/// in local builds: then nothing can be uploaded.
const firestoreProject = String.fromEnvironment('FIRESTORE_PROJECT');

/// The project's web API key (optional for Firestore, which the security
/// rules protect).
const firestoreApiKey = String.fromEnvironment('FIRESTORE_API_KEY');

/// What the Stats screen shows about collection and upload.
final class StatsState {
  const StatsState({
    this.consent,
    this.uploadConfigured = false,
    this.waiting = 0,
    this.uploaded = 0,
    this.lastError,
    this.current,
    this.saved = 0,
  });

  /// The adult's answer: true to share, false not to, null if never asked.
  final bool? consent;

  /// Whether this build knows where to upload ([firestoreProject]).
  final bool uploadConfigured;

  /// Finished sessions waiting to be uploaded (with consent, while offline).
  final int waiting;

  /// Sessions uploaded from this device.
  final int uploaded;

  /// Why the last upload failed, if it did.
  final String? lastError;

  /// The session being recorded right now, or null.
  final Map<String, Object?>? current;

  /// Session files on this device.
  final int saved;

  StatsState copyWith({
    Object? consent = _keep,
    int? waiting,
    int? uploaded,
    Object? lastError = _keep,
    Object? current = _keep,
    int? saved,
  }) => StatsState(
    consent: identical(consent, _keep) ? this.consent : consent as bool?,
    uploadConfigured: uploadConfigured,
    waiting: waiting ?? this.waiting,
    uploaded: uploaded ?? this.uploaded,
    lastError: identical(lastError, _keep) ? this.lastError : lastError as String?,
    current: identical(current, _keep) ? this.current : current as Map<String, Object?>?,
    saved: saved ?? this.saved,
  );
}

const Object _keep = Object();

/// A saved session summary.
final class SessionFile {
  const SessionFile(this.path, this.summary);

  final String path;
  final Map<String, Object?> summary;

  String get id => summary['id'] as String? ?? '';
}

/// What the TV screens need from the analytics. A fake implements it in
/// tests.
abstract class StatsService {
  StatsState get state;
  Stream<StatsState> get changes;

  /// Saved sessions, newest first.
  Future<List<SessionFile>> sessions();

  /// Copies every session file to the export folder and returns its path
  /// (PRD v2 T18).
  Future<String> exportAll();

  /// The adult's answer to the consent prompt, or a change in Stats.
  void setConsent(bool share);

  /// Tries the upload queue now.
  Future<void> uploadNow();
}

/// Collects analytics on the TV (PRD v2 T17 to T19): joins every phone's
/// metrics batches, ratings and latency with the game's records into one
/// [SessionCollector] per play session, saves it (every minute and at the
/// end), asks for ratings after games, and with consent uploads finished
/// sessions, queued while offline.
///
/// A session starts when the first player joins and ends after
/// [sessionGap] with nobody connected.
class LiveStats implements StatsService {
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
    _subs.addAll([
      server.changes.listen((_) => _checkPlayers()),
      host.playersChanged.listen((_) => _checkPlayers()),
      server.messages.listen(_onMessage),
      host.stages.listen((s) => _session?.stage(s.playerId, s.stage, s.ms)),
      host.records.listen(_onRecord),
    ]);
    _pingTimer = Timer.periodic(const Duration(seconds: 5), (_) => _samplePings());
  }

  final HostServer server;
  final ServerGameHost host;
  final SharedPreferences prefs;

  /// Where Export copies them.
  final Future<Directory> Function() exportDirectory;
  final String hostType;
  final String hostApp;
  final String? hostOs;
  final Duration sessionGap;
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
  SessionCollector? _session;
  String? _sessionPath;
  Timer? _endTimer;
  Timer? _checkpointTimer;
  final _present = <String>{};
  final _ratings = RatingScheduler();
  final _askedGames = <String, String>{};
  bool _uploading = false;
  Timer? _retry;

  @override
  StatsState get state => _state;

  @override
  Stream<StatsState> get changes => _changes.stream;

  /// The live session's collector, for tests.
  SessionCollector? get session => _session;

  Set<String> get _uploadedIds => (prefs.getStringList(_uploadedKey) ?? const []).toSet();

  /// Where session files are kept, once [start] has run.
  Directory? get directory => _directory;
  Directory? _directory;

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
        s.joined(id, number: locals[id]!.number, atMs: now, local: true, platform: Platform.operatingSystem);
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
    _sessionPath = dir == null ? null : '${dir.path}${Platform.pathSeparator}session-$stamp-$id.json';
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
    final path = _sessionPath;
    if (s == null || path == null) return;
    final summary = s.summary(host.nowMs);
    _set(_state.copyWith(current: summary));
    try {
      final tmp = File('$path.tmp');
      await tmp.writeAsString(jsonEncode(summary));
      await tmp.rename(path);
    } catch (e) {
      _log('Stats: could not save the session: $e');
    }
  }

  void _onMessage(ControllerMessage m) {
    final s = _session;
    if (s == null) return;
    switch (m.message) {
      case InputStateMessage():
        s
          ..input(m.controllerId)
          ..mode(m.controllerId, InputMode.of(m.message as InputStateMessage).name);
      case final MetricsMessage batch:
        s.metrics(m.controllerId, batch);
      case final RatingMessage r:
        s.rating(m.controllerId, r, game: _askedGames.remove(r.id) ?? arenaGameName);
      default:
    }
  }

  void _onRecord(GameRecord r) {
    final s = _session;
    if (s == null) return;
    switch (r.name) {
      case 'round_start':
        s.roundStarted();
      case 'round_end':
        final modes = <String, String>{
          for (final MapEntry(:key, :value) in ((r.data['modes'] as Map?) ?? const {}).entries)
            if (key is String && value is String) key: value,
        };
        final time = r.data['timeS'];
        s.roundEnded(
          r.game,
          timeS: time is num ? time.toDouble() : 0,
          modes: modes,
          winnerId: r.data['winner'] as String?,
        );
        _maybeAskRatings(r.game, modes.keys);
      case 'frames':
        s.frames((r.data['drawn'] as num?)?.toInt() ?? 0, (r.data['late'] as num?)?.toInt() ?? 0);
      default:
        if (r.playerId != null) s.gameEvent(r.game, r.name, r.playerId!);
    }
  }

  void _maybeAskRatings(String game, Iterable<String> players) {
    for (final id in players) {
      if (!_ratings.gameEnded(id, host.nowMs)) continue;
      final askId = List.generate(6, (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
      if (host.askRating(id, id: askId, game: game)) {
        _askedGames[askId] = game;
        _log('Stats: asked P${host.players.where((p) => p.id == id).firstOrNull?.number ?? '?'} how the controls felt');
      }
    }
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
  Future<List<SessionFile>> sessions() async {
    final directory = _directory;
    if (directory == null || !await directory.exists()) return const [];
    final files = await directory.list().where((e) => e is File && e.path.endsWith('.json')).cast<File>().toList();
    final out = <SessionFile>[];
    for (final f in files) {
      try {
        final json = jsonDecode(await f.readAsString());
        if (json is Map<String, Object?> && json['schema'] == summarySchema) out.add(SessionFile(f.path, json));
      } catch (_) {}
    }
    out.sort((a, b) => b.path.compareTo(a.path));
    return out;
  }

  @override
  Future<String> exportAll() async {
    await _save();
    final base = await exportDirectory();
    final now = _clock();
    String two(int n) => n.toString().padLeft(2, '0');
    final folder = Directory(
      '${base.path}${Platform.pathSeparator}thumb-party-sessions-${now.year}${two(now.month)}${two(now.day)}-'
      '${two(now.hour)}${two(now.minute)}',
    );
    await folder.create(recursive: true);
    final files = await sessions();
    for (final f in files) {
      await File(f.path).copy('${folder.path}${Platform.pathSeparator}${f.path.split(RegExp(r'[\\/]')).last}');
    }
    _log('Stats: exported ${files.length} session file${files.length == 1 ? '' : 's'} to ${folder.path}');
    return folder.path;
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

/// The game name for ratings asked before the name was known.
const arenaGameName = 'arena';

/// Sends one session summary to the cloud store.
abstract class SessionUploader {
  /// Null on success (or if it was already there), otherwise why it failed.
  Future<String?> upload(Map<String, Object?> summary);
}

/// Firestore through its REST API (PRD v2: the same code on Android TV and
/// Windows). Each session is one document in `sessions`, named by its ID,
/// holding the summary as JSON text plus a few fields the security rules
/// check (firebase/firestore.rules). The rules let apps create documents
/// and nothing else: no reads, no changes.
class FirestoreUploader implements SessionUploader {
  FirestoreUploader({required this.project, this.apiKey = '', HttpClient Function()? client})
    : _client = client ?? HttpClient.new;

  final String project;
  final String apiKey;
  final HttpClient Function() _client;

  @override
  Future<String?> upload(Map<String, Object?> summary) async {
    final id = summary['id'];
    if (id is! String || id.isEmpty) return 'no session ID';
    final uri = Uri.https('firestore.googleapis.com', '/v1/projects/$project/databases/(default)/documents/sessions', {
      'documentId': id,
      if (apiKey.isNotEmpty) 'key': apiKey,
    });
    final body = jsonEncode({
      'fields': {
        'json': {'stringValue': jsonEncode(summary)},
        'schema': {'integerValue': '${summary['schema']}'},
        'date': {'stringValue': '${summary['date']}'},
        'app': {'stringValue': '${(summary['host'] as Map?)?['app'] ?? ''}'},
        'host': {'stringValue': '${(summary['host'] as Map?)?['type'] ?? ''}'},
      },
    });
    final client = _client()..connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType.json;
      request.write(body);
      final response = await request.close().timeout(const Duration(seconds: 20));
      final text = await response.transform(utf8.decoder).join();
      if (response.statusCode == 200) return null;
      if (response.statusCode == 409) return null; // Already uploaded.
      return 'HTTP ${response.statusCode}: ${text.length > 200 ? text.substring(0, 200) : text}';
    } catch (e) {
      return '$e';
    } finally {
      client.close();
    }
  }
}
