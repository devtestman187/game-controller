import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/testing.dart';

import 'support/pump_app.dart';

/// The TV's sound (M13 design section 8): its home screen keeps the cue alive
/// for a phone joining, and plays it once for each phone that appears.
void main() {
  testWidgets('a phone joining the TV plays the phone-joined cue once', (tester) async {
    final fake = await pumpApp(tester);
    expect(sounds.played, isEmpty);

    fake.state = withController(fake.state, phoneInfo('p3', 3));
    fake.emit();
    await tester.pump();
    await tester.pump();

    expect(sounds.played, ['player_joined']);
  });
}
