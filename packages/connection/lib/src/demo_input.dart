import 'dart:async';

import 'package:protocol/protocol.dart';

import 'controller_client.dart';

/// One step of the simulated controller's demo: what is held.
typedef DemoStep = ({Set<ControllerButton> buttons, int dx, int dy});

/// Walks the D-pad round all eight directions, presses every button, then
/// holds a direction and a button together (the multi-touch case).
const List<DemoStep> demoSteps = [
  (buttons: {}, dx: 0, dy: -1),
  (buttons: {}, dx: 1, dy: -1),
  (buttons: {}, dx: 1, dy: 0),
  (buttons: {}, dx: 1, dy: 1),
  (buttons: {}, dx: 0, dy: 1),
  (buttons: {}, dx: -1, dy: 1),
  (buttons: {}, dx: -1, dy: 0),
  (buttons: {}, dx: -1, dy: -1),
  (buttons: {}, dx: 0, dy: 0),
  (buttons: {ControllerButton.a}, dx: 0, dy: 0),
  (buttons: {ControllerButton.b}, dx: 0, dy: 0),
  (buttons: {ControllerButton.x}, dx: 0, dy: 0),
  (buttons: {ControllerButton.y}, dx: 0, dy: 0),
  (buttons: {ControllerButton.select}, dx: 0, dy: 0),
  (buttons: {ControllerButton.start}, dx: 0, dy: 0),
  (buttons: {ControllerButton.a}, dx: 1, dy: 0),
  (buttons: {ControllerButton.a, ControllerButton.b}, dx: 1, dy: 0),
  (buttons: {}, dx: 0, dy: 0),
];

/// Plays [demoSteps] on [client] in a loop. Cancel the timer to stop, then
/// release everything with `client.sendInput({})`.
Timer runDemoInput(ControllerClient client, {Duration step = const Duration(milliseconds: 400)}) {
  var i = 0;
  return Timer.periodic(step, (_) {
    final s = demoSteps[i++ % demoSteps.length];
    client.sendInput(s.buttons, dx: s.dx, dy: s.dy);
  });
}
