import 'dart:async';

import 'package:connection/connection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_assets/asset_manifest.dart';
import 'package:protocol/protocol.dart';
import 'package:toy_look/toy_look.dart';

import '../away_log.dart';
import '../controls.dart';
import '../host_presence.dart';
import '../players_away.dart';
import '../sound.dart';
import '../text/host_text.dart';
import '../providers.dart';
import 'away_card.dart';
import 'controller_menus.dart';
import 'leave_round.dart';
import 'host_button.dart';
import 'ready_card.dart';
import 'round_phase.dart';

export 'leave_round.dart';

part 'pause_menu_widgets.dart';

/// The labels while the game is paused: the menu, and Start to resume.
const _pauseLabels = {
  ControllerButton.a: HostText.ok,
  ControllerButton.b: HostText.resume,
  ControllerButton.start: HostText.resume,
};

/// The buttons a phone never shows while the game is paused.
const _pauseHidden = {
  ControllerButton.x,
  ControllerButton.y,
  ControllerButton.lb,
  ControllerButton.rb,
  ControllerButton.select,
};

/// The buttons while the game is paused: the menu, and Start to resume.
final pauseLayout = GameLayoutMessage(labels: _pauseLabels, hidden: _pauseHidden);

/// Pausing with Start, for any game (PRD v2 M11): any player's Start pauses
/// the game for everyone and opens the pause menu (Resume, Quit). Only the
/// player who paused and Player 1 can work it, or press Start again to
/// resume, so Player 1 can always override a pause. If neither is here any
/// more, anyone can. Quit leaves the game for the game picker. Only the
/// game's [players] can pause (not someone watching), simulated controllers
/// never do, and Start does nothing for the first [startGrace] of a game, so
/// the press that began it can't pause it. [builder] gets whether the game is
/// paused.
///
/// The game is paused too while the host app is away (m12 §2.10): the
/// builder gets `paused == true` and no menu opens, so the app comes back to
/// the game where it left it. It is paused the same way while the round waits
/// for a phone that dropped (m12 bug 1107d): the away card shows over the game
/// there, and Start opens no menu either.
///
/// A round also starts held for the "Get ready" beat its host asks for
/// ([readyCountdownProvider], m12-host-touch rule 3): the builder gets
/// `paused == true` and [ReadyCard] counts the seconds down. The TV asks for no
/// beat, so nothing of it shows there (rule 6).
///
/// The beat brings the 3-2-1 countdown sound with it (M13 design section 8):
/// it plays as the beat starts from the top (the card's 3) and stops when the
/// beat is held, so no "go" sounds over a round that waits. A round with no
/// beat, the TV's, plays no countdown.
///
/// It is the one place that is up exactly while a round is on, so it also
/// writes the round's phase ([roundPhaseProvider], m12-host-touch): `none`
/// whenever the round stands still, `ready` while the beat holds it and
/// `playing` while it runs. The host phone hides its own pad from it.
class Pausable extends ConsumerStatefulWidget {
  const Pausable({super.key, required this.enabled, required this.builder, this.players});

  /// Start pauses only while this is true (not on the results).
  final bool enabled;

  /// Who can pause: the players in the game. Null: everyone (the Arena).
  final Set<String>? players;

  /// Start is ignored this long after the game starts.
  static const startGrace = Duration(milliseconds: 500);

  /// The "Get ready" beat a round is held for before its first step, when the
  /// host asks for one ([readyCountdownProvider], m12-host-touch rule 3): 3 s,
  /// long enough for thumbs to find the pad before the clock runs. The TV asks
  /// for none (rule 6).
  static const ready = Duration(seconds: 3);
  final Widget Function(BuildContext context, bool paused) builder;

  @override
  ConsumerState<Pausable> createState() => _PausableState();
}

class _PausableState extends ConsumerState<Pausable> {
  late final Timer _timer = Timer.periodic(ControllerMenus.step, (_) => _tick());

  /// Whether each player held Start last time; a new player counts as
  /// holding what they hold now.
  final _startDown = <String, bool>{};

  /// The log's lines about the phones the round waits for (m12 bug 1107e,
  /// 1108g).
  late final AwayLog _awayLog;
  late final StreamSubscription<AwayEnded> _awayEnds;
  late final LogSink _log;
  late final ValueListenable<bool> _away;
  late final VoidCallback _awayChanged;
  late final RoundPhaseSignal _phase;
  GamePlayer? _pausedBy;
  BuildContext? _menuContext;
  int _sinceStartMs = 0;

  /// The "Get ready" beat this round was given, and how much of it is left, in
  /// ms (m12-host-touch rule 3). Zero asks for no beat, as the TV does.
  int _readyTotalMs = 0;
  int _readyMs = 0;

  /// Whether the 3-2-1 countdown is sounding (M13 design section 8): it plays
  /// as the beat starts from the top and stops while the beat is held.
  bool _countdownOn = false;

  /// The host's sounds, once this round has asked for the countdown.
  SoundPlayer? _sound;

