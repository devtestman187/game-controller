import 'package:connection/connection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';
import 'package:puzzle_game/puzzle_game.dart';

/// The string table (M13 3b, design section 7): the words a screen builds out
/// of a value, one spelling for each, so a screen that says one thing two ways
/// fails here.
void main() {
  test('a player who is away is named one way, wherever it is said', () {
    expect(HostText.playerAway(2), 'Player 2 is away');
    expect(HostText.playerAway(3), 'Player 3 is away');
    expect(HostText.awayCountdown(24), 'The game goes on if they\'re back in 24 s');
    expect(HostText.awayGone, 'The game goes on without them…');
  });

  test('the sides, the levels and the formats have one spelling', () {
    expect(HostText.leftSide, '◀ Left');
    expect(HostText.rightSide, 'Right ▶');
    expect(HostText.level(Level.easy), 'Easy');
    expect(HostText.level(Level.hard), 'Hard');
    expect(HostText.anyPuzzle('Easy'), 'Any Easy puzzle');
    expect(HostText.formatName(MatchFormat.oneVsOne), '1 vs 1');
    expect(HostText.titled('Shape Race', 'Tree'), 'Shape Race · Tree');
    expect(HostText.playerLabel('P1', simulated: false, own: true), 'P1 (you)');
    expect(HostText.playerLabel('P2', simulated: true, own: false), 'P2 (simulated)');
    expect(HostText.roomFor(1), 'Room for 1 more');
  });

  test('the results and the pause card read as the screens always said them', () {
    expect(HostText.leftWins, 'Left wins!');
    expect(HostText.draw, 'Draw!');
    expect(HostText.seconds(105.94), '105.9 seconds');
    expect(HostText.piecesPlaced(3, 4), '3 of 4 pieces placed');
    expect(HostText.resumerName(2), 'P2 or P1');
    expect(HostText.resumers('P2 or P1'), 'P2 or P1 can resume, with Start or Resume.');
  });

  test('the debug overlay builds its rows from the same values', () {
    expect(HostText.pingMs(42, 40, 90), '42 ms (30 s avg 40, max 90)');
    expect(HostText.pingMs(42, null, null), '42 ms (30 s avg –, max –)');
    expect(HostText.inputDelayMs(30, 4), '~30 ms avg (± 4 ms)');
    expect(HostText.inputDelayMs(30, null), '~30 ms avg (± ? ms)');
    expect(HostText.modeName(InputMode.dpad), 'D-pad');
    expect(HostText.modeName(InputMode.none), '–');
    expect(
      HostText.gamepadValues(
        const GamepadState(mode: InputMode.dpad, buttons: {GamepadButton.dpadRight, GamepadButton.dpadUp}),
      ),
      'D-pad 1, -1',
    );
    expect(HostText.gamepadButtons(const GamepadState(mode: InputMode.dpad)), '–');
    expect(HostText.gamepadButtons(const GamepadState(mode: InputMode.dpad, buttons: {GamepadButton.a})), 'A');
    expect(HostText.debugPlayer(1, 'P1 iPhone', local: true), 'P1 P1 iPhone (on this device)');
  });

  test('a stats row and a setting value are built here too', () {
    expect(HostText.timePlaying(60000), '1 min 0 s');
    expect(HostText.timePlaying(42000), '42 s');
    expect(HostText.inputDelayRow(9, 10), '9 ms (p95 10)');
    expect(HostText.inputDelayRow(9, null), '9 ms (p95 –)');
    expect(HostText.modeRow('dpad'), 'D-pad');
    expect(HostText.modeRow('sticks'), 'Sticks');
    expect(HostText.settingValue('angleToleranceDeg', 16), '±16°');
    expect(HostText.settingValue('timeLimitS', 90), '1:30');
    // The reach is the worker's body against the piece's edge since device
    // test 1, so the setting reads as a share of it, not of a piece's radius.
    expect(HostText.settingValue('pickupRange', 1.25), "125% of the worker's reach");
    expect(HostText.lessOf('Angle tolerance'), 'Less Angle tolerance');
    expect(HostText.autoLine(7, 19), 'Auto: Sunny from 7:00 to 19:00, Night otherwise');
  });
}
