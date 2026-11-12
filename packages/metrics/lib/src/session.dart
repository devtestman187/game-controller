import 'dart:math';

import 'package:protocol/protocol.dart';

import 'host_device_sample.dart';
import 'segment.dart';
import 'session_device.dart';
import 'session_player.dart';
import 'session_stats.dart';
import 'stream_resource_sample.dart';
import 'stream_stats.dart';

/// What hosted the session (PRD v2 S6).
abstract final class HostType {
  static const androidTv = 'android_tv';
  static const windows = 'windows';
  static const phone = 'phone';

  /// A tablet hosting its own game (M12 host mode, design §0).
  static const tablet = 'tablet';
  static const other = 'other';
}

/// Joins everything the host learns in one play session into one summary
/// (PRD v2 T17): each phone's mode segments, ratings, latency, connection
/// health, where they watched from, the rounds with their battery and heat,
/// and the host device's own samples. Pure Dart: the host app feeds it, and
/// saves [summary] as JSON.
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

  final _players = <String, PlayerRecord>{};
  final _rounds = <Map<String, Object?>>[];
  final _device = HostDeviceTally();
  final _stream = StreamTally();
  int? _roundHz;
  int _frames = 0;
  int _frameDrops = 0;
  bool _inGame = false;
  bool _simulated = false;

  bool get isEmpty => _players.isEmpty;

  /// True once [simulatedOnly] marked the session: nobody real played in it.
  bool get isSimulated => _simulated;

  Iterable<String> get playerIds => _players.keys;

  /// Marks the session as one only simulated players joined (M15 a2), so the
  /// report can set it apart and the host never uploads it.
  void simulatedOnly() => _simulated = true;

  /// A player joined, or came back after a drop. [inProcess] is the host
  /// device's own player, over its in-process link (m12 §1): it watched on
  /// the host's screen, whatever else it did.
  void joined(
    String id, {
    required int number,
    required int atMs,
    bool local = false,
    bool inProcess = false,
    String platform = '',
    String app = '',
    DeviceInfo? device,
  }) {
    app = _clean(app, 24) ?? '';
    platform = _clean(platform, 16) ?? '';
    device = device == null ? null : _cleanDevice(device);
    final p = _players[id] ??= PlayerRecord(number: number, local: local, platform: platform, app: app, device: device);
    p.number = number;
    if (inProcess) p.inProcess = true;
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

  /// A metrics batch: the newest batch of each segment wins. [hz] is the rate
  /// of the view the batch's player was drawing when it was counted (m12
  /// §0.4): its view counts are filed under that rate too.
  void metrics(String id, MetricsMessage batch, {int? hz}) {
    final p = _players[id];
    if (p == null) return;
    final old = p.segments[batch.segment];
    if (old != null && old.index >= batch.index) return;
    if (p.segments.length >= 200 && old == null) return; // A runaway phone.
    final view = batch.view;
    if (view != null) {
      // The counts are the player's, not the mode's: they carry across the
      // batches of every segment (m12 §6).
      final frames = max(0, view.frames);
      final gaps = max(0, view.gaps);
      final late = max(0, view.late);
      p.viewFrames += frames;
      p.viewGaps += gaps;
      p.viewLate += late;
      if (hz case final hz? when hz >= minViewHz && hz <= maxViewHz) {
        final byHz = p.viewByHz['$hz'] ?? (frames: 0, gaps: 0, late: 0);
        p.viewByHz['$hz'] = (frames: byHz.frames + frames, gaps: byHz.gaps + gaps, late: byHz.late + late);
      }
    }
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

  /// A latency stage sample (S7). [hz] is the rate of the view that was
  /// running when it arrived (m12 §0.4), or null when the host doesn't share
  /// its view: the sample is then filed by stage only.
  void stage(String id, String stage, int ms, {int? hz}) {
    final p = _players[id];
    if (p == null || stage.length > 32) return;
    (p.stages[stage] ??= DelayStats()).add(ms);
    if (hz case final hz? when hz >= minViewHz && hz <= maxViewHz) {
      ((p.stagesByHz['$hz'] ??= {})[stage] ??= DelayStats()).add(ms);
    }
  }

  /// A post-game rating. [roundTags] are the tags of the round it asked
  /// about ([roundEnded]'s), so the report knows what the player was rating
  /// (M14's "By game and feature"); an answer to a round with no tags has
  /// none.
  void rating(String id, RatingMessage r, {required String game, List<String> roundTags = const []}) {
    final p = _players[id];
    if (p == null || p.ratings.length >= 50) return;
    final round = _roundTags(roundTags);
    p.ratings.add({
      'game': game,
      'face': ?r.face?.name,
      if (r.skipped) 'skipped': true,
      'tags': [
        for (final t in r.tags.take(8))
          if (t.length <= 32 && _tagPattern.hasMatch(t)) t,
      ],
      'mode': ?p.mode,
      if (round.isNotEmpty) 'round': round,
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

  /// A number measured in a game for one player, e.g. the angle error at a
  /// drop or the time spent rotating: kept as count, mean and max.
  void gameValue(String game, String name, String id, double value) {
    final p = _players[id];
    if (p == null || !value.isFinite || name.length > 32) return;
    ((p.gameStats[game] ??= {})[name] ??= ValueStats()).add(value);
  }

  /// A round started at the rate of the view that runs it (m12 §0.4): [hz] is
  /// null when the host keeps the game on its own screen, and the round then
  /// has no rate to be filed under.
  void roundStarted({int? hz}) {
    _inGame = true;
    _roundHz = hz != null && hz >= minViewHz && hz <= maxViewHz ? hz : null;
  }

  /// A round ended. [modes] is each player's mode; [winnerId] won, or
  /// [winnerIds] (a team) did; [draw]: a race nobody won. The round keeps the
  /// rate of the view it started at.
  ///
  /// [abandoned] is a round nobody played, which the games write when the host
  /// abandons one (M14 design section 2 N1): it adds no round, no count and no
  /// game time, but it still ends the game.
  ///
  /// [tags] say what the round was (M14's "By game and feature"): the game
  /// and the host write short `kind_value` strings such as `mode_bumper`,
  /// `map_playroom` or `night_2of3` ([RoundTag] names the kinds the report
  /// reads). A string that isn't one of those is dropped, a tag a reader
  /// doesn't know is ignored, and a round from before these tags has none: the
  /// summary keeps its schema either way.
  void roundEnded(
    String game, {
    required double timeS,
    required Map<String, String> modes,
    String? winnerId,
    Set<String> winnerIds = const {},
    bool draw = false,
    bool abandoned = false,
    List<String> tags = const [],
  }) {
    final winners = {...winnerIds, ?winnerId};
    _inGame = false;
    if (abandoned) {
      _roundHz = null;
      return;
    }
    if (_rounds.length < 1000) {
      final roundTags = _roundTags(tags);
      _rounds.add({
        'game': game,
        'hz': ?_roundHz,
        'timeS': double.parse(timeS.toStringAsFixed(2)),
        'players': modes.length,
        'winner': ?_players[winners.firstOrNull]?.number,
        if (winners.length > 1) 'winners': [for (final id in winners) ?_players[id]?.number],
        if (draw) 'draw': true,
        if (roundTags.isNotEmpty) 'tags': roundTags,
      });
    }
    _roundHz = null;
    for (final MapEntry(key: id, value: mode) in modes.entries) {
      final p = _players[id];
      if (p == null) continue;
      final m = _mode(mode);
      p.modeGames[m] = (p.modeGames[m] ?? 0) + 1;
      if (draw) p.modeDraws[m] = (p.modeDraws[m] ?? 0) + 1;
      if (winners.contains(id)) {
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

  /// Gives the round that just ended its battery and heat (m12 §0.8): [start]
  /// is the level when it began, [end] when it ended, [charging] whether the
  /// device was on the charger then (the report leaves such a round out of the
  /// battery drop, m12 §1), and [thermal] the device's state at the end.
  /// Nothing is written when no round is waiting (a game that didn't record a
  /// start) or when the round has them already.
  void roundBattery({double? start, double? end, String? thermal, bool charging = false}) {
    if (_rounds.isEmpty) return;
    final round = _rounds.last;
    if (round.containsKey('battery') || round.containsKey('thermal')) return;
    final battery = {'start': ?batteryLevel(start), 'end': ?batteryLevel(end), if (charging) 'charging': true};
    if (battery.isNotEmpty) round['battery'] = battery;
    if (thermal != null) round['thermal'] = thermal;
  }

  /// A reading of the host device's battery and heat while the session runs
  /// (m12 §0.8). [forS] is the seconds passed in the sample's thermal state:
  /// its interval since the last one, or 0 for a sample at a round's edge.
  void deviceSample(HostDeviceSample? sample, {int forS = 0}) {
    if (sample != null) _device.add(sample, forS: forS);
  }

  /// Registers a screen showing the stream (M15) and returns its short id
  /// (`v1`, `v2`, …), or '' when the session already has
  /// [maxStreamViewers]. The caller keeps the id for the session; a client
  /// that comes back is the same viewer, with a higher reconnect count.
  String streamViewer({required String kind, String platform = ''}) => _stream.viewer(kind: kind, platform: platform);

  /// Whether [viewerId] is a viewer this session registered (M15): a client
  /// that keeps reporting sends its id back, and an ingest refuses an id the
  /// session never answered rather than dropping its samples unread.
  bool hasStreamViewer(String viewerId) => _stream.hasViewer(viewerId);

  /// A streaming stage sample in ms (M15, `StreamStage`): a video stage, a
  /// sound stage, or a newer client's own. [fps] files it by the frame rate
  /// the viewer ran at, as a phone's stages are filed (m12 §0.4).
  void streamStage(String viewerId, String name, int ms, {int? fps}) => _stream.stage(viewerId, name, ms, fps: fps);

  /// A gauge sample for a viewer (M15): a number read from time to time, such
  /// as its bitrate, loss or round trip.
  void streamGauge(String viewerId, String name, num value) => _stream.gauge(viewerId, name, value);

  /// One of a viewer's counters (M15): a total since the session started, such
  /// as the frames it sent or the freezes it counted.
  void streamCounter(String viewerId, String name, num value) => _stream.counter(viewerId, name, value);

  /// A fact about a viewer's stream (M15): its codec, its encoder's name, or
  /// `yes` when it went through a relay.
  void streamFact(String viewerId, String name, String value) => _stream.fact(viewerId, name, value);

  /// A reading of the host container's resources while the session streams
  /// (M15): CPU, memory, GPU and the game's and encoder's own numbers.
  void streamResource(StreamResourceSample sample) => _stream.resource(sample);

  /// The session so far, as JSON (PRD v2 "What it records").
  Map<String, Object?> summary(int atMs) {
    final players = [for (final MapEntry(key: id, value: p) in _players.entries) playerJson(id, p, atMs)]
      ..sort((a, b) => (a['player'] as int).compareTo(b['player'] as int));
    return {
      'schema': summarySchema,
      'id': id,
      'host': {'type': hostType, 'app': hostApp, 'os': ?hostOs, 'device': ?_device.toJson()},
      // The day only, not the time: enough for the report, less to know.
      'date': startedAt.toUtc().toIso8601String().substring(0, 10),
      'durationS': (max(0, atMs - startMs) / 1000).round(),
      'players': players,
      // Copied: a summary taken at a checkpoint keeps the rounds it had, and
      // the rounds recorded after it go in the next one (m12 bug 1107e).
      'rounds': [for (final round in _rounds) Map<String, Object?>.of(round)],
      'frames': {'drawn': _frames, 'dropped': _frameDrops},
      // Left out until the session streams (M15), so an older summary reads
      // exactly as it did.
      'stream': ?(_stream.isEmpty ? null : _stream.toJson()),
      // Left out of a session with real players, so an ordinary summary reads
      // exactly as it did.
      'simulated': ?(_simulated ? true : null),
    };
  }

  static String _mode(String mode) => const {'dpad', 'gyro', 'sticks', 'keyboard'}.contains(mode) ? mode : 'other';
}

/// Version of the session summary format.
const summarySchema = 1;

/// The most tags a round or a rating keeps: a game writes a handful, and a
/// runaway one must not fill the summary.
const maxRoundTags = 8;

/// The tags of [tags] that look like a round's own (M14): short `kind_value`
/// strings such as `mode_bumper`, `map_toy-factory` or `night_2of3`. Anything
/// else — a name, a sentence — is dropped, so no tag can carry a person's
/// words.
List<String> _roundTags(List<String> tags) => [
  for (final tag in tags.take(maxRoundTags))
    if (_roundTagPattern.hasMatch(tag)) tag,
];

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

/// A round's tag: lower case and digits, with `_` between a kind and its
/// value and `-` inside a map's id (`map_toy-factory`).
final _roundTagPattern = RegExp(r'^[a-z0-9_.-]{1,32}$');
