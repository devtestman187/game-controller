import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:party_host/party_host.dart' as party;

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The start's clock begins at the tap that picks a way (m12 bug 1108b):
    // the lines after it say how long the picker took to come up, and where
    // the time went.
    void choose(HostChoice choice) {
      ref.read(party.hostStartLogProvider).tap();
      Navigator.of(context).pop(choice);
    }

    return AlertDialog(
      key: const Key('hostStartSheet'),
      title: const Text('Host a game'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Choice(
            key: const Key('hostOnPhone'),
            icon: Icons.sports_esports,
            title: 'Play on this phone',
            why: 'Play here with the controls on the screen',
            primary: true,
            onPressed: () => choose(HostChoice.onPhone),
          ),
          const SizedBox(height: 8),
          _Choice(
            key: const Key('hostOnDevice'),
            icon: Icons.tv,
            title: 'Show on this device',
            why: 'Everyone joins from their phones; this phone shows the game',
            primary: false,
            onPressed: () => choose(HostChoice.onDevice),
          ),
        ],
      ),
      actions: [
        TextButton(
          key: const Key('hostCancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

/// One way to host: a button with a line under its name. The primary one has
/// the focus, so the remote's OK picks it.
class _Choice extends StatelessWidget {
  const _Choice({
    super.key,
    required this.icon,
    required this.title,
    required this.why,
    required this.primary,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String why;
  final bool primary;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final label = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: text.titleMedium),
        Text(why, style: text.bodySmall),
      ],
    );
    final style = ButtonStyle(
      alignment: Alignment.centerLeft,
      padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
    );
    return primary
        ? FilledButton.icon(autofocus: true, style: style, icon: Icon(icon), label: label, onPressed: onPressed)
        : OutlinedButton.icon(style: style, icon: Icon(icon), label: label, onPressed: onPressed);
  }
}
