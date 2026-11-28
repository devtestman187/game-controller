import 'dart:math';

import 'package:flutter/material.dart';
import 'package:puzzle_game/puzzle_game.dart';
import 'package:toy_look/toy_look.dart';

import '../text/host_text.dart';

/// Remembers how the hot-potato present last ended (M17 r3f): fed each frame with the match's present, it notes the
/// side that held it when it popped. [pops] counts the pops, so a widget can tell a new one from the last.
final class PresentTracker {
  /// Counts the pops this round has seen; it changes on the frame a present pops.
  final ValueNotifier<int> pops = ValueNotifier(0);

  PuzzleSide? _heldAtPop;
  bool _wasPopped = false;

  /// The side that held the present when it last popped; null while none has popped this round.
  PuzzleSide? get heldAtPop => _heldAtPop;

  /// Takes one frame's [present] (null while none is out). A pop counts once, on the first frame that shows it.
  void feed(PresentState? present) {
    final popped = present?.popped ?? false;
    if (popped && !_wasPopped) {
      _heldAtPop = present!.holder;
      pops.value++;
    }
    _wasPopped = popped;
  }

  /// Frees [pops]; call it once the round's screen is gone and nothing listens any more.
  void dispose() => pops.dispose();
}

/// How many pieces a pop throws.
const _confettiPieces = 28;

/// A piece's size in logical px, so it reads from three metres on the TV as well.
const _confettiPiecePx = 14.0;

/// How far a piece flies, as a share of the shorter side of the board.
const _confettiReachShare = 0.45;

/// The golden angle in radians: it spreads the pieces evenly round the burst without a random source.
const _goldenAngle = 2.399963;

/// How many distinct depths the pieces fly to; piece i takes depth i modulo this, so the depths repeat.
const _confettiDepthLevels = 5;

/// The nearest a piece flies, as a share of its full reach.
const _confettiDepthNear = 0.4;

/// How much further the farthest piece flies than the nearest, as a share of its full reach.
const _confettiDepthSpan = 0.6;

/// A short confetti burst over the board each time the present pops (M17 r3f), for [PresentRules.popMs]. It takes no
/// touch and uses no asset, so it shows under every look and on the TV.
class PresentConfetti extends StatefulWidget {
  /// The burst for [tracker]'s pops.
  const PresentConfetti({super.key, required this.tracker});

  /// Tells when the present pops.
  final PresentTracker tracker;

  @override
  State<PresentConfetti> createState() => _PresentConfettiState();
}

class _PresentConfettiState extends State<PresentConfetti> with SingleTickerProviderStateMixin {
  late final AnimationController _burst = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: PresentRules.popMs),
  );

  @override
  void initState() {
    super.initState();
    widget.tracker.pops.addListener(_pop);
  }

  void _pop() => _burst.forward(from: 0);

  @override
  void didUpdateWidget(PresentConfetti old) {
    super.didUpdateWidget(old);
    if (old.tracker == widget.tracker) return;
    old.tracker.pops.removeListener(_pop);
    widget.tracker.pops.addListener(_pop);
  }

  @override
  void dispose() {
    widget.tracker.pops.removeListener(_pop);
    _burst.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    final colours = [look.colors.good, look.colors.caution, look.colors.focus, look.colors.bad, look.colors.star];
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _burst,
        builder: (context, _) => _burst.isAnimating
            ? CustomPaint(
                key: const Key('presentConfetti'),
                size: Size.infinite,
                painter: _ConfettiPainter(progress: _burst.value, colours: colours),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  const _ConfettiPainter({required this.progress, required this.colours});

  /// 0 as the present pops, 1 as the burst ends.
  final double progress;
  final List<Color> colours;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final reach = size.shortestSide * _confettiReachShare * Curves.easeOut.transform(progress);
    final paint = Paint();
    for (var i = 0; i < _confettiPieces; i++) {
      final angle = i * _goldenAngle;
      // Pieces fly to different depths, and fade out over the burst's last half.
      final level = (i % _confettiDepthLevels) / (_confettiDepthLevels - 1);
      final depth = _confettiDepthNear + _confettiDepthSpan * level;
      final at = centre + Offset(cos(angle), sin(angle)) * (reach * depth);
      paint.color = colours[i % colours.length].withValues(alpha: (1 - progress).clamp(0, 1));
      canvas.save();
      canvas.translate(at.dx, at.dy);
      canvas.rotate(angle + progress * pi);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: _confettiPiecePx, height: _confettiPiecePx / 2),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}

/// The results' line on who held the present (M17 r3f). Neutral on purpose: it names the side the present was with
/// last and never says who lost it. Nothing while no present has popped.
class PresentHeldLine extends StatelessWidget {
  /// The line for what [tracker] saw.
  const PresentHeldLine({super.key, required this.tracker});

  /// Knows which side held the present at its last pop.
  final PresentTracker tracker;

  /// The line's words for [side].
  static String text(PuzzleSide side) =>
      'The present was with the ${side == PuzzleSide.left ? HostText.left : HostText.right} side last. '
      'Everyone batted it around!';

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: tracker.pops,
    builder: (context, _) {
      final side = tracker.heldAtPop;
      if (side == null) return const SizedBox.shrink();
      final look = ToyLookScope.of(context);
      return Padding(
        padding: const EdgeInsets.only(top: ToySizes.space8),
        child: Text(
          text(side),
          key: const Key('presentHeldLine'),
          style: look.type.body.copyWith(color: look.colors.ink),
        ),
      );
    },
  );
}
