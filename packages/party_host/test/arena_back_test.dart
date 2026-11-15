import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';
import 'package:party_host/testing.dart';

import 'support/host_harness.dart';
import 'support/toy_fonts.dart';

/// The Arena's waiting card's Back button (M14 bugs B-024): a touch host has no
/// B, and the card sits under a game screen with no title bar, so the card
/// carries a Back of its own — tapped by a thumb, or pressed with the focus on
/// it from a remote, a keyboard or a phone's A.
void main() {
  // The card is measured with the look's real fonts, as a phone draws it.
  setUpAll(loadLookFonts);

  /// What a phone host that plays here supplies: this phone's own player is in
  /// the round, and the host is worked by touch (m12-host-touch rules A and B).
  List<Override> ownPhoneOverrides(String id) => [
    ownPlayerIdProvider.overrideWithValue(id),
    hostTouchFirstProvider.overrideWithValue(true),
  ];

  /// Home → Play → the Arena's card on a phone in landscape, with this phone's
  /// own player on the roster.
  Future<FakeHostService> openTouchCard(WidgetTester tester) async {
    final fake = await pumpHost(
      tester,
      screen: const StubHome(),
      size: const Size(852, 393),
      overrides: ownPhoneOverrides('p1'),
    );
    await neutral(tester, fake, ['p1']);
    await openArenaCard(tester);
    return fake;
  }

  testWidgets('the card shows a Back button, which leaves the Arena, as the join screen\'s does', (tester) async {
    final fake = await pumpHost(tester, screen: const StubHome());
    await neutral(tester, fake, ['p1']);
    await openArenaCard(tester);

    expect(find.byKey(const Key('arenaBack')), findsOneWidget, reason: 'a thumb has no B to leave the card with');
    expect(find.text('Back'), findsOneWidget);

    await tester.tap(find.byKey(const Key('arenaBack')));
    await navigated(tester);
    expect(find.byType(GameScreen), findsNothing, reason: 'Back leaves the Arena');
    expect(find.byType(GamesScreen), findsOneWidget, reason: 'and lands on the game picker, as B does');
  });

  testWidgets('the focus walks onto the Back button, and the remote\'s or keyboard\'s select pops the card', (
    tester,
  ) async {
    final fake = await pumpHost(tester, screen: const StubHome());
    await neutral(tester, fake, ['p1']);
    await openArenaCard(tester);

    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'arena waiting mode',
      reason: 'the Back button joins the focus order without taking the card\'s opening focus',
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(focused(tester, 'arenaBack'), isTrue, reason: 'the arrows reach the card\'s Back');

    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await navigated(tester);
    expect(find.byType(GameScreen), findsNothing, reason: 'the remote\'s OK presses Back');
    expect(find.byType(GamesScreen), findsOneWidget);
  });

  testWidgets('a phone in landscape shows its Back button, taps it, and reaches it with the arrows', (tester) async {
    await openTouchCard(tester);
    expect(tester.takeException(), isNull, reason: 'the card with its Back button fits the phone\'s width');

    final back = tester.getRect(find.byKey(const Key('arenaBack')));
    expect(back.top, greaterThanOrEqualTo(0.0));
    expect(
      back.bottom,
      lessThanOrEqualTo(393.0),
      reason: 'the Back button sits under the mode row, above the fold of an 852x393 screen',
    );
    expect(back.right, lessThanOrEqualTo(852.0), reason: 'it fits the phone\'s width');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(focused(tester, 'arenaBack'), isTrue, reason: 'a phone host with a keyboard walks onto it');

    await tester.tap(find.byKey(const Key('arenaBack')));
    await navigated(tester);
    expect(find.byType(GameScreen), findsNothing, reason: 'the tap leaves the Arena on a phone host');
    expect(find.byType(GamesScreen), findsOneWidget);
  });
}
