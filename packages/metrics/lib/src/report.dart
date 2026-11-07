import 'session_player.dart';

/// One player in one input mode in one session: the report's unit of
/// comparison (PRD v2 "Derived signals in the report").
final class ModeRow {
  const ModeRow({
    required this.session,
    required this.date,
    required this.hostType,
    required this.install,
    required this.deviceKind,
    required this.model,
    required this.platform,
    required this.watched,
    required this.mode,
    required this.ms,
    required this.activeMs,
    required this.touches,
    required this.presses,
    required this.empty,
    required this.near,
    required this.slide,
    required this.rapid,
    required this.games,
    required this.wins,
    required this.good,
    required this.okay,
    required this.bad,
    required this.earlySwitch,
    required this.firstMode,
    this.inputMedianMs,
    this.inputP95Ms,
    this.touchMedianMs,
    this.touchP95Ms,
    this.jitterMedianMs,
    this.jitterP95Ms,
    this.viewFrames,
    this.viewGaps,
    this.viewLate,
  });

  final String session;
  final String date;
  final String hostType;
  final String install;
  final String deviceKind;
  final String model;
  final String platform;

  /// Where the player watched the game (m12 §0.2): `host_phone`,
  /// `joined_phone` or `host_screen`, and null for a summary from a version
  /// that didn't record it.
  final String? watched;
  final String mode;
  final int ms;

  /// Time near player activity (m11.3); [ms] for older phones.
  final int activeMs;
  final int touches;
  final int presses;
  final int empty;
  final int near;
  final int slide;
  final int rapid;
  final int games;
  final int wins;
  final int good;
  final int okay;
  final int bad;

  /// Switched away from this mode within the first minute of using it.
  final bool earlySwitch;

  /// This was the first mode the player picked in the session.
  final bool firstMode;
  final int? inputMedianMs;
  final int? inputP95Ms;

  /// The mode's touch_to_frame median and p95 in ms (m12 §6), null for a
  /// player that doesn't show the game.
  final int? touchMedianMs;
  final int? touchP95Ms;

  /// The mode's frame_jitter median and p95 in ms (m12 §6), null likewise.
  final int? jitterMedianMs;
  final int? jitterP95Ms;

  /// The frames the player drew, the gaps in the host's frames and the late
  /// draws (m12 §6), null for a player that doesn't show the game.
  final int? viewFrames;
  final int? viewGaps;
  final int? viewLate;

  /// The mode's full time, idle included.
  double get openMinutes => ms / 60000;

  /// Time the player was near the controls (m11.3).
  double get minutes => activeMs / 60000;

  /// Empty taps, near misses, slide-offs and rapid repeats per minute.
  double get frustrationPerMin => minutes == 0 ? 0 : (empty + near + slide + rapid) / minutes;

  static const csvHeader =
      'session,date,host,install,device,model,platform,mode,minutes,touches,presses,empty,near,slide,rapid,'
      'games,wins,good,okay,bad,early_switch,first_mode,input_median_ms,input_p95_ms,frustration_per_min,'
      'open_minutes,touch_median_ms,touch_p95_ms,jitter_median_ms,jitter_p95_ms,view_frames,view_gaps,view_late';

  String toCsv() => [
    session,
    date,
    hostType,
    install,
    deviceKind,
    _csv(model),
    platform,
    mode,
    minutes.toStringAsFixed(2),
    touches,
    presses,
    empty,
    near,
    slide,
    rapid,
    games,
    wins,
    good,
    okay,
    bad,
    earlySwitch ? 1 : 0,
    firstMode ? 1 : 0,
    inputMedianMs ?? '',
    inputP95Ms ?? '',
    frustrationPerMin.toStringAsFixed(2),
    openMinutes.toStringAsFixed(2),
    touchMedianMs ?? '',
    touchP95Ms ?? '',
    jitterMedianMs ?? '',
    jitterP95Ms ?? '',
    viewFrames ?? '',
    viewGaps ?? '',
    viewLate ?? '',
  ].join(',');
}

String _csv(String s) => s.contains(',') || s.contains('"') ? '"${s.replaceAll('"', '""')}"' : s;

/// The rows of one session summary (as saved by the TV app).
List<ModeRow> rowsOf(Map<String, Object?> summary) {
  final about = (
    session: summary['id'] as String? ?? '',
    date: summary['date'] as String? ?? '',
    host: (summary['host'] as Map?)?['type'] as String? ?? '',
  );
  return [
    for (final player in (summary['players'] as List?) ?? const [])
      if (player is Map) ..._PlayerRows(player, about: about).rows(),
  ];
}

