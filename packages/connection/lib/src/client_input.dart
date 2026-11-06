import 'package:protocol/protocol.dart';

/// The input the phone holds, sent as a state with a sequence number
/// (internal; [ControllerClient.sendInput] feeds it).
///
/// The client owns it from the start, so a button held through a reconnect
/// still counts and a released one is released.
final class ClientInput {
  int _seq = 0;
  Set<ControllerButton> _buttons = const {};
  int _dx = 0;
  int _dy = 0;
  double? _ax;
  double? _ay;
  ({double x, double y})? _left;
  ({double x, double y})? _right;
  int _statesSent = 0;

  /// Input states sent since the app started, for Diagnostics.
  int get statesSent => _statesSent;

  /// Remembers the input. [ax] and [ay] are the gyro tilt (-1 to 1), null
  /// outside gyro mode; [left] and [right] are the analog sticks, null
  /// outside stick mode.
  void remember(
    Set<ControllerButton> buttons, {
    int dx = 0,
    int dy = 0,
    double? ax,
    double? ay,
    ({double x, double y})? left,
    ({double x, double y})? right,
  }) {
    _buttons = Set.of(buttons);
    _dx = dx;
    _dy = dy;
    _ax = ax;
    _ay = ay;
    _left = left;
    _right = right;
  }

  /// The input held right now, as a new state with the next sequence number
  /// and [sentAtMs], the phone's clock.
  InputStateMessage nextState(int sentAtMs) {
    _statesSent++;
    return InputStateMessage(
      seq: ++_seq,
      buttons: _buttons,
      dx: _dx,
      dy: _dy,
      ax: _ax,
      ay: _ay,
      lx: _left?.x,
      ly: _left?.y,
      rx: _right?.x,
      ry: _right?.y,
      sentAtMs: sentAtMs,
    );
  }
}
