import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';

import 'package:party_host/src/night/night_pick_provider.dart';
import 'package:party_host/src/night/night_settings.dart';
import 'package:party_host/src/night/night_vote.dart';
import 'package:party_host/src/night/vote_round.dart';

import 'package:protocol/protocol.dart' show ControllerButton;

import '../support/night_harness.dart';
import 'systest_support.dart';

/// The ids the three phones have in every test.
const _ids = ['phone-1', 'phone-2', 'phone-3'];

/// The points a round gives the three phones.
const _points = {'phone-1': 3, 'phone-2': 2, 'phone-3': 1};

void main() {
  for (final picker in NightPicker.values) {
    systestWidgets('a 3-phone night of 3 rounds runs to its end with the ${picker.name} picker', (tester) async {
      final t = await openSystest(tester, picker: picker);
      for (final id in _ids) {
        await t.addPhone(id);
      }
      final night = t.container.read(partyNightProvider.notifier)
        ..start(length: NightLength.three, awards: threeAwards);
      expect(t.playerIds, _ids);

      final played = <String>[];
      for (var round = 1; round <= 3; round++) {
        if (picker == NightPicker.vote) {
          final run = t.container.read(nightVoteProvider.notifier).run(round);
          await t.until(() => t.phones.every((p) => p.offers.isNotEmpty && p.offers.last.round == round));
          expect(t.container.read(nightVoteProvider)!.isOpen, isTrue);
          for (final p in t.phones) {
            p.vote(0);
          }
          await t.elapse(voteDuration + const Duration(seconds: 1));
          await run;
          expect(t.container.read(nightVoteProvider)!.result!.votes, 3, reason: 'every phone voted for card 0');
        }
        final pick = t.container.read(nightPickProvider.notifier).pickFor(round);
        if (picker == NightPicker.host || picker == NightPicker.rotating) {
          expect(pick, isNull, reason: 'the host chooses the game');
        } else {
          expect(pick, isNotNull, reason: 'the picker names round $round game');
          played.add(pick!.variant.id);
        }
        t.recordRound(_points);
        expect(t.container.read(partyNightProvider)!.round, round);
      }

      final done = t.container.read(partyNightProvider)!;
      expect(done.isOver, isTrue);
      expect(done.totals, {'phone-1': 9, 'phone-2': 6, 'phone-3': 3});
      expect(done.outcomes, isNotEmpty, reason: 'the awards are decided when the last round is in');
      if (picker == NightPicker.shuffle || picker == NightPicker.playlist) {
        expect(played.toSet(), hasLength(3), reason: 'no game twice in three rounds');
      }
      night.end();
      expect(t.container.read(partyNightProvider), isNull);
      expect(t.container.read(nightPickProvider), isNull);
    });
  }

  systestWidgets('a phone that drops in the middle of the vote leaves a vote that settles', (tester) async {
    final t = await openSystest(tester, webSocket: true);
    for (final id in _ids) {
      await t.addPhone(id);
    }
    t.container.read(partyNightProvider.notifier).start(length: NightLength.three, awards: threeAwards);
    final run = t.container.read(nightVoteProvider.notifier).run(1);
    await t.until(() => t.phones.every((p) => p.offers.isNotEmpty));

    t.phones[0].vote(1);
    t.phones[1].vote(0);
    t.phones[2].vote(1);
    await t.settle();
    t.phones[1].client.disconnect();
    await t.until(() => t.host.players.any((p) => p.id == 'phone-2' && p.away));
    await t.elapse(voteDuration + const Duration(seconds: 1));
    await run;

    final state = t.container.read(nightVoteProvider)!;
    expect(state.isOpen, isFalse, reason: 'the vote closed on its own timer');
    final winner = state.offered[1].id;
    expect(state.result!.variant.id, winner, reason: 'two phones that stayed outvote the one that left');
    final pick = t.container.read(nightPickProvider.notifier).pickFor(1);
    expect(pick!.variant.id, winner);
    t.recordRound(_points);
    expect(t.container.read(partyNightProvider)!.round, 1, reason: 'the night goes on past the vote');
  });

  systestWidgets('every phone leaving before it votes still settles the vote at random, with no hang', (tester) async {
    final t = await openSystest(tester, webSocket: true);
    for (final id in _ids) {
      await t.addPhone(id);
    }
    t.container.read(partyNightProvider.notifier).start(length: NightLength.three, awards: threeAwards);
    final run = t.container.read(nightVoteProvider.notifier).run(1);
    await t.until(() => t.phones.every((p) => p.offers.isNotEmpty));

    for (final p in t.phones) {
      p.client.disconnect();
    }
    await t.elapse(voteDuration + const Duration(seconds: 1));
    await run;

    final result = t.container.read(nightVoteProvider)!.result!;
    expect(result.votes, 0);
    expect(result.byChance, isTrue);
  });

  systestWidgets('an old phone votes with its buttons next to new phones in one night', (tester) async {
    final t = await openSystest(tester);
    await t.addPhone('phone-1');
    await t.addPhone('phone-2');
    final old = await t.addOldPhone('phone-3');
    t.container.read(partyNightProvider.notifier).start(length: NightLength.three, awards: threeAwards);

    final run = t.container.read(nightVoteProvider.notifier).run(1);
    await t.until(() => t.phones.every((p) => p.offers.isNotEmpty) && old.latestLabels != null);
    final offered = t.container.read(nightVoteProvider)!.offered;
    expect(
      old.latestLabels!.keys,
      containsAll([ControllerButton.a, ControllerButton.b]),
      reason: 'the old phone shows the games',
    );
    expect(offered.length, greaterThanOrEqualTo(3));

    // Old phone: B is the second card. New phones: one votes the second card, one the first.
    old.press({ControllerButton.b});
    t.phones[0].vote(1);
    t.phones[1].vote(0);
    await t.elapse(voteDuration + const Duration(seconds: 1));
    await run;

    final result = t.container.read(nightVoteProvider)!.result!;
    expect(result.variant.id, offered[1].id, reason: 'the old phone\'s B press counted as a vote for card 2');
    expect(result.votes, 2);
    expect(result.byChance, isFalse);
  });
}
