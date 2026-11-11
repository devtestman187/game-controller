import 'package:protocol/protocol.dart' show HapticEvent;

import 'host_text.dart';
import 'phone_text.dart';

/// The phone's Settings, its tuning dialogs and Diagnostics in words (M13 3c):
/// [PhoneText]'s other half, split off when the one table passed 400 lines
/// (Claude's 3c review). The same rules hold: one place for each wording, a
/// small function for a text with a value, and the tests keep their literals.
abstract final class SettingsText {
  // The Settings screen.
  static const defaults = 'Defaults';
  static const resetQuestion = 'Back to the defaults?';
  static const resetLine = 'Haptics, gyro, stick and game settings go back to how they were on a fresh install.';
  static const reset = 'Reset';
  static const haptics = 'Haptics';
  static const hapticsLine = 'A tick on every press, and the TV\'s game events';
  static const buttonTick = 'Button tick';
  static const trySomething = 'Try';
  static const tvEvents = 'TV events';
  static const tvEventsLine =
      'How strong each event from the TV feels, on its own. 0% turns that event off. The button tick isn\'t affected.';
  static const off = 'Off';
  static const checkingHardware = 'Checking the hardware…';
  static const noHaptics = 'This device has no haptics. Everything else still works.';
  static String motorOnOff(String engine) =>
      '$engine. This motor can only buzz on or off, so the strengths have no effect.';
  static const withoutHaptics = 'Without haptics';
  static const flashOnPress = 'Flash on press';
  static const flashOnPressLine = 'On by itself on devices without haptics';
  static const clickSound = 'Click sound';
  static const clickSoundLineIOS = 'A click on every press. The device must not be muted.';
  static const clickSoundLine = 'A click on every press. Needs Touch sounds on in the system settings.';
  static const gyroCalibrate = 'Calibrate from the gyro mode screen (or its settings button).';
  static const sensitivity = 'Sensitivity';
  static const deadZone = 'Dead zone';
  static const smoothing = 'Smoothing';
  static String gyroTiltHint(int degrees) => 'full at $degrees° of tilt';
  static const floatingSticks = 'Floating sticks';
  static const floatingLine = 'Each stick starts where your thumb lands in its half of the screen.';
  static const buttonSize = 'Button size';
  static const buttonSizeHint = 'A, B, X and Y, compared with D-pad mode';
  static String stickTravelHint(int percent) => 'full at $percent% of the travel';
  static const gameOnThisPhone = 'Game on this phone';
  static const gameOnThisPhoneLine = 'How much you can see the buttons when a game is behind them';
  static const opacity = 'Button visibility (opacity)';
  static const frameRate = 'Frame rate (test)';
  static const frameRateLine = 'For testing: fewer pictures a second saves battery but looks less smooth';
  static const controlStats = 'Control stats';
  static const hostStatsLine = 'The sessions this phone hosted, and the sharing choice, as the TV shows them.';
  static const shareStats = 'Share control stats with the TV';
  static const shareStatsLine =
      'The host counts how the controls are used: presses, missed taps, timing and how each mode feels. '
      'Never names, contacts, location or a trace of your touches. '
      'It sends them on to help improve Thumb Party only if an adult allows it on the device that hosts.';
  static const about = 'About';
  static String aboutVersion(String version) => 'Thumb Party $version';
  static const privacyPolicy = 'Privacy policy';
  static const testerGuide = 'Tester guide';
  static String couldNotOpen(String url) => 'Couldn\'t open $url';

  /// A percentage setting's value: "70%".
  static String percent(num value) => '${value.round()}%';

  /// A setting kept as a 0 to 1 fraction, shown as its percentage: "40%".
  static String share(num fraction) => percent(fraction * 100);

  /// A multiplier setting's value: "1.50×".
  static String times(double value) => '${value.toStringAsFixed(2)}×';

