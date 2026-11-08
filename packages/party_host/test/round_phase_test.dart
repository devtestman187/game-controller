import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';

void main() {
  // M10: Play again puts the new screen up before the old one is disposed, and
  // the old one keeps ticking until then. Only the screen that claimed the
  // phase last says what the round is doing.
  testWidgets('only the round that claimed the phase last speaks for it', (tester) async {
    final signal = RoundPhaseSignal();
    addTearDown(signal.dispose);
    signal.claim('results');
    signal.publish('results', RoundPhase.playing);
    expect(signal.value, RoundPhase.playing);

    // Play again: the new round claims the phase, and the results below it
    // still tick, still saying their round is over.
    signal.claim('round');
    signal.publish('round', RoundPhase.playing);
    signal.publish('results', RoundPhase.none);
    expect(signal.value, RoundPhase.playing, reason: 'the screen being replaced says nothing');

    // Its dispose says nothing either.
    signal.release('results');
    await tester.pump();
    expect(signal.value, RoundPhase.playing);

    // The round's own screen going leaves no round on.
    signal.release('round');
    await tester.pump();
    expect(signal.value, RoundPhase.none);
  });
}
