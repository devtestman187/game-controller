import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/testing.dart';

import 'support/host_harness.dart';

/// The phone-joined cue (M13 design section 8): the host plays it once for each
/// phone that appears in its players and wasn't there before. A phone back from
/// away is the same player all along, and the host's own player is no phone.
void main() {
  /// Lets the host's players change reach the screens.
  Future<void> settlePlayers(WidgetTester tester) async {
    await tester.pump();
    await tester.pump();
  }

  testWidgets('a phone joining plays it once', (tester) async {
    final fake = await pumpHost(tester, screen: const StubHome());
    expect(sounds.played, isEmpty);

    fake.state = withController(fake.state, phoneInfo('p2', 2));
    fake.emit();
    await settlePlayers(tester);

    expect(sounds.played, ['player_joined']);
  });

  testWidgets('the same phone away and back plays nothing more', (tester) async {
    final fake = await pumpHost(tester, screen: const StubHome());
    fake.state = withController(fake.state, phoneInfo('p2', 2));
    fake.emit();
    await settlePlayers(tester);
    expect(sounds.played, ['player_joined']);

    fake.gameHost.setAway('p2', isAway: true);
    await settlePlayers(tester);
    fake.gameHost.setAway('p2', isAway: false);
    await settlePlayers(tester);

    expect(sounds.played, ['player_joined'], reason: 'the same player was in the list all along');
  });

  testWidgets('the host\'s own player plays nothing', (tester) async {
    final fake = await pumpHost(tester, screen: const StubHome());
    fake.gameHost.addLocalPlayer(nickname: 'Keys');
    await settlePlayers(tester);

    expect(sounds.played, isEmpty, reason: 'the keys on this device are no phone joining');
  });

  testWidgets('two phones joining play it twice', (tester) async {
    final fake = await pumpHost(tester, screen: const StubHome());
    fake.state = withController(withController(fake.state, phoneInfo('p2', 2)), phoneInfo('p3', 3));
    fake.emit();
    await settlePlayers(tester);

    expect(sounds.played, ['player_joined', 'player_joined']);
  });
}
