import 'dart:math';

import 'package:protocol/protocol.dart';

import 'segment.dart';

/// Delays in ms, kept as a 1 ms histogram (up to [maxMs], then one overflow
/// bin), so a whole session's medians and 95th percentiles cost a few KB
/// however long it runs.
class DelayStats {
  static const maxMs = 2000;

  final _bins = List<int>.filled(maxMs + 2, 0);
  int _count = 0;
  int _max = 0;

  int get count => _count;

  void add(int ms) {
    if (ms < 0) return;
    _bins[min(ms, maxMs + 1)]++;
    _count++;
    _max = max(_max, ms);
  }

  /// The value at fraction [q] (0.5 = median), or null without samples.
  int? quantile(double q) {
    if (_count == 0) return null;
    final rank = (q * (_count - 1)).round() + 1;
    var seen = 0;
    for (var i = 0; i < _bins.length; i++) {
      seen += _bins[i];
      if (seen >= rank) return i > maxMs ? _max : i;
    }
    return _max;
  }

  int? get median => quantile(0.5);
  int? get p95 => quantile(0.95);
  int? get maxValue => _count == 0 ? null : _max;

  /// `{n, median, p95, max}`, or null without samples.
  Map<String, Object>? toJson() => _count == 0 ? null : {'n': _count, 'median': median!, 'p95': p95!, 'max': _max};
}

/// Decides when to show the rating prompt (PRD v2 C19): at most once every
/// few games, and not too often in time either. The first time comes after
/// a few games, so a player has had a chance to get used to the controls.
class RatingScheduler {
  RatingScheduler({this.firstAfterGames = 3, this.everyGames = 5, this.minGapMs = 3 * 60 * 1000});

  final int firstAfterGames;
  final int everyGames;
  final int minGapMs;

  final _games = <String, int>{};
  final _lastAskMs = <String, int>{};

  /// A game (an arena round) ended for [playerId] at [atMs]. True if the
  /// player should be asked now.
  bool gameEnded(String playerId, int atMs) {
    final games = (_games[playerId] ?? 0) + 1;
    _games[playerId] = games;
    final last = _lastAskMs[playerId];
    final due = last == null ? games >= firstAfterGames : games >= everyGames && atMs - last >= minGapMs;
    if (!due) return false;
    _games[playerId] = 0;
    _lastAskMs[playerId] = atMs;
    return true;
  }
}

/// What hosted the session (PRD v2 S6).
abstract final class HostType {
  static const androidTv = 'android_tv';
  static const windows = 'windows';
  static const phone = 'phone';
  static const other = 'other';
}

class _Player {
  _Player({required this.number, required this.local, required this.platform, required this.app, this.device});

  int number;
  final bool local;
  final String platform;
  String app;
  DeviceInfo? device;
  int connectedMs = 0;
  int? joinedAtMs;
  int? leftAtMs;
  int disconnects = 0;
  final reconnect = DelayStats();
  int inputs = 0;
  final ping = DelayStats();
  final stages = <String, DelayStats>{};
  final segments = <String, MetricsMessage>{};
  final ratings = <Map<String, Object?>>[];
  final games = <String, Map<String, int>>{};
  final modeGames = <String, int>{};
  final modeWins = <String, int>{};
  int quitsMidGame = 0;
  String? mode;
}

/// Joins everything the host learns in one play session into one summary
/// (PRD v2 T17): each phone's mode segments, ratings, latency, connection
/// health and game events. Pure Dart: the TV app feeds it, and saves
/// [summary] as JSON.
///
/// No names, nicknames or network details go in: players are known by
/// their random install ID and number only.
class SessionCollector {
  SessionCollector({
    required this.id,
    required this.hostType,
    required this.hostApp,
    required this.startedAt,
    required this.startMs,
    this.hostOs,
  });

  /// Random session ID.
  final String id;
  final String hostType;
  final String hostApp;
  final String? hostOs;
  final DateTime startedAt;

  /// [startedAt] on the host's monotonic clock.
  final int startMs;

  final _players = <String, _Player>{};
  final _rounds = <Map<String, Object?>>[];
  int _frames = 0;
  int _frameDrops = 0;
  bool _inGame = false;

  bool get isEmpty => _players.isEmpty;

  Iterable<String> get playerIds => _players.keys;

