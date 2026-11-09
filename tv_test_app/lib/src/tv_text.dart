import 'package:protocol/protocol.dart' show protocolVersion;

import 'app_info.dart';

/// Every word the TV app's own screens show a player, in one place (M13 3d,
/// design section 7: "one string table"). The host's screens take theirs from
/// `HostText`; what only the TV shell says — its title, its panels, the test
/// tools — is here.
///
/// The texts a screen builds out of a value are small functions beside their
/// plain strings. The tests keep their literal texts: they are the
/// specification of what a player reads, so a changed word fails one.
abstract final class TvText {
  // The header.
  static const name = 'Thumb Party TV';
  static const starting = 'Starting…';

  /// What the server is doing: "Listening on port 45780".
  static String listeningOn(int? port) => 'Listening on port $port';

  /// The app's version and the protocol it speaks, under the pairing code.
  static const buildLine = 'Version $versionLabel · protocol v$protocolVersion';
  static const hapticTest = 'Haptic test';
  static const latency = 'Latency';
  static const lookTest = 'Look test';

  // The controllers panel.
  /// The panel's title: "Controllers · 2 connected".
  static String controllers(int connected) => 'Controllers · $connected connected';
  static const forgetPhones = 'Forget phones';
  static String forgot(int count) => 'Forgot $count phone${count == 1 ? '' : 's'}. They need the code again.';
  static const noControllers = 'No controllers yet. Open the controller app on the phone.';
  static const connected = 'Connected';
  static const waitingForCode = 'Waiting for code';
  static const disconnected = 'Disconnected';

  /// A controller's ping, its average and worst, and its input delay.
  static String ping(int ms) => '$ms ms';
  static String pingAverage(int ms) => 'avg $ms ms';
  static String pingWorst(int ms) => 'max $ms ms';
  static String inputDelay(int ms) => 'input ~$ms ms';

  // The pairing panel.
  static const pairingCode = 'Pairing code';

  /// How to pair, with the name the phones find: "On the phone, choose "…"
  /// and enter this code."
  static String enterCode(String hostName) => 'On the phone, choose "$hostName" and enter this code.';
  static const manualAddress = 'Address for manual entry';
  static const noNetwork = 'No network connection';

  /// An address to type on a phone by hand, with the interface it is on.
  static String address(String address, int port) => '$address:$port';
  static const firewall =
      'Phones can\'t connect? Allow Thumb Party TV through Windows Firewall on private networks '
      '(see the tester guide).';
  static String site(String url) => 'Tester guide and privacy policy: $url';
  static const newCode = 'New code';
  static const simulateController = 'Simulate controller';
  static const addSimulatedController = 'Add simulated controller';
  static const stopSimulation = 'Stop simulation';
  static const stopSimulations = 'Stop simulations';
  static const dropConnections = 'Drop connections';

  /// One simulated controller's line in the pairing panel.
  static String simulatedController(String number, String status, {int? pingMs}) =>
      'Simulated controller$number: $status${pingMs == null ? '' : ' · $pingMs ms'}';

  /// A simulated (or dropped) phone's state.
  static const off = 'Off';
  static const connecting = 'Connecting…';
  static const pairing = 'Pairing…';
  static String reconnecting(int attempt) => 'Reconnecting (attempt $attempt)…';
  static String failed(String problem) => 'Failed ($problem)';

  // How network discovery stands.
  static const discovering = 'Starting network discovery…';
  static const discoverable = 'Phones on this Wi-Fi can find this TV';
  static String discoveryFailed(String? error) =>
      'Network discovery isn\'t working ($error). Phones can still use the address above.';

  // The four event sounds.
  static const soundsLoading = 'Loading sounds…';
  static String soundsOff(String error) => 'Sounds are off: $error';
  static String soundsLoaded(int loaded, int total, String engine) => '$loaded of $total event sounds loaded ($engine)';

  // The log.
  static const log = 'Log';
  static const saveLog = 'Save log';
  static String logSaved(String path) => 'Log saved to $path';
  static String logSaveFailed(Object error) => 'Could not save the log: $error';

