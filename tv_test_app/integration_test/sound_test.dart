// On-device check that every game sound loads and really plays with
// flutter_soloud (decoded and mixed, not just found). Run it on each build:
//
//   cd tv_test_app
//   flutter test integration_test -d windows
//   flutter test integration_test -d <TV-IP>:5555
//
// It plays each sound briefly, so the TV or laptop makes
// some noise.
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:game_assets/asset_manifest.dart';
import 'package:party_host/party_host.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('every game sound loads and plays', (tester) async {
    final log = <String>[];
    final player = SoLoudSoundPlayer(log: log.add);
    await tester.runAsync(player.load);
    // ignore: avoid_print
    print(log.join('\n'));
    expect(player.status.error, isNull);
    expect(player.status.loaded, SoundKey.values.length, reason: '${player.status.files}');

    for (final key in SoundKey.values) {
      player.play(key.eventName);
      // Short enough for the shortest sound (the tick).
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
      final position = player.positionOf(key);
      // ignore: avoid_print
      print('${key.eventName}: played ${position?.inMilliseconds} ms of ${player.status.files[key]}');
      expect(position, isNotNull, reason: '${key.eventName} is playing');
      expect(position!.inMilliseconds, greaterThan(20), reason: '${key.eventName} advances (the mixer is playing it)');
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    }

    // Playing the same sound again restarts it instead of layering.
    player.play('error');
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 500)));
    player.play('error');
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    expect(player.positionOf(SoundKey.error)!.inMilliseconds, lessThan(400));
    await tester.runAsync(player.dispose);
  });
}
