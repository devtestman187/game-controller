import 'package:connection/connection.dart' show ClientProblem, ClientSnapshot, ClientStatus, maxNicknameLength;
import 'package:protocol/protocol.dart' show RatingTag;

import 'host_text.dart';

/// Every word the phone app's own screens show a player (M13, design section
/// 7: "one string table"), beside the host's screens' in `host_text.dart`.
///
/// A screen takes its words from here, so a change of wording moves one place
/// and no two screens say one thing two ways. What the phone and the host both
/// say is the host's table's: a player who is away, the countdown before their
/// round goes on without them and the look's name are [HostText]'s, and the
/// phone reads them from there. The texts a screen builds out of a value are
/// small functions beside their plain strings, and the tests keep their literal
/// texts, as the string table's own rule says.
abstract final class PhoneText {
  // The Connect screen.
  static const connectTitle = 'Connect to a TV';
  static const gamesOnWifi = 'Games on this Wi-Fi';
  static const searchAgain = 'Search again';
  static const diagnostics = 'Diagnostics';
  static const kindPc = 'PC';
  static const kindPhone = 'Phone';
  static const kindTablet = 'Tablet';
  static const kindTv = 'TV';

  /// A host's second line's word for its kind, or nothing for a host that
  /// didn't say (m12 §0.6).
  static String hostKindWord(String? kind) => switch (kind) {
    'pc' => kindPc,
    'phone' => kindPhone,
    'tablet' => kindTablet,
    'tv' => kindTv,
    _ => '',
  };
  static const searching = 'Searching… Open the Thumb Party TV app on the TV or PC, on the same Wi-Fi as this phone.';
  static String discoveryFailed(Object error) =>
      'Discovery isn\'t working ($error). Type the address shown on the TV below.';
  static const addressLabel = 'Or type the address';
  static const addressHint = '192.168.1.50:45780';
  static const connect = 'Connect';
  static const hostAGame = 'Host a game';
  static const settings = 'Settings';
  static const tryWithoutTv = 'Try without a TV';

  /// A host's second line: its kind's word, then what it shows today.
  static String hostLine(String kindWord, String shown) => kindWord.isEmpty ? shown : '$kindWord · $shown';

  /// A host that runs another protocol version than this app: "… · needs a
  /// matching app version".
  static String needsMatchingApp(String shown) => '$shown · needs a matching app version';

  // The connection panel.
  static const notConnected = 'Not connected';
  static const pickATv = 'Pick a TV on the left, or type its address.';
  static const connected = 'Connected';
  static const connecting = 'Connecting…';
  static const enterCode = 'Enter code';
  static const pairing = 'Pairing…';
  static const reconnecting = 'Reconnecting…';
  static String connectingTo(String host) => 'Connecting to $host…';
  static String connectionLostTo(String host) => 'Connection lost. Reconnecting to $host…';
  static String attempt(int count) => 'Attempt $count';
  static const stop = 'Stop';
  static const cancel = 'Cancel';
  static String connectedTo(String host) => 'Connected to $host';
  static String ping(int? ms) => ms == null ? 'Ping ${HostText.dash}' : 'Ping $ms ms';
  static String last30(String stats) => 'Last 30 s: $stats';
  static String pingStats(int minMs, int avgMs, int maxMs) => '30 s: min $minMs · avg $avgMs · max $maxMs ms';
  static const goBackToControls = 'Go back to use the controller.';
  static const disconnect = 'Disconnect';
  static const tryAgain = 'Try again';
  static String enterCodeOn(String host) => 'Enter the code shown on $host';
  static const codeHint = '0000';
  static const pair = 'Pair';

  /// The connection's state in one word, for the bar's chip and Diagnostics.
  static String status(ClientStatus status) => switch (status) {
    ClientStatus.idle => notConnected,
    ClientStatus.connecting => connecting,
    ClientStatus.waitingForCode => enterCode,
    ClientStatus.pairing => pairing,
    ClientStatus.connected => connected,
    ClientStatus.reconnecting => reconnecting,
    ClientStatus.failed => notConnected,
  };

  /// What a problem means and what to do about it.
  static String? problemText(ClientSnapshot s) {
    final host = s.hostLabel;
    return switch (s.problem) {
      null => null,
      ClientProblem.unreachable =>
        'Couldn\'t reach $host. Check that the TV app is open and that the phone is on the same Wi-Fi.',
      ClientProblem.wrongCode => 'Wrong code. Check the code on the TV and try again.',
      ClientProblem.tooManyAttempts => 'Too many wrong codes. The TV now shows a new code.',
      ClientProblem.pairingForgotten =>
        'The TV doesn\'t remember this phone (it may have restarted). Enter the code again.',
      ClientProblem.versionMismatch =>
        'The TV app and this app use different protocol versions. Install matching builds.',
      ClientProblem.replaced => 'This phone connected to the TV again on another connection.',
      ClientProblem.protocolError => 'The TV rejected a message${s.detail == null ? '' : ' (${s.detail})'}.',
      ClientProblem.pairingTimeout => 'The code wasn\'t entered in time.',
      ClientProblem.connectionLost => 'The connection to $host was lost.',
    };
  }

