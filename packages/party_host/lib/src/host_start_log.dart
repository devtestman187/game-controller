import 'package:connection/connection.dart';

/// The steps of a host's start, in the order they are logged (m12 bug 1108b):
/// picking how to host froze the owner's phone for about 1.6 s, and each step
/// is one log line that says how far into the start it was reached.
enum HostStartStep {
  /// The tap that chose how to host: every later line counts from here.
  tap('tap'),

  /// The app built this phone's host ([PhoneHost.live]).
  hostBuilt('host built'),

  /// The host service started: the server, its addresses and its advertising.
  serviceStarted('service started'),

  /// This phone's own player paired with the host it runs. A host that shows
  /// the game on this device pairs none, so it logs no line.
  ownPlayerPaired('own player paired'),

  /// The sound engine came up.
  soundEngineInit('sound engine init'),

  /// Every game sound was loaded.
  soundsLoaded('sounds loaded'),

  /// The host route's first frame was drawn: the end of the freeze the player
  /// sees after picking a mode.
  firstFrame('first frame');

  const HostStartStep(this.label);

  /// How the step reads in its log line.
  final String label;
}

/// Times a host's start, one `host` log line per [HostStartStep] (m12 bug
/// 1108b). The ms after a step's name is the time since the tap that chose how
/// to host, so a Diagnostics copy from the owner's phone names the step that
/// froze it.
///
/// Nothing is logged before a [tap]: a host started by anything but a player
/// (the TV's home screen) logs no lines and reads as it always has.
final class HostStartLog {
  /// [sink] takes the lines; [nowMs] is the clock they count on, which a test
  /// replaces and the app leaves out.
  HostStartLog(this._sink, {int Function()? nowMs}) : _nowMs = nowMs ?? _monotonicMs;

  final LogSink _sink;
  final int Function() _nowMs;
  int _tapMs = 0;
  bool _started = false;

  /// The tap that chose how to host: this start's first line, and the moment
  /// the lines after it count from.
  void tap() {
    _tapMs = _nowMs();
    _started = true;
    step(HostStartStep.tap);
  }

  /// Logs [step] with the ms since [tap].
  void step(HostStartStep step) {
    if (!_started) return;
    _sink('Host start: ${step.label} ${_nowMs() - _tapMs} ms');
  }
}

/// The clock the lines count on when the app leaves it out: monotonic, so a
/// phone that slept in the middle of a start doesn't read as a slower step.
final _monotonic = Stopwatch()..start();

int _monotonicMs() => _monotonic.elapsedMilliseconds;
