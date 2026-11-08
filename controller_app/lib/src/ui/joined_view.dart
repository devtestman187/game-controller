import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_kit/game_kit.dart';
import 'package:party_host/party_host.dart' as party;

import '../gyro.dart';
import '../layout.dart';
import '../providers.dart';
import '../sticks.dart';
import 'pad_widgets.dart';
import 'top_bar_metrics.dart';

/// Where the game [JoinedView] draws must keep clear, in a screen of [box]: the
/// left hand's controls as [mode] draws them, in the screen's px, passed to the
/// game through [FrameView.padRects] (m12-opponent-mirror rule 3, code-health
/// N4).
///
/// The pad's layout is this app's ([padLayout], [stickLayout]) and a game
/// can't import it, so the app says where the controls are. D-pad mode passes
/// the D-pad's four arms — its square's corners are empty, and the game uses
/// them as it does today; stick mode passes the left stick's disc (its zone
/// while a floating stick may be anywhere) and the D-pad's arms; gyro mode
/// draws the tilt view anywhere in its area, so the whole area counts.
List<Rect> leftPadRects(
  Size box, {
  required PadMode mode,
  required double mm,
  StickSettings sticks = const StickSettings(),
}) {
  // The pad is laid out in the body, below the bar the game shows through.
  final body = Size(box.width, box.height - topBarHeightPx);
  if (body.width <= 0 || body.height <= 0) return const [];
  final bar = Offset(0, topBarHeightPx);
  List<Rect> arms(Rect dpad) => [for (final (_, arm) in dpadArms(dpad.width)) arm.shift(dpad.topLeft + bar)];
  switch (mode) {
    case PadMode.dpad:
      return arms(padLayout(body, mm: mm).dpad);
    case PadMode.sticks:
      final layout = stickLayout(body, mm: mm, buttonSize: sticks.buttonSize);
      return [(sticks.floating ? layout.leftZone : layout.leftStick).shift(bar), ...arms(layout.dpad)];
    case PadMode.gyro:
      return [padLayout(body, mm: mm).leftArea.shift(bar)];
  }
}

/// The game the host shows this phone (m12 §5), drawn behind this phone's own
/// controls: the frames the client receives, and each frame's sounds played
/// by the party sound player. The waiting card sits over it while the host is
/// away or the link is down (m12-joined-view §0.3); the last frame it drew
/// stays under the card until the link is back or the player leaves.
///
/// Shown only while the host shows a view, and nothing at all while it shows
/// none, so a phone joined to a host that sends it no game keeps its
/// controller screen.
class JoinedView extends ConsumerStatefulWidget {
  const JoinedView({super.key});

  @override
  ConsumerState<JoinedView> createState() => _JoinedViewState();
}

class _JoinedViewState extends ConsumerState<JoinedView> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // iOS stops the app's sound while it is hidden, when the phone locks or
    // another app takes it, and the engine doesn't come back by itself: start
    // it again when the app is shown, as the host route does (s5c). Only a
    // game shown here plays through that engine.
    _lifecycle = AppLifecycleListener(onShow: _onShown);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  void _onShown() {
    if (ref.read(viewActiveProvider)) unawaited(ref.read(party.soundPlayerProvider).restart());
  }

  @override
  Widget build(BuildContext context) {
    final client = ref.watch(clientProvider);
    final stats = client.viewerStats;
    // A client without the view capability is sent no frames and measures
    // nothing (m12 §4), so there is nothing to draw or measure.
    if (stats == null) return const SizedBox.shrink();
    final mode = ref.watch(gyroProvider.select((g) => g.mode));
    final sticks = ref.watch(stickSettingsProvider);
    final mm = ref.watch(pxPerMmProvider);
    // A dropped link ended the view ([viewActiveProvider]), but its last frame
    // stays under the card until the link is back or the player leaves: the
    // card then covers the game they played last (m12-joined-view §0.3).
    final drawn = ref.watch(viewActiveProvider) || ref.watch(hostWaitProvider) != null;
    // The whole safe area, which is the box the game draws in: the pad's
    // controls are measured in the same box, so the game keeps clear of where
    // they are (m12-opponent-mirror rule 3).
    return LayoutBuilder(
      builder: (context, window) => Stack(
        fit: StackFit.expand,
        children: [
          // The view stays mounted while none is on, so it hears the start
          // that turns one on: it draws nothing itself until then. Keeping it
          // off the screen and its ticker quiet is all this does.
          Visibility(
            visible: drawn,
            maintainState: true,
            child: FrameView(
              views: client.view,
              registry: ref.watch(gameRegistryProvider),
              stats: stats,
              // The client's clock is the one frame arrivals are taken on (D3).
              nowMs: () => client.nowMs,
              playerId: ref.watch(identityProvider).controllerId,
              // A tablet has the room for both sides of a phones match (m12-
              // phone-layout §0.6); a phone draws its own.
              wholeMatch: ref.watch(isTabletProvider),
              padRects: leftPadRects(window.biggest, mode: mode, mm: mm, sticks: sticks),
              // The screen's own density: the game keeps the other side's
              // mirror's marks at a physical size by it (rule 7).
              pxPerMm: mm,
              onSounds: (names) => _play(ref, names),
            ),
          ),
        ],
      ),
    );
  }

  /// A frame's sounds, through the player the host screens use (m12 §0.2):
  /// the phone app has no other sound player.
  void _play(WidgetRef ref, List<String> names) {
    final player = ref.read(party.soundPlayerProvider);
    for (final name in names) {
      player.play(name);
    }
  }
}
