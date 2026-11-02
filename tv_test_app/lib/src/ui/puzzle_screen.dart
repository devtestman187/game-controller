import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puzzle_game/puzzle_game.dart';

import '../keyboard_player.dart';
import '../providers.dart';
import 'gamepad_menu.dart';
import 'tv_button.dart';

/// Which puzzle to play: a specific one, or a random one of a level.
final class PuzzleChoice {
  const PuzzleChoice({required this.level, this.puzzleId});

  final Level level;
  final String? puzzleId;
}

/// Shape Race for one player (PRD v2 M10): the puzzle, played through the
/// game host, then the result (the time, or the pieces placed) with Play
/// again and Back. On Windows the keyboard can play too (arrows, Space, X and
/// Z).
class PuzzleScreen extends ConsumerStatefulWidget {
  const PuzzleScreen({super.key, required this.choice, this.game});

  final PuzzleChoice choice;

  /// The game to run. Tests pass one in.
  final PuzzleGame? game;

  @override
  ConsumerState<PuzzleScreen> createState() => _PuzzleScreenState();
}

class _PuzzleScreenState extends ConsumerState<PuzzleScreen> {
  late final KeyboardPlayer _keyboard;
  final _againFocus = FocusNode(debugLabel: 'playAgain');
  PuzzleResult? _result;
  Puzzle? _puzzle;

  @override
  void initState() {
    super.initState();
    _keyboard = KeyboardPlayer(ref.read(gameHostProvider), onJoined: (_) => setState(() {}));
  }

  @override
  void dispose() {
    _keyboard.dispose();
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
    return _puzzle ??= id != null ? library.byId(id) : library.random(widget.choice.level);
  }

  // The screen's key handler holds the focus, so the button's autofocus
  // would be ignored: move the focus there, for the remote's OK button.
  void _finished(PuzzleResult r) {
    setState(() => _result = r);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _againFocus.requestFocus();
    });
  }

  void _again() =>
      Navigator.of(context)
          .pushReplacement(MaterialPageRoute<void>(builder: (_) => PuzzleScreen(choice: widget.choice)));

  @override
  Widget build(BuildContext context) {
    final puzzle = widget.game?.puzzle ?? ref.watch(puzzleLibraryProvider).whenOrNull(data: _pick);
    final result = _result;
    return Focus(
      autofocus: true,
      // Not a stop for arrow keys or the phone's stick: on the results an
      // up or down push moved the focus here, off the buttons, and A then
      // pressed nothing (m10.2 device test).
      skipTraversal: true,
      onKeyEvent: _onKey,
      child: Scaffold(
        body: GamepadMenu(
          // On the results, the phones work Play again and Back too.
          enabled: result != null,
          onBack: () => Navigator.of(context).maybePop(),
          child: SafeArea(
            child: puzzle == null
                ? const Center(child: CircularProgressIndicator())
                : Stack(
                    children: [
                      Positioned.fill(
                        child: PuzzlePlayView(
                          host: ref.read(gameHostProvider),
                          puzzle: puzzle,
                          game: widget.game,
                          settings: () => ref.read(puzzleSettingsProvider),
                          onFinished: _finished,
                        ),
                      ),
                      if (result != null)
                        Center(
                          child: _Results(result: result, onAgain: _again, againFocus: _againFocus),
                        ),
                      if (result == null)
                        Positioned(
                          right: 12,
                          bottom: 6,
                          child: Text(
                            keyboardPlayerAvailable && _keyboard.player == null
                                ? 'Arrows, Space, X and Z: play on the keyboard · Esc: leave'
                                : 'Back: leave',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white60),
                          ),
                        ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _Results extends StatelessWidget {
  const _Results({required this.result, required this.onAgain, required this.againFocus});

  final PuzzleResult result;
  final VoidCallback onAgain;
  final FocusNode againFocus;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final finished = result.finished;
    return DecoratedBox(
      key: const Key('puzzleResults'),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.82), borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              finished ? 'Done!' : 'Time\'s up!',
              style: text.displaySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: finished ? Colors.greenAccent : Colors.amberAccent,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              finished
                  ? '${result.timeS!.toStringAsFixed(1)} seconds'
                  : '${result.placed} of ${result.total} pieces placed',
              key: const Key('puzzleResultLine'),
              style: text.headlineSmall?.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TvButton(
                  key: const Key('playAgain'),
                  label: 'Play again',
                  icon: Icons.replay,
                  focusNode: againFocus,
                  onPressed: onAgain,
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
