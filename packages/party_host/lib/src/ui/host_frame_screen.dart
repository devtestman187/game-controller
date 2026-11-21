import 'package:flutter/material.dart';
import 'package:toy_look/toy_look.dart';

import '../text/host_text.dart';
import 'host_focus_ring.dart';

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
/// The footer sits on the look's paper, with an ink line above it (the look's
/// "footer bar", M16 phonehost2 S3): the way-on buttons stand on a band of
/// their own rather than on the sky, so they read as the screen's end wherever
/// the body stops. The header shows the phone's or remote's way back — a back
/// arrow that pops the route — only while there is a route to go back to, as
/// the title bar's arrow always did (m12 bug 1107f rule C).
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

/// The header's one row (DESIGN section 1, rule 5): the way back, the title on
/// the left in the frame's title type on the background, and the screen's chip
/// at the right end. A title too long for the room the arrow and the chip leave
/// is ellipsised, so a long screen name never pushes either off the frame.
///
/// The row keeps the title bar's key, so a finder that looked for the old
/// title bar's row finds this one on a screen the frame now draws.
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
        key: const Key('hostTitleBar'),
        children: [
          if (Navigator.of(context).canPop()) ...[
            _FrameBackButton(color: colors.onBackground),
            const SizedBox(width: ToySizes.space8),
          ],
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

/// The way back out of a screen the frame draws, at the header's left end: the
/// title bar's arrow (key `hostTitleBarBack`, m12 bug 1107f rule C) in the
/// look's ink on the background, with the host's focus ring around it, popping
/// the route it is in.
class _FrameBackButton extends StatelessWidget {
  const _FrameBackButton({required this.color});

  /// The arrow's colour: the look's ink on the frame's background.
  final Color color;

  @override
  Widget build(BuildContext context) => HostFocusRing(
    child: IconButton(
      key: const Key('hostTitleBarBack'),
      tooltip: HostText.back,
      color: color,
      icon: const Icon(Icons.arrow_back),
      onPressed: () => Navigator.of(context).maybePop(),
    ),
  );
}

/// The footer's one row on the look's paper band (key `hostFrameFooterBand`):
/// a line of ink along its top, then the screen's buttons at the right end, in
/// the order given, with the look's room between them.
///
/// The band is what makes the footer read as the screen's end (DESIGN section
/// 1, rule 5: "the footer bar"): the body's sky stops at its ink line, and the
/// way-on buttons stand on paper wherever the body ends.
///
/// Each button is [Flexible], so two buttons that together want more room than
/// the frame has give room to each other instead of overflowing it: a button's
/// label is ellipsised, which the look's [ToyButton] already does.
///
/// The ink line's width is padding above the row and the same below it, so the
/// buttons stand centred in the band under the line: a 64 px button has 10
/// frame px above it and 10 below, with the TV look's 4 px line (brief fB).
class _FrameFooter extends StatelessWidget {
  const _FrameFooter({required this.buttons});

  final List<Widget> buttons;

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    final edge = BorderSide(color: look.colors.ink, width: look.sizes.outlineWidth);
    return DecoratedBox(
      key: const Key('hostFrameFooterBand'),
      decoration: BoxDecoration(
        color: look.colors.paper,
        border: Border(top: edge),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: hostFrameGutterPx, vertical: edge.width),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            for (var i = 0; i < buttons.length; i++) ...[
              if (i > 0) const SizedBox(width: ToySizes.space16),
              Flexible(child: buttons[i]),
            ],
          ],
        ),
      ),
    );
  }
}
