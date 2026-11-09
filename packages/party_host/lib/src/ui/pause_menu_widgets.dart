part of 'pause_menu.dart';

/// The pause menu's card (M13 3b, mock-up `phone-paused`): a [ToyCard] headed
/// `focus`, the badge of the player who paused — wearing their character (M13
/// 4c), in the room the card keeps above it for the accessory — beside who may
/// resume, and Quit and Resume. It works the phones and the remote as it
/// always did (m12).
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
              _Pauser(number: pausedBy.number, anyone: only == null),
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

/// Who paused: their badge, wearing their character (M13 4c), and who can
/// resume. The accessory is drawn above the badge's box, so the row keeps room
/// for it.
class _Pauser extends StatelessWidget {
  const _Pauser({required this.number, required this.anyone});

  final int number;

  /// Anyone can resume, not only the player who paused.
  final bool anyone;

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    return Padding(
      padding: EdgeInsets.only(top: toyAccessoryHeadroom(look.sizes.buttonHeight)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ToyBadge(number: number, diameter: look.sizes.buttonHeight, character: ToyCharacter.forPlayer(number)),
          const SizedBox(width: ToySizes.space12),
          Flexible(
            child: Text(
              anyone ? HostText.anyoneCanResume : HostText.resumers(HostText.resumerName(number)),
              style: look.type.body.copyWith(color: look.colors.ink),
            ),
          ),
        ],
      ),
    );
  }
}
