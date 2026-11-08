import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:party_host/party_host.dart' show HostText, PhoneText, ToyCard, ToyLookScope, ToySizes;

import '../host_grace.dart';
import '../providers.dart';
import 'connect_screen.dart';

/// The card over a game while the phone waits (m12-joined-view §0.3, m12 bug
/// 1107d): the host is away, the link to it dropped while it showed a game, or
/// the game holds a place for a player who dropped.
///
/// The waits say different things: an away host gets a countdown that runs
/// once a second on the client's own clock, so a late away message doesn't
/// lengthen the wait, and a dropped link says the phone is reconnecting. Once
/// the countdown is out, or the grace it gets when the host said nothing, the
/// card says the host has left. An away player gets a line each with the same
/// countdown, and says the game goes on without them once it is out. Leave
/// game is the way out either way.
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
    final nowMs = ref.watch(clientProvider).nowMs;
    final elapsedS = (nowMs - widget.wait.sinceMs) ~/ Duration.millisecondsPerSecond;
    final secondsLeft = widget.wait.secondsLeft;
    final left = secondsLeft == null ? null : secondsLeft - elapsedS;
    // A host that gave a number has left when its countdown is out; one that
    // said nothing (the link dropped) gets the grace the phone counts for it.
    // A player who is away can't leave the host: their round just goes on.
    final hostLeft = widget.wait.kind == HostWaitKind.playerAway
        ? false
        : left == null
        ? elapsedS >= hostGraceS
        : left <= 0;
    final look = ToyLookScope.of(context);
    return Center(
      child: ToyCard(
        key: const Key('waitingCard'),
        header: PhoneText.waiting,
        headerColor: look.colors.caution,
        padding: const EdgeInsets.symmetric(horizontal: ToySizes.space24, vertical: ToySizes.space16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (i, away) in widget.wait.away.indexed) ...[
              if (i > 0) const SizedBox(height: ToySizes.space8),
              _AwayLines(away: away, nowMs: nowMs),
            ],
            if (widget.wait.kind != HostWaitKind.playerAway) _hostLines(hostLeft: hostLeft, left: left),
            const SizedBox(height: ToySizes.space8),
            if (hostLeft)
              FilledButton(key: const Key('leaveGame'), onPressed: _leave, child: const Text(PhoneText.leaveGame))
            else
              TextButton(key: const Key('leaveGame'), onPressed: _leave, child: const Text(PhoneText.leaveGame)),
          ],
        ),
      ),
    );
  }

  /// What the host (or the link to it) is doing, and how long the round waits.
  Widget _hostLines({required bool hostLeft, required int? left}) {
    final look = ToyLookScope.of(context);
    final title = hostLeft
        ? PhoneText.hostHasLeft
        : widget.wait.kind == HostWaitKind.hostAway
        ? PhoneText.waitingForHost
        : PhoneText.reconnectingToGame;
    final line = hostLeft
        ? PhoneText.youCanKeepWaiting
        : left == null
        ? null
        : HostText.awayCountdown(left);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: look.type.button, textAlign: TextAlign.center),
        if (line != null) ...[
          const SizedBox(height: ToySizes.space4),
          Text(line, style: look.type.body, textAlign: TextAlign.center),
        ],
      ],
    );
  }
}

/// One away player's two lines (m12 bug 1107d): which player the game waits
/// for, and how long it waits before going on without them.
class _AwayLines extends StatelessWidget {
  const _AwayLines({required this.away, required this.nowMs});

  /// The player, and when this phone heard it is away.
  final AwayWait away;

  /// This phone's clock: the countdown runs on it, so a late message doesn't
  /// lengthen the wait.
  final int nowMs;

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    final elapsedS = (nowMs - away.sinceMs) ~/ Duration.millisecondsPerSecond;
    final left = away.secondsLeft - elapsedS;
    final line = left > 0 ? HostText.awayCountdown(left) : HostText.awayGone;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(HostText.playerAway(away.number), style: look.type.button, textAlign: TextAlign.center),
        const SizedBox(height: ToySizes.space4),
        Text(line, style: look.type.body, textAlign: TextAlign.center),
      ],
    );
  }
}
