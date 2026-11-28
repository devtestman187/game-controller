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
import '../night/night_flow_provider.dart';
import '../night/night_settings.dart';
import '../night/party_night.dart';
import '../night/round_results.dart';
import '../players_away.dart';
import '../providers.dart';
import '../puzzle_bag.dart';
import '../text/host_text.dart';
import '../text/night_text.dart';
import '../text/record_text.dart';
import 'controller_menus.dart';
import 'host_button.dart';
import 'host_frame_screen.dart';
import 'join_screen.dart';
import 'lobby_music.dart';
import 'night_reveal_screen.dart';
import 'night_scoreboard_screen.dart';
import 'pause_menu.dart';
import 'player_badge.dart';
import 'present_pop_widgets.dart';
import 'puzzle_best_times.dart';
import 'puzzle_choice.dart';
import 'puzzle_pad_scale.dart';
import 'puzzle_photo.dart';

part 'puzzle_continue.dart';
part 'puzzle_pick.dart';
part 'puzzle_results_widgets.dart';
part 'puzzle_screen_results.dart';
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
    this.series,
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

  /// The series this round goes on with (B-011): the results' Next puzzle
  /// carries it. Null for an `any <level> puzzle` round and for a night's.
  final PuzzleSeries? series;

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
  final _present = PresentTracker();

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

  /// The puzzle this round plays (B-009): the one the caller's match holds, or
  /// the one the level's bag drew as the screen opened.
  Puzzle? _puzzle;
  bool _handedOver = false;

  /// The run of rounds this one belongs to (B-011): carried from the results'
  /// Next puzzle, or started here by a hand-picked puzzle. A night's rounds
  /// keep their own card (design section 4), so no series runs through them.
  PuzzleSeries? _series;

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
    _series = ref.read(partyNightProvider) == null ? widget.series ?? _startedSeries() : null;
    unawaited(_pickedPuzzle().then(_showPuzzle));
  }

  /// Shows the puzzle this round plays (B-009), once the library has answered
  /// and the bag has drawn; the round's id joins the series (B-011), so Next
  /// never plays it again. Here, not in the part: [setState] is the state's own.
  void _showPuzzle(Puzzle? picked) {
    if (!mounted || picked == null) return;
    setState(() {
      _puzzle = picked;
      _series = _series?.withPlayed(picked.id);
    });
  }

  /// The results' Shuffle switch (B-011): the series keeps it for later rounds; here for [setState]'s sake.
  void _shuffle(bool isOn) {
    final series = _series;
    if (series == null) return;
    setState(() => _series = series.withShuffled(isOn));
  }

  @override
  void dispose() {
    _cardTimer?.cancel();
    _music.roundScreenClosed(this);
    if (!_handedOver) _keyboard.dispose();
    _againFocus.dispose();
    _present.dispose();
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
    // A new best time is the results' moment (T15): its cue plays once, with
    // the chip the results card wears.
    if (times.values.any((time) => time.isRecord)) {
      ref.read(soundPlayerProvider).play(SoundKey.newRecord.eventName);
    }
    // A finished picture celebrates for a moment before the results card comes
    // (design 3a); a round that ran out of time has nothing to celebrate, so
    // its card comes at once, as it always did.
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

  void _replaceWith(Widget screen) {
    _handedOver = true;
    Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => screen));
  }

  /// The settings this round plays with (M14 c1): a night's round counts its points, doubled in its last round
  /// (N3), with the cat capped by Kids or sitting out there (G3). Outside a night, the host's own settings.
  PuzzleSettings _roundSettings() {
    final settings = ref.read(puzzleSettingsProvider);
    final night = ref.read(partyNightProvider);
    if (night == null) return settings;
    final kids = ref.read(nightSettingsProvider).isKids;
    return NightChaos.settingsForRound(settings, lastRound: night.isNextRoundTheLast, kids: kids);
  }

  /// The same camera rule as a viewer's (m12-phone-layout §3): this phone's
  /// own side of a phones match, the whole match otherwise. A tablet draws its
  /// side too, and the whole match only where the mirror has no spot (B-041).
  PuzzleCamera get _camera =>
      PuzzleCamera.forPlayer(target: _target, teams: widget.teams, playerId: ref.watch(ownPlayerIdProvider));

  @override
  Widget build(BuildContext context) {
    final puzzle = widget.match?.puzzle ?? _puzzle;
    final result = _result;
    // Who each player is drawn as (M16 identity): the host's own players keep
    // the choice their phone sent, so the round's workers wear it.
    final characters = {
      for (final p in ref.watch(gamePlayersProvider)) p.number: ToyCharacter.of(p.character, p.number),
    };
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
              child: _screen(puzzle, result, characters),
            ),
          ),
        ),
      ),
    );
  }

  /// The board, the results over it, and the play hint, with the players' own
  /// [characters] drawn on it.
  Widget _screen(Puzzle? puzzle, MatchResult? result, Map<int, ToyCharacter> characters) => Scaffold(
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
                        // its density: the round keeps the mirror clear of both
                        // (m12-opponent-mirror rules 3, 7 and 8; no pad, none).
                        final pad = padClearanceFor(context, ref.watch(hostPadProvider), box.biggest);
                        final night = ref.read(partyNightProvider);
                        final numbers = nightRoundNumbers(night);
                        return PuzzlePlayView(
                          key: _play,
                          host: ref.read(gameHostProvider),
                          puzzle: puzzle,
                          teams: widget.teams,
                          random: _random,
                          target: _target,
                          hosting: _hosting,
                          camera: _camera,
                          wholeIfNoMirror: ref.watch(wholeMatchProvider),
                          padRects: pad.rects,
                          hudRects: pad.hudRects,
                          pxPerMm: pad.pxPerMm,
                          match: widget.match,
                          paused: paused,
                          abandon: ref.read(hostAbandonProvider),
                          settings: _roundSettings,
                          // The host's tags (M14): a night's round number,
                          // read as the round starts.
                          roundTags: nightRoundTags(night),
                          round: numbers?.round,
                          rounds: numbers?.rounds,
                          characters: characters,
                          onFinished: _finished,
                          onClock: _clocked,
                        );
                      },
                    ),
                  ),
                  Positioned.fill(child: PresentConfetti(tracker: _present)),
                  if (_cardShown && result != null)
                    // The results cover the board (it stays mounted: the
                    // results' photos are its last frame) and are drawn in the
                    // host's frame, so their way on is always on screen.
                    Positioned.fill(
                      child: _Results(
                        result: result,
                        teams: widget.teams,
                        total: puzzle.pieces.length,
                        menu: _menu,
                        onChangeTeams: _changeTeams,
                        night: ref.read(partyNightProvider) != null,
                        lastRound: ref.read(partyNightProvider)?.isNextRoundTheLast ?? false,
                        onEndNight: _endNight,
                        puzzle: puzzle,
                        match: _play.currentState?.match,
                        times: _times,
                        present: _present,
                      ),
                    ),
                ],
              ),
            ),
    ),
  );
}