  /// A player joined, or came back after a drop.
  void joined(
    String id, {
    required int number,
    required int atMs,
    bool local = false,
    String platform = '',
    String app = '',
    DeviceInfo? device,
  }) {
    app = _clean(app, 24) ?? '';
    platform = _clean(platform, 16) ?? '';
    device = device == null ? null : _cleanDevice(device);
    final p = _players[id] ??= _Player(number: number, local: local, platform: platform, app: app, device: device);
    p.number = number;
    if (app.isNotEmpty) p.app = app;
    p.device = device ?? p.device;
    if (p.joinedAtMs != null) return; // Already here.
    final left = p.leftAtMs;
    if (left != null) p.reconnect.add(atMs - left);
    p.joinedAtMs = atMs;
    p.leftAtMs = null;
  }

  /// A player's connection dropped (or the player left).
  void left(String id, int atMs) {
    final p = _players[id];
    final joined = p?.joinedAtMs;
    if (p == null || joined == null) return;
    p.connectedMs += max(0, atMs - joined);
    p.joinedAtMs = null;
    p.leftAtMs = atMs;
    p.disconnects++;
    if (_inGame) p.quitsMidGame++;
  }

  /// A metrics batch: the newest batch of each segment wins.
  void metrics(String id, MetricsMessage batch) {
    final p = _players[id];
    if (p == null) return;
    final old = p.segments[batch.segment];
    if (old != null && old.index >= batch.index) return;
    if (p.segments.length >= 200 && old == null) return; // A runaway phone.
    p.segments[batch.segment] = MetricsMessage(
      segment: batch.segment,
      index: batch.index,
      mode: _mode(batch.mode),
      durationMs: max(0, batch.durationMs),
      ended: batch.ended,
      data: sanitizeSegmentData(batch.data),
    );
  }

  /// The player's current input mode (from their input), for game events.
  void mode(String id, String mode) => _players[id]?.mode = _mode(mode);

  void input(String id) => _players[id]?.inputs++;

  void ping(String id, int ms) => _players[id]?.ping.add(ms);

  /// A latency stage sample (S7).
  void stage(String id, String stage, int ms) {
    final p = _players[id];
    if (p == null || stage.length > 32) return;
    (p.stages[stage] ??= DelayStats()).add(ms);
  }

  void rating(String id, RatingMessage r, {required String game}) {
    final p = _players[id];
    if (p == null || p.ratings.length >= 50) return;
    p.ratings.add({
      'game': game,
      'face': ?r.face?.name,
      if (r.skipped) 'skipped': true,
      'tags': [
        for (final t in r.tags.take(8))
          if (t.length <= 32 && _tagPattern.hasMatch(t)) t,
      ],
      'mode': ?p.mode,
    });
  }

  /// A game event for one player: `wall_hit`, `hazard_hit`, `goal`, `dash`,
  /// `failed_dash`, ….
  void gameEvent(String game, String name, String id) {
    final p = _players[id];
    if (p == null) return;
    final counts = p.games[game] ??= {};
    counts[name] = (counts[name] ?? 0) + 1;
  }

  /// A round started.
  void roundStarted() => _inGame = true;

  /// A round ended. [modes] is each player's mode, [winnerId] who won.
  void roundEnded(String game, {required double timeS, required Map<String, String> modes, String? winnerId}) {
    _inGame = false;
    if (_rounds.length < 1000) {
      _rounds.add({
        'game': game,
        'timeS': double.parse(timeS.toStringAsFixed(2)),
        'players': modes.length,
        'winner': ?_players[winnerId]?.number,
      });
    }
    for (final MapEntry(key: id, value: mode) in modes.entries) {
      final p = _players[id];
      if (p == null) continue;
      final m = _mode(mode);
      p.modeGames[m] = (p.modeGames[m] ?? 0) + 1;
      if (id == winnerId) {
        p.modeWins[m] = (p.modeWins[m] ?? 0) + 1;
        final counts = p.games[game] ??= {};
        counts['wins'] = (counts['wins'] ?? 0) + 1;
      }
      final counts = p.games[game] ??= {};
      counts['rounds'] = (counts['rounds'] ?? 0) + 1;
    }
  }

  /// Frames the host drew, and how many took too long (dropped).
  void frames(int frames, int drops) {
    _frames += max(0, frames);
    _frameDrops += max(0, drops);
  }

