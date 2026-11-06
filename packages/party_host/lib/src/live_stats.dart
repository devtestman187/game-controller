import 'dart:io';
import 'dart:math';

import 'package:connection/connection.dart';
import 'package:metrics/metrics.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
/// with nobody connected.
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
  });

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

  /// The live session's collector, for tests.
  SessionCollector? get session => throw UnimplementedError();

  /// Where session files are kept, once [start] has run.
  Directory? get directory => throw UnimplementedError();

  @override
  StatsState get state => throw UnimplementedError();

  @override
  Stream<StatsState> get changes => throw UnimplementedError();

  /// Starts saving in [dir]: counts the saved sessions and uploads any left
  /// from earlier.
  Future<void> start(Directory dir) => throw UnimplementedError();

  @override
  Future<List<SessionFile>> sessions() => throw UnimplementedError();

  @override
  Future<String> exportAll() => throw UnimplementedError();

  @override
  void setConsent(bool share) => throw UnimplementedError();

  @override
  Future<void> uploadNow() => throw UnimplementedError();

  /// Ends the session: saves it, and queues it for upload.
  Future<void> endSession() => throw UnimplementedError();

  /// Ends the session, stops the timers and closes the streams.
  Future<void> dispose() => throw UnimplementedError();
}
