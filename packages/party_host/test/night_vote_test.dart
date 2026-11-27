import 'dart:async';
import 'dart:math';

import 'package:connection/connection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';
import 'package:party_host/src/night/night_pick_provider.dart';
import 'package:party_host/src/night/night_settings.dart';
import 'package:party_host/src/night/night_vote.dart';
import 'package:party_host/src/night/vote_round.dart';
import 'package:protocol/protocol.dart';

import 'support/fake_prefs.dart';
import 'support/host_harness.dart';
import 'support/night_harness.dart';

const _player = 'phone-1';

/// The most time a test waits for a state, so a stuck test fails.
const _waitLimit = Duration(seconds: 5);

/// The gap between two polls.
const _pollStep = Duration(milliseconds: 10);

/// The seed of the night's random source in the tests.
const _seed = 1;

/// How many votes the first game gets in the tie test, and the second one too.
const _tieVotes = 1;

/// A vote round the test finishes by hand.
final class _FakeHandle implements VoteHandle {
  _FakeHandle() : atClose = {};

  /// The outcomes [closeNow] closes the round with.
  final Map<String, ChoiceOutcome> atClose;

  final _done = Completer<Map<String, ChoiceOutcome>>();
  bool isDisposed = false;

  @override
  Future<Map<String, ChoiceOutcome>> get done => _done.future;

  /// Closes the round as its timer would, with [outcomes].
  void finish(Map<String, ChoiceOutcome> outcomes) => _done.complete(outcomes);

  @override
  Map<String, ChoiceOutcome> closeNow() {
    if (!_done.isCompleted) _done.complete(atClose);
    return atClose;
  }

  @override
  void dispose() => isDisposed = true;
}

/// What the fake starter was asked.
final class _Started {
  final setups = <ChoiceRoundSetup>[];
  final durations = <Duration>[];
}

ChoiceOutcome _vote(String id) => ChoiceOutcome(cardId: id, count: 1, byDefault: false);

/// A container with a vote that starts [handle] (null: no phone can vote) and the vote picker set.
ProviderContainer _container(_Started started, VoteHandle? handle) {
  final container = ProviderContainer(
    overrides: [
      prefsProvider.overrideWithValue(FakePrefs()),
      gamePlayersProvider.overrideWith(TestRoster.new),
      arenaMapLibraryProvider.overrideWith((ref) => testMaps()),
      nightRandomProvider.overrideWithValue(Random(_seed)),
      voteStarterProvider.overrideWithValue((setup, duration) {
        started.setups.add(setup);
        started.durations.add(duration);
        return handle;
      }),
    ],
  );
  addTearDown(container.dispose);
  container.read(nightSettingsProvider.notifier).update(const NightSettings(picker: NightPicker.vote));
  return container;
}

/// The ids of the games the open vote offers.
List<String> _offeredIds(ProviderContainer container) => [
  for (final variant in container.read(nightVoteProvider)!.offered) variant.id,
];

