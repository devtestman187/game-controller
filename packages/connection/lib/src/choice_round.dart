import 'dart:async';

import 'package:protocol/protocol.dart';

import 'choice_round_setup.dart';
import 'host_server.dart';
import 'host_types.dart';

part 'choice_round_state.dart';

/// One choice round on the phones (M17 phone1a): the host offers each player a
/// list of cards, takes their picks until the timer ends, and settles each
/// player's outcome. A pick can be changed until then; nothing chosen, or a
/// player away for [ChoiceTiming.grace], gets [defaultId].
///
/// Only a phone that lists [Capability.choices] is sent the round. The others
/// (old phones) still get an outcome, and their picks come in through
/// [pick] (the old-phone fallback).
final class ChoiceRound {
  /// Builds a round for [players]; nothing is sent or timed until [start].
  ChoiceRound({required this.server, required this.players, required this.setup, required this.timing});

  /// The host the round sends through and listens to for picks and connections.
  final HostServer server;

  /// The IDs of the players who take part.
  final List<String> players;

  /// What the round shows and settles with: the title, the cards, the default and the currency.
  final ChoiceRoundSetup setup;

  /// How long the round lasts, how long a player may stay away, and the clock.
  final ChoiceTiming timing;

  /// The cards one player may pick from, asked each time so a list may change.
  List<ChoiceCard> Function(String playerId) get cardsFor => setup.cardsFor;

  /// The card that applies when nothing is chosen, or null when nothing does. The build stop must set it to
  /// the build stop's default card; with null an away player's pick is removed and the player abstains (the away timer).
  String? get defaultId => setup.defaultId;

  /// The unit the costs are in, or null when there are none.
  String? get currency => setup.currency;

