import 'dart:async';
import 'dart:math';

import 'package:protocol/protocol.dart';

import 'controller_client.dart';

typedef Stick = ({double x, double y});

/// One step of the simulated controller's demo: what is held, the gyro tilt
/// and the two sticks (each null when that mode isn't in use).
typedef DemoStep = ({Set<ControllerButton> buttons, int dx, int dy, double? ax, double? ay, Stick? left, Stick? right});

DemoStep _held(Set<ControllerButton> buttons, [int dx = 0, int dy = 0]) =>
    (buttons: buttons, dx: dx, dy: dy, ax: null, ay: null, left: null, right: null);

DemoStep _tilt(double ax, double ay, [Set<ControllerButton> buttons = const {}]) =>
    (buttons: buttons, dx: 0, dy: 0, ax: ax, ay: ay, left: null, right: null);

DemoStep _sticks(Stick left, Stick right, [Set<ControllerButton> buttons = const {}, int dx = 0, int dy = 0]) =>
    (buttons: buttons, dx: dx, dy: dy, ax: null, ay: null, left: left, right: right);

const Stick _center = (x: 0, y: 0);

/// Walks the D-pad round all eight directions, presses every button, holds a
/// direction and buttons together (the multi-touch case), sweeps the gyro
/// tilt round a circle while pressing A, then moves both sticks (the right
/// one the opposite way round) with the shoulder buttons.
final List<DemoStep> demoSteps = [
  _held({}, 0, -1),
  _held({}, 1, -1),
  _held({}, 1, 0),
  _held({}, 1, 1),
  _held({}, 0, 1),
  _held({}, -1, 1),
  _held({}, -1, 0),
  _held({}, -1, -1),
  _held({}),
  _held({ControllerButton.a}),
  _held({ControllerButton.b}),
  _held({ControllerButton.x}),
  _held({ControllerButton.y}),
  _held({ControllerButton.select}),
  _held({ControllerButton.start}),
  _held({ControllerButton.a}, 1),
  _held({ControllerButton.a, ControllerButton.b}, 1),
  _held({}),
  _tilt(0, 0),
  for (var i = 0; i < 12; i++)
    _tilt(0.8 * cos(i * pi / 6), 0.8 * sin(i * pi / 6), i == 6 ? {ControllerButton.a} : const {}),
  _tilt(0, 0),
  _sticks(_center, _center),
  for (var i = 0; i < 12; i++)
    _sticks((x: cos(i * pi / 6), y: sin(i * pi / 6)), (x: 0.6 * cos(-i * pi / 6), y: 0.6 * sin(-i * pi / 6)), {
      if (i < 4) ControllerButton.lb,
      if (i >= 4 && i < 8) ControllerButton.rb,
      if (i >= 8) ControllerButton.y,
    }, i >= 8 ? -1 : 0),
  _sticks(_center, _center),
  _held({}),
];

/// Plays [demoSteps] on [client] in a loop. Cancel the timer to stop, then
/// release everything with `client.sendInput({})`.
Timer runDemoInput(ControllerClient client, {Duration step = const Duration(milliseconds: 400)}) {
  var i = 0;
  return Timer.periodic(step, (_) {
    final s = demoSteps[i++ % demoSteps.length];
    client.sendInput(s.buttons, dx: s.dx, dy: s.dy, ax: s.ax, ay: s.ay, left: s.left, right: s.right);
  });
}