  /// The session so far, as JSON (PRD v2 "What it records").
  Map<String, Object?> summary(int atMs) {
    final players = <Map<String, Object?>>[];
    for (final MapEntry(key: id, value: p) in _players.entries) {
      final connected = p.connectedMs + (p.joinedAtMs == null ? 0 : max(0, atMs - p.joinedAtMs!));
      final segments = p.segments.values.toList()..sort((a, b) => _start(a).compareTo(_start(b)));
      final modeMs = <String, int>{};
      for (final s in segments) {
        modeMs[s.mode] = (modeMs[s.mode] ?? 0) + s.durationMs;
      }
      final switches = [
        for (var i = 1; i < segments.length; i++)
          if (segments[i].mode != segments[i - 1].mode)
            {'from': segments[i - 1].mode, 'to': segments[i].mode, 'atS': (_start(segments[i]) / 1000).round()},
      ];
      players.add({
        'install': id,
        'player': p.number,
        if (p.local) 'local': true,
        'platform': p.platform,
        'app': p.app,
        'device': ?p.device?.toJson(),
        'connectedS': (connected / 1000).round(),
        'disconnects': p.joinedAtMs == null ? max(0, p.disconnects - 1) : p.disconnects,
        'reconnect': ?p.reconnect.toJson(),
        if (p.quitsMidGame > 0) 'quitsMidGame': p.quitsMidGame,
        'inputs': p.inputs,
        'inputsPerS': connected == 0 ? 0 : double.parse((p.inputs / (connected / 1000)).toStringAsFixed(1)),
        'ping': ?p.ping.toJson(),
        'stages': {
          for (final MapEntry(:key, :value) in p.stages.entries)
            key: ?value.toJson(),
        },
        if (segments.isNotEmpty) 'firstMode': segments.first.mode,
        'modes': {
          for (final m in {...modeMs.keys, ...p.modeGames.keys})
            m: {'ms': modeMs[m] ?? 0, 'games': p.modeGames[m] ?? 0, 'wins': p.modeWins[m] ?? 0},
        },
        'switches': switches,
        'segments': [
          for (final s in segments)
            {'id': s.segment, 'mode': s.mode, 'ms': s.durationMs, 'ended': s.ended, 'data': s.data},
        ],
        'ratings': p.ratings,
        'games': p.games,
      });
    }
    players.sort((a, b) => (a['player'] as int).compareTo(b['player'] as int));
    return {
      'schema': summarySchema,
      'id': id,
      'host': {'type': hostType, 'app': hostApp, 'os': ?hostOs},
      // The day only, not the time: enough for the report, less to know.
      'date': startedAt.toUtc().toIso8601String().substring(0, 10),
      'durationS': (max(0, atMs - startMs) / 1000).round(),
      'players': players,
      'rounds': _rounds,
      'frames': {'drawn': _frames, 'dropped': _frameDrops},
    };
  }

  static int _start(MetricsMessage s) => (s.data['start'] as int?) ?? 0;

  static String _mode(String mode) => const {'dpad', 'gyro', 'sticks', 'keyboard'}.contains(mode) ? mode : 'other';
}

/// Version of the session summary format.
const summarySchema = 1;

/// Keeps a short technical string (a version, a model like "Pixel 8" or
/// "iPhone15,2"), or drops it if it looks like anything else.
String? _clean(String? s, int maxLength) {
  if (s == null) return null;
  final t = s.trim();
  if (t.isEmpty || t.length > maxLength || !_technical.hasMatch(t) || t.contains("'")) return null;
  return t;
}

DeviceInfo _cleanDevice(DeviceInfo d) => DeviceInfo(
  kind: _clean(d.kind, 16) ?? 'other',
  model: _clean(d.model, 40),
  os: _clean(d.os, 40),
  widthMm: d.widthMm == null || d.widthMm! < 0 || d.widthMm! > 2000 ? null : d.widthMm,
  heightMm: d.heightMm == null || d.heightMm! < 0 || d.heightMm! > 2000 ? null : d.heightMm,
  haptics: d.haptics,
);

final _technical = RegExp(r'^[A-Za-z0-9 ,._()+-]+$');

final _tagPattern = RegExp(r'^[a-z0-9_]+$');
