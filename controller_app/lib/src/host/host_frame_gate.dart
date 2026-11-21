import 'package:flutter/widgets.dart';
import 'package:party_host/party_host.dart' as party;

import '../ui/top_bar_metrics.dart';

/// The phone app's way into the host's frame (M16 phonehost2 wph, DESIGN
/// section 2): the host's screens are laid out in the 960x540 frame, while
/// this phone's own bar and, over a round, its pad stay in device pixels.
///
/// The app's one `MaterialApp` draws both the pad's screens and the host's, so
/// [party.HostFrame] cannot sit above the app (s1-report.md:47-55): the pad is
/// this phone's own, drawn at its device sizes, and scaling it would move every
/// thumb target (DESIGN risk 5). It wraps `HostGames`'s navigator instead, so
/// only the host's screens are in the frame; the bar and the controls are
/// above the navigator in the controller's stack and never meet it.
///
/// The phone's bar covers the top [topBarHeightPx] of the safe area, so the
/// frame lies below it: the frame's [MediaQuery] is the room that is left,
/// whose scale is `min(W/960, (H - bar)/540)` (852x393: 0.63148, the frame
/// 1349.2x540; 640x360: 0.57037, the frame 1122.1x540). The strip above the
/// frame is filled with the look's background, so the sky the bar shows
/// through it ends at a line that reads as the bar's rather than as a gap.
class HostFrameGate extends StatelessWidget {
  const HostFrameGate({super.key, required this.child});

  /// The host's screens, laid out in the frame and drawn scaled below the bar.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = party.ToyLookScope.maybeOf(context)?.colors;
    return LayoutBuilder(
      builder: (context, box) {
        final room = Size(box.maxWidth, box.maxHeight - topBarHeightPx);
        return Column(
          children: [
            SizedBox(
              width: double.infinity,
              height: topBarHeightPx,
              // With no look above there is nothing to paint with: the sky the
              // bar shows through stays, as it was before the frame.
              child: colors == null ? null : ColoredBox(key: const Key('hostFrameBarStrip'), color: colors.background),
            ),
            Expanded(
              child: room.width <= 0 || room.height <= 0
                  ? const SizedBox.shrink()
                  // The insets are already claimed by the controller's SafeArea
                  // around this gate, so the frame's screens must not claim
                  // them again; HostFrame divides by the scale what is left.
                  : MediaQuery(
                      data: MediaQuery.of(context)
                          .copyWith(size: room, padding: EdgeInsets.zero, viewPadding: EdgeInsets.zero),
                      child: party.HostFrame(child: child),
                    ),
            ),
          ],
        );
      },
    );
  }
}
