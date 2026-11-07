import 'dart:math';

import 'package:protocol/protocol.dart';

import 'session_stats.dart';

class PlayerRecord {
  PlayerRecord({required this.number, required this.local, required this.platform, required this.app, this.device});

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
  int viewFrames = 0;
  int viewGaps = 0;
  int viewLate = 0;
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

/// One player's part of the summary: connection, inputs, latency, modes,
/// segments, ratings and games.
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
    'stages': {for (final MapEntry(:key, :value) in p.stages.entries) key: ?value.toJson()},
    if (p.viewFrames + p.viewGaps + p.viewLate > 0)
      'view': {'frames': p.viewFrames, 'gaps': p.viewGaps, 'late': p.viewLate},
    if (segments.isNotEmpty) 'firstMode': segments.first.mode,
    'modes': modesJson(p, segments),
    'switches': switchesOf(segments),
    'segments': [for (final s in segments) segmentJson(s)],
    'ratings': p.ratings,
    'games': p.games,
    if (p.gameStats.isNotEmpty)
      'gameStats': {
        for (final MapEntry(key: game, value: stats) in p.gameStats.entries)
          game: {for (final MapEntry(:key, :value) in stats.entries) key: value.toJson()},
      },
  };
}

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