  @override
  void initState() {
    super.initState();
    _log = ref.read(logProvider).sink('host');
    // The round's waits are logged as the host ends them, not a tick later
    // (m12 bug 1108g).
    _awayLog = AwayLog(_log);
    _awayEnds = ref.read(hostServiceProvider).awayEnded.listen(_awayLog.ended);
    _away = ref.read(hostAwayProvider);
    _awayChanged = _noteHostAway;
    _away.addListener(_awayChanged);
    _phase = ref.read(roundPhaseProvider)..claim(this);
    _readyTotalMs = ref.read(readyCountdownProvider).inMilliseconds;
    _readyMs = _readyTotalMs;
    _publish();
    _timer;
    // The card shows 3 from the first frame, so the countdown plays with it,
    // unless the round already stands still (the host app is away).
    if (!_stopped) _startCountdown();
  }

  @override
  void didUpdateWidget(Pausable oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The results end the round: nothing is playing any more (m12-host-touch).
    _publish();
  }

  @override
  void dispose() {
    _away.removeListener(_awayChanged);
    unawaited(_awayEnds.cancel());
    _timer.cancel();
    // A round that ends on its beat takes the countdown with it.
    _stopCountdown();
    // The round is gone, and its phase with it: unless the screen that
    // replaced it (Play again) has said what its own round is (M10).
    _phase.release(this);
    super.dispose();
  }

  /// The round is running: on, with no menu over it (m12 bug 1108g rule 2).
  /// Only then does the host's own going away pause it, and only then does the
  /// log say "Round paused" and "Round resumed".
  bool get _running => widget.enabled && _pausedBy == null;

  /// The round stands still: the results, an open menu, the host app away or a
  /// phone the round waits for (m12 §2.10, bug 1107d).
  bool get _stopped => !_running || ref.read(hostAwayProvider).value || ref.read(playersAwayProvider).isNotEmpty;

  /// The "Get ready" beat is still holding the round (m12-host-touch rule 3).
  bool get _onBeat => _readyMs > 0;

  /// The whole seconds the card shows: 3, 2, 1.
  int get _readySeconds => (_readyMs / Duration.millisecondsPerSecond).ceil();

  /// Moves the "Get ready" beat on (m12-host-touch rule 3): the round is held
  /// with no step while the card counts down. A round that stands still holds
  /// the beat too, and it starts again from the top once nothing waits (§2.10,
  /// bug 1107d); the results end it.
  ///
  /// The countdown sound follows it (M13 design section 8): it plays as the
  /// beat starts from the top, so its beeps land on 3, 2 and 1 and its chord on
  /// the round's first step, and it stops while the beat is held or ends early.
  void _beat() {
    if (!_onBeat) return;
    if (!widget.enabled) {
      // The results ended the round before the beat did: no "go" over them.
      _stopCountdown();
      if (_readyMs != 0) setState(() => _readyMs = 0);
      return;
    }
    if (_stopped) {
      // The host is away, or a phone the round waits for is: the beat waits
      // with the round, and starts over from the top (bug 1107d). Its
      // countdown stops with it and plays again from the top.
      _stopCountdown();
      if (_readyMs != _readyTotalMs) setState(() => _readyMs = _readyTotalMs);
      return;
    }
    _startCountdown();
    final next = _readyMs - ControllerMenus.step.inMilliseconds;
    if (next != _readyMs) setState(() => _readyMs = next < 0 ? 0 : next);
    // The beat ran out on its "go": the countdown is this round's no longer, so
    // nothing later stops it by name, not even a Play again's new countdown as
    // this screen is disposed (owner's test of m13.3).
    if (next <= 0) _countdownOn = false;
  }

  /// Plays the 3-2-1 countdown when the beat is at its top, the moment the card
  /// first shows 3 (M13 design section 8). A round with no beat, the TV's, has
  /// none to play.
  void _startCountdown() {
    if (_countdownOn || _readyTotalMs == 0 || _readyMs != _readyTotalMs) return;
    _countdownOn = true;
    final SoundPlayer sound = _sound ?? ref.read(soundPlayerProvider);
    _sound = sound;
    sound.play(SoundKey.countdown.eventName);
  }

  /// Stops the countdown so no "go" sounds over a held round.
  void _stopCountdown() {
    if (!_countdownOn) return;
    _countdownOn = false;
    // Only a countdown this round played is stopped.
    _sound?.stop(SoundKey.countdown.eventName);
  }

  /// What this round is doing now (m12-host-touch rules 1–3): still while it
  /// stands, `ready` while the beat holds it, `playing` once it runs.
  RoundPhase get _roundPhase {
    if (_stopped) return RoundPhase.none;
    return _onBeat ? RoundPhase.ready : RoundPhase.playing;
  }

