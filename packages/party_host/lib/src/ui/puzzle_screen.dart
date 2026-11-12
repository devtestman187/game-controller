import 'dart:async';
import 'dart:math';

import 'package:connection/connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_assets/asset_manifest.dart';
import 'package:game_kit/game_kit.dart';
import 'package:puzzle_game/puzzle_game.dart';
import 'package:toy_look/toy_look.dart';

import '../abandon_signal.dart';
import '../best_times.dart';
import '../controls.dart';
import '../local_player_source.dart';
import '../look_providers.dart';
import '../night/party_night.dart';
import '../automation/automation_providers.dart';
import '../night/round_results.dart';
import '../players_away.dart';
import '../providers.dart';
import '../text/host_text.dart';
import '../text/night_text.dart';
import '../text/record_text.dart';
import 'controller_menus.dart';
import 'host_button.dart';
import 'join_screen.dart';
import 'lobby_music.dart';
import 'night_reveal_screen.dart';
import 'night_scoreboard_screen.dart';
import 'pause_menu.dart';
import 'player_badge.dart';
import 'puzzle_best_times.dart';
import 'puzzle_choice.dart';
import 'puzzle_photo.dart';

part 'puzzle_results_widgets.dart';
part 'puzzle_screen_widgets.dart';

/// Shape Race (PRD v2 M10, M11): the match, played through the game host,
/// with Start to pause, then the results: the winner, each side's time or
/// pieces placed, and Rematch (Play again on one board, Next puzzle after an
/// "any puzzle" round), Change teams and Back (T14). The phones work the
/// results like the remote. On a desktop the keyboard can play too (arrows,
/// Space, X and Z).
class PuzzleScreen extends ConsumerStatefulWidget {
  const PuzzleScreen({
    super.key,
    required this.choice,
    required this.teams,
    this.keyboard,
    this.match,
    this.avoidPuzzleId,
  });

  final PuzzleChoice choice;

  /// Each player's side, from the join screen.
  final Map<String, PuzzleSide> teams;

  /// The local player, carried over from the join screen.
  final LocalPlayerSource? keyboard;

  /// The match to run. Tests pass one in.
  final PuzzleMatch? match;

  /// A rematch of a random puzzle picks another one than this, if it can.
  final String? avoidPuzzleId;

  @override
  ConsumerState<PuzzleScreen> createState() => _PuzzleScreenState();
}

class _PuzzleScreenState extends ConsumerState<PuzzleScreen> {
  late final LocalPlayerSource _keyboard;

  /// Where the round's moments go (m12 bug 1107e): the Diagnostics screen
  /// reads them back.
  late final LogSink _log;

  /// The host's music (M13 design section 8): this round reports its clock and
  /// its end, so the music speeds up with the clock and fades out on the
  /// results. Made here, not lazily: dispose() can't read providers any more.
  late final HostMusic _music;
  final _againFocus = FocusNode(debugLabel: 'rematch');

  /// The screen's randomness, made once here at the edge: the puzzle to play
  /// and the match's trays start from it (S8).
  final _random = Random();

  /// The world this round plays in, fixed when the round starts (m12 §0.4):
  /// the phones' when this host shares its view, because the phones draw the
  /// game; the screen's otherwise. A change of [HostService.shareView] waits
  /// for the next round (a rematch builds a new screen).
  late final LayoutTarget _target;

  /// How this round runs (m12 §3): its frame rate, read when the round starts
  /// so a change of the setting waits for the next one.
  late final HostingSettings _hosting;

  /// The play view, whose last snapshot the results show as photos (design
  /// 3a): the picture as it was finished, or as it stood.
  final _play = GlobalKey<PuzzlePlayViewState>();

  MatchResult? _result;

  /// What this round did to each finished side's best time (T15, design
  /// section 9 N14): whether it was a new record, and the board's best now.
  Map<PuzzleSide, BestTimeResult> _times = const {};

  /// Whether the results card is up: it waits for the finish celebration
  /// (design 3a: the card comes after it, never on top of it).
  bool _cardShown = false;
  Timer? _cardTimer;

  Puzzle? _puzzle;
  bool _handedOver = false;

  @override
  void initState() {
    super.initState();
    _log = ref.read(logProvider).sink('host');
    _target = ref.read(hostServiceProvider).shareView ? LayoutTarget.phones : LayoutTarget.screen;
    _hosting = ref.read(hostingSettingsProvider);
    // Made here, not lazily: dispose() can't read providers any more.
    _keyboard =
        widget.keyboard ??
        ref.read(localPlayerSourceProvider)(ref.read(gameHostProvider), onJoined: () => setState(() {}));
    final format = MatchFormat.of(widget.teams);
    _log('Round started: $puzzleGameName, ${format.label}, ${_playersLine(widget.teams.length)}');
    _music = ref.read(lobbyMusicProvider)..roundScreenOpened(this);
  }

