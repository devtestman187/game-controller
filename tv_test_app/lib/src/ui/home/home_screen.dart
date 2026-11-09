import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:party_host/party_host.dart';

import '../../tv_text.dart';
import '../haptic_panel_screen.dart';
import '../latency_screen.dart';
import '../shader_spike_screen.dart';
import 'controllers_panel.dart';
import 'first_launch_consent.dart';
import 'log_panel.dart';
import 'pairing_panel.dart';

/// The TV's main screen: pairing code, addresses, connected controllers with
/// live ping, and the log. Works with a TV remote and in a laptop window.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  /// From this window width and height up, the panels sit side by side as on
  /// a TV; below one of them they stack and scroll, as on a small laptop.
  static const wideWidth = 720.0;
  static const wideHeight = 420.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(hostStateProvider);
    // Keeps the screen on while controllers are connected.
    ref.watch(keepAwakeProvider);
    // Plays the games' sounds, and the phone-joined cue (M13 section 8).
    ref.watch(gameSoundsProvider);
    ref.watch(playerJoinedProvider);
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => constraints.maxWidth >= wideWidth && constraints.maxHeight >= wideHeight
              ? _WideHome(state: state)
              : _NarrowHome(state: state),
        ),
      ),
    );
  }
}

/// A TV or a large window: the header over two columns, the pairing code and
/// the log at the left and the controllers at the right.
///
/// The controllers take the wider column (M13 3d): a tile at the TV's type
/// needs about 550 for the name, the state, the input picture and the ping,
/// and the panel holds two of them in full at 960 x 540. The log moved under
/// the pairing code, where its lines are a tester's footnote; the pairing
/// code is what a player reads from the couch, so it keeps the left column's
/// top.
class _WideHome extends StatelessWidget {
  const _WideHome({required this.state});

  /// How the row splits: the pairing panel's share, then the controllers'.
  static const _pairingShare = 5;
  static const _controllersShare = 8;

  /// How the left column splits: the pairing panel, then the log.
  static const _pairingHeightShare = 7;
  static const _logHeightShare = 3;

  final HostViewState state;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(ToySizes.space8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Header(state: state),
          const SizedBox(height: ToySizes.space8),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: _pairingShare,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: _pairingHeightShare,
                        child: PairingPanel(state: state),
                      ),
                      const SizedBox(height: ToySizes.space8),
                      const Expanded(flex: _logHeightShare, child: LogPanel()),
                    ],
                  ),
                ),
                const SizedBox(width: ToySizes.space8),
                Expanded(
                  flex: _controllersShare,
                  child: ControllersPanel(state: state),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A narrow laptop window: everything stacked and scrolling.
class _NarrowHome extends StatelessWidget {
  const _NarrowHome({required this.state});

  /// The two lists' heights when the home scrolls: a controller's tile and a
  /// few log lines at the TV's type (M13 3d).
  static const _controllersHeight = 380.0;
  static const _logHeight = 240.0;

  final HostViewState state;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(ToySizes.space8),
      children: [
        Header(state: state),
        const SizedBox(height: ToySizes.space8),
        PairingPanel(state: state),
        const SizedBox(height: ToySizes.space8),
        SizedBox(
          height: _controllersHeight,
          child: ControllersPanel(state: state),
        ),
        const SizedBox(height: ToySizes.space8),
        const SizedBox(height: _logHeight, child: LogPanel()),
      ],
    );
  }
}

/// The app's name and what the host is doing, with the buttons to the other
/// screens.
///
/// It is one wrapping row (M13 3d): the title, the status, then the buttons in
/// their order. The title is never cut — it takes the width it needs and the
/// buttons run onto a second line when the window is 960 wide (on a TV they
/// take two: the six of them need about 1055). The version and the protocol
/// moved to the pairing panel: they don't fit beside the title at the TV's
/// type.
class Header extends StatelessWidget {
  const Header({super.key, required this.state});

  /// Below this window width the buttons are compact, so the header keeps to
  /// two lines on a TV.
  static const compactWidth = 1100.0;

  final HostViewState state;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => Wrap(
        spacing: ToySizes.space8,
        runSpacing: ToySizes.space8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const _HeaderTitle(),
          _HostStatus(state: state),
          ..._headerButtons(context, compact: constraints.maxWidth < compactWidth),
        ],
      ),
    );
  }
}

/// The app's name, with the TV's icon.
class _HeaderTitle extends StatelessWidget {
  const _HeaderTitle();

  /// The icon's size: the title's cap height, so the two line up.
  static const _iconSize = 32.0;

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.tv, size: _iconSize, color: look.colors.onBackground),
        const SizedBox(width: ToySizes.space8),
        Text(TvText.name, style: look.type.title.copyWith(color: look.colors.onBackground)),
      ],
    );
  }
}

/// What the host is doing: listening, starting, or why it couldn't start. It
/// sits on the background, so it is text on the background, never a status
/// colour.
class _HostStatus extends StatelessWidget {
  const _HostStatus({required this.state});

  final HostViewState state;

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    final error = state.serverError;
    final status = error ?? (state.host.running ? TvText.listeningOn(state.host.port) : TvText.starting);
    return Text(
      status,
      style: look.type.body.copyWith(color: look.colors.onBackground),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.end,
    );
  }
}

/// The buttons to the other screens, and the first-launch consent prompt:
/// always in view at the top, so the remote reaches them with Up.
List<Widget> _headerButtons(BuildContext context, {required bool compact}) => [
  HostButton(
    key: const Key('openPlay'),
    label: HostText.playTitle,
    icon: Icons.sports_esports_outlined,
    compact: compact,
    onPressed: () => Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: gamesRouteName),
        builder: (_) => const GamesScreen(),
      ),
    ),
  ),
  HostButton(
    label: TvText.hapticTest,
    icon: Icons.vibration,
    compact: compact,
    onPressed: () => _open(context, const HapticPanelScreen()),
  ),
  HostButton(
    label: TvText.latency,
    icon: Icons.speed,
    compact: compact,
    onPressed: () => _open(context, const LatencyScreen()),
  ),
  HostButton(
    key: const Key('openLookAndSound'),
    label: HostText.lookAndSound,
    icon: Icons.brightness_6_outlined,
    compact: compact,
    onPressed: () => _open(context, const LookAndSoundScreen()),
  ),
  HostButton(
    label: TvText.lookTest,
    icon: Icons.palette_outlined,
    compact: compact,
    onPressed: () => _open(context, const ShaderSpikeScreen()),
  ),
  HostButton(
    key: const Key('openStats'),
    label: HostText.stats,
    icon: Icons.insights_outlined,
    compact: compact,
    onPressed: () => _open(context, const StatsScreen()),
  ),
  // Asks the adult about sharing stats on the first launch (M9).
  const FirstLaunchConsent(),
];

void _open(BuildContext context, Widget screen) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
