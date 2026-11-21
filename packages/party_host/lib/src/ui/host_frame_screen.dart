import 'package:flutter/material.dart';
import 'package:toy_look/toy_look.dart';

/// The frame's header, in frame px (DESIGN section 1, rule 5): the screen's
/// title on the left and its round or state chip on the right, the same on
/// every screen, so the chip's place never moves.
const hostFrameHeaderHeightPx = 64.0;

/// The frame's footer, in frame px (DESIGN section 1, rule 5): the way-on
/// button(s) at the right end, always on screen, never inside a scrollable.
const hostFrameFooterHeightPx = 84.0;

/// The room a frame screen keeps from the frame's edges, in frame px (DESIGN
/// section 1, rule 4): a card fills the stage minus this gutter.
const hostFrameGutterPx = 24.0;

/// A host screen drawn in the frame (M16 phonehost1 S2, DESIGN section 1,
/// rule 5): a [hostFrameHeaderHeightPx] header, the body that takes the rest,
/// and a [hostFrameFooterHeightPx] footer.
///
/// The body is the screen's only [Expanded] region, so it is the only part
/// that flexes when the frame is taller than 16:9 (a tablet's 180 px of extra
/// height, a laptop's 60), and the only part that may hold a list. The footer
/// is a plain child of the column: whatever the body does, the way-on buttons
/// stay at the bottom of the frame, where a thumb reaches them.
///
/// The design draws no host screen per device (rule 1): [title], the header's
/// [trailing] chip, the body and the footer's buttons are all the screen needs
/// to say, and the frame's scale makes them fit every one.
///
/// The column is in a [SafeArea], so this scaffold claims the device's insets
/// once for every screen (a notched phone's top strip, a home bar's bottom):
/// the header starts under the notch and the footer stops above the home bar,
/// the 64 and 84 px are the room the content has, and the insets add room
/// outside them ([HostFrame] divides them by the scale, so they cover the same
/// strip of the screen). Without one the insets are zero and nothing changes.
class HostFrameScreen extends StatelessWidget {
  const HostFrameScreen({super.key, required this.title, this.trailing, required this.body, this.footer = const []});

  /// The screen's title, at the header's left in the frame's title type.
  final String title;

  /// The chip at the header's right end (a `RoundSegment`, a status pill), or
  /// null for a screen with nothing to say there.
  final Widget? trailing;

  /// The screen's content, under the header and above the footer: the only
  /// region that flexes, and the only one that may scroll.
  final Widget body;

  /// The way-on button(s) at the footer's right end, in the order they show.
  /// They are never in a scrollable, so they are always on screen.
  final List<Widget> footer;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              key: const Key('hostFrameHeader'),
              height: hostFrameHeaderHeightPx,
              child: _FrameHeader(title: title, trailing: trailing),
            ),
            Expanded(
              key: const Key('hostFrameBody'),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: hostFrameGutterPx),
                child: body,
              ),
            ),
            SizedBox(
              key: const Key('hostFrameFooter'),
              height: hostFrameFooterHeightPx,
              child: _FrameFooter(buttons: footer),
            ),
          ],
        ),
      ),
    );
  }
}

/// The header's one row (DESIGN section 1, rule 5): the title on the left, in
/// the frame's title type on the background, and the screen's chip at the
/// right end. A title too long for the room the chip leaves is ellipsised, so
/// a long screen name never pushes the chip off the frame.
class _FrameHeader extends StatelessWidget {
  const _FrameHeader({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = ToyLookScope.of(context).colors;
    final trailing = this.trailing;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: hostFrameGutterPx),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: ToyType.frame.title.copyWith(color: colors.onBackground),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: ToySizes.space16), trailing],
        ],
      ),
    );
  }
}

/// The footer's one row: the screen's buttons at the right end, in the order
/// given, with the look's room between them.
///
/// Each button is [Flexible], so two buttons that together want more room than
/// the frame has give room to each other instead of overflowing it: a button's
/// label is ellipsised, which the look's [ToyButton] already does.
class _FrameFooter extends StatelessWidget {
  const _FrameFooter({required this.buttons});

  final List<Widget> buttons;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: hostFrameGutterPx),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          for (var i = 0; i < buttons.length; i++) ...[
            if (i > 0) const SizedBox(width: ToySizes.space16),
            Flexible(child: buttons[i]),
          ],
        ],
      ),
    );
  }
}
