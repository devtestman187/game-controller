part of 'pause_menu.dart';

/// The pause menu's card (M13 3b, mock-up `phone-paused`): a [ToyCard] headed
/// `focus`, the badge of the player who paused beside who may resume, and Quit
/// and Resume. It works the phones and the remote as it always did (m12).
class _PauseMenu extends ConsumerWidget {
  const _PauseMenu({required this.pausedBy, required this.resumers});

  final GamePlayer pausedBy;
  final Set<String>? Function(List<GamePlayer> players) resumers;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final players = [
      for (final p in ref.watch(gamePlayersProvider))
        if (!p.simulated && !p.local && !p.away) p,
    ];
    final only = resumers(players);
    final look = ToyLookScope.of(context);
    return ControlsClaim(
      controls: Controls.menus(only: only, layout: pauseLayout),
      child: Dialog(
        key: const Key('pauseMenu'),
        child: ToyCard(
          header: HostText.paused,
          headerColor: look.colors.focus,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ToyBadge(number: pausedBy.number, diameter: look.sizes.buttonHeight),
                  const SizedBox(width: ToySizes.space12),
                  Flexible(
                    child: Text(
                      only == null
                          ? HostText.anyoneCanResume
                          : HostText.resumers(HostText.resumerName(pausedBy.number)),
                      style: look.type.body.copyWith(color: look.colors.ink),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: ToySizes.space16),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  HostButton(
                    key: const Key('pauseQuit'),
                    label: HostText.quit,
                    icon: Icons.exit_to_app,
                    onPressed: () => Navigator.of(context).pop(true),
                  ),
                  const SizedBox(width: ToySizes.space12),
                  HostButton(
                    key: const Key('pauseResume'),
                    label: HostText.resume,
                    icon: Icons.play_arrow,
                    autofocus: true,
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
