import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_assets/asset_manifest.dart';
import 'package:party_host/party_host.dart';
import 'package:party_host/testing.dart';

import 'support/host_harness.dart';

/// The 3-2-1 countdown sound (M13 design section 8): it plays with the "Get
/// ready" beat as the card first shows 3, stops while the beat is held so no
/// "go" sounds over a round that waits, plays again when the beat starts over,
/// and a round with no beat (the TV's) has none to play.
void main() {
  /// Home → Play → Shape Race → the house puzzle with P1 on the left and P2 on
  /// the right, with a [Pausable.ready] beat: the beat is running when this
  /// returns. [appAway] is the host app's away state, which a test moves.
  Future<FakeHostService> startBeat(WidgetTester tester, {ValueNotifier<bool>? appAway}) async {
    final fake = await pumpHost(
      tester,
      screen: const StubHome(),
      overrides: [
        readyCountdownProvider.overrideWithValue(Pausable.ready),
        if (appAway != null) hostAwayProvider.overrideWithValue(appAway),
      ],
    );
    fake.state = withController(fake.state, phoneInfo('p2', 2));
    fake.emit();
    await neutral(tester, fake, ['p1', 'p2']);
    await openJoin(tester);
    await startRace(tester, fake);
    return fake;
  }

  /// How many times the countdown started.
  int plays() => sounds.played.where((name) => name == SoundKey.countdown.eventName).length;

  testWidgets('a round with a 3 s beat plays the countdown once, as the card shows 3', (tester) async {
    await startBeat(tester);
    expect(find.byKey(const Key('getReady')), findsOneWidget);
    expect(plays(), 1, reason: 'the card shows 3, so the beeps start with it');

    // The beat runs out, and nothing starts it a second time.
    for (var i = 0; i < 400 && find.byKey(const Key('getReady')).evaluate().isNotEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pump(const Duration(milliseconds: 32));
    expect(find.byKey(const Key('getReady')), findsNothing);
    expect(plays(), 1);
  });

  testWidgets('a host-away hold stops it, and the beat starting over plays it again', (tester) async {
    final appAway = ValueNotifier(false);
    await startBeat(tester, appAway: appAway);
    expect(plays(), 1);

    appAway.value = true;
    // The beat's own tick sees the hold and stops the countdown.
    await tester.pump(const Duration(milliseconds: 120));
    expect(sounds.stopped, contains(SoundKey.countdown.eventName), reason: 'no "go" over a held round');

    appAway.value = false;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(plays(), 2, reason: 'the beat starts again from the top, and its countdown with it');
  });

  testWidgets('a round with no beat (the TV\'s) plays no countdown', (tester) async {
    final fake = await pumpHost(tester, screen: const StubHome());
    fake.gameHost.hasViewers = true;
    fake.state = withController(fake.state, phoneInfo('p2', 2));
    fake.emit();
    await neutral(tester, fake, ['p1', 'p2']);
    await openJoin(tester);
    await startRace(tester, fake);
    expect(find.byKey(const Key('getReady')), findsNothing, reason: 'no beat was asked for');
    expect(plays(), 0, reason: 'no beat, no countdown');

    await tester.pump(const Duration(seconds: 4));
    expect(plays(), 0);
  });
}