  /// One haptic event's name, on the settings rows.
  static String eventLabel(HapticEvent e) => switch (e) {
    HapticEvent.hit => 'Hit',
    HapticEvent.success => 'Success',
    HapticEvent.error => 'Error',
    HapticEvent.rumble => 'Rumble',
    HapticEvent.snap => 'Snap (puzzle)',
    HapticEvent.wrong => 'Wrong (puzzle)',
    HapticEvent.dropReady => 'Drop-ready (puzzle)',
    HapticEvent.help => 'Help (puzzle)',
    HapticEvent.tick => 'Last seconds',
  };

  /// What one haptic event feels like, so the sliders are easy to match up.
  static String eventFeel(HapticEvent e) => switch (e) {
    HapticEvent.hit => 'one deep thud',
    HapticEvent.success => 'three rising taps',
    HapticEvent.error => 'two harsh buzzes',
    HapticEvent.rumble => 'a long throb',
    HapticEvent.snap => 'a click and a firm lock',
    HapticEvent.wrong => 'a low, falling uh-oh',
    HapticEvent.dropReady => 'one light tap',
    HapticEvent.help => 'two gentle knocks',
    HapticEvent.tick => 'the lightest tap',
  };

  // The gyro and stick dialogs.
  static const done = 'Done';
  static const calibrate = 'Calibrate';
  static String gyroSensitivityLine(double times, int degrees) => '${times.toStringAsFixed(2)}× (full at $degrees°)';
  static const gyroLine =
      'Higher sensitivity: less tilt for the same value. A bigger dead zone hides small shakes '
      'around the center. More smoothing: steadier but a little slower.';
  static String stickButtonSizeLine(int percent) => 'Button size: $percent% of D-pad mode (A, B, X and Y)';
  static String stickDeadZoneLine(int percent) => 'Dead zone: $percent%';
  static String stickSensitivityLine(double times, int percent) =>
      'Sensitivity: ${times.toStringAsFixed(2)}× (full at $percent% of the travel)';
  static const stickLine =
      'A bigger dead zone ignores small thumb movements around the center. Higher sensitivity reaches '
      'full scale with less travel; a stick never goes past full scale, even diagonally.';