  // The top bar and the host chip.
  static const connection = 'Connection';
  static const padMode = 'Pad mode';
  static const demoLink = 'Demo, no TV · tap to connect';

  /// A player's number as the bar's badge says it: "P2".
  static String playerShort(int number) => 'P$number';

  /// The bar's connection as its label and ping: "Android TV · 9 ms".
  static String linkWithPing(String label, int? ms) => '$label · ${ms ?? HostText.dash} ms';
  static String tapToConnect(String label) => '$label · tap to connect';
  static String hosting(String code) => 'Hosting · $code';
  static const newCode = 'New code';
  static const stopHosting = 'Stop hosting';
  static const noWifi = 'Turn on Wi-Fi so other phones can join';
  static String youArePlayer(int number) => 'You are player $number on the TV';

  // The pad's modes.
  static const dpad = 'D-pad';
  static const gyro = 'Gyro';
  static const sticks = 'Sticks';
  static const gyroSettings = 'Gyro settings';
  static const stickSettings = 'Stick settings';
  static const notInThisGame = 'Not used in this game';
  static const steerByTilting = 'Steer by tilting the phone';
  static const twoSticks = 'Two analog sticks, Xbox-style';
  static const gyroUnavailable = 'Gyro mode isn\'t available.';

  /// A mode's name from its name in the protocol or the app.
  static String modeName(String name) => switch (name) {
    'dpad' => dpad,
    'gyro' => gyro,
    'sticks' => sticks,
    _ => name,
  };

  // The cards over the pad.
  static const waiting = 'Waiting';
  static const roundOver = 'Round over';
  static const leaveGame = 'Leave game';
  static const hostHasLeft = 'The host has left';
  static const youCanKeepWaiting = 'You can keep waiting, or leave.';
  static const waitingForHost = 'Waiting for the host to come back';
  static const reconnectingToGame = 'Reconnecting to the game…';
  static const abandoned = 'The host was away too long, so the round ended.';

  // The phone's player: nickname and character (M14 design section 9).
  static const nickname = 'Nickname';
  static const nicknameHint = 'Up to 10 characters: letters, numbers and spaces.';
  static String nicknameCount(int length) => '$length / $maxNicknameLength';
  static const colour = 'Colour';
  static const accessory = 'Accessory';
  static const you = 'You';
  static const worker = 'worker';
  static const marble = 'marble';
  static const showsNextTime = 'Shows next time you join.';

  /// What the phone says when the host gave it another colour (M14 design
  /// section 9): "Blue is taken tonight, you're Teal".
  static String takenTonight(String wanted, String given) => '$wanted is taken tonight, you\'re $given';

  // The results card over the last frame (M14 design section 9).
  static const youWin = 'You win!';
  static const youLose = 'You lose';
  static const draw = 'Draw';
  static String doneIn(String time) => 'Done! $time';
  static const done = 'Done!';
  static String pointsEarned(int points) => '+$points points';
  static String pieces(int count) => '$count pieces';
  static String coins(int count) => '$count coins';
  static const standings = 'Standings';
  static const waitingForNext = 'Waiting for the host to pick what\'s next.';

  /// A round's time as the results card and the game's clock say it: "1:42".
  static String clock(int minutes, int seconds) => '$minutes:${seconds.toString().padLeft(2, '0')}';

  // The rating prompt.
  static const howDidItFeel = 'How did the controls feel?';
  static const whatGotInTheWay = 'What got in the way?';
  static const good = 'Good';
  static const okay = 'Okay';
  static const bad = 'Bad';
  static const pickAnyThatFit = 'Pick any that fit (optional)';
  static const skip = 'Skip';
  static const send = 'Send';
  static const thanks = 'Thanks! That helps make the controls better.';

  /// The reasons a player can pick after Okay or Bad.
  static String ratingTag(String tag) => switch (tag) {
    RatingTag.buttonsTooSmall => 'Buttons too small',
    RatingTag.laggy => 'Laggy',
    RatingTag.hardToSteer => 'Hard to steer',
    RatingTag.rotationHard => 'Rotation hard',
    _ => tag,
  };

  // The host start sheet.
  static const playOnThisPhone = 'Play on this phone';
  static const playOnThisPhoneWhy = 'Play here with the controls on the screen';
  static const showOnThisDevice = 'Show on this device';
  static const showOnThisDeviceWhy = 'Everyone joins from their phones; this phone shows the game';
}
