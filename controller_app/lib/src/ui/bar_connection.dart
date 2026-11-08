import 'package:connection/connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:party_host/party_host.dart' show PhoneText, ToyLook, ToyLookScope, ToySizes;

import '../providers.dart';
import 'connect_screen.dart';
import 'labels.dart';
import 'status_panel.dart';

/// The bar's left side in controller mode: your player number, the connection
/// and its ping, or the game's status panel (P6, C24).
class BarConnection extends ConsumerWidget {
  const BarConnection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.watch(clientStateProvider);
    final look = ToyLookScope.of(context);
    final stats = client.rttStats;
    final status = ref.watch(gameStatusProvider);
    final label = look.type.body.copyWith(color: look.colors.onBackground);
    // While a game shows on this phone the game draws its own status (m12
    // §2.7), so the panel stays out of the bar and the ping shows instead.
    final gameShown = ref.watch(showsGameProvider);
    return Row(
      children: [
        if (client.isConnected && client.player != null) ...[
          PlayerBadge(number: client.player!),
          const SizedBox(width: ToySizes.space8),
        ],
        Flexible(
          child: ActionChip(
            key: const Key('connectionChip'),
            avatar: const ConnectionDot(),
            labelStyle: label,
            label: Text(
              client.isConnected
                  ? PhoneText.linkWithPing(client.hostLabel, client.rttMs)
                  : ref.watch(demoProvider)
                  ? PhoneText.demoLink
                  : PhoneText.tapToConnect(statusLabel(client)),
              overflow: TextOverflow.ellipsis,
            ),
            onPressed: () => openConnect(context),
          ),
        ),
        // The game's status panel takes the ping's place (P6, C24).
        if (client.isConnected && !gameShown && !status.isHidden) ...[
          const SizedBox(width: ToySizes.space8),
          Flexible(child: StatusPanel(status: status)),
        ] else if (client.isConnected && stats != null) ...[
          const SizedBox(width: ToySizes.space8),
          Flexible(
            child: Text(
              PhoneText.pingStats(stats.minMs, stats.avgMs, stats.maxMs),
              key: const Key('pingStats'),
              style: label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );
  }
}

/// The bar's left side over a game (m12-phone-layout §0.7b): the own player
/// and the link's dot alone. The host's name, the ping and the status panel
/// would cover the game's own HUD, so they stay out of the compact bar.
///
/// The dot is a button to the Connect screen (m12-joined-view §0.3): a phone
/// that plays a host's game can always leave it, not only while it waits.
class CompactConnection extends ConsumerWidget {
  const CompactConnection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(clientStateProvider.select((s) => s.player));
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (player != null) ...[PlayerBadge(number: player), const SizedBox(width: ToySizes.space8)],
        IconButton(
          key: const Key('connectionButton'),
          tooltip: PhoneText.connection,
          icon: const ConnectionDot(key: Key('connectionDot')),
          onPressed: () => openConnect(context),
        ),
      ],
    );
  }
}

/// The link's state as a dot (P6, M13 3c): the chip's avatar, on its own in
/// the compact bar. A badge's disc, in the state's colour with the look's ink
/// edge, so the bar's text never changes colour with the link.
class ConnectionDot extends ConsumerWidget {
  const ConnectionDot({super.key});

  /// The dot's diameter, the size the chip's avatar always drew.
  static const dotSize = LinkDot.dotSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(clientStateProvider.select((s) => s.status));
    return LinkDot(status: status);
  }
}

/// The link's dot for a [status] the caller already has, as the Connect
/// screen's chip draws it beside its word.
class LinkDot extends StatelessWidget {
  const LinkDot({super.key, required this.status});

  final ClientStatus status;

  /// The dot's diameter, the size the chip's avatar always drew.
  static const dotSize = 12.0;

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    return CustomPaint(
      size: const Size.square(dotSize),
      painter: LinkDotPainter(look: look, color: linkDotColor(look, status)),
    );
  }
}

/// A link's state as a colour (M13 3c, rule 4): good when connected, caution
/// on the way, focus for a code to enter, and paper when there is no link (a
/// faded ink dot was lost on the Night sky, Claude's review).
Color linkDotColor(ToyLook look, ClientStatus status) => switch (status) {
  ClientStatus.connected => look.colors.good,
  ClientStatus.reconnecting || ClientStatus.connecting || ClientStatus.pairing => look.colors.caution,
  ClientStatus.waitingForCode => look.colors.focus,
  ClientStatus.idle || ClientStatus.failed => look.colors.paper,
};

/// Paints [LinkDot]: the state's disc with the look's ink edge, as a badge is
/// drawn, so a dot reads on the pad and on the sky alike.
class LinkDotPainter extends CustomPainter {
  const LinkDotPainter({required this.look, required this.color});

  /// The look whose edge colour and width the dot is drawn with.
  final ToyLook look;

  /// The state's fill.
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - look.sizes.outlineWidth / 2;
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = look.sizes.outlineWidth
      ..color = look.colors.ink;
    canvas
      ..drawCircle(centre, radius, Paint()..color = color)
      ..drawCircle(centre, radius, edge);
  }

  @override
  bool shouldRepaint(LinkDotPainter oldDelegate) => oldDelegate.look != look || oldDelegate.color != color;
}

/// "P1" in the player's colour, matching the sprite and the badge on the TV.
class PlayerBadge extends StatelessWidget {
  const PlayerBadge({super.key, required this.number});

  final int number;

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    return Tooltip(
      message: PhoneText.youArePlayer(number),
      child: Container(
        key: const Key('playerBadge'),
        padding: const EdgeInsets.symmetric(horizontal: ToySizes.space8, vertical: ToySizes.space4),
        decoration: BoxDecoration(
          color: look.colors.player(number),
          borderRadius: BorderRadius.circular(ToySizes.space12),
        ),
        child: Text(PhoneText.playerShort(number), style: look.type.body.copyWith(color: look.colors.ink)),
      ),
    );
  }
}