  // Diagnostics.
  static const copyReport = 'Copy report';
  static const reportCopied = 'Report copied';
  static const shareLog = 'Share log';
  static const copySubject = 'Controller diagnostics';
  static const connectionSection = 'Connection';
  static const statusRow = 'Status';
  static const tvRow = 'TV';
  static const addressRow = 'Address';
  static const tvIdRow = 'TV ID';
  static const playerRow = 'Player';
  static const pingRow = 'Ping';
  static const pingLast30Row = 'Ping, last 30 s';
  static const problemRow = 'Problem';
  static const detailRow = 'Detail';
  static const osErrorRow = 'OS error';
  static const reconnectAttemptRow = 'Reconnect attempt';
  static const localNetworkSection = 'Local network permission';
  static const discoverySection = 'Discovery';
  static String discoveryWithType(String type) => 'Discovery ($type)';
  static const runningRow = 'Running';
  static const errorRow = 'Error';
  static const foundRow = 'TVs found';
  static const yes = 'Yes';
  static const no = 'No';
  static const checking = 'Checking…';
  static const supportedRow = 'Supported';
  static const engineRow = 'Engine';
  static const intensityControlRow = 'Intensity control';
  static const onOffOnly = 'No (on/off only)';
  static const settingRow = 'Setting';
  static String tickStrength(int percent) => 'On, tick $percent%';
  static const eventStrengthsRow = 'TV event strengths';
  static const ticksPlayedRow = 'Ticks played';
  static const tvEventsRow = 'TV events';
  static String receivedPlayed(int received, int played) => '$received received, $played played';
  static const lastEventRow = 'Last TV event';
  static String eventDetail(String name, int percent, int durationMs) => '$name, $percent%, $durationMs ms';
  static const lastErrorRow = 'Last error';
  static const nativeDetailRow = 'Native detail';
  static const inputSection = 'Input';
  static const nowRow = 'Now';
  static const nothingPressed = 'Nothing pressed';
  static const statesSentRow = 'States sent';
  static const stickSettingsRow = 'Stick settings';
  static String stickSettingsValue(String kind, int deadZone, double sensitivity) =>
      '$kind, dead zone $deadZone%, sensitivity ${sensitivity.toStringAsFixed(2)}';
  static const floating = 'floating';
  static const fixed = 'fixed';
  static const modeRow = 'Mode';
  static const gyroscopeRow = 'Gyroscope';
  static const gyroNotChecked = 'Not checked yet (switch to Gyro)';
  static const working = 'Working';
  static const notAvailable = 'Not available';
  static const lockedToRow = 'Screen locked to';
  static String landscape(String side) => 'landscape $side';
  static const stickRow = 'Stick';
  static const upDirectionRow = 'Up direction';
  static const updatesRow = 'Updates';
  static const settingsRow = 'Settings';
  static String gyroSettingsValue(int deadZone, int smoothing) => 'dead zone $deadZone%, smoothing $smoothing%';
  static const reconnectsSection = 'Reconnects';
  static const noDrops = 'No drops since the app started.';
  static String droppedReconnecting(String reason) => 'Dropped ($reason), reconnecting…';
  static String droppedBackAfter(String reason, String seconds) => 'Dropped ($reason), back after $seconds s';
  static const sessionSection = 'Session (battery and CPU)';
  static const measuring = 'Measuring… (this phone build may not report it)';
  static const runningForRow = 'Running for';
  static const cpuRow = 'CPU';
  static String cpuValue(String recent, String all) => '$recent of one core (last minute), $all since launch';
  static const batteryRow = 'Battery';
  static String batteryValue(
    String level, {
    required bool charging,
    required bool lowPower,
    required String atLaunch,
  }) => '$level${charging ? ', charging' : ''}${lowPower ? ', Low Power Mode' : ''} ($atLaunch at launch)';
  static const batteryUseRow = 'Battery use';
  static const batteryLater = 'shown after 5 min on battery';
  static String perHour(String value) => '$value% per hour';
  static const heatRow = 'Heat';
  static const inputSentRow = 'Input sent';
  static String statesPerSecond(String value) => '$value states/s (last minute)';
  static const thisPhoneSection = 'This phone';
  static const nameRow = 'Name';
  static const controllerIdRow = 'Controller ID';
  static const platformRow = 'Platform';
  static const appVersionRow = 'App version';
  static const protocolRow = 'Protocol';
  static const gameView = 'Game view';

  /// A host's row in Discovery: its addresses, port, id and protocol version.
  static String discovered(String addresses, int port, String? id, String? version) =>
      '$addresses port $port · ID ${id ?? questionMark} · protocol v${version ?? questionMark}';

  /// A player's row: "P2 on the TV".
  static String playerOnTv(int number) => '${PhoneText.playerShort(number)} on the TV';

  /// A ping in a row: "42 ms", or a dash.
  static String milliseconds(int? ms) => ms == null ? HostText.dash : '$ms ms';

  /// The ping over 30 s in a row: "min 5, …, p95 300 ms", a dash for no p95.
  static String summaryWithP95(String summary, int? p95Ms) => '$summary, p95 ${p95Ms ?? HostText.dash} ms';

  /// The haptics setting's row: its tick strength, or off.
  static String tickSetting(bool on, int percent) => on ? 'On, tick $percent%' : off;

  /// One TV event's strength, as its row lists them: "hit 70%".
  static String eventStrength(String name, int percent) => '$name $percent%';

  /// The tilt's row: "x 0.120  y -0.340".
  static String tilt(double x, double y) => 'x ${x.toStringAsFixed(3)}  y ${y.toStringAsFixed(3)}';

  /// The protocol's version as a row and the report say it: "v1".
  static String protocolVersion(int version) => 'v$version';

  /// The log's heading: "Log (newest last, 12 lines)".
  static String logHeading(int lines) => 'Log (newest last, $lines lines)';
  static const hostLogHeading = 'Host log (this phone is the host):';
  static const questionMark = '?';
}
