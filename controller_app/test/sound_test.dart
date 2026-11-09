import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart' as party;
import 'package:party_host/testing.dart' as party_test;

import 'support/host_app.dart';
import 'support/joined.dart';
import 'support/pump_app.dart';

/// This phone's sound (M13 design section 8): a phone that hosts plays the
/// lobby music on its own picker, a phone that joins a TV never plays it, and
/// the Settings screen works the Mute, Sounds and Music rows.
void main() {
  setUpAll(loadPuzzles);

  testWidgets('the host phone\'s picker plays the lobby music', (tester) async {
    final sounds = party_test.FakeSoundPlayer();
    await pumpHostApp(tester, sounds: sounds);
    final host = await enterHostMode(tester);
    await settle(tester);

    expect(find.byType(party.GamesScreen), findsOneWidget);
    expect(sounds.loop, 'lobby');
    expect(sounds.loopStarts, ['lobby'], reason: 'a host phone plays it once');
    await tester.runAsync(host.dispose);
  });

  testWidgets('a joined phone\'s waiting and pad screens never play the lobby music', (tester) async {
    final sounds = party_test.FakeSoundPlayer();
    final app = await pumpApp(tester, paired: true, extra: [party.soundPlayerProvider.overrideWithValue(sounds)]);
    expect(sounds.loop, isNull, reason: 'the waiting screen is no lobby');
    expect(sounds.loopStarts, isEmpty);

    // In play with a TV, and no game shown: the pad, which is no lobby either.
    app.client.emit(connected);
    await settle(tester);
    expect(sounds.loop, isNull, reason: 'the pad is no lobby');
    expect(sounds.loopStarts, isEmpty, reason: 'a joined phone never plays it');

    // In a round the TV runs: the round's music is the TV's to play too (M13
    // design section 8, rule 1).
    app.client.viewStart(arenaStart());
    await settle(tester);
    app.client.viewFrame(arenaFrame(0));
    await settle(tester);
    expect(sounds.loop, isNull, reason: 'the TV plays the round\'s music, not its phones');
    expect(sounds.loopStarts, isEmpty, reason: 'a joined phone plays no music at all');
  });

  testWidgets('the Settings screen shows the Mute, Sounds and Music rows', (tester) async {
    await pumpApp(tester, paired: true);
    await openSettings(tester);
    await scrollTo(tester, find.byKey(const Key('musicVolume')));

    expect(find.byKey(const Key('soundVolume')), findsOneWidget);
    expect(find.byKey(const Key('musicVolume')), findsOneWidget);
    expect(find.text(party.HostText.sounds), findsOneWidget);
    expect(find.text(party.HostText.music), findsOneWidget);
    expect(find.text(party.HostText.musicLine), findsOneWidget);
    // Owner, Nov 9, 2026: Mute silences the music and every sound.
    expect(find.byKey(const Key('soundMute')), findsOneWidget);
    expect(find.text(party.HostText.mute), findsOneWidget);
  });
}
