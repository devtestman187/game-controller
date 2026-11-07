import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/testing.dart';

void main() {
  // SoLoudSoundPlayer needs a device's audio engine, so the restart is checked
  // through the fake: it counts every restart on the same contract the phone
  // app's host route calls (s5c).
  test('the fake sound player counts every restart', () async {
    final player = FakeSoundPlayer();
    expect(player.restarts, 0);

    await player.restart();
    expect(player.restarts, 1);
    expect(player.status.ready, isTrue, reason: 'a restart leaves the sounds loaded');

    await player.restart();
    expect(player.restarts, 2);
  });
}
