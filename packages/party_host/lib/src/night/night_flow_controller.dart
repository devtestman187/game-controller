import 'dart:async';
import 'dart:collection';

import 'night_flow.dart';

/// Starts a timer that calls [fire] after [after]; a test hands in a fake clock instead of real time.
typedef NightSchedule = Timer Function(Duration after, void Function() fire);

Timer _realTimer(Duration after, void Function() fire) => Timer(after, fire);

/// What the controller does to a round for the host: starts it, or plays another one in its place.
abstract interface class NightRoundHooks {
  /// Starts [round] ([lastRound]: it is the night's last); true when it started, false to stay at the how-to card.
  bool startRound(int round, bool lastRound);

  /// Plays [round] again, with the same game when [sameGame] or another one.
  void replaceRound(int round, {required bool sameGame});
}

/// How long each card stays before the night moves on by itself.
final class NightPacing {
  /// Pacing of a night; the defaults keep the gap between two rounds under [maxGap]. A [Duration] cannot be compared
  /// in a const constructor, so [isPlayable] is what the controller asserts.
  const NightPacing({
    this.setup = const Duration(seconds: 3),
    this.howTo = const Duration(seconds: 6),
    this.results = const Duration(seconds: 6),
    this.scoreboard = const Duration(seconds: 8),
    this.ceremony = const Duration(seconds: 8),
  });

  /// The shortest a how-to card may stay, so a player can read it.
  static const minHowTo = Duration(seconds: 5);

  /// The longest a how-to card may stay, so the night does not drag.
  static const maxHowTo = Duration(seconds: 10);

  /// The longest gap between one scoreboard and the next round's how-to card, so the TV never idles (plan n1f).
  static const maxGap = Duration(seconds: 15);

  /// Whether the how-to card stays [minHowTo] to [maxHowTo] and the gap between two rounds stays under [maxGap].
  bool get isPlayable => howTo >= minHowTo && howTo <= maxHowTo && scoreboard + howTo < maxGap;

  /// The start card, before round 1's how-to card.
  final Duration setup;

  /// A round's how-to card, before the round starts.
  final Duration howTo;

  /// The round's end, before its scoreboard.
  final Duration results;

  /// A scoreboard, before the next how-to card or the ceremony.
  final Duration scoreboard;

  /// The last-round ceremony, before the night ends.
  final Duration ceremony;
}

/// Moves a night from card to card on its own and logs every [NightEvent] it emits (plan n1f). The host starts and ends
/// each round: [hooks] starts it after the how-to card, and [roundEnded] says it is over.
final class NightFlowController {
  /// A night of [rounds] rounds, not begun yet. [onEvent] hears each accepted event.
  NightFlowController({required int rounds, this.pacing = const NightPacing(), NightSchedule? schedule, this.onEvent})
    : assert(pacing.isPlayable, 'the pacing keeps how-to cards and gaps in range'),
      _schedule = schedule ?? _realTimer,
      _flow = NightFlow.start(rounds);

  /// A night resumed after [playedRounds] rounds (1 up to [rounds] - 1): replays them without telling [onEvent], ends
  /// at the last played round's scoreboard and arms the step after it.
  NightFlowController.resumed({
    required int rounds,
    required int playedRounds,
    this.pacing = const NightPacing(),
    NightSchedule? schedule,
    this.onEvent,
  }) : assert(playedRounds >= 1 && playedRounds < rounds, 'a resumed night has played 1 to rounds - 1 rounds'),
       assert(pacing.isPlayable, 'the pacing keeps how-to cards and gaps in range'),
       _schedule = schedule ?? _realTimer,
       _flow = NightFlow.start(rounds) {
    _apply(NightSetup(rounds), notify: false);
    for (var round = 1; round <= playedRounds; round++) {
      _apply(NightHowTo(round), notify: false);
      _apply(NightRoundStarted(round, false), notify: false);
      _apply(NightRoundEnded(round, false), notify: false);
      _apply(NightScoreboard(round, false), notify: false);
    }
    _armScoreboard(playedRounds);
  }

