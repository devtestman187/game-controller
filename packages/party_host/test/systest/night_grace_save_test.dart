import 'dart:io';

import 'package:connection/connection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';
import 'package:party_host/src/night/night_pick_provider.dart';
import 'package:party_host/src/night/night_settings.dart';

import '../support/night_harness.dart';
import 'systest_support.dart';

const _ids = ['phone-1', 'phone-2', 'phone-3'];

const _points = {'phone-1': 3, 'phone-2': 2, 'phone-3': 1};

void main() {
  group('the 30 s grace in the middle of a night', () {
    Future<Systest> nightWithThreePhones(WidgetTester tester) async {
      final t = await openSystest(tester, picker: NightPicker.director, webSocket: true);
      for (final id in _ids) {
        await t.addPhone(id);
      }
      t.container.read(partyNightProvider.notifier).start(length: NightLength.three, awards: threeAwards);
      t.recordRound(_points);
      return t;
    }

    systestWidgets('a phone back after 25 s is the same player again, and the night keeps its points', (tester) async {
      expect(ServerGameHost.defaultAwayGrace, const Duration(seconds: 30));
      final t = await nightWithThreePhones(tester);
      final number = t.host.players.firstWhere((p) => p.id == 'phone-2').number;

      t.phones[1].client.disconnect();
      await t.until(() => t.host.players.any((p) => p.id == 'phone-2' && p.away));
      await t.elapse(const Duration(seconds: 25));
      expect(t.host.players.where((p) => p.id == 'phone-2' && p.away), hasLength(1), reason: 'still held at 25 s');
      await t.rejoin(t.phones[1]);
      await t.elapse(const Duration(seconds: 10));

      final back = t.host.players.singleWhere((p) => p.id == 'phone-2');
      expect(back.away, isFalse);
      expect(back.number, number, reason: 'the slot kept its number');
      expect(t.container.read(partyNightProvider)!.totals['phone-2'], 2);
      t.recordRound(_points);
      expect(t.container.read(partyNightProvider)!.totals['phone-2'], 4);
    });

    systestWidgets('a phone still away after 30 s is gone, and the night goes on with a greyed row', (tester) async {
      final t = await nightWithThreePhones(tester);
      final ends = <AwayEnded>[];
      final sub = t.host.awayEnded.listen(ends.add);
      addTearDown(sub.cancel);

      t.phones[1].client.disconnect();
      await t.until(() => t.host.players.any((p) => p.id == 'phone-2' && p.away));
      await t.elapse(const Duration(seconds: 29));
      expect(ends, isEmpty, reason: 'not over at 29 s');
      await t.elapse(const Duration(seconds: 2));

      expect(ends.single.reason, AwayEnd.graceOver);
      expect(t.playerIds, ['phone-1', 'phone-3']);
      t.recordRound({'phone-1': 3, 'phone-3': 1});
      final night = t.container.read(partyNightProvider)!;
      expect(night.round, 2);
      final row = night.rows(t.host.players).singleWhere((r) => r.id == 'phone-2');
      expect(row.isHere, isFalse);
      expect(row.total, 2, reason: 'the player who left keeps the points');
    });
  });

  group('the night on a real disk', () {
    systestWidgets('a night saved to a temp directory is read back and played on after a restart', (tester) async {
      final dir = await tester.runAsync(() => Directory.systemTemp.createTemp('thumb_systest_'));
      addTearDown(() => dir!.deleteSync(recursive: true));

      final first = await openSystest(tester, picker: NightPicker.shuffle, prefs: DiskPrefs(dir!));
      for (final id in _ids) {
        await first.addPhone(id);
      }
      first.container.read(partyNightProvider.notifier).start(length: NightLength.three, awards: threeAwards);
      final firstGame = first.container.read(nightPickProvider.notifier).pickFor(1)!.variant.id;
      first.recordRound(_points);
      final file = File('${dir.path}${Platform.pathSeparator}prefs.json');
      expect(file.existsSync(), isTrue, reason: 'the night is on the disk');
      expect(file.readAsStringSync(), contains('party_night_v1'));

      // The host restarts: a new server, a new container, a new prefs instance on the same directory.
      first.container.dispose();
      final second = await openSystest(tester, picker: NightPicker.shuffle, prefs: DiskPrefs(dir));
      for (final id in _ids) {
        await second.addPhone(id);
      }
      final resumed = second.container.read(partyNightProvider);
      expect(resumed, isNotNull, reason: 'the night resumes from the file');
      expect(resumed!.round, 1);
      expect(resumed.totals, {'phone-1': 3, 'phone-2': 2, 'phone-3': 1});
      expect(resumed.awards, threeAwards);

      final secondGame = second.container.read(nightPickProvider.notifier).pickFor(2)!.variant.id;
      expect(secondGame, isNot(firstGame), reason: 'the played list came back too, so no repeat');
      second.recordRound(_points);
      second.recordRound(_points);
      expect(second.container.read(partyNightProvider)!.isOver, isTrue);
      expect(second.container.read(partyNightProvider)!.totals['phone-1'], 9);

      second.container.read(partyNightProvider.notifier).end();
      expect(DiskPrefs(dir).containsKey('party_night_v1'), isFalse, reason: 'the finished night is gone from disk');
    });
  });
}
