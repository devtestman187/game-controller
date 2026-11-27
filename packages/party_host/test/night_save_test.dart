import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';
import 'package:party_host/src/night/night_save.dart';

import 'support/fake_prefs.dart';
import 'support/night_harness.dart';

void main() {
  group('NightSave', () {
    test('a night with rounds, awards and a player who left reads back as it was', () {
      final prefs = FakePrefs();
      final night =
          NightState.start(
                length: NightLength.three,
                awards: threeAwards,
                players: [nightPlayer('p1', 1, 'Mia'), nightPlayer('p2', 2)],
              )
              .record(
                roundResult(
                  points: {'p1': 5, 'p2': 2},
                  winners: {'p1'},
                  stats: {
                    'p1': {'snaps': 1},
                  },
                ),
              )
              .record(roundResult(points: {'p1': 1, 'p2': 4}))
              .remember([nightPlayer('p1', 1, 'Mia')])
              .awarded([
                const NightAwardOutcome(award: NightAward.comeback, winners: ['p1'], value: 2),
              ]);
      NightSave(prefs).save(night);

      final restored = NightSave(prefs).load();
      expect(restored, isNotNull);
      expect(restored!.round, 2);
      expect(restored.totals, {'p1': 6, 'p2': 6});
      expect(restored.counter('p1', 'snaps'), 1);
      expect(restored.awards, threeAwards);
      expect(restored.outcomes.single.award, NightAward.comeback);
      expect(restored.outcomes.single.winners, ['p1']);
      expect(restored.outcomes.single.value, 2);
      expect(
        [
          for (final row in restored.rows([nightPlayer('p1', 1, 'Mia')])) (row.id, row.total, row.isHere, row.nickname),
        ],
        [('p1', 9, true, 'Mia'), ('p2', 6, false, null)],
      );
    });

    test('a garbled, mistyped or unknown save is dropped and reads as no night', () async {
      final prefs = FakePrefs();
      for (final raw in ['not json', '[1, 2]', '{}']) {
        await prefs.setString('party_night_v1', raw);
        expect(NightSave(prefs).load(), isNull, reason: raw);
        expect(prefs.containsKey('party_night_v1'), isFalse, reason: raw);
      }

      NightSave(
        prefs,
      ).save(NightState.start(length: NightLength.three, awards: threeAwards).record(roundResult(points: {'p1': 5})));
      final valid = jsonDecode(prefs.getString('party_night_v1')!) as Map<String, Object?>;
      expect(NightSave(prefs).load(), isNotNull, reason: 'a valid save reads back');
      for (final broken in [
        {...valid, 'round': 'one'},
        {
          ...valid,
          'awards': ['nope', 'comeback', 'sharpshooter'],
        },
      ]) {
        await prefs.setString('party_night_v1', jsonEncode(broken));
        expect(NightSave(prefs).load(), isNull, reason: '$broken');
        expect(prefs.containsKey('party_night_v1'), isFalse, reason: '$broken');
      }
    });

    test('one host saves a round and a second host on the same prefs resumes it at round 1', () {
      final prefs = FakePrefs();
      final (container: first, :roster) = savingNightContainer(prefs: prefs);
      roster.put([nightPlayer('p1', 1, 'Mia')]);
      first.read(partyNightProvider.notifier)
        ..start(length: NightLength.three, awards: threeAwards)
        ..recordRound(roundResult(points: {'p1': 5}));

      final (container: second, roster: _) = savingNightContainer(prefs: prefs);
      final resumed = second.read(partyNightProvider);
      expect(resumed, isNotNull);
      expect(resumed!.round, 1);
      expect(resumed.totals, {'p1': 5});
    });

    test('ending the night clears the save, so the next host has no night', () {
      final prefs = FakePrefs();
      final (container: first, :roster) = savingNightContainer(prefs: prefs);
      roster.put([nightPlayer('p1', 1, 'Mia')]);
      final host = first.read(partyNightProvider.notifier)
        ..start(length: NightLength.three, awards: threeAwards)
        ..recordRound(roundResult(points: {'p1': 5}));
      expect(prefs.containsKey('party_night_v1'), isTrue, reason: 'the played night is saved before it ends');
      host.end();

      final (container: second, roster: _) = savingNightContainer(prefs: prefs);
      expect(second.read(partyNightProvider), isNull);
      expect(prefs.containsKey('party_night_v1'), isFalse);
    });

    test('a night saved with no round played is not resumed, and its save is cleared', () {
      final prefs = FakePrefs();
      NightSave(prefs).save(NightState.start(length: NightLength.three, awards: threeAwards));
      expect(prefs.containsKey('party_night_v1'), isTrue);

      final (container: second, roster: _) = savingNightContainer(prefs: prefs);
      expect(second.read(partyNightProvider), isNull, reason: 'B-032: a night nobody played is not resumed');
      expect(prefs.containsKey('party_night_v1'), isFalse);
    });

    test('a player who joins after a round and then leaves is kept in the resumed night', () {
      final prefs = FakePrefs();
      final (container: first, :roster) = savingNightContainer(prefs: prefs);
      roster.put([nightPlayer('p1', 1, 'Mia')]);
      first.read(partyNightProvider.notifier)
        ..start(length: NightLength.three, awards: threeAwards)
        ..recordRound(roundResult(points: {'p1': 5}));
      roster.put([nightPlayer('p1', 1, 'Mia'), nightPlayer('p2', 2, 'Sam')]);
      roster.put([nightPlayer('p1', 1, 'Mia')]);

      final (container: second, roster: _) = savingNightContainer(prefs: prefs);
      final resumed = second.read(partyNightProvider)!;
      expect(resumed.seen.keys, unorderedEquals(['p1', 'p2']));
      expect(resumed.seen['p2']?.nickname, 'Sam');
    });

    test('a night that is over is not resumed, and its save is cleared', () {
      final prefs = FakePrefs();
      var over = NightState.start(length: NightLength.three, awards: threeAwards);
      for (var i = 0; i < 3; i++) {
        over = over.record(roundResult(points: {'p1': 5}));
      }
      expect(over.isOver, isTrue);
      NightSave(prefs).save(over);

      expect(NightSave(prefs).load(), isNull);
      expect(prefs.containsKey('party_night_v1'), isFalse);
    });
  });
}