/// One player's part of a summary, read once for all their modes. The session,
/// date and host are the same for every row.
class _PlayerRows {
  _PlayerRows(this.player, {required this.about})
    : device = player['device'] as Map? ?? const {},
      segments = [
        for (final s in (player['segments'] as List?) ?? const [])
          if (s is Map) s,
      ],
      ratings = [
        for (final r in (player['ratings'] as List?) ?? const [])
          if (r is Map) r,
      ],
      switches = [
        for (final s in (player['switches'] as List?) ?? const [])
          if (s is Map) s,
      ],
      stages = (player['stages'] as Map?) ?? const {},
      watched = _watchedOf(player['watched']),
      firstMode = player['firstMode'] as String?;

  final Map player;
  final ({String session, String date, String host}) about;
  final Map device;
  final List<Map> segments;
  final List<Map> ratings;
  final List<Map> switches;
  final Map stages;

  /// Where the player watched (m12 §0.2), or null when the summary doesn't
  /// say or says something a report can't place.
  final String? watched;
  final String? firstMode;

  /// A row per mode the player was in.
  List<ModeRow> rows() {
    final modes = (player['modes'] as Map?) ?? const {};
    return [for (final MapEntry(key: mode as String, value: info) in modes.entries) _row(mode, info)];
  }

  ModeRow _row(String mode, Object? info) {
    final ofMode = segments.where((s) => s['mode'] == mode).toList();
    int sum(String key) => ofMode.fold(0, (a, s) => a + _total((s['data'] as Map?)?[key]));
    final touches = ofMode.fold(0, (a, s) => a + _int((s['data'] as Map?)?['touches']));
    // A switch away from this mode less than a minute after starting it.
    var early = false;
    for (var i = 0; i < segments.length - 1; i++) {
      if (segments[i]['mode'] == mode && segments[i + 1]['mode'] != mode && _int(segments[i]['ms']) < 60000) {
        early = true;
      }
    }
    final rated = ratings.where((r) => r['mode'] == mode);
    final ms = _int((info as Map?)?['ms']);
    // A summary from an older version has no active time: use the full time.
    final active = info?['activeMs'];
    final input = (stages['sent_to_received'] as Map?) ?? const {};
    final touch = (stages['touch_to_frame'] as Map?) ?? const {};
    final jitter = (stages['frame_jitter'] as Map?) ?? const {};
    final view = (player['view'] as Map?) ?? const {};
    return ModeRow(
      session: about.session,
      date: about.date,
      hostType: about.host,
      install: player['install'] as String? ?? '',
      deviceKind: device['kind'] as String? ?? (player['local'] == true ? 'keyboard' : 'unknown'),
      model: device['model'] as String? ?? '',
      platform: player['platform'] as String? ?? '',
      watched: watched,
      mode: mode,
      ms: ms,
      activeMs: active is num ? active.round() : ms,
      touches: touches,
      presses: sum('presses'),
      empty: sum('empty'),
      near: sum('near'),
      slide: sum('slide'),
      rapid: sum('rapid'),
      games: _int(info?['games']),
      wins: _int(info?['wins']),
      good: rated.where((r) => r['face'] == 'good').length,
      okay: rated.where((r) => r['face'] == 'okay').length,
      bad: rated.where((r) => r['face'] == 'bad').length,
      earlySwitch: early && switches.isNotEmpty,
      firstMode: firstMode == mode,
      inputMedianMs: input['median'] as int?,
      inputP95Ms: input['p95'] as int?,
      touchMedianMs: touch['median'] as int?,
      touchP95Ms: touch['p95'] as int?,
      jitterMedianMs: jitter['median'] as int?,
      jitterP95Ms: jitter['p95'] as int?,
      viewFrames: view['frames'] as int?,
      viewGaps: view['gaps'] as int?,
      viewLate: view['late'] as int?,
    );
  }
}

int _int(Object? v) => v is num ? v.round() : 0;

/// Where a player watched, when the summary names one of the places
/// [Watched] defines: anything else is a summary a newer version wrote.
String? _watchedOf(Object? value) =>
    const {Watched.hostPhone, Watched.joinedPhone, Watched.hostScreen}.contains(value) ? value as String : null;

int _total(Object? counts) => counts is Map ? counts.values.fold(0, (a, v) => a + _int(v)) : 0;