  final _picks = <String, _Pick>{};
  final _awayTimers = <String, Timer>{};
  final _connected = <String>{};
  // Players whose pick was stored during a pause; resume() must not overwrite them with the default.
  final _pickedWhilePaused = <String>{};
  final _changes = StreamController<void>.broadcast();
  Map<String, ChoiceOutcome>? _outcomes;
  Timer? _endTimer;
  StreamSubscription<ControllerMessage>? _messageSub;
  StreamSubscription<HostSnapshot>? _serverSub;
  int _endsAtMs = 0;
  int? _pausedLeftMs;
  bool _isStarted = false;
  bool _isDisposed = false;

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
  /// starts the timer. Does nothing once started, closed or disposed.
  void start() {
    if (_isStarted || _isDisposed || isClosed) return;
    assert(_isDefaultOffered(), 'the default card must be in every player\'s list and enabled');
    _isStarted = true;
    _endsAtMs = timing.nowMs() + timing.duration.inMilliseconds;
    _messageSub = server.messages.listen(_onMessage);
    _serverSub = server.changes.listen(_onServerChange);
    _endTimer = Timer(timing.duration, close);
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

  /// Whether the round is paused: its timers are frozen and the phones are told.
  bool get isPaused => _pausedLeftMs != null;

  /// Freezes the end timer and every away timer, keeping the time left, and
  /// tells each connected phone (paused true, [ChoicesMessage.endsInMs] the time
  /// left). While paused no player is defaulted and no end comes by timer; picks
  /// are still stored and [close] still works. Does nothing unless the round is
  /// started, open, not disposed and not already paused.
  void pause() {
    if (!_isStarted || _isDisposed || isClosed || isPaused) return;
    _pausedLeftMs = _timeLeftMs();
    _endTimer?.cancel();
    _endTimer = null;
    _cancelAwayTimers();
    _sendToConnected();
  }

  /// Ends a pause: the end timer runs for the time left, every player who is
  /// not connected, not already set to the default and not picked during the
  /// pause gets a full grace again, and the phones are told. A pick made during
  /// the pause is kept, not overwritten. Does nothing unless the round is paused.
  void resume() {
    final left = _pausedLeftMs;
    if (left == null || _isDisposed || isClosed) return;
    _pausedLeftMs = null;
    _endsAtMs = timing.nowMs() + left;
    _endTimer = Timer(Duration(milliseconds: left), close);
    for (final id in players) {
      if (!_connected.contains(id) && _picks[id]?.byDefault != true && !_pickedWhilePaused.contains(id)) {
        _startAwayTimer(id);
      }
    }
    _pickedWhilePaused.clear();
    _sendToConnected();
  }

  /// Stores [pickId] for [playerId]; null, or an unlocked pick, is an undo.
  /// Ignores a player not in the round, a card the player's list lacks or that
  /// is disabled, and any pick once the round is closed or disposed. [count] is
  /// held to 1 up to the card's maxCount.
  void pick(String playerId, {String? pickId, int count = 1, bool locked = false}) {
    if (_isDisposed || isClosed || !players.contains(playerId)) return;
    if (pickId == null) {
      if (_picks.remove(playerId) != null) _changes.add(null);
      return;
    }
    final card = cardsFor(playerId).where((c) => c.id == pickId).firstOrNull;
    if (card == null || !card.enabled) return;
    _picks[playerId] = _Pick(cardId: pickId, count: count.clamp(1, card.maxCount), locked: locked);
    if (isPaused) _pickedWhilePaused.add(playerId);
    _changes.add(null);
  }

  /// Ends the round, now or at the timer: settles each player's outcome, sends
  /// each capable phone its end and returns the outcomes. A second call
  /// returns the same outcomes and sends nothing. After [dispose] it returns
  /// the stored outcomes, or an empty map, and sends nothing.
  Map<String, ChoiceOutcome> close() {
    final done = _outcomes;
    if (done != null) return done;
    if (_isDisposed) return const {};
    _cancelWatching();
    _pausedLeftMs = null;
    final outcomes = {for (final id in players) id: _outcomeFor(id)};
    _outcomes = outcomes;
    for (final entry in outcomes.entries) {
      final o = entry.value;
      server.send(
        entry.key,
        ChoicesEndMessage(round: setup.round, result: o.cardId, count: o.count, byDefault: o.byDefault),
      );
    }
    _changes.add(null);
    return outcomes;
  }

  /// Cancels the timers and listeners and ends any pause. The round sends nothing after it.
  Future<void> dispose() async {
    _isDisposed = true;
    _pausedLeftMs = null;
    _cancelWatching();
    await _changes.close();
  }

  /// Whether the default card, when there is one, is in every player's list and enabled.
  bool _isDefaultOffered() {
    final id = defaultId;
    if (id == null) return true;
    return players.every((p) => cardsFor(p).any((c) => c.id == id && c.enabled));
  }

  void _cancelWatching() {
    _endTimer?.cancel();
    _endTimer = null;
    unawaited(_messageSub?.cancel());
    _messageSub = null;
    unawaited(_serverSub?.cancel());
    _serverSub = null;
    _cancelAwayTimers();
  }

  void _cancelAwayTimers() {
    for (final t in _awayTimers.values) {
      t.cancel();
    }
    _awayTimers.clear();
  }

  int _timeLeftMs() => (_endsAtMs - timing.nowMs()).clamp(0, timing.duration.inMilliseconds);

  void _sendToConnected() {
    for (final id in players) {
      if (_connected.contains(id)) _sendState(id);
    }
  }

  ChoiceOutcome _outcomeFor(String playerId) {
    final held = _picks[playerId];
    if (held != null) return ChoiceOutcome(cardId: held.cardId, count: held.count, byDefault: held.byDefault);
    return ChoiceOutcome(cardId: defaultId, count: defaultId == null ? 0 : 1, byDefault: true);
  }

  void _onMessage(ControllerMessage m) {
    if (_isDisposed) return;
    final message = m.message;
    if (message is! ChoicePickMessage || message.round != setup.round) return;
    final sender = server.snapshot.controllers.where((c) => c.controllerId == m.controllerId).firstOrNull;
    if (sender == null || !sender.supports(Capability.choices)) return;
    pick(m.controllerId, pickId: message.pick, count: message.count, locked: message.locked);
  }

  void _onServerChange(HostSnapshot snapshot) {
    if (_isDisposed) return;
    final live = _connectedPlayers(snapshot);
    for (final id in players) {
      final isLive = live.contains(id);
      if (isLive && _connected.add(id)) {
        _awayTimers.remove(id)?.cancel();
        _sendState(id);
      } else if (!isLive && _connected.remove(id)) {
        if (!isPaused) _startAwayTimer(id);
      }
    }
  }

  Set<String> _connectedPlayers(HostSnapshot snapshot) => {for (final c in snapshot.connected) c.controllerId};

  void _startAwayTimer(String playerId) {
    _awayTimers[playerId]?.cancel();
    _awayTimers[playerId] = Timer(timing.grace, () {
      _awayTimers.remove(playerId);
      if (isClosed) return;
      final card = defaultId;
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
        round: setup.round,
        title: setup.title,
        cards: [for (final card in cardsFor(playerId)) _shownCard(card)],
        endsInMs: _pausedLeftMs ?? _timeLeftMs(),
        defaultId: defaultId,
        currency: currency,
        picked: held?.cardId,
        pickedCount: held?.count ?? 1,
        locked: held?.locked ?? false,
        paused: isPaused,
      ),
    );
  }

  /// The card as the phone shows it: the same card with its title cut to [ChoiceCard.maxTitleLength].
  ChoiceCard _shownCard(ChoiceCard card) {
    return ChoiceCard(
      id: card.id,
      title: _cutTitle(card.title),
      detail: card.detail,
      cost: card.cost,
      maxCount: card.maxCount,
      enabled: card.enabled,
    );
  }

  /// Cuts [title] to [ChoiceCard.maxTitleLength] code points, so a character outside the Basic Multilingual
  /// Plane (an emoji) is never split in two.
  String _cutTitle(String title) {
    if (title.runes.length <= ChoiceCard.maxTitleLength) return title;
    return String.fromCharCodes(title.runes.take(ChoiceCard.maxTitleLength));
  }
}
