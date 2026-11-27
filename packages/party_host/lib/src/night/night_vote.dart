import 'dart:async';

import 'package:connection/connection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import 'night_pick_provider.dart';
import 'party_night.dart';
import 'variant.dart';
import 'vote_round.dart';

/// How long a phone may stay away from the vote before it abstains, in seconds: the vote is short, so a brief gap.
const _voteGraceS = 2;

/// How often the countdown moves on: a whole second, the unit it shows.
const _countdownTick = Duration(seconds: 1);

/// A vote round that is running: it closes by its own timer or by [closeNow].
abstract interface class VoteHandle {
  /// Completes with each player's outcome when the round closes, by its timer or by [closeNow].
  Future<Map<String, ChoiceOutcome>> get done;

  /// Closes the round now and returns the outcomes; a round already closed returns the same ones.
  Map<String, ChoiceOutcome> closeNow();

  /// Stops the round and lets go of what it holds.
  void dispose();
}

/// Starts a vote round for [setup] lasting [duration], or returns null when no phone can vote.
typedef VoteStarter = VoteHandle? Function(ChoiceRoundSetup setup, Duration duration);

/// A [VoteHandle] over a started [ChoiceRound] and the [OldPhoneChoices] that play its old phones.
final class ServerVoteHandle implements VoteHandle {
  /// Wraps [round], which must be started, and [oldPhones].
  ServerVoteHandle({required this.round, required this.oldPhones}) {
    if (round.isClosed) {
      _done.complete(round.outcomes);
    } else {
      _sub = round.changes.listen((_) => _complete(), onDone: _complete);
    }
  }

  /// The round the phones vote in.
  final ChoiceRound round;

  /// The old phones' buttons for the round.
  final OldPhoneChoices oldPhones;

  final _done = Completer<Map<String, ChoiceOutcome>>();
  StreamSubscription<void>? _sub;

  @override
  Future<Map<String, ChoiceOutcome>> get done => _done.future;

  @override
  Map<String, ChoiceOutcome> closeNow() {
    final outcomes = round.close();
    _complete();
    return outcomes;
  }

  @override
  void dispose() {
    _complete();
    // A round let go of before it closed has no votes; whoever awaits `done` must not wait for ever.
    if (!_done.isCompleted) _done.complete(const {});
    unawaited(_sub?.cancel());
    unawaited(oldPhones.dispose());
    unawaited(round.dispose());
  }

  void _complete() {
    if (round.isClosed && !_done.isCompleted) _done.complete(round.outcomes);
  }
}

/// Starts the vote on the phones; a test overrides it with a fake. Null when the host is not a server host or no real
/// player (not the local one, not a simulated one) is there to vote.
final voteStarterProvider = Provider<VoteStarter>((ref) {
  return (setup, duration) {
    final host = ref.read(gameHostProvider);
    final players = [
      for (final p in ref.read(gamePlayersProvider))
        if (!p.local && !p.simulated) p.id,
    ];
    if (host is! ServerGameHost || players.isEmpty) return null;
    final round = ChoiceRound(
      server: host.server,
      players: players,
      setup: setup,
      timing: ChoiceTiming(
        duration: duration,
        grace: const Duration(seconds: _voteGraceS),
        nowMs: () => host.nowMs,
      ),
    );
    final oldPhones = OldPhoneChoices(round: round, host: host, input: host.server.messages);
    round.start();
    oldPhones.start();
    return ServerVoteHandle(round: round, oldPhones: oldPhones);
  };
});

/// How long a vote lasts; a test overrides it.
final nightVoteDurationProvider = Provider<Duration>((_) => voteDuration);

/// A vote for one round: what is offered, the seconds left and, once it has closed, what it settled.
final class NightVoteState {
  /// Groups the vote of [round] over [offered]; [result] is null while the vote is open.
  const NightVoteState({required this.round, required this.offered, required this.secondsLeft, this.result});

  /// The round, counting from 1, the vote picks the game for.
  final int round;

  /// The games the phones vote on.
  final List<Variant> offered;

  /// Whole seconds left to vote; 0 once the vote has closed.
  final int secondsLeft;

  /// What the vote settled, or null while it is open.
  final VoteResult? result;

  /// Whether the phones can still vote.
  bool get isOpen => result == null;
}

/// Runs the night's vote round by round: see [run], [takeResult] and [cancel].
class NightVoteNotifier extends Notifier<NightVoteState?> {
  VoteHandle? _handle;
  Timer? _tick;

  @override
  NightVoteState? build() {
    // A night that ends takes its vote with it.
    ref.listen(partyNightProvider, (_, night) {
      if (night == null) cancel();
    });
    ref.onDispose(_release);
    return null;
  }

  /// Starts the vote for [round] (counting from 1). Does nothing when the state already holds that round. With no
  /// game to offer there is no vote, with one game it is settled at once, and with no phone to vote it is settled at
  /// random.
  Future<void> run(int round) async {
    if (state?.round == round) return;
    _release();
    final offered = ref.read(nightPickProvider.notifier).voteOffer();
    if (offered.isEmpty) {
      state = null;
      return;
    }
    final duration = ref.read(nightVoteDurationProvider);
    final handle = offered.length == 1
        ? null
        : ref.read(voteStarterProvider)(voteSetup(round: round, offered: offered), duration);
    if (handle == null) {
      state = _settled(round, offered, const {});
      return;
    }
    _handle = handle;
    state = NightVoteState(round: round, offered: offered, secondsLeft: duration.inSeconds);
    _tick = Timer.periodic(_countdownTick, (_) => _onTick());
    final outcomes = await handle.done;
    final open = state;
    if (_handle == handle && open != null && open.isOpen) _finish(open, outcomes);
  }

  /// The result of the vote for [round], or null when none was run for it. A vote still open is closed now.
  VoteResult? takeResult(int round) {
    final open = state;
    if (open == null || open.round != round) return null;
    final handle = _handle;
    if (open.isOpen && handle != null) _finish(open, handle.closeNow());
    return state?.result;
  }

  /// Closes the vote, lets go of it and clears the state.
  void cancel() {
    _handle?.closeNow();
    _release();
    state = null;
  }

  void _onTick() {
    final open = state;
    if (open == null || !open.isOpen || open.secondsLeft <= 0) return;
    state = NightVoteState(round: open.round, offered: open.offered, secondsLeft: open.secondsLeft - 1);
  }

  void _finish(NightVoteState open, Map<String, ChoiceOutcome> outcomes) {
    _release();
    state = _settled(open.round, open.offered, outcomes);
  }

  NightVoteState _settled(int round, List<Variant> offered, Map<String, ChoiceOutcome> outcomes) {
    final result = settleVote(offered: offered, outcomes: outcomes, random: ref.read(nightRandomProvider));
    return NightVoteState(round: round, offered: offered, secondsLeft: 0, result: result);
  }

  void _release() {
    _tick?.cancel();
    _tick = null;
    _handle?.dispose();
    _handle = null;
  }
}

/// The night's vote: see [NightVoteNotifier]. Null when no vote has run this night.
final nightVoteProvider = NotifierProvider<NightVoteNotifier, NightVoteState?>(NightVoteNotifier.new);
