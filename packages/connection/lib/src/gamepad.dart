import 'package:protocol/protocol.dart';

/// How a player is controlling right now.
enum InputMode {
  dpad,
  gyro,
  sticks,

  /// A keyboard on the host itself (PRD v2 S2).
  keyboard,

  /// Nothing received yet.
  none;

  /// The mode an input state comes from: sticks if it has sticks, gyro if it
  /// has a tilt, otherwise the D-pad.
  static InputMode of(InputStateMessage? s) => s == null
      ? none
      : s.hasSticks
      ? sticks
      : s.hasAnalog
      ? gyro
      : dpad;
}

/// The standard gamepad buttons (PRD v2 P4): the Xbox-style face and
/// shoulder buttons, Select and Start, and the four D-pad directions.
enum GamepadButton { a, b, x, y, lb, rb, select, start, dpadUp, dpadDown, dpadLeft, dpadRight }

/// One player's controls as a standard Xbox-style gamepad (PRD v2 P4), the
/// same whatever input mode the phone is in, so a game (or a future bridge)
/// reads every player the same way:
///
/// * D-pad mode: the D-pad and the buttons. Both sticks stay centered.
/// * Gyro mode: the tilt is the left stick, and also [tiltX] and [tiltY].
/// * Stick mode: both sticks, the D-pad and every button.
/// * Keyboard: whatever the host maps its keys to.
///
/// Stick values run from -1 to 1, with y = -1 up, inside the unit circle.
final class GamepadState {
  const GamepadState({
    this.buttons = const {},
    this.leftX = 0,
    this.leftY = 0,
    this.rightX = 0,
    this.rightY = 0,
    this.tiltX,
    this.tiltY,
    this.mode = InputMode.none,
  });

  static const neutral = GamepadState();

  /// The standard mapping of a phone's input state.
  factory GamepadState.fromInput(InputStateMessage? s) {
    if (s == null) return neutral;
    final buttons = <GamepadButton>{
      for (final b in s.buttons) _buttonMap[b]!,
      if (s.dy < 0) GamepadButton.dpadUp,
      if (s.dy > 0) GamepadButton.dpadDown,
      if (s.dx < 0) GamepadButton.dpadLeft,
      if (s.dx > 0) GamepadButton.dpadRight,
    };
    final mode = InputMode.of(s);
    return GamepadState(
      buttons: buttons,
      leftX: s.lx ?? s.ax ?? 0,
      leftY: s.ly ?? s.ay ?? 0,
      rightX: s.rx ?? 0,
      rightY: s.ry ?? 0,
      tiltX: s.ax,
      tiltY: s.ay,
      mode: mode,
    );
  }

  static const _buttonMap = {
    ControllerButton.a: GamepadButton.a,
    ControllerButton.b: GamepadButton.b,
    ControllerButton.x: GamepadButton.x,
    ControllerButton.y: GamepadButton.y,
    ControllerButton.lb: GamepadButton.lb,
    ControllerButton.rb: GamepadButton.rb,
    ControllerButton.select: GamepadButton.select,
    ControllerButton.start: GamepadButton.start,
  };

  final Set<GamepadButton> buttons;
  final double leftX;
  final double leftY;
  final double rightX;
  final double rightY;

  /// The raw tilt, in gyro mode only (an extra beyond the standard pad).
  final double? tiltX;
  final double? tiltY;

  final InputMode mode;

  bool pressed(GamepadButton b) => buttons.contains(b);

  /// The D-pad as -1, 0 or 1 (x: right, y: down).
  int get dpadX => (pressed(GamepadButton.dpadRight) ? 1 : 0) - (pressed(GamepadButton.dpadLeft) ? 1 : 0);

  int get dpadY => (pressed(GamepadButton.dpadDown) ? 1 : 0) - (pressed(GamepadButton.dpadUp) ? 1 : 0);

  bool get usesDpad => dpadX != 0 || dpadY != 0;

  bool get isNeutral => buttons.isEmpty && leftX == 0 && leftY == 0 && rightX == 0 && rightY == 0;

  @override
  bool operator ==(Object other) =>
      other is GamepadState &&
      other.leftX == leftX &&
      other.leftY == leftY &&
      other.rightX == rightX &&
      other.rightY == rightY &&
      other.tiltX == tiltX &&
      other.tiltY == tiltY &&
      other.mode == mode &&
      other.buttons.length == buttons.length &&
      other.buttons.containsAll(buttons);

  @override
  int get hashCode => Object.hash(leftX, leftY, rightX, rightY, tiltX, tiltY, mode, Object.hashAllUnordered(buttons));

  @override
  String toString() =>
      'GamepadState(${mode.name}, ${buttons.map((b) => b.name).join('+')}, '
      'L $leftX,$leftY R $rightX,$rightY)';
}
