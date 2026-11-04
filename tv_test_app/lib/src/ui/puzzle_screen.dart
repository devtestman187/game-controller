import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puzzle_game/puzzle_game.dart';

import '../demo/demo_navigation.dart';
import '../keyboard_player.dart';
import '../providers.dart';
import 'controller_menus.dart';
import 'join_screen.dart';
import 'latency_screen.dart' show PlayerBadge;
import 'pause_menu.dart';
import 'tv_button.dart';

/// Which puzzle to play: a specific one, or a random one of a level.
final class PuzzleChoice {
  const PuzzleChoice({required this.level, this.puzzleId});

  final Level level;
  final String? puzzleId;
}

/// Shape Race (PRD v2 M10, M11): the match, played through the game host,
/// with Start to pause, then the results: the winner, each side's time or
/// pieces placed, and Rematch (Play again on one board), Change teams and
/// Back (T14). The phones work the results like the remote. On Windows the
/// keyboard can play too (arrows, Space, X and Z).
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

  /// The keyboard player, carried over from the join screen.
  final KeyboardPlayer? keyboard;

  /// The match to run. Tests pass one in.
  final PuzzleMatch? match;

  /// A rematch of a random puzzle picks another one than this, if it can.
  final String? avoidPuzzleId;

  @override
  ConsumerState<PuzzleScreen> createState() => _PuzzleScreenState();
}

class _PuzzleScreenState extends ConsumerState<PuzzleScreen> {
  late final KeyboardPlayer _keyboard;
  final _againFocus = FocusNode(debugLabel: 'rematch');
  MatchResult? _result;
  Puzzle? _puzzle;
  bool _handedOver = false;

  @override
  void initState() {
    super.initState();
    // Made here, not lazily: dispose() can't read providers any more.
    _keyboard = widget.keyboard ?? KeyboardPlayer(ref.read(gameHostProvider), onJoined: (_) => setState(() {}));
  }

  @override
  void dispose() {
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
    return _puzzle = from.isEmpty ? null : from[Random().nextInt(from.length)];
  }

  // The screen's key handler holds the focus, so the button's autofocus
  // would be ignored: move the focus there, for the remote's OK button.
  void _finished(MatchResult r) {
    setState(() => _result = r);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _againFocus.requestFocus();
    });
  }

  void _replaceWith(Widget screen, String name) {
    _handedOver = true;
    Navigator.of(context)
        .pushReplacement(MaterialPageRoute<void>(settings: demoRouteSettings(name), builder: (_) => screen));
  }

  /// Same teams; a random puzzle becomes another random one.
  void _rematch() => _replaceWith(
    PuzzleScreen(choice: widget.choice, teams: widget.teams, keyboard: _keyboard, avoidPuzzleId: _puzzle?.id),
    'match',
  );

  void _changeTeams() =>
      _replaceWith(JoinScreen(choice: widget.choice, teams: widget.teams, keyboard: _keyboard), 'join');

  @override
  Widget build(BuildContext context) {
    final puzzle = widget.match?.puzzle ?? ref.watch(puzzleLibraryProvider).whenOrNull(data: _pick);
    final result = _result;
    return ControlsClaim(
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
        child: Scaffold(
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
                          child: PuzzlePlayView(
                            host: ref.read(gameHostProvider),
                            puzzle: puzzle,
                            teams: widget.teams,
                            match: widget.match,
                            paused: paused,
                            settings: () => ref.read(puzzleSettingsProvider),
                            onFinished: _finished,
                          ),
                        ),
                        if (result != null)
                          Center(
                            child: _Results(
                              result: result,
                              teams: widget.teams,
                              total: puzzle.pieces.length,
                              againFocus: _againFocus,
                              onAgain: _rematch,
                              onChangeTeams: _changeTeams,
                            ),
                          ),
                        if (result == null)
                          Positioned(
                            right: 12,
                            bottom: 6,
                            child: Text(
                              keyboardPlayerAvailable && _keyboard.player == null
                                  ? 'Arrows, Space, X and Z: play on the keyboard · Start on a phone: pause · '
                                        'Esc: leave'
                                  : 'Start on a phone: pause · Back: leave',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white60),
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _Results extends ConsumerWidget {
  const _Results({
    required this.result,
    required this.teams,
    required this.total,
    required this.againFocus,
    required this.onAgain,
    required this.onChangeTeams,
  });

  final MatchResult result;
  final Map<String, PuzzleSide> teams;
  final int total;
  final FocusNode againFocus;
  final VoidCallback onAgain;
  final VoidCallback onChangeTeams;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final players = ref.watch(gamePlayersProvider);
    final race = result.format.split;
    final (title, colour) = race
        ? switch (result.winner) {
            PuzzleSide.left => ('Left wins!', Colors.greenAccent),
            PuzzleSide.right => ('Right wins!', Colors.greenAccent),
            null => ('Draw!', Colors.amberAccent),
          }
        : result.sides.values.single.finished
        ? ('Done!', Colors.greenAccent)
        : ('Time\'s up!', Colors.amberAccent);

    String line(PuzzleResult r) =>
        r.finished ? '${r.timeS!.toStringAsFixed(1)} seconds' : '${r.placed} of $total pieces placed';

    Widget sideRow(PuzzleSide side, PuzzleResult r) {
      final badges = [
        for (final p in players)
          if (teams[p.id] == side || (!race && teams.containsKey(p.id))) p,
      ];
      final won = race && result.winner == side;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (race)
              SizedBox(width: 80, child: Text(side == PuzzleSide.left ? 'Left' : 'Right', style: text.titleLarge)),
            for (final p in badges) ...[PlayerBadge(number: p.number, size: 30), const SizedBox(width: 6)],
            const SizedBox(width: 8),
            Text(
              line(r),
              key: Key('puzzleResultLine-${side.name}'),
              style: text.headlineSmall?.copyWith(color: won ? Colors.greenAccent : Colors.white),
            ),
          ],
        ),
      );
    }

    return DecoratedBox(
      key: const Key('puzzleResults'),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.82), borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              key: const Key('puzzleResultTitle'),
              style: text.displaySmall?.copyWith(fontWeight: FontWeight.bold, color: colour),
            ),
            const SizedBox(height: 8),
            for (final MapEntry(key: side, value: r) in result.sides.entries) sideRow(side, r),
            const SizedBox(height: 24),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TvButton(
                  key: Key(race ? 'rematch' : 'playAgain'),
                  label: race ? 'Rematch' : 'Play again',
                  icon: Icons.replay,
                  focusNode: againFocus,
                  onPressed: onAgain,
                ),
                const SizedBox(width: 12),
                TvButton(
                  key: const Key('changeTeams'),
                  label: 'Change teams',
                  icon: Icons.group,
                  onPressed: onChangeTeams,
                ),
                const SizedBox(width: 12),
                TvButton(
                  key: const Key('resultsBack'),
                  label: 'Back',
                  icon: Icons.arrow_back,
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
