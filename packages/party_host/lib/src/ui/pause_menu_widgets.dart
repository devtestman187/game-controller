part of 'pause_menu.dart';

/// The labels while the game is paused: the menu, and Start to resume.
const _pauseLabels = {
  ControllerButton.a: HostText.ok,
  ControllerButton.b: HostText.resume,
  ControllerButton.start: HostText.resume,
};

/// The buttons a phone never shows while the game is paused.
const _pauseHidden = {
  ControllerButton.x,
  ControllerButton.y,
  ControllerButton.lb,
  ControllerButton.rb,
  ControllerButton.select,
};

/// The buttons while the game is paused: the menu, and Start to resume.
final pauseLayout = GameLayoutMessage(labels: _pauseLabels, hidden: _pauseHidden);

/// Who may resume the round the menu paused: the player who paused and Player
/// 1, or anyone if neither is here. It lives here, with the menu that asks it,
/// to keep the screen file within its size.
extension _PausableResumers on _PausableState {
  /// Who may resume: the player who paused and Player 1, or anyone if
  /// neither is here.
  Set<String>? _resumers(List<GamePlayer> players) {
    final by = _pausedBy;
    final ids = {
      for (final p in players)
        if (p.id == by?.id || p.number == 1) p.id,
    };
    return ids.isEmpty ? null : ids;
  }
}

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
              _Pauser(number: pausedBy.number, character: pausedBy.character, anyone: only == null),
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
  const _Pauser({required this.number, required this.anyone, this.character});

  final int number;

  /// The character the host gave the player (M14 L7), or null for the default.
  final PlayerCharacter? character;

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
          ToyBadge(number: number, diameter: look.sizes.buttonHeight, character: ToyCharacter.of(character, number)),
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
