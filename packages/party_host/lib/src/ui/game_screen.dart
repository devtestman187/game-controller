import 'dart:math';

import 'package:connection/connection.dart' show LogSink;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_kit/game_kit.dart';
import 'package:test_game/test_game.dart';
import 'package:toy_look/toy_look.dart';

import '../abandon_signal.dart';
import '../controls.dart';
import '../local_player_source.dart';
import '../night/party_night.dart';
import '../night/round_results.dart';
import '../providers.dart';
import '../text/arena_text.dart';
import '../text/host_text.dart';
import '../text/night_text.dart';
import 'arena_results.dart';
import 'arena_waiting_card.dart';
import 'controller_menus.dart';
import 'game_debug_overlay.dart';
import 'lobby_music.dart';
import 'night_reveal_screen.dart';
import 'night_scoreboard_screen.dart';
import 'pause_menu.dart';

/// Keys that show or hide the debug overlay: OK on the remote (and Enter),
/// the remote's Info or Menu key if it has one, and D or F3 on a keyboard.
final _debugKeys = {
  LogicalKeyboardKey.select,
  LogicalKeyboardKey.enter,
  LogicalKeyboardKey.numpadEnter,
  LogicalKeyboardKey.info,
  LogicalKeyboardKey.contextMenu,
  LogicalKeyboardKey.keyD,
  LogicalKeyboardKey.f3,
};

/// The playable test (PRD T7): the arena, where every player drives their
/// own sprite in their player colour (T9). It runs through the game host
/// interface (PRD v2 P3), like every game. Each game event goes as a haptic
/// event to the controller whose sprite caused it, and plays as a sound on
/// the host. On a desktop, the arrow keys and Space add a keyboard player.
///
/// A round has three stages, one owner each (M14 design section 8): the waiting
/// card (codes, the modes, the maps and Robo's level, and each phone's ready),
/// the field under [Pausable] with its 3-2-1, and the Bumper Round's results.
class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key, this.game});

  /// The game to run. Tests pass one in.
  final ArenaGame? game;

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

/// The stage a round is in (M14 design section 8): one owner each.
enum _Stage {
  /// The waiting card, before the round.
  waiting,

  /// The field, under [Pausable].
  playing,

  /// The Bumper Round's results card.
  results,
}

class _GameScreenState extends ConsumerState<GameScreen> {
  bool _debug = false;

  late final LocalPlayerSource _keyboard;

  /// Where the round's moments go (m12 bug 1107e): the Diagnostics screen reads
  /// them back.
  late final LogSink _log;

  /// The host's music (M13 design section 8): this round reports its clock and
  /// its end, so the Arena's piece speeds up with the Bumper Round's clock and
  /// fades out on the results. Made here, not lazily: dispose() can't read
  /// providers any more.
  late final HostMusic _music;

  /// The results' first button takes the focus, for the remote's OK and a
  /// phone's A.
  final _againFocus = FocusNode(debugLabel: 'arenaAgain');

  /// The screen's own focus: the waiting card's buttons take it while the card
  /// is up, and the round takes it back as it starts, so the keyboard and the
  /// remote's Escape reach the round.
  final _screenFocus = FocusNode(debugLabel: 'arenaScreen');

  /// The screen's randomness, made once here at the edge: Surprise me's map and
  /// the Bumper Round's coins start from it (S8).
  final _random = Random();

  /// How this round runs (m12 §3): its frame rate, read when the round starts
  /// so a change of the setting waits for the next one.
  late final HostingSettings _hosting;

  _Stage _stage = _Stage.waiting;

  /// The round's game, once the waiting card has started it.
  ArenaGame? _game;

  /// The Bumper Round's result, while its card is up.
  RoundResult? _result;

  @override
  void initState() {
    super.initState();
    _hosting = ref.read(hostingSettingsProvider);
    _log = ref.read(logProvider).sink('host');
    // Made here, not lazily: dispose() can't read providers any more.
    final log = ref.read(logProvider);
    _keyboard = ref.read(localPlayerSourceProvider)(
      ref.read(gameHostProvider),
      onJoined: () {
        // The player joined the host a moment ago; its number names it here.
        final who = ref.read(gameHostProvider).players.where((p) => p.local).lastOrNull;
        log.add('game', 'Keyboard player joined${who == null ? '' : ' as P${who.number}'}');
        if (mounted) setState(() {});
      },
    );
    _music = ref.read(lobbyMusicProvider)..roundScreenOpened(this, arena: true);
  }

