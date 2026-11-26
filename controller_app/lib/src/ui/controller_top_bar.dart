part of 'controller_screen.dart';

/// The slim bar above the controls: the own player and the link (or, while
/// this phone hosts, its game and how to join it), the pad's mode, Settings
/// and Diagnostics.
///
/// Over a game it goes compact (m12-phone-layout §0.7b): the game draws its
/// own clock and counts right under the bar, so the bar keeps only what
/// playing needs and draws it at the controls' opacity.
///
/// The phone that hosts follows the round's phase instead (m12-host-touch
/// rules 1, 2): the full bar over its menus and the compact one over the
/// round, which is the only game it shows.
class _TopBar extends ConsumerWidget {
  const _TopBar({required this.hosting, required this.controls});

  /// This phone is hosting: the host chip takes the connection's place in the
  /// full bar, and follows the dot in the compact one.
  final bool hosting;

  /// The pad plays the game behind it, so its mode and Settings stay.
  final bool controls;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (hosting) {
      return ValueListenableBuilder<party.RoundPhase>(
        valueListenable: ref.watch(party.roundPhaseProvider),
        builder: (context, phase, _) => phase == party.RoundPhase.none
            ? _ControllerTopBar(hosting: hosting, controls: controls)
            : _GameTopBar(hosting: hosting, controls: controls),
      );
    }
    return ref.watch(showsGameProvider)
        ? _GameTopBar(hosting: hosting, controls: controls)
        : _ControllerTopBar(hosting: hosting, controls: controls);
  }
}

/// The bar over a game (m12-phone-layout §0.7b): the own player and the
/// link's dot on the left, the mode, Settings and Diagnostics as icons on the
/// right, and nothing in the middle, so neither the host's name nor the ping
/// covers the game's HUD.
class _GameTopBar extends ConsumerWidget {
  const _GameTopBar({required this.hosting, required this.controls});

  /// This phone hosts: the code to join it follows the dot, so a host can
  /// still show the code and stop from here (s7d2 Q1).
  final bool hosting;

  /// False for "Show on this device" (C34): no pad, so no mode or Settings.
  final bool controls;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
    padding: barPadding,
    child: Opacity(
      opacity: ref.watch(controlsSettingsProvider).opacity,
      child: Row(
        children: [
          // The dot is the way into Connect, and a phone that only shows the
          // game has no link of its own to connect: its bar keeps the host's
          // chip alone, after the dot when there is one (m12 bug 1108a fix2
          // Q1).
          if (controls) ...[const CompactConnection(), const SizedBox(width: party.ToySizes.space8)],
          if (hosting) const HostChip(compact: true),
          const Spacer(),
          if (controls) const _StartButton(),
          if (controls) const ModeMenuButton(),
          if (controls) const _MoreMenuButton() else const _DiagnosticsButton(),
        ],
      ),
    ),
  );
}

/// Start, which the game calls Pause, in the compact bar while a game shows
/// (the pad drops its own pill then). The game's layout decides whether it is
/// there: a phone that only watches and the menus hide it, so nobody can pause
/// the TV for everyone.
class _StartButton extends ConsumerWidget {
  const _StartButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(gameLayoutProvider).hidden.contains(ControllerButton.start)) return const SizedBox.shrink();
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // SmallButton's default size, 96 x 44 dp, fits the bar's 48 dp row.
        SmallButton(key: Key('barStart'), button: ControllerButton.start, label: 'Start'),
        SizedBox(width: party.ToySizes.space8),
      ],
    );
  }
}

/// The full bar, as it is in controller mode: the connection (or, while this
/// phone hosts, the host chip), the mode's three labels, Settings and
/// Diagnostics.
class _ControllerTopBar extends ConsumerWidget {
  const _ControllerTopBar({required this.hosting, required this.controls});

  final bool hosting;
  final bool controls;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
    padding: barPadding,
    child: Row(
      children: [
        // The chip and the ping take whatever room is left, and shorten.
        Expanded(child: hosting ? const HostChip() : const BarConnection()),
        const SizedBox(width: party.ToySizes.space8),
        if (controls) const BarModes(),
        if (controls) const _MoreMenuButton() else const _DiagnosticsButton(),
      ],
    ),
  );
}

/// The bar's "More" menu on every device and look: Settings (the pad's and the
/// phone's) and Diagnostics, so the bar keeps one button for both. Its icon is
/// drawn on the pad's background, so it takes `onBackground` (M13 3c).
class _MoreMenuButton extends StatelessWidget {
  const _MoreMenuButton();

  /// The touch target's side, in dp, which the bar's other buttons keep too.
  static const _minTargetDp = 48.0;

  @override
  Widget build(BuildContext context) => MenuAnchor(
    menuChildren: [
      MenuItemButton(
        key: const Key('moreSettings'),
        leadingIcon: const Icon(Icons.settings_outlined),
        onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen())),
        child: const Text(party.PhoneText.settings),
      ),
      MenuItemButton(
        key: const Key('moreDiagnostics'),
        leadingIcon: const Icon(Icons.monitor_heart_outlined),
        onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const DiagnosticsScreen())),
        child: const Text(party.PhoneText.diagnostics),
      ),
    ],
    builder: (context, menu, _) => IconButton(
      key: const Key('moreMenu'),
      tooltip: party.PhoneText.more,
      constraints: const BoxConstraints(minWidth: _minTargetDp, minHeight: _minTargetDp),
      icon: Icon(Icons.more_horiz, color: party.ToyLookScope.of(context).colors.onBackground),
      onPressed: () => menu.isOpen ? menu.close() : menu.open(),
    ),
  );
}

/// The bar's way into Diagnostics (M9), in the background's own colour.
class _DiagnosticsButton extends StatelessWidget {
  const _DiagnosticsButton();

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: party.PhoneText.diagnostics,
    icon: Icon(Icons.monitor_heart_outlined, color: party.ToyLookScope.of(context).colors.onBackground),
    onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const DiagnosticsScreen())),
  );
}
