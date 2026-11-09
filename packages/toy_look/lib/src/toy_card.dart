import 'package:flutter/material.dart';

import 'toy_look.dart';
import 'toy_look_scope.dart';
import 'toy_shape.dart' show toyShadowAlpha;
import 'toy_sizes.dart';

/// A card in the look (design section 4): cream paper with the ink edge, the
/// hard shadow and 16 px corners, an optional coloured header band, and a
/// pop-in when it first appears if effects are on and motion isn't reduced.
///
/// What it holds is ink text, because paper is a screen of its own: the theme
/// below it turns the text and the list tiles to ink, so a card on Night's
/// grape background keeps its dark text (Claude's step 2a review).
class ToyCard extends StatefulWidget {
  const ToyCard({
    super.key,
    required this.child,
    this.header,
    this.headerColor,
    this.headerKey,
    this.padding = const EdgeInsets.all(ToySizes.space16),
    this.popIn = true,
    this.scrollBody = false,
  });

  /// What the card holds, under [padding] and in ink.
  final Widget child;

  /// The header band's title, or no band when null.
  final String? header;

  /// The band's fill, or the palette's focus yellow.
  final Color? headerColor;

  /// The header text's key, for a screen whose title a test or a player looks
  /// up by name (the results).
  final Key? headerKey;

  /// The room around [child].
  final EdgeInsets padding;

  /// Whether the card pops in when it first appears; the effects setting also
  /// has to be on, and the device must not ask for reduced motion (design D8).
  final bool popIn;

  /// Whether [child] scrolls when the card is shorter than it is (M13 3b, the
  /// join screen's sides): a card in a layout that gives it a height, like a
  /// panel under the phone's own bar. The card has to be given a bounded
  /// height, as a column's child is not; without one the scroll has nothing to
  /// shrink into.
  final bool scrollBody;

  @override
  State<ToyCard> createState() => _ToyCardState();
}

class _ToyCardState extends State<ToyCard> with SingleTickerProviderStateMixin {
  /// The pop-in's length (design section 4).
  static const _popDuration = Duration(milliseconds: 180);

  /// Where the pop-in starts and ends: a little smaller, then full size with a
  /// small overshoot from [Curves.easeOutBack].
  static const _popFrom = 0.9;
  static const _popTo = 1.0;

  late final AnimationController _pop = AnimationController(vsync: this, duration: _popDuration);
  late final CurvedAnimation _popCurve = CurvedAnimation(parent: _pop, curve: Curves.easeOutBack);
  late final Animation<double> _scale = Tween<double>(begin: _popFrom, end: _popTo).animate(_popCurve);

  /// Whether the first build has decided about the pop-in, so a later look
  /// change doesn't start it again.
  bool _isStarted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isStarted) return;
    _isStarted = true;
    final motion = ToyLookScope.of(context).effects && !MediaQuery.disableAnimationsOf(context);
    if (widget.popIn && motion) {
      _pop.forward();
    } else {
      _pop.value = 1;
    }
  }

  @override
  void dispose() {
    _popCurve.dispose();
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    return AnimatedBuilder(
      animation: _pop,
      builder: (context, card) => Transform.scale(scale: _scale.value, child: card),
      child: _card(look),
    );
  }

  /// The card: the shadow behind, the clipped paper with its band and body,
  /// and the ink edge over all of it so the band's corners stay inside it.
  ///
  /// The paper takes the width the card is given, as a [Stack]'s passthrough
  /// does, so a card in a list or a side of the join screen fills it (M13 3b);
  /// with room to choose, it is as wide as its widest part.
  Widget _card(ToyLook look) {
    final header = widget.header;
    return Stack(
      fit: StackFit.passthrough,
      children: [
        Positioned.fill(
          child: Transform.translate(
            offset: ToySizes.shadowOffset,
            child: DecoratedBox(decoration: _shadow(look)),
          ),
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(ToySizes.cardCorner),
          child: ColoredBox(
            color: look.colors.paper,
            // As wide as the widest part, and the band stretched to it, so the
            // band runs across the whole top of the card.
            child: IntrinsicWidth(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [if (header != null) _header(look, header), _bodyArea(look)],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(child: DecoratedBox(decoration: _edge(look))),
        ),
      ],
    );
  }

  /// What the card holds, on its padding: in a scroll view that takes the room
  /// left under the header band when [ToyCard.scrollBody] is set, so a card
  /// shorter than its content scrolls rather than overflowing.
  Widget _bodyArea(ToyLook look) {
    final body = Padding(padding: widget.padding, child: _body(look));
    if (!widget.scrollBody) return body;
    return Flexible(child: SingleChildScrollView(child: body));
  }

  /// The header band: [ToyCard.headerColor] (or focus), its title in ink and
  /// an ink line under it.
  Widget _header(ToyLook look, String header) {
    final colors = look.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: widget.headerColor ?? colors.focus,
        border: Border(
          bottom: BorderSide(color: colors.ink, width: look.sizes.outlineWidth),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: ToySizes.space16, vertical: ToySizes.space8),
        child: Text(
          header,
          key: widget.headerKey,
          textAlign: TextAlign.center,
          style: look.type.button.copyWith(color: colors.ink),
        ),
      ),
    );
  }

  /// What the card holds: ink text with the look's body type, and ink list
  /// tiles, whatever the screen behind it says.
  Widget _body(ToyLook look) {
    final theme = Theme.of(context);
    final ink = look.colors.ink;
    return Theme(
      data: theme.copyWith(
        textTheme: theme.textTheme.apply(bodyColor: ink, displayColor: ink),
        listTileTheme: ListTileThemeData(textColor: ink, iconColor: ink),
      ),
      child: DefaultTextStyle.merge(
        style: look.type.body.copyWith(color: ink),
        child: widget.child,
      ),
    );
  }

  BoxDecoration _shadow(ToyLook look) => BoxDecoration(
    color: look.colors.ink.withValues(alpha: toyShadowAlpha),
    borderRadius: BorderRadius.circular(ToySizes.cardCorner),
  );

  /// The ink edge over the paper, drawn last so the band cannot cross it.
  ShapeDecoration _edge(ToyLook look) => ShapeDecoration(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(ToySizes.cardCorner),
      side: BorderSide(color: look.colors.ink, width: look.sizes.outlineWidth),
    ),
  );
}
