import 'package:flutter/widgets.dart';

import 'toy_look.dart';
import 'toy_look_scope.dart';
import 'toy_sizes.dart';

/// How much of its label's size the pill gives the line the label sits in:
/// Nunito's line is about a fifth taller than its size, so the label is never
/// cut by the stadium round it.
const toyPillLineShare = 1.25;

/// A status pill in the look (M13 3c, design section 4): a stadium of [fill]
/// with the ink edge, its label in ink at the body's size in the button's
/// family and weight, [ToySizes.space8] either side of it and
/// [ToySizes.space4] above and below, and no shadow.
///
/// It's a small flat chip that says what a thing is or how it is going (the
/// TV's controllers panel, a link's state) rather than something to press:
/// text on a fill is always ink (design D12), never white, so the pill reads
/// in both palettes.
class ToyPill extends StatelessWidget {
  const ToyPill({super.key, required this.label, required this.fill, this.icon});

  /// What the pill says, in ink.
  final String label;

  /// The stadium's fill, the token for the pill's meaning.
  final Color fill;

  /// An icon before the label, in ink.
  final IconData? icon;

  /// How tall a pill of [look] is: its label's line and the room round it.
  static double heightOf(ToyLook look) =>
      look.type.body.fontSize! * toyPillLineShare + ToySizes.space4 * 2 + look.sizes.outlineWidth;

  /// The label's style: the body's size in the button's family and weight, in
  /// ink (design D12). A style's family carries its package, so the button's
  /// own style is copied rather than named again.
  static TextStyle labelStyle(ToyLook look) {
    final type = look.type;
    return type.button.copyWith(fontSize: type.body.fontSize, color: look.colors.ink);
  }

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    final style = labelStyle(look);
    final icon = this.icon;
    return SizedBox(
      height: heightOf(look),
      child: CustomPaint(
        painter: ToyPillPainter(look: look, fill: fill),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: ToySizes.space8, vertical: ToySizes.space4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: style.fontSize, color: look.colors.ink),
                const SizedBox(width: ToySizes.space4),
              ],
              Flexible(
                child: Text(label, style: style, maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// What [ToyPill] draws: the stadium of its fill, and the ink edge inside the
/// pill's box so the whole look stays in the room it is given.
class ToyPillPainter extends CustomPainter {
  const ToyPillPainter({required this.look, required this.fill});

  /// The look the pill is drawn in.
  final ToyLook look;

  /// The stadium's fill.
  final Color fill;

  /// The stadium, filling [size] inside the ink edge's own half width.
  Path pill(Size size) {
    final rect = (Offset.zero & size).deflate(look.sizes.outlineWidth / 2);
    return Path()..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(rect.height / 2)));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final pill = this.pill(size);
    canvas.drawPath(pill, Paint()..color = fill);
    canvas.drawPath(
      pill,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = look.sizes.outlineWidth
        ..color = look.colors.ink,
    );
  }

  @override
  bool shouldRepaint(ToyPillPainter oldDelegate) => oldDelegate.look != look || oldDelegate.fill != fill;
}
