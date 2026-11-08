import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:party_host/party_host.dart' as party;
import 'package:party_host/party_host.dart' show PhoneText, ToyButton, ToyCard, ToyLookScope, ToySizes;

/// What "Host a game" does with this phone (m12 §3, C34).
enum HostChoice {
  /// The game runs here, and this phone's own controls play it.
  onPhone,

  /// This phone only shows the game; everyone plays from their own phone.
  onDevice,
}

/// Asks how to host, and returns the choice, or null if it was cancelled.
Future<HostChoice?> showHostStartSheet(BuildContext context) =>
    showDialog<HostChoice>(context: context, builder: (_) => const _HostStartSheet());

class _HostStartSheet extends ConsumerWidget {
  const _HostStartSheet();

  /// The sheet's width: 520 px on the phone's look.
  static const _widthShare = 520 / 48;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The start's clock begins at the tap that picks a way (m12 bug 1108b):
    // the lines after it say how long the picker took to come up, and where
    // the time went.
    void choose(HostChoice choice) {
      ref.read(party.hostStartLogProvider).tap();
      Navigator.of(context).pop(choice);
    }

    final look = ToyLookScope.of(context);
    return Dialog(
      key: const Key('hostStartSheet'),
      // The paper, the band and the ink edge are the card's and the theme's.
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: look.sizes.buttonHeight * _widthShare),
        child: ToyCard(
          header: PhoneText.hostAGame,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Choice(
                buttonKey: const Key('hostOnPhone'),
                icon: Icons.sports_esports,
                title: PhoneText.playOnThisPhone,
                why: PhoneText.playOnThisPhoneWhy,
                onPressed: () => choose(HostChoice.onPhone),
              ),
              const SizedBox(height: ToySizes.space12),
              _Choice(
                buttonKey: const Key('hostOnDevice'),
                icon: Icons.tv,
                title: PhoneText.showOnThisDevice,
                why: PhoneText.showOnThisDeviceWhy,
                onPressed: () => choose(HostChoice.onDevice),
              ),
              const SizedBox(height: ToySizes.space8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  key: const Key('hostCancel'),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(PhoneText.cancel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One way to host: a toy button, its name on it, and a line under it saying
/// what the way does. Both ways look the same and neither takes the focus, so
/// nothing is lit when the sheet opens (m12 bug 1108d); a toy button lights
/// only while a thumb presses it. This phone has no remote to move a focus
/// with.
class _Choice extends StatelessWidget {
  const _Choice({
    required this.buttonKey,
    required this.icon,
    required this.title,
    required this.why,
    required this.onPressed,
  });

  /// The choice's key, on the button itself so a thumb or a test presses it.
  final Key buttonKey;
  final IconData icon;
  final String title;
  final String why;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ToyButton(key: buttonKey, icon: icon, label: title, onPressed: onPressed),
        Text(why, style: look.type.body.copyWith(color: look.colors.inkSoft)),
      ],
    );
  }
}
