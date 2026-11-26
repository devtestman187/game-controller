import 'dart:async';

import 'package:protocol/protocol.dart';

import 'host_server.dart';
import 'host_types.dart';

part 'choice_round_state.dart';

/// One choice round on the phones (M17 phone1a): the host offers each player a
/// list of cards, takes their picks until the timer ends, and settles each
/// player's outcome. A pick can be changed until then; nothing chosen, or a
/// player away for [grace], gets [defaultId].
///
/// Only a phone that lists [Capability.choices] is sent the round. The others
/// ("legacy" phones) still get an outcome, and their picks come in through
/// [pick] (the old-phone fallback).
final class ChoiceRound {
  ChoiceRound({
    required this.server,
    required this.round,
    required this.title,
    required this.cardsFor,
    required this.players,
    required this.duration,
    required this.grace,
    required this.nowMs,
    this.defaultId,
    this.currency,
  });

  final HostServer server;

  /// The round's number, which a phone's pick must name.
  final int round;

  /// The question the phones show.
  final String title;

  /// The cards one player may pick from, asked each time so a list may change.
  final List<ChoiceCard> Function(String playerId) cardsFor;

  /// The IDs of the players who take part.
  final List<String> players;

  /// How long the round lasts, from [start].
  final Duration duration;

  /// How long a player may stay away before getting the default.
  final Duration grace;

  /// The clock the time left in each message comes from, in ms.
  final int Function() nowMs;

  /// The card that applies when nothing is chosen, or null when nothing does.
  final String? defaultId;

  /// The unit the costs are in, or null when there are none.
  final String? currency;

  final _picks = <String, _Pick>{};
  final _awayTimers = <String, Timer>{};
  final _connected = <String>{};
  final _changes = StreamController<void>.broadcast();
  Map<String, ChoiceOutcome>? _outcomes;
  Timer? _endTimer;
  StreamSubscription<ControllerMessage>? _messageSub;
  StreamSubscription<HostSnapshot>? _serverSub;
  int _endsAtMs = 0;
  bool _started = false;

  /// Fires after every pick, every default set for an away player, and the close.
  Stream<void> get changes => _changes.stream;

  /// Whether the round has ended.
  bool get isClosed => _outcomes != null;

  /// The players whose stored pick is locked in, or set by the default.
  Set<String> get lockedIds => {
    for (final e in _picks.entries)
      if (e.value.locked) e.key,
  };

  /// Each player's outcome once the round is closed; empty before.
  Map<String, ChoiceOutcome> get outcomes => _outcomes ?? const {};

  /// Sends the round to every player whose phone lists the capability and
  /// starts the timer.
  void start() {
    if (_started || isClosed) return;
    _started = true;
    _endsAtMs = nowMs() + duration.inMilliseconds;
    _messageSub = server.messages.listen(_onMessage);
    _serverSub = server.changes.listen(_onServerChange);
    _endTimer = Timer(duration, close);
    final live = _connectedPlayers(server.snapshot);
    for (final id in players) {
      if (live.contains(id)) {
        _connected.add(id);
        _sendState(id);
      } else {
        _startAwayTimer(id);
      }
    }
  }

  /// Stores [pickId] for [playerId]; null, or an unlocked pick, is an undo.
  /// Ignores a player not in the round, a card the player's list lacks or that
  /// is disabled, and any pick once the round is closed. [count] is held to
  /// 1 up to the card's maxCount.
  void pick(String playerId, {String? pickId, int count = 1, bool locked = false}) {
    if (isClosed || !players.contains(playerId)) return;
    if (pickId == null) {
      if (_picks.remove(playerId) != null) _changes.add(null);
      return;
    }
    final card = cardsFor(playerId).where((c) => c.id == pickId).firstOrNull;
    if (card == null || !card.enabled) return;
    _picks[playerId] = _Pick(cardId: pickId, count: count.clamp(1, card.maxCount), locked: locked);
    _changes.add(null);
  }

  /// Ends the round, now or at the timer: settles each player's outcome, sends
  /// each capable phone its end and returns the outcomes. A second call
  /// returns the same outcomes and sends nothing.
  Map<String, ChoiceOutcome> close() {
    final done = _outcomes;
    if (done != null) return done;
    _cancelWatching();
    final outcomes = {for (final id in players) id: _outcomeFor(id)};
    _outcomes = outcomes;
    for (final entry in outcomes.entries) {
      final o = entry.value;
      server.send(entry.key, ChoicesEndMessage(round: round, result: o.cardId, count: o.count, byDefault: o.byDefault));
    }
    _changes.add(null);
    return outcomes;
  }

  /// Cancels the timers and listeners. The round sends nothing after it.
  Future<void> dispose() async {
    _cancelWatching();
    for (final t in _awayTimers.values) {
      t.cancel();
    }
    _awayTimers.clear();
    await _changes.close();
  }

  void _cancelWatching() {
    _endTimer?.cancel();
    _endTimer = null;
    unawaited(_messageSub?.cancel());
    _messageSub = null;
    unawaited(_serverSub?.cancel());
    _serverSub = null;
    for (final t in _awayTimers.values) {
      t.cancel();
    }
    _awayTimers.clear();
  }

  ChoiceOutcome _outcomeFor(String playerId) {
    final held = _picks[playerId];
    if (held != null) return ChoiceOutcome(cardId: held.cardId, count: held.count, byDefault: held.byDefault);
    return ChoiceOutcome(cardId: defaultId, count: defaultId == null ? 0 : 1, byDefault: true);
  }

  void _onMessage(ControllerMessage m) {
    final message = m.message;
    if (message is! ChoicePickMessage || message.round != round) return;
    final sender = server.snapshot.controllers.where((c) => c.controllerId == m.controllerId).firstOrNull;
    if (sender == null || !sender.supports(Capability.choices)) return;
    pick(m.controllerId, pickId: message.pick, count: message.count, locked: message.locked);
  }

  void _onServerChange(HostSnapshot snapshot) {
    final live = _connectedPlayers(snapshot);
    for (final id in players) {
      final isLive = live.contains(id);
      if (isLive && _connected.add(id)) {
        _awayTimers.remove(id)?.cancel();
        _sendState(id);
      } else if (!isLive && _connected.remove(id)) {
        _startAwayTimer(id);
      }
    }
  }

  Set<String> _connectedPlayers(HostSnapshot snapshot) => {for (final c in snapshot.connected) c.controllerId};

  void _startAwayTimer(String playerId) {
    _awayTimers[playerId]?.cancel();
    _awayTimers[playerId] = Timer(grace, () {
      _awayTimers.remove(playerId);
      final card = defaultId;
      if (isClosed) return;
      if (card == null) {
        _picks.remove(playerId);
      } else {
        _picks[playerId] = _Pick(cardId: card, count: 1, locked: true, byDefault: true);
      }
      _changes.add(null);
    });
  }

  void _sendState(String playerId) {
    final held = _picks[playerId];
    server.send(
      playerId,
      ChoicesMessage(
        round: round,
        title: title,
        cards: cardsFor(playerId),
        endsInMs: (_endsAtMs - nowMs()).clamp(0, duration.inMilliseconds),
        defaultId: defaultId,
        currency: currency,
        picked: held?.cardId,
        pickedCount: held?.count ?? 1,
        locked: held?.locked ?? false,
      ),
    );
  }
}
