import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:party_host/party_host.dart';
import 'package:protocol/protocol.dart';

import '../../app_info.dart';
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
    // Plays the games' sounds.
    ref.watch(gameSoundsProvider);
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

/// A TV or a large window: the header over the pairing panel and, beside it,
/// the controllers and the log.
class _WideHome extends StatelessWidget {
  const _WideHome({required this.state});

  final HostViewState state;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Header(state: state),
          const SizedBox(height: 12),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 5, child: PairingPanel(state: state)),
                const SizedBox(width: 16),
                Expanded(
                  flex: 6,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 7, child: ControllersPanel(state: state)),
                      const SizedBox(height: 12),
                      const Expanded(flex: 4, child: LogPanel()),
                    ],
                  ),
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

  final HostViewState state;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Header(state: state),
        const SizedBox(height: 12),
        PairingPanel(state: state),
        const SizedBox(height: 12),
        SizedBox(height: 320, child: ControllersPanel(state: state)),
        const SizedBox(height: 12),
        const SizedBox(height: 240, child: LogPanel()),
      ],
    );
  }
}

/// The app's name, version and status, with the buttons to the other screens.
class Header extends StatelessWidget {
  const Header({super.key, required this.state});

  /// From this window width up, the buttons sit beside the title, wrapping
  /// onto a second line inside their share of it when the window can't hold
  /// them all (six of them on a 1080p TV, 960 logical pixels wide); below it
  /// they wrap underneath, where a narrow window has room.
  static const rowWidth = 760.0;

  /// Below this window width the buttons are compact, so all six fit beside
  /// the title on a 1080p TV.
  static const compactWidth = 1100.0;

  /// The most of the header the buttons take beside the title: six compact
  /// buttons need more than a 960-pixel header leaves, so they run onto a
  /// second line rather than off the screen.
  static const _buttonsShare = 0.65;

  final HostViewState state;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < compactWidth;
        if (constraints.maxWidth >= rowWidth) {
          return Row(
            children: [
              Expanded(child: _HeaderTitle(state: state)),
              const SizedBox(width: 16),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: constraints.maxWidth * _buttonsShare),
                child: _HeaderButtons(compact: compact),
              ),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _HeaderTitle(state: state),
            const SizedBox(height: 8),
            _HeaderButtons(compact: compact),
          ],
        );
      },
    );
  }
}

/// The title and version, with what the host is doing at the end.
class _HeaderTitle extends StatelessWidget {
  const _HeaderTitle({required this.state});

  final HostViewState state;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final error = state.serverError;
    final (status, statusColor) = error != null
        ? (error, scheme.error)
        : state.host.running
        ? ('Listening on port ${state.host.port}', scheme.onSurface)
        : ('Starting…', scheme.onSurface);
    return Row(
      children: [
        Icon(Icons.tv, size: 32, color: scheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: 'Thumb Party TV', style: text.headlineSmall),
                TextSpan(
                  text: '   Version $versionLabel · protocol v$protocolVersion',
                  style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            status,
            style: text.bodyMedium?.copyWith(color: statusColor),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}

/// The buttons to the other screens, and the first-launch consent prompt.
class _HeaderButtons extends StatelessWidget {
  const _HeaderButtons({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    // Always in view at the top, so the remote reaches them with Up.
    final buttons = <Widget>[
      HostButton(
        key: const Key('openPlay'),
        label: 'Play',
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
        label: 'Haptic test',
        icon: Icons.vibration,
        compact: compact,
        onPressed: () => _open(context, const HapticPanelScreen()),
      ),
      HostButton(
        label: 'Latency',
        icon: Icons.speed,
        compact: compact,
        onPressed: () => _open(context, const LatencyScreen()),
      ),
      HostButton(
        key: const Key('openLookAndSound'),
        label: 'Look and sound',
        icon: Icons.brightness_6_outlined,
        compact: compact,
        onPressed: () => _open(context, const LookAndSoundScreen()),
      ),
      HostButton(
        label: 'Look test',
        icon: Icons.palette_outlined,
        compact: compact,
        onPressed: () => _open(context, const ShaderSpikeScreen()),
      ),
      HostButton(
        key: const Key('openStats'),
        label: 'Stats',
        icon: Icons.insights_outlined,
        compact: compact,
        onPressed: () => _open(context, const StatsScreen()),
      ),
      // Asks the adult about sharing stats on the first launch (M9).
      const FirstLaunchConsent(),
    ];
    return Wrap(spacing: 8, runSpacing: 8, children: buttons);
  }
}

void _open(BuildContext context, Widget screen) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
