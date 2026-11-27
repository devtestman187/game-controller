import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';
import 'package:party_host/src/night/night_flow.dart';
import 'package:party_host/src/night/night_flow_provider.dart';

import 'support/fake_prefs.dart';
import 'support/night_harness.dart';

void main() {
  test('a player who joins after the controller exists is a NightPlayerJoined in its events', () {
    final harness = nightContainer(overrides: [prefsProvider.overrideWithValue(FakePrefs())]);
    final container = harness.container;
    container.read(partyNightProvider.notifier).start(length: NightLength.three, awards: threeAwards);
    final controller = container.read(nightFlowControllerProvider)!;
    expect(controller.events, isEmpty);

    harness.roster.put([nightPlayer('p1', 1, 'Ada')]);

    expect(controller.events, [const NightPlayerJoined('player1', 0)]);
  });
}
