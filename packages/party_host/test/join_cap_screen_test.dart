import 'package:connection/connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';
import 'package:party_host/testing.dart';
import 'package:puzzle_game/puzzle_game.dart';

import 'support/host_harness.dart';
import 'support/night_harness.dart';

/// Pumps the join screen for [level] with [maxPerSide] saved as the setting,
/// with [players] phones connected and in the menu.
Future<FakeHostService> _joinWith(
  WidgetTester tester, {
  required Level level,
  required int players,
  int? maxPerSide,
}) async {
  final fake = await pumpHost(
    tester,
    screen: JoinScreen(choice: PuzzleChoice(level: level)),
  );
  if (maxPerSide != null) {
    appContainer(tester)
        .read(puzzleSettingsProvider.notifier)
        .set(PuzzleSettings.defaults.withValue('maxPerSide', maxPerSide));
  }
  await tester.pump();
  for (var n = 2; n <= players; n++) {
    fake.state = withController(fake.state, phoneInfo('p$n', n));
  }
  fake.emit();
  await neutral(tester, fake, [for (var n = 1; n <= players; n++) 'p$n']);
  return fake;
}

/// The name a phone shows on the join screen, and the side it's on.
Finder _onSide(String side, String name) =>
    find.descendant(of: find.byKey(Key('side-$side')), matching: find.text(name));

/// Neither side shows the player: a player turned away waits off the sides.
void _expectNotSeated(String name, {required String reason}) {
  expect(_onSide('left', name), findsNothing, reason: reason);
  expect(_onSide('right', name), findsNothing, reason: reason);
}

void main() {
  testWidgets('at a cap of four on Medium, the ninth player joins nobody and a right player stays right', (
    tester,
  ) async {
    final fake = await _joinWith(tester, level: Level.medium, players: 9, maxPerSide: 4);
    // Odd players go left and even right, as the join screen has always placed them.
    for (var n = 1; n <= 9; n++) {
      await press(tester, fake, 'p$n', GamepadButton.a);
    }
    expect(_onSide('left', 'P1 iPhone 3F1C'), findsOneWidget);
    expect(_onSide('right', 'P8 Phone 8'), findsOneWidget);
    _expectNotSeated('P9 Phone 9', reason: 'both sides are full at 4');

    // The left side is full: the right player's left press is refused.
    await press(tester, fake, 'p2', GamepadButton.dpadLeft);
    expect(_onSide('right', 'P2 Phone 2'), findsOneWidget);
    expect(_onSide('left', 'P2 Phone 2'), findsNothing);
  });

  testWidgets('at a cap of four on Easy, only two a side: the fifth player joins nobody', (tester) async {
    final fake = await _joinWith(tester, level: Level.easy, players: 5, maxPerSide: 4);
    for (var n = 1; n <= 5; n++) {
      await press(tester, fake, 'p$n', GamepadButton.a);
    }
    expect(_onSide('left', 'P1 iPhone 3F1C'), findsOneWidget);
    expect(_onSide('right', 'P2 Phone 2'), findsOneWidget);
    expect(_onSide('left', 'P3 Phone 3'), findsOneWidget);
    expect(_onSide('right', 'P4 Phone 4'), findsOneWidget);
    _expectNotSeated('P5 Phone 5', reason: 'Easy seats 2 a side');
  });

  testWidgets('at the default setting of two, Medium seats only two a side', (tester) async {
    final fake = await _joinWith(tester, level: Level.medium, players: 5);
    for (var n = 1; n <= 5; n++) {
      await press(tester, fake, 'p$n', GamepadButton.a);
    }
    expect(_onSide('left', 'P1 iPhone 3F1C'), findsOneWidget);
    expect(_onSide('right', 'P2 Phone 2'), findsOneWidget);
    expect(_onSide('left', 'P3 Phone 3'), findsOneWidget);
    expect(_onSide('right', 'P4 Phone 4'), findsOneWidget);
    _expectNotSeated('P5 Phone 5', reason: 'the default seats 2 a side');
  });
}
