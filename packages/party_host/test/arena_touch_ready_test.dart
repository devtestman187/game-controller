import 'package:connection/connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';
import 'package:party_host/testing.dart';

import 'support/host_harness.dart';
import 'support/night_harness.dart';
import 'support/toy_fonts.dart';

/// The Arena's waiting card on the host device that plays here (M14 b1): a
/// phone or tablet host has no pad over the card, so its own player gets a
/// Ready button and a line that says so, and every player's row marks its
/// readiness in words.
void main() {
  // The card is measured with the look's real fonts, as a phone draws it.
  setUpAll(loadLookFonts);

  /// What a phone host that plays here supplies: this phone's own player is in
  /// the round, and the host is worked by touch (m12-host-touch rules A and B).
  List<Override> ownPhoneOverrides(String id) => [
    ownPlayerIdProvider.overrideWithValue(id),
    hostTouchFirstProvider.overrideWithValue(true),
  ];

  /// Home → Play → the Arena's card on a phone in landscape, with the host's
  /// own player and [phones] more phones on the roster, every pad quiet so the
  /// card waits for the test.
  Future<FakeHostService> openTouchCard(WidgetTester tester, {List<String> phones = const []}) async {
    final fake = await pumpHost(
      tester,
      screen: const StubHome(),
      size: const Size(852, 393),
      overrides: ownPhoneOverrides('p1'),
    );
    for (final id in phones) {
      fake.state = withController(fake.state, phoneInfo(id, 2));
    }
    if (phones.isNotEmpty) fake.emit();
    await neutral(tester, fake, ['p1', ...phones]);
    await openArenaCard(tester);
    return fake;
  }

  /// Home → Play → Party night → its Bumper Round's waiting card, on the same
  /// phone host.
  Future<FakeHostService> openTouchNightCard(WidgetTester tester) async {
    final fake = await pumpHost(
      tester,
      screen: const StubHome(),
      size: const Size(852, 393),
      overrides: ownPhoneOverrides('p1'),
    );
    await neutral(tester, fake, ['p1']);
    await openNight(tester);
    await tapVisible(tester, find.byKey(const Key('nightBumper')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    return fake;
  }

  /// The text a ready label shows for [key] ("ready-p1", "notReady-robo").
  String? labelOf(WidgetTester tester, String key) => tester.widget<Text>(find.byKey(Key(key))).data;

  testWidgets('a phone host\'s card gives its own player a Ready button, which readies it and takes it back', (
    tester,
  ) async {
    await openTouchCard(tester);
    expect(find.byKey(const Key('arenaReady')), findsOneWidget, reason: 'the own player has no pad over the card');
    expect(find.text("Tap Ready when you're ready."), findsOneWidget, reason: 'the line says what this device does');
    expect(find.text("Press A when you're ready."), findsNothing);
    expect(
      find.descendant(of: find.byKey(const Key('arenaPlayer-p1')), matching: find.text('P1 iPhone 3F1C (you)')),
      findsOneWidget,
      reason: 'the host phone\'s own player is marked on its row, as the join screen marks it',
    );
    expect(labelOf(tester, 'notReady-p1'), ArenaText.notReadyLabel);
    expect(labelOf(tester, 'ready-robo'), ArenaText.readyLabel, reason: 'Robo wears the same label');

    await tester.tap(find.byKey(const Key('arenaReady')));
    await tester.pump();
    expect(labelOf(tester, 'ready-p1'), ArenaText.readyLabel, reason: 'the tap is that player\'s A');

    await tester.tap(find.byKey(const Key('arenaReady')));
    await tester.pump();
    expect(labelOf(tester, 'notReady-p1'), ArenaText.notReadyLabel, reason: 'A again takes the ready back');
  });

  testWidgets('the Ready button and a joined phone\'s A start the round when every player is ready', (tester) async {
    final fake = await openTouchCard(tester, phones: ['p2']);
    expect(find.text('P2 Phone 2'), findsOneWidget, reason: 'a joined phone\'s row carries no "(you)"');

    await tester.tap(find.byKey(const Key('arenaReady')));
    await tester.pump();
    expect(labelOf(tester, 'ready-p1'), ArenaText.readyLabel);
    expect(labelOf(tester, 'notReady-p2'), ArenaText.notReadyLabel, reason: 'P2 hasn\'t pressed yet');

    await press(tester, fake, 'p2', GamepadButton.a);
    await tester.pump();
    expect(find.byKey(const Key('arenaWaitingCard')), findsNothing, reason: 'all ready: the round starts');
    expect(find.byKey(const Key('arena')), findsOneWidget);
  });

  testWidgets('a night\'s Bumper Round gives the phone host the same Ready button', (tester) async {
    await openTouchNightCard(tester);
    expect(find.byKey(const Key('arenaWaitingCard')), findsOneWidget);
    expect(find.byKey(const Key('arenaReady')), findsOneWidget);
    expect(find.text("Tap Ready when you're ready."), findsOneWidget);

    await tester.tap(find.byKey(const Key('arenaReady')));
    await roundStarted(tester);
    expect(find.byKey(const Key('arena')), findsOneWidget, reason: 'the one player is ready: the night\'s round runs');
  });

  testWidgets('a TV\'s card has no Ready button, keeps the Press A line, and opens on its chosen mode', (tester) async {
    final fake = await pumpHost(tester, screen: const StubHome());
    await neutral(tester, fake, ['p1']);
    await openArenaCard(tester);

    expect(
      find.byKey(const Key('arenaReady')),
      findsNothing,
      reason: 'a TV has no own player: its pad readies the phones',
    );
    expect(find.text("Press A when you're ready."), findsOneWidget);
    expect(find.text("Tap Ready when you're ready."), findsNothing);
    expect(find.text('P1 iPhone 3F1C'), findsOneWidget, reason: 'no row is marked "(you)" on a TV');

    // The focus the card always opened on, and the order its buttons always
    // had: the ready control adds no stop on a TV.
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'arena waiting mode');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(focused(tester, 'arenaMode-race'), isTrue, reason: 'the arrows still walk the mode buttons first');
  });

  testWidgets('a phone that only shows the game has no Ready button: the joined phones press A', (tester) async {
    final fake = await pumpHost(
      tester,
      screen: const StubHome(),
      size: const Size(852, 393),
      overrides: [hostTouchFirstProvider.overrideWithValue(true)],
    );
    await neutral(tester, fake, ['p1']);
    await openArenaCard(tester);

    expect(find.byKey(const Key('arenaReady')), findsNothing, reason: 'this phone has no own player (m12 bug 1108a)');
    expect(find.text("Press A when you're ready."), findsOneWidget, reason: 'the phones press A, so the line says so');
    expect(find.text('P1 iPhone 3F1C'), findsOneWidget);
  });

  testWidgets('the rows mark readiness in words beside the badge and the name, as the other rows do', (tester) async {
    final fake = await pumpHost(tester, screen: const StubHome());
    fake.state = withController(fake.state, phoneInfo('p2', 2));
    fake.emit();
    await neutral(tester, fake, ['p1', 'p2']);
    await openArenaCard(tester);

    expect(
      find.descendant(of: find.byKey(const Key('arenaPlayer-p1')), matching: find.byType(PlayerBadge)),
      findsOneWidget,
      reason: 'the row is the badge, the name and the word',
    );
    expect(labelOf(tester, 'notReady-p1'), ArenaText.notReadyLabel);
    expect(find.byIcon(Icons.cancel), findsNothing, reason: 'the orange X disc is gone');

    await press(tester, fake, 'p1', GamepadButton.a);
    expect(labelOf(tester, 'ready-p1'), ArenaText.readyLabel, reason: 'a ready player says "Ready"');
  });

  testWidgets('a phone in landscape shows the Ready button without scrolling', (tester) async {
    await openTouchCard(tester);
    expect(tester.takeException(), isNull, reason: 'the card with its ready row fits the phone\'s width');
    final button = tester.getRect(find.byKey(const Key('arenaReady')));
    expect(button.top, greaterThanOrEqualTo(0.0));
    expect(
      button.bottom,
      lessThanOrEqualTo(393.0),
      reason: 'the ready control sits under the mode row, above the fold of an 852x393 screen',
    );
    expect(find.byKey(const Key('arenaWaitingCard')), findsOneWidget);
  });
}
