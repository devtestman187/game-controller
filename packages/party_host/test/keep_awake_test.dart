import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';
import 'package:party_host/testing.dart';

void main() {
  test('a TV host keeps the screen on only while a controller is connected', () async {
    // The sample TV: p1 is connected, p2 is still pairing.
    final fake = FakeHostService(sampleState());
    final awake = FakeScreenAwake();
    final container = ProviderContainer(
      overrides: [hostServiceProvider.overrideWithValue(fake), screenAwakeProvider.overrideWithValue(awake)],
    );
    addTearDown(container.dispose);

    // A host with no app override keeps today's rule (m12 bug 1108a fix2 Q2):
    // the screen is on while a controller is connected (PRD T5).
    expect(container.read(keepAwakeProvider), isTrue);
    expect(awake.on, isTrue);

    // The last phone leaves: a TV waiting for players may sleep, as it always
    // has. The phone app's seam is what turns this the other way for a phone.
    fake.removeController('p1');
    await pumpEventQueue();
    expect(container.read(keepAwakeProvider), isFalse);
    expect(awake.on, isFalse);
  });
}
