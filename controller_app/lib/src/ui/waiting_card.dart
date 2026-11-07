import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';

/// The card over a game while the phone waits for its host (m12-joined-view
/// §0.3): the host is away, or the link to it dropped while it showed a game.
///
/// The countdown runs once a second on the client's own clock, so a late away
/// message doesn't lengthen the wait; at zero the words stay without a number.
class WaitingCard extends ConsumerStatefulWidget {
  const WaitingCard({super.key, required this.wait});

  /// Where the countdown starts: the host's seconds left at the phone clock
  /// they arrived, or the grace from the moment the link dropped.
  final HostWait wait;

  @override
  ConsumerState<WaitingCard> createState() => _WaitingCardState();
}

class _WaitingCardState extends ConsumerState<WaitingCard> {
  late final Timer _tick;

  @override
  void initState() {
    super.initState();
    // A second is the whole resolution the countdown shows; the number comes
    // from the client's clock, not from the timer.
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final elapsedS = (ref.watch(clientProvider).nowMs - widget.wait.sinceMs) ~/ Duration.millisecondsPerSecond;
    final secondsLeft = widget.wait.secondsLeft;
    final left = secondsLeft == null ? null : secondsLeft - elapsedS;
    return Center(
      child: Card(
        key: const Key('waitingCard'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Waiting for the host to come back', style: text.titleMedium, textAlign: TextAlign.center),
              if (left != null) ...[
                const SizedBox(height: 4),
                Text(
                  left <= 0 ? 'The host may have left' : "The game goes on if they're back in $left s",
                  style: text.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
