import 'package:connection/connection.dart';
import 'package:protocol/protocol.dart';

/// One scripted player in the demo video (docs/demo-video-runbook.md 2.3).
///
/// It is a real controller as far as the TV is concerned: a [ControllerClient]
/// that pairs with the code over loopback and sends input states. Its platform
/// is `bot`, not `sim`, so the TV does not treat it as one of its built-in
/// simulators (those auto-join and ignore menu presses) and not `android`
/// either (those would be recorded as phones in the stats).
final class DemoBot {
  DemoBot({required this.name, required this.id, this.appVersion = '0.11.0'})
    : client = ControllerClient(
        identity: ControllerIdentity(
          controllerId: id,
          name: name,
          platform: platform,
          appVersion: appVersion,
          capabilities: const [Capability.layout, Capability.status],
        ),
      );

  /// What the TV shows and the stats record.
  static const platform = 'bot';

  /// Send at least this often while a stick is held off-centre.
  static const resend = Duration(milliseconds: 100);

  final String name;
  final String id;
  final String appVersion;
  final ControllerClient client;

  GamepadState _sent = GamepadState.neutral;
  double _sinceSendS = 0;

  bool get connected => client.snapshot.isConnected;

  void connect({required int port, required String code}) {
    client.connect(
      HostAddress(addresses: const ['127.0.0.1'], port: port),
      code: code,
    );
  }

  /// Whether this frame's state needs sending: it changed, or a stick has been
  /// held off-centre long enough that the host wants a fresh sample.
  static bool shouldSend(GamepadState next, GamepadState sent, Duration sinceSend) =>
      next != sent || (sinceSend >= resend && !next.isNeutral);

  /// Feeds one frame's controls. [dt] is the frame time.
  void step(GamepadState state, double dt) {
    _sinceSendS += dt;
    final since = Duration(microseconds: (_sinceSendS * 1e6).round());
    if (!shouldSend(state, _sent, since)) return;
    _sent = state;
    _sinceSendS = 0;
    client.sendInput(
      {for (final b in state.buttons) _toController[b]!},
      left: (x: state.leftX, y: state.leftY),
      right: (x: state.rightX, y: state.rightY),
    );
  }

  Future<void> dispose() => client.dispose();
}

/// The gamepad's buttons back to the phone's, for [ControllerClient.sendInput].
const _toController = {
  GamepadButton.a: ControllerButton.a,
  GamepadButton.b: ControllerButton.b,
  GamepadButton.x: ControllerButton.x,
  GamepadButton.y: ControllerButton.y,
  GamepadButton.lb: ControllerButton.lb,
  GamepadButton.rb: ControllerButton.rb,
  GamepadButton.select: ControllerButton.select,
  GamepadButton.start: ControllerButton.start,
};
