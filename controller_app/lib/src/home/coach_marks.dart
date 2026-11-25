import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:party_host/party_host.dart' show ToyCard, ToyLook, ToyLookScope, ToySizes;

import 'home_text.dart';

/// The least a thing a thumb has to hit measures, in dp, whatever the look's
/// button height is: Skip and the tap area of the box never get smaller, and the
/// text is never scaled down to make them fit.
const coachMinTouchTargetDp = 48.0;

/// How dark the dimmed screen is, as the ink's alpha: dark enough to quiet the
/// screen, light enough that the buttons under it can still be told apart.
const coachScrimAlpha = 0.6;

/// How far the lit hole reaches past the anchor on every side, in dp, so the
/// anchor's own outline and shadow stay inside it.
const coachHolePaddingDp = ToySizes.space8;

/// The room the hint box leaves to the screen's edge, in dp.
const coachScreenMarginDp = ToySizes.space16;

/// The widest the hint box grows, in dp: a longer line is harder to read on a
/// TV than a second line.
const coachMaxBoxWidthDp = 360.0;

/// The arrow's width and height in dp, as it points from the box at the anchor.
const coachArrowWidthDp = ToySizes.space24;
const coachArrowHeightDp = ToySizes.space12;

/// One stop of the coach marks: the button to point at and what to tell about it.
class CoachStep {
  /// One stop of the tour: a widget and a hint, nothing else, so any screen can
  /// build a tour from its own widgets. A stop whose anchor isn't laid out yet is skipped.
  const CoachStep({required this.anchor, required this.text});

  /// Marks the widget the step points at; a step whose anchor has no render
  /// box yet is skipped over.
  final GlobalKey anchor;

  /// The hint shown in the box.
  final String text;
}

/// The first-time tips: the screen dimmed, a hint box with an arrow pointing at
/// one anchor at a time, a tap to go on and Skip to stop. A pure widget: the
/// caller decides whether to show it, saves nothing and routes nowhere.
///
/// It fills the space its parent gives it, so it sits in a [Stack] above the
/// screen whose anchors it points at.
class CoachMarks extends StatefulWidget {
  /// Shows the marks over the screen; the caller decides when, and reacts to [onDone] and [onSkip].
  const CoachMarks({super.key, required this.steps, required this.onDone, required this.onSkip});

  /// The stops, in the order they show.
  final List<CoachStep> steps;

  /// Called once, when the last step is tapped (or no step has an anchor to show).
  final VoidCallback onDone;

  /// Called once, when Skip is tapped at any step.
  final VoidCallback onSkip;

  @override
  State<CoachMarks> createState() => _CoachMarksState();
}

class _CoachMarksState extends State<CoachMarks> {
  int _index = 0;

  /// The current anchor's rect in this widget's own coordinates, or null until
  /// it has been read after layout.
  Rect? _anchor;

  /// Whether a read of the anchor is already waiting for the end of the frame.
  bool _isReadScheduled = false;

  /// Whether onDone or onSkip has been called, so neither runs twice.
  bool _isFinished = false;

