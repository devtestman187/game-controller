// On-device check that the four event sounds load and really play with
// flutter_soloud (decoded and mixed, not just found). Run it on each build:
//
//   cd tv_test_app
//   flutter test integration_test -d windows
//   flutter test integration_test -d <TV-IP>:5555
//
// It plays each sound for about half a second, so the TV or laptop makes
// some noise.
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:protocol/protocol.dart';
import 'package:tvtest/src/sound.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('all four event sounds load and play', (tester) async {
    final log = <String>[];
    final player = SoLoudSoundPlayer(log: log.add);
    await tester.runAsync(player.load);
    // ignore: avoid_print
    print(log.join('\n'));
    expect(player.status.error, isNull);
    expect(player.status.loaded, HapticEvent.values.length, reason: '${player.status.files}');

    for (final event in HapticEvent.values) {
      player.play(event);
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 500)));
      final position = player.positionOf(event);
      // ignore: avoid_print
      print('${event.name}: played ${position?.inMilliseconds} ms of ${player.status.files[event]}');
      expect(position, isNotNull, reason: '${event.name} is playing');
      expect(position!.inMilliseconds, greaterThan(200), reason: '${event.name} advances (the mixer is playing it)');
    }

    // Playing the same sound again restarts it instead of layering.
    player.play(HapticEvent.error);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    expect(player.positionOf(HapticEvent.error)!.inMilliseconds, lessThan(400));
    await tester.runAsync(player.dispose);
  });
}