  @override
  void dispose() {
    _cardTimer?.cancel();
    _music.roundScreenClosed(this);
    if (!_handedOver) _keyboard.dispose();
    _againFocus.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (_result == null && _keyboard.handle(event)) return KeyEventResult.handled;
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.of(context).maybePop();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Puzzle? _pick(PuzzleLibrary library) {
    final id = widget.choice.puzzleId;
    if (id != null) return _puzzle ??= library.byId(id);
    if (_puzzle != null) return _puzzle;
    final all = library.ofLevel(widget.choice.level);
    final others = all.where((p) => p.id != widget.avoidPuzzleId).toList();
    final from = others.isEmpty ? all : others;
    return _puzzle = from.isEmpty ? null : from[_random.nextInt(from.length)];
  }

  void _finished(MatchResult r) {
    final times = recordBestTimes(
      result: r,
      puzzle: _puzzle,
      teams: widget.teams,
      players: ref.read(gamePlayersProvider),
      times: ref.read(bestTimesProvider.notifier),
    );
    setState(() {
      _result = r;
      _times = times;
    });
    ref.read(automationResultProvider.notifier).record(r.round);
    // A new best time is the results' moment (T15): its cue plays once, with
    // the chip the results card wears.
    if (times.values.any((time) => time.isRecord)) {
      ref.read(soundPlayerProvider).play(SoundKey.newRecord.eventName);
    }
    // A finished picture celebrates for a moment before the results card comes
    // (design 3a); a round that ran out of time has nothing to celebrate, so its card comes at once.
    if (r.sides.values.any((side) => side.finished)) {
      _cardTimer = Timer(const Duration(milliseconds: Celebration.totalMs), _showCard);
    } else {
      _showCard();
    }
    // Each joined phone shows its own result over the last frame (M14 design
    // section 9), while this screen shows the results it always has.
    ref
        .read(gameHostProvider)
        .showResults(
          viewResultsFor(result: r.round, night: ref.read(partyNightProvider), players: ref.read(gamePlayersProvider)),
        );
    // The round's music fades out with the results, before the phase says the
    // round stands still (M13 design section 8, rule 2).
    _music.roundEnded(this);
    _log('Round ended: ${_resultsHead(ref.read(toyLookProvider), r).title}${_endTime(r)}');
  }

  /// The results card comes up, after the finish celebration, if there was one.
  /// The screen's key handler holds the focus, so the card's first button has
  /// it moved here, for the remote's OK button.
  void _showCard() {
    if (!mounted || _cardShown) return;
    setState(() => _cardShown = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _againFocus.requestFocus();
    });
  }

  /// Each frame of the round: its clock, for the music's tempo (M13 design
  /// section 8, rule 3).
  void _clocked(int timeLeftMs, int warningS) =>
      _music.roundScreenClock(this, timeLeftMs: timeLeftMs, warningS: warningS);