void main() {
  test('the starter gets the 5 s vote and at most 4 cards from the default pool of 7', () async {
    final started = _Started();
    final container = _container(started, _FakeHandle());
    unawaited(container.read(nightVoteProvider.notifier).run(1));

    expect(started.durations, [const Duration(seconds: 5)]);
    expect(started.setups.single.cardsFor(_player), hasLength(maxVoteCards));
    final state = container.read(nightVoteProvider)!;
    expect(state.isOpen, isTrue);
    expect(state.secondsLeft, 5);
    expect(state.offered, hasLength(maxVoteCards));
  });

  test('a vote that closes by itself picks the game with the most votes', () async {
    final handle = _FakeHandle();
    final container = _container(_Started(), handle);
    final run = container.read(nightVoteProvider.notifier).run(1);
    final ids = _offeredIds(container);

    handle.finish({'a': _vote(ids[1]), 'b': _vote(ids[1]), 'c': _vote(ids[0])});
    await run;

    final state = container.read(nightVoteProvider)!;
    expect(state.isOpen, isFalse);
    expect(state.result!.variant.id, ids[1]);
    expect(state.result!.votes, 2);
    expect(state.result!.byChance, isFalse);
    expect(handle.isDisposed, isTrue);
  });

  test('nobody voting picks a random offered game by chance', () async {
    final handle = _FakeHandle();
    final container = _container(_Started(), handle);
    final run = container.read(nightVoteProvider.notifier).run(1);
    final ids = _offeredIds(container);

    handle.finish(const {});
    await run;

    final result = container.read(nightVoteProvider)!.result!;
    expect(ids, contains(result.variant.id));
    expect(result.votes, 0);
    expect(result.byChance, isTrue);
  });

  test('a 1-1 tie is settled at random between the two tied games', () async {
    final handle = _FakeHandle();
    final container = _container(_Started(), handle);
    final run = container.read(nightVoteProvider.notifier).run(1);
    final ids = _offeredIds(container);

    handle.finish({'a': _vote(ids[0]), 'b': _vote(ids[1])});
    await run;

    final result = container.read(nightVoteProvider)!.result!;
    expect([ids[0], ids[1]], contains(result.variant.id));
    expect(result.votes, _tieVotes);
    expect(result.byChance, isTrue);
  });

  test('takeResult closes an open vote early with the votes so far', () async {
    final handle = _FakeHandle();
    final container = _container(_Started(), handle);
    final notifier = container.read(nightVoteProvider.notifier);
    final run = notifier.run(1);
    final id = _offeredIds(container).last;
    handle.atClose['a'] = _vote(id);

    final result = notifier.takeResult(1);

    expect(result!.variant.id, id);
    expect(container.read(nightVoteProvider)!.isOpen, isFalse);
    expect(handle.isDisposed, isTrue);
    expect(notifier.takeResult(2), isNull, reason: 'no vote ran for round 2');
    await run;
  });

  test('run twice for one round starts one vote', () async {
    final started = _Started();
    final container = _container(started, _FakeHandle());
    final notifier = container.read(nightVoteProvider.notifier);
    unawaited(notifier.run(1));
    unawaited(notifier.run(1));

    expect(started.setups, hasLength(1));
  });

  test('with no phone to vote the vote is settled at once at random', () async {
    final container = _container(_Started(), null);
    await container.read(nightVoteProvider.notifier).run(1);

    final state = container.read(nightVoteProvider)!;
    expect(state.isOpen, isFalse);
    expect(state.result!.byChance, isTrue);
    expect(state.result!.votes, 0);
  });

  testWidgets('secondsLeft counts down one a second while the vote is open', (tester) async {
    final container = _container(_Started(), _FakeHandle());
    final notifier = container.read(nightVoteProvider.notifier);
    unawaited(notifier.run(1));

    await tester.pump(const Duration(seconds: 1));
    expect(container.read(nightVoteProvider)!.secondsLeft, 4);
    await tester.pump(const Duration(seconds: 2));
    expect(container.read(nightVoteProvider)!.secondsLeft, 2);
    notifier.cancel();
  });

  test('a night that ends cancels the vote and lets go of its round', () async {
    final handle = _FakeHandle();
    final container = _container(_Started(), handle);
    final night = container.read(partyNightProvider.notifier)..start(length: NightLength.three, awards: threeAwards);
    unawaited(container.read(nightVoteProvider.notifier).run(1));
    expect(container.read(nightVoteProvider), isNotNull);

    night.end();

    expect(container.read(nightVoteProvider), isNull);
    expect(handle.isDisposed, isTrue);
  });

  group('ServerVoteHandle', () {
    Future<({ServerVoteHandle handle, ChoiceRound round})> setup() async {
      final link = InProcessListener();
      final server = HostServer(
        hostId: 'host-1',
        hostName: 'Test TV',
        appVersion: 'test',
        listeners: [link],
        heartbeatInterval: const Duration(milliseconds: 100),
        heartbeatTimeout: const Duration(milliseconds: 1500),
        capabilities: const [Capability.choices],
      );
      await server.start();
      final client = ControllerClient(
        identity: const ControllerIdentity(
          controllerId: _player,
          name: 'Phone',
          platform: 'android',
          appVersion: 'test',
          capabilities: [Capability.choices],
        ),
        connector: InProcessConnector(link),
        heartbeatInterval: const Duration(milliseconds: 100),
        heartbeatTimeout: const Duration(milliseconds: 1500),
        retryDelays: const [Duration(minutes: 5)],
      );
      final seen = <ChoicesMessage>[];
      final sub = client.choices.listen(seen.add);
      client.connect(
        HostAddress.local(hostId: server.hostId, name: 'Test TV'),
        code: server.pairingCode,
      );
      await client.changes.firstWhere((s) => s.isConnected).timeout(_waitLimit);
      final host = ServerGameHost(server);
      final round = ChoiceRound(
        server: server,
        players: const [_player],
        setup: ChoiceRoundSetup(
          round: 1,
          title: 'Vote',
          cardsFor: (_) => const [ChoiceCard(id: 'a', title: 'A'), ChoiceCard(id: 'b', title: 'B')],
        ),
        timing: ChoiceTiming(duration: const Duration(minutes: 5), grace: const Duration(minutes: 5), nowMs: () => 0),
      );
      final oldPhones = OldPhoneChoices(round: round, host: host, input: server.messages);
      round.start();
      oldPhones.start();
      final handle = ServerVoteHandle(round: round, oldPhones: oldPhones);
      addTearDown(() async {
        handle.dispose();
        await sub.cancel();
        await client.dispose();
        await host.dispose();
        await server.dispose();
      });
      final watch = Stopwatch()..start();
      while (seen.isEmpty) {
        if (watch.elapsed > _waitLimit) throw TimeoutException('the phone got no round');
        await Future<void>.delayed(_pollStep);
      }
      return (handle: handle, round: round);
    }

    test('a card picked on the host shows in closeNow and in done', () async {
      final s = await setup();
      s.round.pick(_player, pickId: 'a');

      final outcomes = s.handle.closeNow();

      expect(outcomes[_player], _vote('a'));
      expect(await s.handle.done, outcomes);
    });

    test('a round nobody picked in gives an abstain outcome', () async {
      final s = await setup();

      final outcomes = s.handle.closeNow();

      expect(outcomes[_player], const ChoiceOutcome(cardId: null, count: 0, byDefault: true));
    });
  });
}
