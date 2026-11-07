part of 'controller_screen.dart';

/// The slim bar above the controls: the own player and the link (or, while
/// this phone hosts, its game and how to join it), the pad's mode, Settings
/// and Diagnostics.
class _TopBar extends ConsumerWidget {
  const _TopBar({required this.hosting, required this.controls});

  /// This phone is hosting: the host chip takes the connection's place.
  final bool hosting;

  /// The pad plays the game behind it, so its mode and Settings stay.
  final bool controls;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 4, 8, 0),
    child: Row(
      children: [
        // The chip and the ping take whatever room is left, and shorten.
        Expanded(child: hosting ? const HostChip() : const BarConnection()),
        const SizedBox(width: 8),
        if (controls) const BarModes(),
        if (controls)
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () =>
                Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen())),
          ),
        IconButton(
          tooltip: 'Diagnostics',
          icon: const Icon(Icons.monitor_heart_outlined),
          onPressed: () =>
              Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const DiagnosticsScreen())),
        ),
      ],
    ),
  );
}
