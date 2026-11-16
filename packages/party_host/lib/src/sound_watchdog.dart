import 'dart:async';

/// What one look at the music loop found (M14 B-027): whether the engine still
/// knows the loop's voice, and how far it has played. A null
/// [SoundWatchdog.pulse] instead means no loop sounds at all, so a voice the
/// engine lost is told apart from a loop nobody asked for.
typedef SoundPulse = ({bool valid, Duration position});

/// Starts the sound engine again when it dies without saying so (M14 B-027: on
/// an iPad the music and the sounds stopped after several minutes, and only
/// hiding and showing the app brought them back, because nothing but the
/// lifecycle's onShow ever restarted the engine).
///
/// Every [period] it looks at the music loop the host wants sounding: a loop
/// with no voice, a voice the engine no longer knows, or a place that hasn't
/// moved since the look before all mean the engine is gone, so [restart] starts
/// it again, and the player carries the loop on from the place it kept. A look
/// taken while the app is hidden, the music paused, no loop wanted or a restart
/// running judges nothing and forgets the place seen before, so a loop that
/// comes back is never called frozen for standing still.
///
/// [cooldown] is kept between restarts, so an engine that is really gone is
/// not started over and over.
final class SoundWatchdog {
  /// [active] is whether the app is on screen, [wanted] whether a loop should
  /// be sounding, [paused] whether the music is paused, [busy] whether a
  /// restart already runs, [pulse] what the loop found, [restart] how the
  /// engine is started again, and [now] the clock [cooldown] is measured on
  /// (injected so a test doesn't wait 5 s).
  SoundWatchdog({
    required this.active,
    required this.wanted,
    required this.paused,
    required this.busy,
    required this.pulse,
    required this.restart,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  /// How often the loop is looked at: often enough to bring the music back
  /// within a few seconds of the engine dying, rarely enough to cost nothing
  /// while it plays.
  static const period = Duration(seconds: 3);

  /// The shortest time between two restarts: an engine that dies again at
  /// once is not started over every look.
  static const cooldown = Duration(seconds: 5);

  /// Whether the app is on screen (a hidden app's engine is the lifecycle's
  /// business, not the watchdog's).
  final bool Function() active;

  /// Whether a loop should be sounding now: one is asked for and its sounds
  /// are in, or one is asked for while the load that would bring the engine up
  /// did not, so its silence is the engine's death (M14 bugs14, review
  /// finding 3).
  final bool Function() wanted;

  /// Whether the music is paused where it is.
  final bool Function() paused;

  /// Whether a restart already runs: its load reports the sounds it gets.
  final bool Function() busy;

  /// What the loop found, or null when no loop sounds.
  final SoundPulse? Function() pulse;

  /// Starts the engine again, keeping what was asked for.
  final void Function() restart;

  final DateTime Function() _now;
  Timer? _timer;

  /// The place the last look found and the time of the last restart, both
  /// forgotten when a look judges nothing.
  SoundPulse? _lastPulse;
  DateTime? _lastRestartAt;

  /// Starts looking every [period]; a second call does nothing, so a load after
  /// a restart keeps the one timer.
  void start() => _timer ??= Timer.periodic(period, (_) => tick());

  /// Looks once. Called by the timer, and by a test without one.
  void tick() {
    if (!active() || !wanted() || paused() || busy()) {
      _lastPulse = null;
      return;
    }
    final looked = pulse();
    if (looked == null || !looked.valid) {
      _lastPulse = null;
      _restartOnce();
      return;
    }
    final frozen = looked.position == _lastPulse?.position;
    _lastPulse = looked;
    if (frozen) _restartOnce();
  }

  /// A play() call threw, so the engine is likely gone: start it again when
  /// the app is on screen and no restart runs, at most once per [cooldown].
  void failed() {
    if (!active() || busy()) return;
    _restartOnce();
  }

  /// Stops looking; nothing of the watchdog outlives the player that owns it.
  void dispose() {
    _timer?.cancel();
    _timer = null;
  }

  /// Starts the engine again unless one started less than [cooldown] ago, and
  /// forgets the place: the new loop starts fresh.
  void _restartOnce() {
    final now = _now();
    final last = _lastRestartAt;
    if (last != null && now.difference(last) < cooldown) return;
    _lastRestartAt = now;
    _lastPulse = null;
    restart();
  }
}
