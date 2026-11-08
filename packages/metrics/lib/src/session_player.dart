import 'dart:math';

import 'package:protocol/protocol.dart';

import 'session_stats.dart';

/// The slowest and the fastest rate a view can run at (m12 §3): a sample that
/// says it came from a view outside this range is a bug or a newer game, and
/// counts in the totals only, never by rate.
const minViewHz = 20;
const maxViewHz = 120;

/// Where a player watched the game (m12 §0.2), as the summary's `watched`.
abstract final class Watched {
  /// The host phone's own player, joined over the in-process channel (D1).
  static const hostPhone = 'host_phone';

  /// A phone that drew frames of the game on itself.
  static const joinedPhone = 'joined_phone';

  /// Everyone else: the host's own screen showed the game, as on the TV.
  static const hostScreen = 'host_screen';
}

/// Where [p] watched the game (m12 §0.2): the host phone's own player is on
/// the host's screen whether or not it also drew frames; a phone that drew
/// frames watched on itself; a keyboard player and a host that keeps the game
/// to itself watched on the host's screen.
String watchedOf(PlayerRecord p) {
  if (p.inProcess) return Watched.hostPhone;
  return p.viewFrames > 0 ? Watched.joinedPhone : Watched.hostScreen;
}

class PlayerRecord {
  PlayerRecord({required this.number, required this.local, required this.platform, required this.app, this.device});

  int number;
  final bool local;

  /// Joined over the host device's own link, not a phone on the network
  /// (m12 §1): only the phone app's host mode has one.
  bool inProcess = false;
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

  /// The same stages filed by the rate of the view that was running when each
  /// sample arrived, keyed by that rate in frames a second (m12 §0.4).
  final stagesByHz = <String, Map<String, DelayStats>>{};
  int viewFrames = 0;
  int viewGaps = 0;
  int viewLate = 0;

  /// The viewer's counts filed by the rate of the view it was drawing, keyed
  /// like [stagesByHz] (m12 §0.4).
  final viewByHz = <String, ({int frames, int gaps, int late})>{};
  final segments = <String, MetricsMessage>{};
  final ratings = <Map<String, Object?>>[];
  final games = <String, Map<String, int>>{};
  final gameStats = <String, Map<String, ValueStats>>{};
  final modeGames = <String, int>{};
  final modeWins = <String, int>{};
  final modeDraws = <String, int>{};
  int quitsMidGame = 0;
  String? mode;
}

/// One player's part of the summary: connection, inputs, latency (by rate
/// too), where they watched, modes, segments, ratings and games.
Map<String, Object?> playerJson(String id, PlayerRecord p, int atMs) {
  final connected = p.connectedMs + (p.joinedAtMs == null ? 0 : max(0, atMs - p.joinedAtMs!));
  final segments = p.segments.values.toList()..sort((a, b) => startMsOf(a).compareTo(startMsOf(b)));
  return {
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
    'stages': stagesOf(p.stages),
    if (p.stagesByHz.isNotEmpty)
      'stagesByHz': {for (final MapEntry(key: hz, value: stages) in p.stagesByHz.entries) hz: stagesOf(stages)},
    if (p.viewFrames + p.viewGaps + p.viewLate > 0)
      'view': viewOf((frames: p.viewFrames, gaps: p.viewGaps, late: p.viewLate)),
    if (p.viewByHz.isNotEmpty)
      'viewByHz': {for (final MapEntry(:key, :value) in p.viewByHz.entries) key: viewOf(value)},
    'watched': watchedOf(p),
    if (segments.isNotEmpty) 'firstMode': segments.first.mode,
    'modes': modesJson(p, segments),
    'switches': switchesOf(segments),
    'segments': [for (final s in segments) segmentJson(s)],
    // Copied, like the rounds: a saved checkpoint must not grow when a later
    // rating or round is recorded (m12 bug 1107e, code-health N7).
    'ratings': [for (final rating in p.ratings) Map<String, Object?>.of(rating)],
    'games': {for (final MapEntry(key: game, value: counts) in p.games.entries) game: Map<String, int>.of(counts)},
    if (p.gameStats.isNotEmpty)
      'gameStats': {
        for (final MapEntry(key: game, value: stats) in p.gameStats.entries)
          game: {for (final MapEntry(:key, :value) in stats.entries) key: value.toJson()},
      },
  };
}

/// Delay statistics of some stages, as the summary writes them: a stage with
/// no sample is left out.
Map<String, Object?> stagesOf(Map<String, DelayStats> stages) => {
  for (final MapEntry(:key, :value) in stages.entries) key: ?value.toJson(),
};

/// A viewer's counts, as the summary writes them.
Map<String, int> viewOf(({int frames, int gaps, int late}) view) => {
  'frames': view.frames,
  'gaps': view.gaps,
  'late': view.late,
};

/// A player's modes: time, time near the controls, games, wins and draws.
Map<String, Object?> modesJson(PlayerRecord p, List<MetricsMessage> segments) {
  final ms = <String, int>{};
  final activeMs = <String, int>{};
  for (final s in segments) {
    ms[s.mode] = (ms[s.mode] ?? 0) + s.durationMs;
    activeMs[s.mode] = (activeMs[s.mode] ?? 0) + activeMsOf(s);
  }
  return {
    for (final m in {...ms.keys, ...p.modeGames.keys})
      m: {
        'ms': ms[m] ?? 0,
        'activeMs': activeMs[m] ?? 0,
        'games': p.modeGames[m] ?? 0,
        'wins': p.modeWins[m] ?? 0,
        'draws': ?p.modeDraws[m],
      },
  };
}

/// The player's switches between modes, in order.
List<Map<String, Object?>> switchesOf(List<MetricsMessage> segments) => [
  for (var i = 1; i < segments.length; i++)
    if (segments[i].mode != segments[i - 1].mode)
      {'from': segments[i - 1].mode, 'to': segments[i].mode, 'atS': (startMsOf(segments[i]) / 1000).round()},
];

/// One of a player's segments, as the summary lists it.
Map<String, Object?> segmentJson(MetricsMessage s) => {
  'id': s.segment,
  'mode': s.mode,
  'ms': s.durationMs,
  'activeMs': activeMsOf(s),
  'ended': s.ended,
  'data': s.data,
};

int startMsOf(MetricsMessage s) => (s.data['start'] as int?) ?? 0;

/// The segment's active time, or its full time for an older phone that
/// doesn't send one.
int activeMsOf(MetricsMessage s) {
  final active = s.data['activeMs'];
  return active is num ? active.round() : s.durationMs;
}

class ValueStats {
  int n = 0;
  double sum = 0;
  double max = double.negativeInfinity;

  void add(double v) {
    n++;
    sum += v;
    if (v > max) max = v;
  }

  Map<String, Object> toJson() => {'n': n, 'mean': (sum / n * 100).round() / 100, 'max': (max * 100).round() / 100};
}
