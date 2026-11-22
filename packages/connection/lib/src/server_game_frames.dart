part of 'server_game_host.dart';

/// The view a game shows on the phones (m12 §2): the start it sent, the latest
/// frame and the host's away countdown, kept so a viewer that pairs mid-round
/// gets them, and sent through the [HostServer].
///
/// It also marks the round's start and end on the server, so a character
/// change waits for the round to end (M16 identity), and fills each frame's
/// characters for the phones that take them.
final class RoundView {
  RoundView({
    required this.server,
    required this.away,
    required this.nowMs,
    required this.characters,
    required this.onEnded,
  });

  /// Where the view's messages go: each one needs [Capability.view], so a
  /// controller that doesn't show the game never gets one.
  final HostServer server;

  /// The dropped players' slots: a viewer that pairs mid-round hears of them,
  /// and the round's end frees them.
  final AwaySlots away;

  /// The host's clock in ms, for the host-away countdown.
  final int Function() nowMs;

  /// The character each player wears, by player ID (M16 identity): the
  /// roster's, so a player whose phone dropped keeps theirs.
  final Map<String, PlayerCharacter> Function() characters;

  /// Called when the round's view ends, so the host reports the roster again.
  final void Function() onEnded;

  /// Whether phones show this host's game at all (m12-joined-view §0.1): a
  /// change applies from the next [start].
  bool shareView = true;

  ViewStartMessage? _start;
  ViewStartMessage? _latest;
  FrameMessage? _frame;
  int? _hostAwayEndsAtMs;

  /// Whether a round is being shown: a character change waits for its end, and
  /// a phone that pairs now gets the view.
  bool get isOn => _start != null;

  /// The rate of the view a game is running, in frames a second (m12 §0.4):
  /// the rate viewers were told. Null between games, and when not shared.
  int? get rateHz => _start?.hz;

  /// True while at least one paired controller listed [Capability.view]. A
  /// session skips building frames when nobody would get them.
  bool get hasViewers => shareView && server.snapshot.connected.any(_isViewer);

  /// A controller that gets frames: it listed [Capability.view].
  static bool _isViewer(ControllerInfo info) => info.supports(Capability.view);

  /// A game starts being shown on viewers. Sent to every viewer now, and to
  /// any viewer that pairs later until [end].
  void start(ViewStartMessage start) {
    _latest = start;
    _hostAwayEndsAtMs = null;
    // A view that isn't shared is no view here: no start is kept, so no frame
    // or end can follow, and a viewer that pairs later gets nothing.
    _start = shareView ? start : null;
    // A viewer that pairs from now on gets this start and the frames after it,
    // never a frame of a game that has ended or a previous one.
    _frame = null;
    server.roundStarted();
    if (_start == null) return;
    server.sendToAll(start);
  }

  /// One frame, to every viewer, with the character of each player in its
  /// roster (M16 identity). Ignored outside [start] and [end].
  void publish(FrameMessage frame) {
    if (_start == null) return;
    final shown = _withCharacters(frame);
    _frame = shown;
    server.sendToAll(shown);
  }

  /// Each viewer whose id is in [results] gets its own result of the round
  /// that just ended (M14 design section 9), as a `view_end` carrying it.
  void results(Map<String, ViewResult> results) {
    // The view stays on: each phone keeps the last frame and draws its result
    // over it, until the round's own end.
    if (_start == null) return;
    for (final MapEntry(key: playerId, value: result) in results.entries) {
      server.send(playerId, ViewEndMessage(reason: ViewEndReason.finished, result: result));
    }
  }

  /// The game stopped being shown. With [of], the start this end is for: an
  /// end for a view a newer start has replaced is ignored, so a rematch's new
  /// view, which starts before the old round's screen is gone, runs on
  /// (owner's test of m13.3).
  void end(ViewEndMessage end, {ViewStartMessage? of}) {
    if (of != null && !identical(of, _latest)) return;
    final wasRunning = _start != null;
    _start = null;
    _frame = null;
    _hostAwayEndsAtMs = null;
    if (wasRunning) server.sendToAll(end);
    // The round is over: a character its players asked for during it takes
    // effect now (M16 identity).
    server.roundEnded();
    // A slot ends with the round (m12 bug 1107d): when it is over, the
    // players away lose it at once, so a rematch never waits for someone
    // who left. The game has already stopped, so no step sees them go.
    if (away.isEmpty) return;
    away.endAll();
    onEnded();
  }

  /// The host is away for a while, or back ([secondsLeft] null). A host tells
  /// its phones whether or not a view runs: the phone shows a host-away card
  /// without a view_start (m16 item 2). The message needs [Capability.view],
  /// so no other controller gets it, and a view the host doesn't share is no
  /// reason to keep it back.
  void hostAway(int? secondsLeft) {
    _hostAwayEndsAtMs = secondsLeft == null ? null : nowMs() + secondsLeft * Duration.millisecondsPerSecond;
    final message = secondsLeft == null ? const HostBackMessage() : HostAwayMessage(secondsLeft: secondsLeft);
    server.sendToAll(message);
  }

  /// A viewer that just (re)paired mid-game gets the view's start, its latest
  /// frame and the aways before any later frame (m12 §2).
  void sendTo(String controllerId) {
    final start = _start;
    if (start == null) return;
    server.send(controllerId, start);
    if (_frame case final frame?) server.send(controllerId, frame);
    away.sendTo(controllerId);
    if (_hostAwayEndsAtMs case final endsAt?) {
      server.send(controllerId, HostAwayMessage(secondsLeft: _secondsToGo(endsAt)));
    }
  }

  /// The whole seconds left of the host's away grace at [endsAtMs], rounded up
  /// like the wait's own count, and 0 once it is over.
  int _secondsToGo(int endsAtMs) {
    final ms = endsAtMs - nowMs();
    return ms <= 0 ? 0 : (ms / Duration.millisecondsPerSecond).ceil();
  }

  /// [frame] with the character of every player in its roster (M16 identity):
  /// the server leaves them out of its copy for a phone that didn't list
  /// [Capability.identity], so that one gets the frame it has always had.
  FrameMessage _withCharacters(FrameMessage frame) {
    final known = characters();
    final shown = <String, PlayerCharacter>{
      for (final MapEntry(key: id, value: character) in frame.characters.entries) id: character,
      for (final MapEntry(key: id, value: character) in known.entries)
        if (frame.roster.containsKey(id)) id: character,
    };
    if (shown.length == frame.characters.length) return frame;
    return FrameMessage(
      n: frame.n,
      atMs: frame.atMs,
      snapshot: frame.snapshot,
      sounds: frame.sounds,
      acks: frame.acks,
      roster: frame.roster,
      characters: shown,
      timeLeftMs: frame.timeLeftMs,
    );
  }
}