  /// How long each card stays.
  final NightPacing pacing;
  final NightSchedule _schedule;

  /// Hears each accepted event, except the replayed ones of a resumed night.
  final void Function(NightEvent)? onEvent;
  final List<NightEvent> _events = [];
  NightFlow _flow;
  Timer? _timer;
  void Function()? _pending;
  bool _disposed = false;

  /// Where the night is now.
  NightFlow get flow => _flow;

  /// Every event the flow accepted, in order, the replayed ones of a resumed night included.
  List<NightEvent> get events => UnmodifiableListView(_events);

  /// The host's side of a round; while null the flow waits at each how-to card for [startNow].
  NightRoundHooks? hooks;

  /// Starts the night: the start card, then round 1's how-to card. Only at the start with nothing emitted.
  void begin() {
    if (_disposed || _events.isNotEmpty || !_apply(NightSetup(_flow.rounds))) return;
    _after(pacing.setup, () => _howTo(1));
  }

  /// The host starts the next round now: from the start card or a scoreboard through its how-to card, from a how-to
  /// card straight to the round. It never calls [hooks]; in any other stage it does nothing.
  void startNow() {
    if (_disposed) return;
    if (_events.isEmpty) begin();
    switch (_flow.stage) {
      case NightStage.setup || NightStage.scoreboard when !_flow.isLastRound:
        _clearWait();
        final next = _flow.round + 1;
        if (_emitHowTo(next)) _apply(NightRoundStarted(next, next == _flow.rounds));
      case NightStage.howTo:
        _clearWait();
        _apply(NightRoundStarted(_flow.round, _flow.isLastRound));
      default:
    }
  }

  /// The round in play is over: its end, then its scoreboard after the results' pause. Only while a round is played.
  void roundEnded() {
    if (_disposed || _flow.stage != NightStage.round) return;
    final round = _flow.round;
    final last = _flow.isLastRound;
    _apply(NightRoundEnded(round, last));
    _after(pacing.results, () {
      if (_apply(NightScoreboard(round, last))) _armScoreboard(round);
    });
  }

  /// Runs the waiting step now, and the timer then does nothing; nothing happens when no step waits.
  void next() {
    final step = _pending;
    if (_disposed || step == null) return;
    _clearWait();
    step();
  }

  /// Stops any waiting step; every later call does nothing.
  void dispose() {
    _disposed = true;
    _clearWait();
  }

  bool _apply(NightEvent event, {bool notify = true}) {
    final moved = _flow.apply(event);
    if (_disposed || moved == null) return false;
    _flow = moved;
    _events.add(event);
    if (notify) onEvent?.call(event);
    return true;
  }

  /// Emits a how-to card, and the doubled announcement with the last round's.
  bool _emitHowTo(int round) {
    if (!_apply(NightHowTo(round))) return false;
    if (round == _flow.rounds) _apply(NightLastRoundDoubled(round));
    return true;
  }

  void _howTo(int round) {
    if (!_emitHowTo(round)) return;
    final last = round == _flow.rounds;
    _after(pacing.howTo, () {
      if (hooks?.startRound(round, last) ?? false) _apply(NightRoundStarted(round, last));
    });
  }

  /// After a scoreboard: the next how-to card, or for the last round the ceremony and then the end.
  void _armScoreboard(int round) {
    if (round < _flow.rounds) {
      _after(pacing.scoreboard, () => _howTo(round + 1));
    } else {
      _after(pacing.scoreboard, () {
        if (_apply(const NightCeremony())) _after(pacing.ceremony, () => _apply(const NightEnded()));
      });
    }
  }

  /// Waits [pause], then runs [step]; the one timer that waits is replaced.
  void _after(Duration pause, void Function() step) {
    _clearWait();
    _pending = step;
    _timer = _schedule(pause, next);
  }

  void _clearWait() {
    _timer?.cancel();
    _timer = null;
    _pending = null;
  }
}