  void _scheduleRead() {
    if (_isReadScheduled) return;
    _isReadScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _readAnchor());
  }

  /// Reads the current anchor's place after layout; a step without a render box
  /// is skipped, and past the last one the marks are done.
  void _readAnchor() {
    _isReadScheduled = false;
    if (!mounted || _isFinished) return;
    if (_index >= widget.steps.length) {
      _finish(widget.onDone);
      return;
    }
    final rect = _anchorRect(widget.steps[_index].anchor);
    if (rect == null) {
      _advance();
    } else if (rect != _anchor) {
      setState(() => _anchor = rect);
    }
  }

  Rect? _anchorRect(GlobalKey anchor) {
    final target = anchor.currentContext?.findRenderObject();
    final own = context.findRenderObject();
    if (target is! RenderBox || own is! RenderBox) return null;
    if (!target.attached || !target.hasSize || !own.attached) return null;
    return own.globalToLocal(target.localToGlobal(Offset.zero)) & target.size;
  }

  void _advance() {
    if (_isFinished) return;
    if (_index + 1 >= widget.steps.length) {
      _finish(widget.onDone);
      return;
    }
    setState(() {
      _index++;
      _anchor = null;
    });
  }

  void _finish(VoidCallback callback) {
    if (_isFinished) return;
    _isFinished = true;
    callback();
  }

  @override
  Widget build(BuildContext context) {
    // The size is read so a rotation or a text scale change builds again and the
    // anchor is read again from its new place.
    MediaQuery.sizeOf(context);
    final look = ToyLookScope.of(context);
    final anchor = _anchor;
    return LayoutBuilder(
      builder: (context, _) {
        // A layout change of the overlay can move the anchor too, so it is read again.
        _scheduleRead();
        return Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _advance,
              child: CustomPaint(
                painter: _ScrimPainter(
                  color: look.colors.ink.withValues(alpha: coachScrimAlpha),
                  hole: anchor == null
                      ? null
                      : RRect.fromRectAndRadius(
                          anchor.inflate(coachHolePaddingDp),
                          const Radius.circular(ToySizes.cardCorner),
                        ),
                ),
              ),
            ),
            if (anchor != null && _index < widget.steps.length)
              CustomMultiChildLayout(
                delegate: _HintLayout(anchor.inflate(coachHolePaddingDp)),
                children: [
                  LayoutId(
                    id: _HintSlot.box,
                    child: _HintBox(
                      text: widget.steps[_index].text,
                      onTap: _advance,
                      onSkip: () => _finish(widget.onSkip),
                    ),
                  ),
                  LayoutId(
                    id: _HintSlot.arrowUp,
                    child: _Arrow(look: look, isUp: true),
                  ),
                  LayoutId(
                    id: _HintSlot.arrowDown,
                    child: _Arrow(look: look, isUp: false),
                  ),
                ],
              ),
          ],
        );
      },
    );
  }
}

/// The parts the hint layout places: the box, and the arrow that points up (box
/// below the anchor) or down (box above it); the one not used is given no size.
enum _HintSlot { box, arrowUp, arrowDown }

/// The dim over the screen with a rounded hole where the anchor is.
class _ScrimPainter extends CustomPainter {
  const _ScrimPainter({required this.color, required this.hole});

  final Color color;
  final RRect? hole;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size);
    final hole = this.hole;
    if (hole != null) path.addRRect(hole);
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_ScrimPainter oldDelegate) => oldDelegate.color != color || oldDelegate.hole != hole;
}

/// Places the hint box under the lit hole, or over it when there is no room
/// below, with the arrow in between, and keeps the box inside the screen.
class _HintLayout extends MultiChildLayoutDelegate {
  _HintLayout(this.hole);

  /// The lit hole, in this layout's coordinates.
  final Rect hole;