  // The latency screen.
  static const notMeasured = 'Not measured yet';
  static String withinTarget(int targetMs) => 'Within the $targetMs ms target';
  static String aboveTarget(int targetMs) => 'Above the $targetMs ms target';
  static String latencyIntro(int targetMs) =>
      'Input delay is how long a press or a stick movement takes from the phone to this screen\'s app, '
      'estimated from the heartbeats (one way, not counting the screen itself). The target is about '
      '$targetMs ms on home Wi-Fi. Ping is the full round trip. The stages break the delay down: phone to '
      'TV, then TV to the first frame drawn with that input (while a game runs).';
  static const noControllersConnected = 'No controllers connected.';
  static const inputDelayAverage = 'Input delay, 30 s avg';
  static const inputDelaySession = 'Input delay, whole session';
  static const pingNow = 'Ping now';
  static const pingAverageLabel = 'Ping, 30 s avg';
  static const stagePhoneToTv = 'Stage: phone to TV';
  static const stageTvToScreen = 'Stage: TV to the screen';
  static const waitingForInput = 'waiting for input';
  static const olderPhoneApp = 'not measured (phone app older than 0.6.0?)';
  static String inputDelayDetail(int? p95Ms, int maxMs, int? errorMs) => 'p95 $p95Ms · max $maxMs ms · ± $errorMs ms';
  static String sessionDetail(int maxMs, int samples) => 'max $maxMs ms · $samples states';
  static const roundTrip = 'round trip';
  static String pingDetail(int minMs, int? p95Ms, int maxMs) => 'min $minMs · p95 $p95Ms · max $maxMs ms';
  static const sentToReceived = 'sent → received, 30 s avg';
  static const receivedToDrawn = 'received → drawn, while a game runs';
  static String receivedToDrawnP95(int? p95Ms) => 'received → drawn, p95 $p95Ms ms';

  // The haptic test.
  static const hit = 'Hit';
  static const hitLine = 'One heavy thump';
  static const success = 'Success';
  static const successLine = 'Three rising taps';
  static const error = 'Error';
  static const errorLine = 'Two sharp buzzes';
  static const rumble = 'Rumble';
  static const rumbleLine = 'A low, wobbling buzz';
  static const snap = 'Snap';
  static const snapLine = 'A click and a firm lock';
  static const wrong = 'Wrong';
  static const wrongLine = 'A low, falling uh-oh';
  static const dropReady = 'Drop-ready';
  static const dropReadyLine = 'One light tap';
  static const help = 'Help';
  static const helpLine = 'Two gentle knocks';
  static const tick = 'Tick';
  static const tickLine = 'The lightest tap';

  /// What an event's sound is doing: its file, or "none", "loading…" or "off".
  static String sound(String fileName) => 'Sound: $fileName';
  static String naturalLengths(int hit, int success, int error, int rumble) =>
      'Natural lengths: hit $hit ms, success $success ms, error $error ms, rumble $rumble ms. A longer '
      'duration stretches the pattern; for rumble it is simply how long it lasts.';
  static const nothingSent = 'Nothing sent yet.';
  static String lastSent(String event, int percent, int durationMs, String source, String reached) =>
      'Last: $event, $percent%, $durationMs ms ($source) → $reached';
  static const nothingReached = 'no controller';
  static String reachedControllers(int count) => '$count controller${count == 1 ? '' : 's'}';
  static const noTargets = 'No controller connected (sounds still play)';
  static String sendsTo(String names) => 'Sends to $names';

  /// The steppers: a share of the full intensity, and a duration or each
  /// event's own length.
  static String percent(int percent) => '$percent%';
  static const natural = 'Natural';
  static String durationMs(int ms) => '$ms ms';
  static const intensity = 'Intensity';
  static const duration = 'Duration';

  // The Look test.
  static const shaderLoading = 'Shader: loading…';
  static String shaderOn(int loadMs) => 'Shader: on (loaded in $loadMs ms)';
  static String shaderOff(String error) => 'Shader: off: $error';
  static const noFrames = 'Frame time: no frames yet';
  static String frameTime(int frames, String averageMs, String worstMs) =>
      'Frame time, last $frames frames: $averageMs ms average, $worstMs ms worst';
  static String rows(int stressCount) =>
      'The top row uses the shader when it loaded and the bottom row always uses the fallback; they should '
      'look the same. Stress adds $stressCount more shapes to each row.';
  static const withShader = 'With the shader';
  static const withoutShader = 'Without it (the fallback)';
  static const stressOn = 'Stress: on';
  static const stressOff = 'Stress: off';
  static const shapes = 'Shapes';
  static const widgets = 'Widgets';

  // The screen a debug build shows until a phone joins.
  static const waitingForController = 'Waiting for a controller…';
}