  @override
  void dispose() {
    _music.roundScreenClosed(this);
    _keyboard.dispose();
    _againFocus.dispose();
    _screenFocus.dispose();
    super.dispose();
  }

  /// The round takes the focus back once its first frame is drawn: the waiting
  /// card's button it came from is gone, and the keyboard and the remote's
  /// Escape reach the screen only through its own focus.
  void _takeFocus() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) _screenFocus.requestFocus();
  });

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    // The keyboard plays the round and joins on the waiting card; on the
    // results its buttons are the way on, as Shape Race's are.
    if (_stage != _Stage.results && _keyboard.handle(event)) return KeyEventResult.handled;
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (_debugKeys.contains(event.logicalKey)) {
      setState(() => _debug = !_debug);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.of(context).maybePop();
      return KeyEventResult.handled;
    }
    // Back on the remote is left to the system, which closes the screen.
    return KeyEventResult.ignored;
  }

  /// The arena already buzzed the phone and played the sound through the
  /// game host (S5): this only notes it for the log and the debug overlay.
  void _onEvent(GameEvent e) {
    final who = ref.read(gamePlayersProvider).where((p) => p.id == e.playerId).firstOrNull;
    ref
        .read(tvEventsProvider.notifier)
        .note(
          e.toMessage(),
          source: 'game: ${e.cause.name}${who == null ? '' : ', P${who.number}'}',
          reached: who == null || who.local ? 0 : 1,
        );
  }

  /// The card's players are all ready: the round starts (design section 8). A
  /// night plays the Bumper Round alone, and its points are doubled in the
  /// night's last round (party-night section 2 N3).
  void _start() {
    final night = ref.read(partyNightProvider);
    final settings = ref.read(arenaSettingsProvider);
    final mode = night == null ? settings.mode : ArenaMode.bumper;
    final map = _mapFor(settings, mode);
    final scale = night != null && night.isNextRoundTheLast ? lastRoundPointsScale : nightPointsScale;
    // A test's game plays the first round as it was given; every later round is
    // built from the card.
    final game = _game == null && widget.game != null
        ? widget.game!
        : ArenaGame(map: map, mode: mode, random: _random, pointsScale: scale);
    ref.read(arenaSettingsProvider.notifier).playedMap(map.id);
    _log('Round started: $arenaGame, ${mode.name}, ${map.name}');
    setState(() {
      _stage = _Stage.playing;
      _result = null;
      _game = game;
    });
    _takeFocus();
  }

  /// The map this round plays (party-night section 7b): the one the card
  /// picked, or Surprise me's — one that plays the mode and wasn't played last,
  /// if there is one.
  ArenaMap _mapFor(ArenaSettings settings, ArenaMode mode) {
    final maps = ref.read(arenaMapLibraryProvider).whenOrNull(data: (library) => library.maps) ?? const <ArenaMap>[];
    final playable = [
      for (final map in maps)
        if (mode == ArenaMode.race ? map.race != null : map.bumper != null) map,
    ];
    final chosen = settings.mapId;
    for (final map in playable) {
      if (map.id == chosen) return map;
    }
    final fresh = [
      for (final map in playable)
        if (map.id != settings.lastMapId) map,
    ];
    final from = fresh.isEmpty ? playable : fresh;
    return from.isEmpty ? ArenaMap.playroom : from[_random.nextInt(from.length)];
  }

  /// Play again: another round on the same map and mode, as Shape Race's
  /// rematch is. A night has Next instead (its round is recorded and the night
  /// goes on), so this is never a night's way on.
  void _again() {
    final last = _game;
    if (last == null) return;
    _log('Results: ${HostText.playAgain}');
    final game = ArenaGame(map: last.map, mode: last.mode, random: _random, pointsScale: last.pointsScale);
    setState(() {
      _stage = _Stage.playing;
      _result = null;
      _game = game;
    });
    _takeFocus();
  }

  /// Change mode: back to the waiting card, to pick another mode, map or Robo
  /// level before the next round.
  void _changeMode() {
    _log('Results: ${ArenaText.changeMode}');
    setState(() {
      _stage = _Stage.waiting;
      _result = null;
    });
  }

  /// The Bumper Round's clock ran out: the results card is up, each joined
  /// phone has its own result (design section 9), and the music fades out
  /// (M13 design section 8, rule 2).
  void _finished(RoundResult result) {
    if (!mounted || _stage != _Stage.playing) return;
    setState(() {
      _stage = _Stage.results;
      _result = result;
    });
    ref
        .read(gameHostProvider)
        .showResults(
          viewResultsFor(result: result, night: ref.read(partyNightProvider), players: ref.read(gamePlayersProvider)),
        );
    _music.roundEnded(this);
    final winner = result.winners.length == 1 ? result.winners.single : HostText.draw;
    _log('Round ended: $winner');
    // The screen's key handler holds the focus, so the card's first button has
    // it moved here, for the remote's OK button.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _againFocus.requestFocus();
    });
  }

  /// A night's Next (M14 c1, design section 4): the round is recorded, and the
  /// scoreboard follows — or, after the night's last round, the awards' reveal,
  /// whose final scores take the scoreboard's place (job c2). Everything above
  /// the game picker goes, so a night of five rounds leaves a phone five routes,
  /// not fifteen.
  void _next() {
    final result = _result;
    if (result == null) return;
    _log('Results: ${NightText.next}');
    ref.read(partyNightProvider.notifier).recordRound(result);
    final over = ref.read(partyNightProvider)?.isOver ?? false;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => over ? const NightRevealScreen() : const NightScoreboardScreen()),
      isGamePickerRoute,
    );
  }

  /// The route asked to go: on the results the answer is the game picker, and
  /// in a night the round is recorded first, as Next does (M14 c1). The waiting
  /// card and the field go back with the route as they came.
  void _leave(bool didPop) {
    if (didPop || _stage != _Stage.results) return;
    if (ref.read(partyNightProvider) != null) return _next();
    _log('Results: ${HostText.back}');
    leaveForGamePicker(context);
  }

  @override
  Widget build(BuildContext context) {
    final night = ref.watch(partyNightProvider);
    // The sky behind every stage stands still (design section 6): a drifting
    // background under a card only costs a phone its battery.
    return RoundHold(
      child: ToyStillSky(
        child: PopScope(
          // Back on the results goes to the game picker, never one route short
          // of it where the next A starts a game (m12 bug 1107e).
          canPop: _stage != _Stage.results,
          onPopInvokedWithResult: (didPop, _) => _leave(didPop),
          child: ControlsClaim(
            // The results are a menu like any other. The waiting card reads the
            // pads itself (A readies a phone), so they are the game's there.
            controls: _stage == _Stage.results ? const Controls.menus() : const Controls.game(),
            child: Focus(
              focusNode: _screenFocus,
              autofocus: true,
              // Not a stop for the arrows: a tap on a card's button moves the
              // focus here, off the buttons, and A then pressed nothing
              // (m10.2 device test).
              skipTraversal: true,
              onKeyEvent: _onKey,
              child: Scaffold(
                body: SafeArea(
                  child: switch (_stage) {
                    _Stage.waiting => ArenaWaitingCard(
                      bumperOnly: night != null,
                      surpriseFirst: night != null,
                      onStart: _start,
                    ),
                    _Stage.playing => _field(),
                    _Stage.results => ArenaResults(
                      result: _result!,
                      night: night != null,
                      againFocus: _againFocus,
                      onAgain: _again,
                      onChangeMode: _changeMode,
                      onNext: _next,
                    ),
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The field, under [Pausable]: Start pauses, the host's going away and a
  /// phone the round waits for hold it, and its 3-2-1 runs on the TV too
  /// (design section 8).
  Widget _field() {
    final nobody = ref.watch(gamePlayersProvider.select((p) => p.isEmpty));
    final game = _game;
    if (game == null) return const SizedBox.shrink();
    return Pausable(
      enabled: true,
      beat: Pausable.ready,
      builder: (context, paused) => Stack(
        children: [
          ArenaView(
            // A new round is a new field: Play again starts from the top.
            key: ObjectKey(game),
            game: game,
            host: ref.read(gameHostProvider),
            settings: _hosting,
            roboLevel: ref.watch(arenaSettingsProvider.select((s) => s.roboLevel)),
            onEvent: _onEvent,
            onClock: _clocked,
            onFinished: _finished,
            paused: paused,
            abandon: ref.read(hostAbandonProvider),
          ),
          if (nobody)
            Positioned(
              left: 0,
              right: 0,
              bottom: arenaNoteBottomPx,
              child: Center(child: ArenaNote(_keyboard.available ? HostText.noControllerKeys : HostText.noController)),
            ),
          if (_debug) const Positioned(top: debugOverlayTopPx, left: ToySizes.space12, child: DebugOverlay()),
        ],
      ),
    );
  }

  /// Each frame of the Bumper Round: its clock, for the music's tempo (M14
  /// design section 7). The race has no clock, so it says nothing and its
  /// piece stays `arena`.
  void _clocked(int timeLeftMs) => _music.roundScreenClock(this, timeLeftMs: timeLeftMs, warningS: 0);
}
