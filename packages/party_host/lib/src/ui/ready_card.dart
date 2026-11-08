import 'package:flutter/material.dart';

/// The card over a round held for the "Get ready" beat (m12-host-touch rule 3):
/// the round stands still while thumbs find the pad, and the card counts the
/// seconds left, 3, 2, 1.
///
/// It takes no touch: the pad is the only thing under a finger (rule 2). The
/// round's screen counts the seconds ([Pausable] in `pause_menu.dart`); this
/// only draws them, so there is one clock.
class ReadyCard extends StatelessWidget {
  const ReadyCard({super.key, required this.seconds});

  /// The whole seconds left in the beat.
  final int seconds;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return IgnorePointer(
      child: Center(
        child: DecoratedBox(
          key: const Key('getReady'),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Get ready', style: text.headlineMedium?.copyWith(color: Colors.white)),
                Text(
                  '$seconds',
                  key: const Key('getReadyCount'),
                  style: text.displayLarge?.copyWith(color: Colors.amberAccent),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
