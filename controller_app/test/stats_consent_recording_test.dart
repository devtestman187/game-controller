import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/pump_app.dart';

/// The stats answer is what turns this phone's recording on and off, at once
/// (design sentry-consent.md; the run's review found the answer no longer
/// reached the recorder): a phone whose adult turns stats off in Settings
/// stops counting and sending there and then, and one that turns them on
/// starts recording then too.
void main() {
  /// Taps once on the pad and switches to [mode], which ends the segment that
  /// was recording and sends it.
  Future<void> playAndSwitch(WidgetTester tester, String mode) async {
    await tester.tapAt(tester.getCenter(find.byKey(const Key('faceButtons'))));
    await tester.pump();
    await tester.tap(find.text(mode));
    await settle(tester);
  }

  testWidgets('turning stats off mid-session sends no further batch', (tester) async {
    final app = await pumpApp(tester, paired: true, saved: const {'statsConsent': true});
    app.client.emit(connected);
    await tester.pump();

    await playAndSwitch(tester, 'Sticks');
    expect(app.client.metrics.map((batch) => batch.mode), ['dpad'], reason: 'recording while the answer is yes');

    await openSettings(tester);
    await scrollTo(tester, find.byKey(const Key('settingsShareStats')));
    await tester.tap(find.byKey(const Key('settingsShareStats')));
    await settle(tester);
    // Turning the answer off ends the segment that was recording, and that
    // last batch is the end of it.
    final sent = app.client.metrics.length;

    await closeSettings(tester);
    await playAndSwitch(tester, 'D-pad');
    expect(app.client.metrics, hasLength(sent), reason: 'nothing is recorded once the answer is no');
  });

  testWidgets('turning stats on mid-session starts a batch', (tester) async {
    final app = await pumpApp(tester, paired: true, saved: const {'statsConsent': false});
    app.client.emit(connected);
    await tester.pump();

    await playAndSwitch(tester, 'Sticks');
    expect(app.client.metrics, isEmpty, reason: 'nothing is recorded before the answer is yes');

    await openSettings(tester);
    await scrollTo(tester, find.byKey(const Key('settingsShareStats')));
    await tester.tap(find.byKey(const Key('settingsShareStats')));
    await settle(tester);
    await closeSettings(tester);

    await playAndSwitch(tester, 'D-pad');
    expect(app.client.metrics.map((batch) => batch.mode), ['sticks'], reason: 'recording starts at the yes');
  });
}
