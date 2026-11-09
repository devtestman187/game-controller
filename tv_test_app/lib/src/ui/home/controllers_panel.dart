import 'package:connection/connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:party_host/party_host.dart';

import '../../tv_text.dart';
import '../input_visualizer.dart';
import '../status_line.dart';
import 'panel.dart';

/// The paired and connected phones, each with its state and live input, and
/// the button that forgets the ones that are gone.
class ControllersPanel extends ConsumerWidget {
  const ControllersPanel({super.key, required this.state});

  final HostViewState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controllers = state.host.controllers;
    final connected = state.host.connected.length;
    final anyGone = controllers.any((c) => c.state != ControllerState.connected);
    return Panel(
      title: TvText.controllers(connected),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          HostButton(
            label: TvText.forgetPhones,
            compact: true,
            onPressed: anyGone
                ? () {
                    final n = ref.read(hostServiceProvider).forgetPairings();
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(TvText.forgot(n))));
                  }
                : null,
          ),
        ],
      ),
      child: controllers.isEmpty
          ? Center(child: Text(TvText.noControllers, textAlign: TextAlign.center))
          : ListView.separated(
              shrinkWrap: true,
              itemCount: controllers.length,
              separatorBuilder: (_, _) => const SizedBox(height: ToySizes.space8),
              itemBuilder: (context, i) => ControllerTile(info: controllers[i]),
            ),
    );
  }
}

/// One controller: who it is, what it does, and its ping. It is a sheet of
/// paper with the ink edge inside the panel's, so two of them read apart.
class ControllerTile extends StatelessWidget {
  const ControllerTile({super.key, required this.info});

  /// From this width up the input picture takes its larger size. The TV's own
  /// tile (about 550 across at 960 x 540) keeps the smaller one, which is what
  /// leaves the name and the state their room (M13 3d).
  static const wideWidth = 640.0;

  /// The smaller picture, sized for a tile in the TV's home.
  static const pictureWidth = 150.0;

  /// The larger picture, for a window with room to spare.
  static const widePictureWidth = 210.0;

  /// How wide the ping's column is, in the body type's size: room for "max
  /// 140 ms" on one line at the look's type (a fixed 126 px broke it at the
  /// TV's, Claude's 3d review).
  static const _latencyWidthShare = 6.0;

  /// The player's badge: smaller than the look's, so a tile keeps its height.
  static const _badgeDiameter = 30.0;

  /// The platform icon, for a controller that isn't a player yet.
  static const _platformIconSize = 28.0;

  final ControllerInfo info;

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    final colors = look.colors;
    final live = info.state == ControllerState.connected;
    return LayoutBuilder(
      builder: (context, constraints) => DecoratedBox(
        decoration: ShapeDecoration(
          color: colors.paper,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ToySizes.cardCorner),
            side: BorderSide(color: colors.ink, width: look.sizes.outlineWidth),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: ToySizes.space8, vertical: ToySizes.space4),
          child: Row(
            children: [
              if (live && info.player != null)
                ToyBadge(key: Key('player-${info.controllerId}'), number: info.player!, diameter: _badgeDiameter)
              else
                Icon(_platformIcon(info.platform), size: _platformIconSize, color: colors.ink),
              const SizedBox(width: ToySizes.space8),
              Expanded(child: _ControllerDetails(info: info)),
              const SizedBox(width: ToySizes.space8),
              InputVisualizer(
                key: Key('visualizer-${info.controllerId}'),
                gamepad: live ? GamepadState.fromInput(info.input) : null,
                width: constraints.maxWidth < wideWidth ? pictureWidth : widePictureWidth,
              ),
              const SizedBox(width: ToySizes.space8),
              SizedBox(
                width: ToyLookScope.of(context).type.body.fontSize! * _latencyWidthShare,
                child: _ControllerLatency(info: info),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The phone's icon by its platform.
IconData _platformIcon(String platform) => switch (platform) {
  'ios' => Icons.phone_iphone,
  'android' => Icons.phone_android,
  'sim' => Icons.smart_toy_outlined,
  _ => Icons.devices_other,
};

/// Who the controller is and what it is doing, including the live tilt and
/// sticks.
class _ControllerDetails extends StatelessWidget {
  const _ControllerDetails({required this.info});

  final ControllerInfo info;

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    final colors = look.colors;
    final (label, color) = switch (info.state) {
      ControllerState.connected => (TvText.connected, colors.good),
      ControllerState.pairing => (TvText.waitingForCode, colors.focus),
      ControllerState.disconnected => (TvText.disconnected, colors.bad),
    };
    final live = info.state == ControllerState.connected;
    final gamepad = GamepadState.fromInput(info.input);
    final soft = look.type.body.copyWith(color: colors.inkSoft);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          info.name,
          style: look.type.body.copyWith(color: colors.ink),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        // The host phone's own player has no address to show (M12).
        Text(
          [info.platform, info.appVersion, ?info.remoteAddress].join(' · '),
          style: soft,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        // The state is the dot's colour and the words are ink (M13 3d).
        StatusLine(label: label, color: color),
        // The values follow the phone's mode, as the host says them.
        if (live && gamepad.mode == InputMode.gyro)
          Text(HostText.gamepadValues(gamepad), key: Key('tilt-${info.controllerId}'), style: soft),
        if (live && gamepad.mode == InputMode.sticks)
          Text(HostText.gamepadValues(gamepad), key: Key('sticks-${info.controllerId}'), style: soft),
      ],
    );
  }
}

/// The ping, its average and worst, and the input delay, of one controller.
class _ControllerLatency extends StatelessWidget {
  const _ControllerLatency({required this.info});

  final ControllerInfo info;

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    final colors = look.colors;
    final soft = look.type.body.copyWith(color: colors.inkSoft);
    final live = info.state == ControllerState.connected;
    final rtt = info.rttMs;
    final stats = info.rttStats;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          live && rtt != null ? TvText.ping(rtt) : HostText.dash,
          style: look.type.button.copyWith(color: colors.ink, fontFeatures: const [FontFeature.tabularFigures()]),
        ),
        if (live && stats != null) ...[
          Text(TvText.pingAverage(stats.avgMs), style: soft),
          Text(TvText.pingWorst(stats.maxMs), style: soft),
        ],
        if (live && info.inputLatency != null)
          Text(TvText.inputDelay(info.inputLatency!.avgMs), key: Key('inputLatency-${info.controllerId}'), style: soft),
      ],
    );
  }
}
