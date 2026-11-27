import 'dart:async';

import 'package:connection/connection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:protocol/protocol.dart';

import '../providers.dart';

/// How long the result of a choice round stays on the phone after the host ended the round, in
/// milliseconds: long enough to read "You got: Save +2", short enough not to hold up the game.
const choicesResultHoldMs = 3000;

/// What the phone knows of one choice round (M17 phone1b): the host's latest message, what this phone
/// holds for it, and the end once it arrives.
class ChoicesState {
  const ChoicesState({
    required this.message,
    required this.receivedMs,
    this.picked,
    this.count = 1,
    this.locked = false,
    this.end,
  });

  /// The latest message of the round.
  final ChoicesMessage message;

  /// The phone's own clock ([ControllerClient.nowMs]) when [message] arrived, which the countdown runs from.
  final int receivedMs;

  /// The card this phone holds, or null when none.
  final String? picked;

  /// How many of [picked] this phone holds.
  final int count;

  /// Whether this phone holds its choice locked in.
  final bool locked;

  /// The host's end of the round, or null while the round runs.
  final ChoicesEndMessage? end;

  /// Whether the host paused the round, so the countdown stands still.
  bool get isPaused => message.paused;

  /// Whether the round is over, so nothing can be picked any more.
  bool get isEnded => end != null;

  /// The time left to choose at [nowMs] on the phone's clock, never below 0.
  int remainingMs(int nowMs) {
    if (isPaused) return message.endsInMs;
    final left = message.endsInMs - (nowMs - receivedMs);
    return left < 0 ? 0 : left;
  }

  /// This state with the given fields changed. [clearPick] drops the pick (a null [picked] keeps it); [end]
  /// and the others keep their current value when null.
  ChoicesState copyWith({String? picked, bool clearPick = false, int? count, bool? locked, ChoicesEndMessage? end}) =>
      ChoicesState(
        message: message,
        receivedMs: receivedMs,
        picked: clearPick ? null : picked ?? this.picked,
        count: count ?? this.count,
        locked: locked ?? this.locked,
        end: end ?? this.end,
      );
}

/// The choice round the host sent this phone (M17 phone1b), or null when none shows. A message of the same
/// round updates it, another round replaces it. A new view clears it, and so does a dropped link, as
/// [nightEndProvider] clears its end; so does [choicesResultHoldMs] after the round's end. So does the host
/// going away: the host-away card shows instead, nothing is sent to an away host, and the host's return does not
/// bring the stale round back (the host sends the round again if it still runs).
final choicesProvider = NotifierProvider<ChoicesNotifier, ChoicesState?>(ChoicesNotifier.new);

/// Holds the round of [choicesProvider] and sends this phone's picks, counts and lock to the host.
class ChoicesNotifier extends Notifier<ChoicesState?> {
  Timer? _clearTimer;

  @override
  ChoicesState? build() {
    final client = ref.watch(clientProvider);
    final subs = [
      client.choices.listen((message) => _onRound(client, message)),
      client.choicesEnds.listen(_onEnd),
      client.view.listen((event) {
        switch (event) {
          case ViewStarted() || HostAway():
            _clear();
          case ViewEnded() || ViewFrame() || HostBack() || PlayerAway() || PlayerBack():
            break;
        }
      }),
    ];
    ref.onDispose(() {
      _clearTimer?.cancel();
      for (final sub in subs) {
        unawaited(sub.cancel());
      }
    });
    ref.listen(clientStateProvider, (previous, next) {
      if (!next.isConnected) _clear();
    });
    return null;
  }

  void _clear() {
    _clearTimer?.cancel();
    _clearTimer = null;
    state = null;
  }

  void _onRound(ControllerClient client, ChoicesMessage message) {
    final current = state;
    // A message of a round that already ended is stale: the end stands.
    if (current != null && current.message.round == message.round && current.isEnded) return;
    _clearTimer?.cancel();
    _clearTimer = null;
    state = ChoicesState(
      message: message,
      receivedMs: client.nowMs,
      picked: message.picked,
      count: message.pickedCount,
      locked: message.locked,
    );
  }

  void _onEnd(ChoicesEndMessage end) {
    final current = state;
    if (current == null || current.message.round != end.round) return;
    state = current.copyWith(end: end);
    _clearTimer?.cancel();
    _clearTimer = Timer(const Duration(milliseconds: choicesResultHoldMs), _clear);
  }

  /// Takes [cardId], or clears it when it is the card already held. A disabled card, a locked choice and an
  /// ended round change nothing.
  void pick(String cardId) {
    final current = state;
    if (current == null || current.isEnded || current.locked || !_isEnabled(current, cardId)) return;
    _hold(
      current.picked == cardId
          ? current.copyWith(clearPick: true, count: 1)
          : current.copyWith(picked: cardId, count: 1),
    );
  }

  /// Moves the count of [cardId] by [delta], within 1 to the card's `maxCount`; a card not held yet is taken.
  void step(String cardId, int delta) {
    final current = state;
    if (current == null || current.isEnded || current.locked || !_isEnabled(current, cardId)) return;
    final max = current.message.cards.firstWhere((c) => c.id == cardId).maxCount;
    final base = current.picked == cardId ? current.count : 0;
    final next = (base + delta).clamp(1, max);
    if (current.picked == cardId && next == current.count) return;
    _hold(current.copyWith(picked: cardId, count: next));
  }

  /// Locks in what the phone holds.
  void lock() {
    final current = state;
    if (current == null || current.isEnded || current.locked) return;
    _hold(current.copyWith(locked: true));
  }

  /// Takes the lock back, so the choice can change until the timer ends.
  void undo() {
    final current = state;
    if (current == null || current.isEnded || !current.locked) return;
    _hold(current.copyWith(locked: false));
  }

  bool _isEnabled(ChoicesState current, String cardId) => current.message.cards.any((c) => c.id == cardId && c.enabled);

  void _hold(ChoicesState next) {
    state = next;
    ref
        .read(clientProvider)
        .sendChoicePick(
          ChoicePickMessage(round: next.message.round, pick: next.picked, count: next.count, locked: next.locked),
        );
  }
}
