import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../host_grace.dart';
import '../providers.dart';
import 'connect_screen.dart';

/// The card over a game while the phone waits for its host (m12-joined-view
/// §0.3): the host is away, or the link to it dropped while it showed a game.
///
/// The two waits say different things: an away host gets a countdown that runs
/// once a second on the client's own clock, so a late away message doesn't
/// lengthen the wait, and a dropped link says the phone is reconnecting. Once
/// the countdown is out, or the grace it gets when the host said nothing, the
/// card says the host has left. Leave game is the way out either way.
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

  /// Leave game: the player goes, as the Connect screen's Stop does (the
  /// saved pairing stays, the last host is forgotten), and that screen opens
  /// so they can join another game (m12-joined-view §0.3).
  void _leave() {
    ref.read(connectionActionsProvider).disconnect();
    openConnect(context);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final elapsedS = (ref.watch(clientProvider).nowMs - widget.wait.sinceMs) ~/ Duration.millisecondsPerSecond;
    final secondsLeft = widget.wait.secondsLeft;
    final left = secondsLeft == null ? null : secondsLeft - elapsedS;
    // A host that gave a number has left when its countdown is out; one that
    // said nothing (the link dropped) gets the grace the phone counts for it.
    final hostLeft = left == null ? elapsedS >= hostGraceS : left <= 0;
    final title = hostLeft
        ? 'The host has left'
        : switch (widget.wait.kind) {
            HostWaitKind.hostAway => 'Waiting for the host to come back',
            HostWaitKind.dropped => 'Reconnecting to the game…',
          };
    final line = hostLeft
        ? 'You can keep waiting, or leave.'
        : left == null
        ? null
        : "The game goes on if they're back in $left s";
    return Center(
      child: Card(
        key: const Key('waitingCard'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: text.titleMedium, textAlign: TextAlign.center),
              if (line != null) ...[
                const SizedBox(height: 4),
                Text(line, style: text.bodyMedium, textAlign: TextAlign.center),
              ],
              const SizedBox(height: 8),
              if (hostLeft)
                FilledButton(key: const Key('leaveGame'), onPressed: _leave, child: const Text('Leave game'))
              else
                TextButton(key: const Key('leaveGame'), onPressed: _leave, child: const Text('Leave game')),
            ],
          ),
        ),
      ),
    );
  }
}