  @override
  void performLayout(Size size) {
    final maxWidth = math.min(size.width - 2 * coachScreenMarginDp, coachMaxBoxWidthDp);
    final maxHeight = math.max(0.0, size.height - 2 * coachScreenMarginDp - coachArrowHeightDp);
    final box = layoutChild(_HintSlot.box, BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight));
    final roomBelow = size.height - coachScreenMarginDp - hole.bottom - coachArrowHeightDp;
    final roomAbove = hole.top - coachScreenMarginDp - coachArrowHeightDp;
    final isBelow = box.height <= roomBelow || roomBelow >= roomAbove;
    const arrowHalf = coachArrowWidthDp / 2;
    final arrowX = hole.center.dx
        .clamp(
          coachScreenMarginDp + arrowHalf,
          math.max(coachScreenMarginDp + arrowHalf, size.width - coachScreenMarginDp - arrowHalf),
        )
        .toDouble();
    final rawBoxY = isBelow ? hole.bottom + coachArrowHeightDp : hole.top - coachArrowHeightDp - box.height;
    final boxY = rawBoxY
        .clamp(coachScreenMarginDp, math.max(coachScreenMarginDp, size.height - coachScreenMarginDp - box.height))
        .toDouble();
    final boxX = (hole.center.dx - box.width / 2)
        .clamp(coachScreenMarginDp, math.max(coachScreenMarginDp, size.width - coachScreenMarginDp - box.width))
        .toDouble();
    positionChild(_HintSlot.box, Offset(boxX, boxY));
    const arrowSize = Size(coachArrowWidthDp, coachArrowHeightDp);
    // With no room on either side the box is pushed over the hole's edge, and an
    // arrow in its slot would lie on the text and take its taps: no arrow then.
    final isRoomy = box.height <= (isBelow ? roomBelow : roomAbove);
    layoutChild(_HintSlot.arrowUp, BoxConstraints.tight(isRoomy && isBelow ? arrowSize : Size.zero));
    layoutChild(_HintSlot.arrowDown, BoxConstraints.tight(isRoomy && !isBelow ? arrowSize : Size.zero));
    positionChild(_HintSlot.arrowUp, Offset(arrowX - arrowHalf, hole.bottom));
    positionChild(_HintSlot.arrowDown, Offset(arrowX - arrowHalf, hole.top - coachArrowHeightDp));
  }

  @override
  bool shouldRelayout(_HintLayout oldDelegate) => oldDelegate.hole != hole;
}

/// The arrow from the box to the anchor: a paper triangle with the ink edge on
/// its two slanted sides, so it joins the box without a seam.
class _Arrow extends StatelessWidget {
  const _Arrow({required this.look, required this.isUp});

  final ToyLook look;

  /// Whether the tip points up (the box is below the anchor).
  final bool isUp;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _ArrowPainter(
      fill: look.colors.paper,
      edge: look.colors.ink,
      edgeWidth: look.sizes.outlineWidth,
      isUp: isUp,
    ),
  );
}

class _ArrowPainter extends CustomPainter {
  const _ArrowPainter({required this.fill, required this.edge, required this.edgeWidth, required this.isUp});

  final Color fill;
  final Color edge;
  final double edgeWidth;
  final bool isUp;

  @override
  void paint(Canvas canvas, Size size) {
    final baseY = isUp ? size.height : 0.0;
    final tipY = isUp ? 0.0 : size.height;
    final sides = Path()
      ..moveTo(0, baseY)
      ..lineTo(size.width / 2, tipY)
      ..lineTo(size.width, baseY);
    canvas.drawPath(Path.from(sides)..close(), Paint()..color = fill);
    canvas.drawPath(
      sides,
      Paint()
        ..color = edge
        ..style = PaintingStyle.stroke
        ..strokeWidth = edgeWidth
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_ArrowPainter oldDelegate) =>
      oldDelegate.fill != fill ||
      oldDelegate.edge != edge ||
      oldDelegate.edgeWidth != edgeWidth ||
      oldDelegate.isUp != isUp;
}

/// The hint: the step's text on paper and a Skip button. A tap anywhere on the
/// box but Skip goes on to the next step.
class _HintBox extends StatelessWidget {
  const _HintBox({required this.text, required this.onTap, required this.onSkip});

  final String text;
  final VoidCallback onTap;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    final touchTarget = math.max(coachMinTouchTargetDp, look.sizes.buttonHeight);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: ToyCard(
        popIn: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: touchTarget),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(text, style: look.type.body.copyWith(color: look.colors.ink)),
              const SizedBox(height: ToySizes.space8),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  style: TextButton.styleFrom(
                    minimumSize: Size(touchTarget, touchTarget),
                    foregroundColor: look.colors.ink,
                  ),
                  onPressed: onSkip,
                  child: Text(HomeText.skip, style: look.type.button.copyWith(color: look.colors.ink)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
