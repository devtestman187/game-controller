import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';

import 'support/host_harness.dart';

/// The tall bar the phone app draws over the host's screens (its
/// topBarHeightPx): the room a title bar must leave at the top on a phone, and
/// the body's top where a screen has no title bar.
const phoneBarPx = 52.0;

/// The harness's screen, a TV's and the Windows app's size.
const screenHeightPx = 540.0;

/// [screen]'s title bar, whichever route it is on.
Finder titleBarOf(Type screen) =>
    find.descendant(of: find.byType(screen), matching: find.byKey(const Key('hostTitleBar')));

/// The host's screens as the phone app mounts them: the picker is the first
/// route under the phone's bar, so there is nothing below it to go back to.
Future<void> pumpPhone(WidgetTester tester) =>
    pumpHost(tester, screen: const GamesScreen(), overrides: [hostBarHeightProvider.overrideWithValue(phoneBarPx)]);

/// [screen]'s level list, the menu the phone's bar gives its 12 px of room to
/// since the picker moved into the frame (M16 phonehost2 S8p).
Finder menuOf(Type screen) => find.descendant(of: find.byType(screen), matching: find.byType(ListView));

void main() {
  test('a menu keeps 12 at the top where the phone bar is above, and 24 where it is not', () {
    expect(hostMenuPadding(phoneBarPx), const EdgeInsets.fromLTRB(24, 12, 24, 24));
    expect(hostMenuPadding(0), const EdgeInsets.all(24));
  });

  testWidgets('the picker draws the frame\'s header at the top, and its body starts under it', (tester) async {
    await pumpPhone(tester);
    // The picker is the frame's screen since M16 phonehost2 S8p: its 64 px
    // header is at the top of the screen, its title in it, and its body under
    // it. It is the first route, so the header has no back arrow.
    final header = tester.getRect(titleBarOf(GamesScreen));
    expect(header.top, 0);
    expect(header.height, 64);
    expect(find.descendant(of: find.byKey(const Key('hostFrameHeader')), matching: find.text('Play')), findsOneWidget);
    expect(find.byKey(const Key('hostTitleBarBack')), findsNothing, reason: 'nothing below the picker to go back to');
    final body = tester.getRect(find.byKey(const Key('hostFrameBody')));
    expect(body.top, header.bottom);
    expect(body.height, screenHeightPx - 64 - 84, reason: 'the frame\'s 64 px header and 84 px footer');
  });

  testWidgets('a phone menu below the picker leaves 12 at the top, where its bar gives the room', (tester) async {
    await pumpPhone(tester);
    await tapVisible(tester, find.byKey(const Key('pickShapeRace')));
    await tester.pumpAndSettle();
    // Shape Race's level list is still the old title-bar screen (M16
    // phonehost2 S8p leaves it as it was), so it keeps the bar's 12 px.
    expect(tester.widget<ListView>(menuOf(ShapeRaceScreen)).padding, const EdgeInsets.fromLTRB(24, 12, 24, 24));
  });

  testWidgets('a TV menu keeps its 24 at the top', (tester) async {
    await pumpHost(tester, screen: const GamesScreen());
    await tapVisible(tester, find.byKey(const Key('pickShapeRace')));
    await tester.pumpAndSettle();
    expect(tester.widget<ListView>(menuOf(ShapeRaceScreen)).padding, const EdgeInsets.all(24));
  });

  testWidgets('every host screen with a title bar leaves the phone bar free, and its back arrow pops', (tester) async {
    await pumpPhone(tester);

    // The level list, whose title met the bar's mode labels (bug 1107f).
    await tester.tap(find.byKey(const Key('pickShapeRace')));
    await tester.pumpAndSettle();
    expect(tester.getRect(titleBarOf(ShapeRaceScreen)).top, phoneBarPx);
    expect(
      tester.getRect(find.descendant(of: find.byType(ShapeRaceScreen), matching: find.text('Shape Race'))).top,
      greaterThanOrEqualTo(phoneBarPx),
      reason: 'the title is below the phone bar',
    );

    // Its back arrow is in the bar and goes back to the picker.
    final back = find.descendant(of: find.byType(ShapeRaceScreen), matching: find.byKey(const Key('hostTitleBarBack')));
    expect(back, findsOneWidget);
    expect(tester.getRect(back).top, greaterThanOrEqualTo(phoneBarPx));
    await tester.tap(back);
    await tester.pumpAndSettle();
    expect(find.byType(ShapeRaceScreen), findsNothing);
    expect(find.byKey(const Key('pickShapeRace')), findsOneWidget);
    expect(
      find.descendant(of: find.byType(GamesScreen), matching: find.byKey(const Key('hostTitleBarBack'))),
      findsNothing,
      reason: 'the picker stays the first route, so its header has no way back',
    );

    // The join screen, whose title ran into the bar's labels too.
    await tester.tap(find.byKey(const Key('pickShapeRace')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('puzzle-house')));
    await tester.pumpAndSettle();
    expect(tester.getRect(titleBarOf(JoinScreen)).top, phoneBarPx);
  });

  testWidgets('the settings screen leaves the phone bar free too', (tester) async {
    await pumpPhone(tester);
    await tapVisible(tester, find.byKey(const Key('openPuzzleSettings')));
    await tester.pumpAndSettle();
    expect(tester.getRect(titleBarOf(PuzzleSettingsScreen)).top, phoneBarPx);
    // Its own button is in the bar, below the phone's.
    expect(tester.getRect(find.byKey(const Key('resetPuzzleSettings'))).top, greaterThanOrEqualTo(phoneBarPx));
  });

  testWidgets('the stats screen draws its title bar at the top, as its TV screen always did', (tester) async {
    await pumpHost(tester, screen: const StatsScreen());
    expect(tester.getRect(titleBarOf(StatsScreen)).top, 0);
  });

  testWidgets('a TV host keeps the picker\'s title bar at the top, where its app bar was', (tester) async {
    // The bar is zero here, so a screen with nothing to go back to keeps its
    // title bar (rule D is about the phone's bar, which the TV has not got).
    await pumpHost(tester, screen: const GamesScreen());
    expect(tester.getRect(titleBarOf(GamesScreen)).top, 0);
    expect(find.text('Play'), findsOneWidget);

    // The TV app's own way in, from its home screen, keeps it too.
    await pumpHost(tester, screen: const StubHome());
    await tapVisible(tester, find.byKey(const Key('openPlay')));
    await tester.pumpAndSettle();
    expect(tester.getRect(titleBarOf(GamesScreen)).top, 0);
  });
}