  /// Says what this round is doing to the host phone's own screens
  /// ([roundPhaseProvider], m12-host-touch rules 1–3), after the frame: the
  /// results end the round during a build, and a screen that read the phase
  /// there must not be rebuilt then.
  void _publish() {
    if (_roundPhase == _phase.value) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _phase.publish(this, _roundPhase);
    });
    // A frame to say it in: a tick or an away signal need not come with one.
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  /// The host app went away or came back: the game pauses with it, without a
  /// menu (m12 §2.10), and the log says which of the round's stops it was. A
  /// round that isn't running (the results, an open menu) is no round to pause,
  /// so there the log only says the host went and came back (m12 bug 1108g
  /// rule 2).
  void _noteHostAway() {
    final away = _away.value;
    // The countdown stops at once with the round, as the music does, not a tick later (M13 9 review).
    if (away) _stopCountdown();
    if (_running) {
      _log(away ? 'Round paused: the host went away' : 'Round resumed: the host is back');
    } else {
      _log(away ? 'The host went away' : 'The host is back');
    }
    _publish();
  }

  /// Who may resume: the player who paused and Player 1, or anyone if
  /// neither is here.
  Set<String>? _resumers(List<GamePlayer> players) {
    final by = _pausedBy;
    final ids = {
      for (final p in players)
        if (p.id == by?.id || p.number == 1) p.id,
    };
    return ids.isEmpty ? null : ids;
  }

  void _tick() {
    if (!mounted) return;
    final host = ref.read(gameHostProvider);
    _awayLog.note(host.players);
    _beat();
    // A phone that dropped, or came back, stands the round still (1107d).
    _publish();
    // Away, the app is hidden: the game is paused as it is, and nothing
    // opens a menu behind it.
    if (ref.read(hostAwayProvider).value) return;
    // The beat holds the round and Start opens nothing until it ends (rule 3).
    if (_onBeat) return;
    _sinceStartMs += ControllerMenus.step.inMilliseconds;
    // A player who is away isn't here to press Start (m12 bug 1107d).
    final players = [
      for (final p in host.players)
        if (!p.simulated && !p.local && !p.away) p,
    ];
    final pressed = _newPresses(host, players);
    if (pressed.isNotEmpty) _startPressed(pressed, players);
  }

  /// The players who pressed Start on this tick.
  List<GamePlayer> _newPresses(GameHost host, List<GamePlayer> players) {
    final pressed = <GamePlayer>[];
    for (final p in players) {
      final down = host.gamepad(p.id).pressed(GamepadButton.start);
      final before = _startDown[p.id];
      _startDown[p.id] = down;
      if (before == false && down) pressed.add(p);
    }
    _startDown.removeWhere((id, _) => !players.any((p) => p.id == id));
    return pressed;
  }

  /// Start opens the menu, or works the one that is up.
  void _startPressed(List<GamePlayer> pressed, List<GamePlayer> players) {
    final menu = _menuContext;
    if (_pausedBy == null) {
      // The away card is the screen's menu while the round waits for a phone
      // that dropped: Start opens no second one (m12 bug 1107d). A menu that
      // was already open can still resume.
      if (ref.read(playersAwayProvider).isNotEmpty) return;
      final can = widget.players;
      final by = pressed.where((p) => can == null || can.contains(p.id)).firstOrNull;
      if (widget.enabled && by != null && _sinceStartMs >= Pausable.startGrace.inMilliseconds) _pause(by);
    } else if (menu != null) {
      final resumers = _resumers(players);
      if (resumers == null || pressed.any((p) => resumers.contains(p.id))) Navigator.of(menu).pop();
    }
  }

  Future<void> _pause(GamePlayer by) async {
    setState(() => _pausedBy = by);
    _publish();
    _log('Round paused: P${by.number} pressed Start');
    final quit = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        _menuContext = context;
        return _PauseMenu(pausedBy: by, resumers: _resumers);
      },
    );
    _menuContext = null;
    if (!mounted) return;
    setState(() => _pausedBy = null);
    _publish();
    if (quit == true) {
      leaveForGamePicker(context);
    } else {
      _log('Round resumed: the menu closed');
    }
  }

  @override
  Widget build(BuildContext context) {
    final hostAway = ref.watch(hostAwayProvider);
    // Who the round waits for (m12 bug 1107d): it stands still while anyone
    // is away, as it does for the menu or a hidden app.
    final away = ref.watch(playersAwayProvider);
    final waiting = widget.enabled && away.isNotEmpty;
    // A phone that drops or comes back changes the phase at once, not on the
    // beat's next step (m12-host-touch).
    ref.listen(playersAwayProvider, (_, _) => _publish());
    return ValueListenableBuilder<bool>(
      valueListenable: hostAway,
      builder: (context, hidden, _) => Stack(
        fit: StackFit.expand,
        children: [
          widget.builder(context, _onBeat || _pausedBy != null || hidden || waiting),
          // The "Get ready" beat stands over the game while it holds the round
          // (m12-host-touch rule 3); the away card takes its place when the
          // round waits for a phone.
          if (_onBeat && !waiting && !hidden) ReadyCard(seconds: _readySeconds),
          // The host's own pause wins while the app is hidden, and the card
          // never stands over the menu: nobody pressed Start for it.
          if (waiting && !hidden && _pausedBy == null)
            AwayCard(players: away, onEndRound: () => leaveForGamePicker(context)),
        ],
      ),
    );
  }
}