  void _replaceWith(Widget screen) {
    _handedOver = true;
    Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => screen));
  }

  /// The first button on the results (m12 bug 1108e), by what this round
  /// played: a round that found its puzzle from `any <level> puzzle` plays
  /// another of the level, so its button says Next puzzle; a round of one
  /// chosen puzzle, or of a level that holds only this one, plays it again, as
  /// Rematch in a race and Play again on one board.
  ///
  /// A night's round has one button, Next (M14 c1, design section 4): the
  /// round is over and the night goes on, so there is nothing to play again
  /// and the teams are picked in the next round's join screen anyway.
  _AgainButton get _again {
    if (ref.read(partyNightProvider) != null) {
      return (label: NightText.next, icon: Icons.skip_next, key: 'next', focusNode: _againFocus, onPressed: _next);
    }
    final race = _result?.format.split ?? false;
    final level = widget.choice.level;
    final another = (ref.read(puzzleLibraryProvider).whenOrNull(data: (l) => l.ofLevel(level).length) ?? 0) > 1;
    final (label, icon, key) = widget.choice.puzzleId == null && another
        ? (HostText.nextPuzzle, Icons.skip_next, 'nextPuzzle')
        : race
        ? (HostText.rematch, Icons.replay, 'rematch')
        : (HostText.playAgain, Icons.replay, 'playAgain');
    return (label: label, icon: icon, key: key, focusNode: _againFocus, onPressed: _rematch);
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
    ref.read(partyNightProvider.notifier).recordRound(result.round);
    final over = ref.read(partyNightProvider)?.isOver ?? false;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => over ? const NightRevealScreen() : const NightScoreboardScreen()),
      isGamePickerRoute,
    );
  }

  /// The settings this round plays with (M14 c1): a night's round counts its
  /// points and doubles them in the night's last round (design section 2 N3),
  /// where the cat also sits out (G3). Outside a night it is the host's own
  /// settings, as it always was.
  PuzzleSettings _roundSettings() {
    final settings = ref.read(puzzleSettingsProvider);
    final night = ref.read(partyNightProvider);
    return night == null ? settings : NightChaos.settingsForRound(settings, lastRound: night.isNextRoundTheLast);
  }

  /// The first button's press: the same teams; a random puzzle becomes
  /// another one of the level.
  void _rematch() {
    _log('Results: ${_again.label}');
    _replaceWith(
      PuzzleScreen(choice: widget.choice, teams: widget.teams, keyboard: _keyboard, avoidPuzzleId: _puzzle?.id),
    );
  }

  void _changeTeams() => _replaceWith(JoinScreen(choice: widget.choice, teams: widget.teams, keyboard: _keyboard));

  /// The same camera rule as a viewer's (m12-phone-layout §3): this phone's
  /// own side of a phones match, the whole match otherwise or on a tablet.
  PuzzleCamera get _camera => PuzzleCamera.forPlayer(
    target: _target,
    teams: widget.teams,
    playerId: ref.watch(ownPlayerIdProvider),
    wholeMatch: ref.watch(wholeMatchProvider),
  );

  @override
  Widget build(BuildContext context) {
    final puzzle = widget.match?.puzzle ?? ref.watch(puzzleLibraryProvider).whenOrNull(data: _pick);
    final result = _result;
    // The round's sky stands still (design section 6): a drifting background
    // under a board only costs a phone its battery.
    return RoundHold(
      child: ToyStillSky(
        child: PopScope(
          // Back on the results goes to the game picker, never one route short of
          // it where the next A starts a game (m12 bug 1107e): the Back button,
          // B on a phone and the system back all ask the route first.
          canPop: result == null,
          onPopInvokedWithResult: (didPop, _) => _leaveForGames(didPop),
          child: ControlsClaim(
            // The results are a menu like any other; while playing, the game reads
            // the controllers.
            controls: result == null ? const Controls.game() : const Controls.menus(),
            child: Focus(
              autofocus: true,
              // Not a stop for arrow keys or the phone's stick: on the results an
              // up or down push moved the focus here, off the buttons, and A then
              // pressed nothing (m10.2 device test).
              skipTraversal: true,
              onKeyEvent: _onKey,
              child: _screen(puzzle, result),
            ),
          ),
        ),
      ),
    );
  }

  /// The route asked: on the results the answer is the game picker. A round
  /// that waits for a phone that dropped stays where it is: the away card
  /// blocks the Back and is the way on (m12 code health N1).
  void _leaveForGames(bool didPop) {
    if (didPop || ref.read(playersAwayProvider).isNotEmpty) return;
    // A night's round is played and scored: Back records it as Next does, and
    // the scoreboard's Back is the one that asks to end the night.
    if (ref.read(partyNightProvider) != null) return _next();
    _log('Results: back to the games');
    leaveForGamePicker(context);
  }

  /// The board, the results over it, and the play hint.
  Widget _screen(Puzzle? puzzle, MatchResult? result) => Scaffold(
    body: SafeArea(
      child: puzzle == null
          ? const Center(child: CircularProgressIndicator())
          : Pausable(
              enabled: result == null,
              // Someone watching can't pause the players.
              players: widget.teams.keys.toSet(),
              builder: (context, paused) => Stack(
                children: [
                  Positioned.fill(
                    child: LayoutBuilder(
                      builder: (context, box) {
                        // Where this app draws its own pad over the game, and
                        // its screen's density: the round keeps the other
                        // side's mirror clear of both (m12-opponent-mirror
                        // rules 3, 7 and 8). A host with no pad passes none.
                        final pad = ref.watch(hostPadProvider);
                        return PuzzlePlayView(
                          key: _play,
                          host: ref.read(gameHostProvider),
                          puzzle: puzzle,
                          teams: widget.teams,
                          random: _random,
                          target: _target,
                          hosting: _hosting,
                          camera: _camera,
                          padRects: pad.rects(box.biggest),
                          pxPerMm: pad.pxPerMm,
                          match: widget.match,
                          paused: paused,
                          abandon: ref.read(hostAbandonProvider),
                          settings: _roundSettings,
                          // The host's tags (M14): a night's round number,
                          // read as the round starts.
                          roundTags: nightRoundTags(ref.read(partyNightProvider)),
                          onFinished: _finished,
                          onClock: _clocked,
                        );
                      },
                    ),
                  ),
                  if (_cardShown && result != null)
                    Center(
                      child: _Results(
                        result: result,
                        teams: widget.teams,
                        total: puzzle.pieces.length,
                        again: _again,
                        onChangeTeams: _changeTeams,
                        night: ref.read(partyNightProvider) != null,
                        puzzle: puzzle,
                        match: _play.currentState?.match,
                        times: _times,
                      ),
                    ),
                ],
              ),
            ),
    ),
  );
}
