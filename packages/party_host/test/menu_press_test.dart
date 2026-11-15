import 'package:connection/connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/game_kit.dart';
import 'package:party_host/party_host.dart';

import 'support/host_harness.dart';
import 'support/night_harness.dart';

/// A phone's A presses the button that has the focus, on every press (M14 bugs
/// B-008 and B-013): the menus press it as the remote's OK, and a host button
/// presses once until that key comes back up. A phone sends no key events, so
/// the menus lift the OK themselves; before that, only the first press on a
/// button did anything, while the remote kept working.
void main() {
  testWidgets('the phone presses the focused button every time, not only the first', (tester) async {
    final pressed = <String>[];
    final fake = await pumpHost(tester, screen: _TwoButtons(pressed: pressed));
    await neutral(tester, fake, ['p1']);

    // The first button has the focus: A presses it, and A presses it again.
    await press(tester, fake, 'p1', GamepadButton.a);
    expect(pressed, ['one']);
    await press(tester, fake, 'p1', GamepadButton.a);
    expect(pressed, ['one', 'one'], reason: 'the second press on the same button works');

    // Right walks the focus to the second button, which takes A twice too.
    await press(tester, fake, 'p1', GamepadButton.dpadRight);
    await press(tester, fake, 'p1', GamepadButton.a);
    await press(tester, fake, 'p1', GamepadButton.a);
    expect(pressed, ['one', 'one', 'two', 'two']);
  });

  testWidgets('the phone works an Arena result card on every press (B-013)', (tester) async {
    final pressed = <String>[];
    final again = FocusNode(debugLabel: 'arenaAgain');
    addTearDown(again.dispose);
    final fake = await pumpHost(
      tester,
      screen: ArenaResults(
        result: RoundResult(game: 'arena', winners: {'p1'}, lines: {'p1': _coin(RoundOutcome.win, 3)}),
        night: false,
        lastRound: false,
        againFocus: again,
        onAgain: () => pressed.add('again'),
        onChangeMode: () => pressed.add('mode'),
        onNext: () => pressed.add('next'),
        onEndNight: () => pressed.add('endNight'),
      ),
      overrides: [gamePlayersProvider.overrideWith(TestRoster.new)],
    );
    (appContainer(tester).read(gamePlayersProvider.notifier) as TestRoster).put([nightPlayer('p1', 1, 'Mia')]);
    await tester.pump();
    await neutral(tester, fake, ['p1']);
    // The card opens on Play again, as the round's screen leaves it.
    again.requestFocus();
    await tester.pump();

    await press(tester, fake, 'p1', GamepadButton.a);
    await press(tester, fake, 'p1', GamepadButton.a);
    expect(pressed, ['again', 'again'], reason: 'the results card takes A again after the first round');

    await press(tester, fake, 'p1', GamepadButton.dpadRight);
    await press(tester, fake, 'p1', GamepadButton.a);
    await press(tester, fake, 'p1', GamepadButton.a);
    expect(pressed, ['again', 'again', 'mode', 'mode']);
  });

  testWidgets('a night\'s result card keeps A on Next and Right reaches End night (B-021)', (tester) async {
    final pressed = <String>[];
    final next = FocusNode(debugLabel: 'arenaNext');
    addTearDown(next.dispose);
    final fake = await pumpHost(
      tester,
      screen: ArenaResults(
        result: RoundResult(game: 'arena', winners: {'p1'}, lines: {'p1': _coin(RoundOutcome.win, 3)}),
        night: true,
        lastRound: false,
        againFocus: next,
        onAgain: () => pressed.add('again'),
        onChangeMode: () => pressed.add('mode'),
        onNext: () => pressed.add('next'),
        onEndNight: () => pressed.add('endNight'),
      ),
      overrides: [gamePlayersProvider.overrideWith(TestRoster.new)],
    );
    (appContainer(tester).read(gamePlayersProvider.notifier) as TestRoster).put([nightPlayer('p1', 1, 'Mia')]);
    await tester.pump();
    await neutral(tester, fake, ['p1']);
    // The screen leaves Next with the focus, as the round's end does.
    next.requestFocus();
    await tester.pump();

    await press(tester, fake, 'p1', GamepadButton.a);
    await press(tester, fake, 'p1', GamepadButton.a);
    expect(pressed, ['next', 'next'], reason: 'Next keeps the card\'s first focus');

    // Right walks to End night beside it, as the brief pins the walk (B-021).
    await press(tester, fake, 'p1', GamepadButton.dpadRight);
    expect(focused(tester, 'endNight'), isTrue, reason: 'Right reaches End night');
    await press(tester, fake, 'p1', GamepadButton.a);
    await press(tester, fake, 'p1', GamepadButton.a);
    expect(pressed, ['next', 'next', 'endNight', 'endNight'], reason: 'End night takes A on every press too');
  });
}

/// A player's line for a round: [count] of the count the game names.
RoundLine _coin(RoundOutcome outcome, int count) =>
    RoundLine(outcome: outcome, count: count, countOf: RoundCount.coins);

/// Two buttons side by side, the first with the focus: a menu with nothing else
/// on it, so the test says what a press does and nothing more.
class _TwoButtons extends StatelessWidget {
  const _TwoButtons({required this.pressed});

  /// What the phone pressed, in order.
  final List<String> pressed;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          HostButton(key: const Key('one'), label: 'One', autofocus: true, onPressed: () => pressed.add('one')),
          const SizedBox(width: 16),
          HostButton(key: const Key('two'), label: 'Two', onPressed: () => pressed.add('two')),
        ],
      ),
    ),
  );
}
