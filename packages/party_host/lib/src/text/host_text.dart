import 'package:connection/connection.dart' show GamepadState, InputMode;
import 'package:puzzle_game/puzzle_game.dart' show Level, MatchFormat;

import '../stats_state.dart';

/// Every word the host's screens show a player, in one place (M13, design
/// section 7: "one string table"; docs/code-health.md's Look-and-sound row).
///
/// A screen takes its words from here, so a change of wording moves one place
/// and no two screens say one thing two ways ("Player 2 is away" is
/// [playerAway] wherever it is said). The texts a screen builds out of a value
/// are small functions beside their plain strings.
///
/// The tests keep their literal texts: they are the specification of what a
/// player reads, so a changed word fails one.
abstract final class HostText {
  // The title bar.
  static const back = 'Back';

  // The game picker.
  static const playTitle = 'Play';
  static const shapeRace = 'Shape Race';
  static const shapeRaceLine = 'Carry, turn and drop the pieces to build the picture.';
  static const arena = 'Arena';
  static const arenaLine = 'Race past walls and hazards to the goal.';
  static const puzzleSettings = 'Puzzle settings';
  static const playtestLine = 'For playtesting: tolerances, speeds and the time limit.';
  static const easy = 'Easy';
  static const medium = 'Medium';
  static const hard = 'Hard';

  /// A level's name, as the picker and the join screen say it.
  static String level(Level level) => switch (level) {
    Level.easy => easy,
    Level.medium => medium,
    Level.hard => hard,
  };

  /// Why the puzzle list is empty.
  static String puzzlesFailed(Object error) => 'The puzzles could not be loaded: $error';

  /// A button that plays any puzzle of a level: "Any Easy puzzle".
  static String anyPuzzle(String levelName) => 'Any $levelName puzzle';

  /// The same in a title, where it runs on after the game's name: "any Easy
  /// puzzle".
  static String anyPuzzleTitle(String levelName) => 'any $levelName puzzle';

  // The join screen.
  static const join = 'Join';
  static const start = 'Start';
  static const leave = 'Leave';
  static const leftSide = '◀ Left';
  static const rightSide = 'Right ▶';
  static const nobodyJoined = 'Nobody has joined yet.';
  static const beginWithPad = 'Press A or Start to begin.';
  static const beginTouch = 'Tap Start to begin.';
  static const beginTouchOrPad = 'Tap Start, or press A on a phone, to begin.';
  static const hintOwnPlayer = 'Tap a side to play; press A on a phone to join.';
  static const hintWithKeyboard =
      'Press A on your phone to join (Space on the keyboard), then left or right to pick a side. '
      'Then A or Start begins.';
  static const hint = 'Press A on your phone to join, then left or right to pick a side. Then A or Start begins.';
  static const separator = ' · ';

  /// A title and its detail: "Shape Race · Tree".
  static String titled(String title, String detail) => '$title$separator$detail';

  /// A joining player's row: its name, then whether it is simulated and
  /// whether it is this host's own player.
  static String playerLabel(String label, {required bool simulated, required bool own}) =>
      '$label${simulated ? ' (simulated)' : ''}${own ? ' (you)' : ''}';

  /// How many more players a side has room for.
  static String roomFor(int count) => 'Room for $count more';

  /// The players who haven't picked a side yet.
  static String notJoined(String names) => 'Not joined: $names';

  /// The format the joined players make: "1 vs 1", "2 vs 2".
  static String formatName(MatchFormat format) => switch (format) {
    MatchFormat.solo => '1 player',
    MatchFormat.team => 'A team of 2 on one board',
    MatchFormat.oneVsOne => '1 vs 1',
    MatchFormat.twoVsOne => '2 vs 1',
    MatchFormat.twoVsTwo => '2 vs 2',
  };

  // The pause menu.
  static const paused = 'Paused';
  static const anyoneCanResume = 'Anyone can resume.';
  static const quit = 'Quit';
  static const resume = 'Resume';

  /// The player who may resume: "P1", or "P2 or P1".
  static String resumerName(int number) => number == 1 ? 'P1' : 'P$number or P1';

  /// Who can resume the round: "P2 or P1 can resume, with Start or Resume."
  static String resumers(String who) => '$who can resume, with Start or Resume.';

  // The card over the game while a phone is away.
  static const ok = 'OK';
  static const playersAway = 'Players away';
  static const awayGone = 'The game goes on without them…';
  static const goOnWithout = 'Go on without them';
  static const endRound = 'End round';

  /// Which player the round waits for: "Player 2 is away" (one text for both
  /// "P2 is away" and "Player 2 is away", design section 7).
  static String playerAway(int number) => 'Player $number is away';

  /// How long a dropped phone's slot is held: "The game goes on if they're back
  /// in 24 s".
  static String awayCountdown(int seconds) => 'The game goes on if they\'re back in $seconds s';

  // The "Get ready" beat.
  static const getReady = 'Get ready';

  // The results.
  static const leftWins = 'Left wins!';
  static const rightWins = 'Right wins!';
  static const draw = 'Draw!';
  static const done = 'Done!';
  static const timeUp = 'Time\'s up!';
  static const left = 'Left';
  static const right = 'Right';
  static const changeTeams = 'Change teams';
  static const nextPuzzle = 'Next puzzle';
  static const rematch = 'Rematch';
  static const playAgain = 'Play again';
  static const playHint = 'Start on a phone: pause · Back: leave';
  static const playHintKeyboard = 'Arrows, Space, X and Z: play on the keyboard · Start on a phone: pause · Esc: leave';

  /// A side's time on the results: "105.9 seconds".
  static String seconds(double value) => '${value.toStringAsFixed(1)} seconds';

  /// A side's pieces on the results: "3 of 4 pieces placed".
  static String piecesPlaced(int placed, int total) => '$placed of $total pieces placed';

  // The Arena.
  static const noController = 'No controller connected. Pair a phone on the main screen.';
  static const noControllerKeys = 'No controller connected. Pair a phone on the main screen, or press an arrow key.';
  static const noneConnected = 'none connected';
  static const onThisDevice = ' (on this device)';
  static const dash = '–';
  static const controller = 'Controller';
  static const ping = 'Ping';
  static const inputDelay = 'Input delay';
  static const mode = 'Mode';
  static const values = 'Values';
  static const buttons = 'Buttons';
  static const lastHaptic = 'Last haptic';
  static const sounds = 'Sounds';

  /// A player's row in the debug overlay: its number and who it is.
  static String debugPlayer(int number, String nickname, {required bool local}) =>
      'P$number $nickname${local ? onThisDevice : ''}';

  /// A phone's latency in the debug overlay: "42 ms (30 s avg 40, max 90)",
  /// with a dash for an average it hasn't finished.
  static String pingMs(int nowMs, int? avgMs, int? maxMs) =>
      '$nowMs ms (30 s avg ${avgMs ?? dash}, max ${maxMs ?? dash})';

  /// A phone's input delay in the debug overlay: "~30 ms avg (± 4 ms)".
  static String inputDelayMs(int avgMs, int? errorMs) => '~$avgMs ms avg (± ${errorMs ?? '?'} ms)';

  /// The last haptic event the host sent.
  static String hapticEvent(String name, String source, int percent, int durationMs, int reached) =>
      '$name ($source), $percent%, $durationMs ms → $reached';

  /// The sound status: how many cues loaded, or why they didn't.
  static String soundsLoaded(int loaded, int all) => '$loaded of $all loaded';
  static String soundsOff(String error) => 'off ($error)';

  /// An input mode's name.
  static String modeName(InputMode mode) => switch (mode) {
    InputMode.dpad => 'D-pad',
    InputMode.gyro => 'Gyro',
    InputMode.sticks => 'Sticks',
    InputMode.keyboard => 'Keyboard',
    InputMode.none => dash,
  };

  /// What a phone's sticks, tilt or D-pad are sending.
  static String gamepadValues(GamepadState g) {
    String f(double v) => v.toStringAsFixed(2);
    return switch (g.mode) {
      InputMode.sticks => 'L ${f(g.leftX)}, ${f(g.leftY)}   R ${f(g.rightX)}, ${f(g.rightY)}',
      InputMode.gyro => 'Tilt x ${f(g.tiltX ?? g.leftX)}  y ${f(g.tiltY ?? g.leftY)}',
      InputMode.none => dash,
      _ => 'D-pad ${g.dpadX}, ${g.dpadY}',
    };
  }

  /// The buttons a phone is holding, by name.
  static String gamepadButtons(GamepadState g) {
    final names = [
      for (final b in g.buttons)
        if (!b.name.startsWith('dpad')) b.name.toUpperCase(),
    ];
    return names.isEmpty ? dash : names.join(' ');
  }

  // The puzzle settings.
  static const resetToDefaults = 'Reset to defaults';
  static const chaos = 'The cat';
  static const chaosOff = 'Off';
  static const chaosLittle = 'A little';
  static const chaosParty = 'Party';
  static const chaosLine = 'It bats a loose piece; on Party it also knocks one placed piece back to the tray';
  static const angleTolerance = 'Angle tolerance';
  static const positionTolerance = 'Position tolerance';
  static const rotationSpeed = 'Rotation speed (X and Y)';
  static const stickDeadZone = 'Right-stick dead zone (rotation)';
  static const pickupRange = 'Pickup range';
  static const hintDelay = 'Hint glow delay';
  static const timeLimit = 'Time limit';
  static const warningPeriod = 'Warning period';
  static const soloBigSpeed = 'Solo big-piece speed (teams, M11)';
  static const helpInterval = 'Help haptic interval (teams, M11)';
  static const dropReadyHighlight = 'Drop-ready highlight';
  static const dropReadyLine = 'The outline brightens and the phone ticks when a piece is close enough';
  static const less = '−';
  static const more = '+';
  static String lessOf(String label) => 'Less $label';
  static String moreOf(String label) => 'More $label';

  /// One setting's value in the settings it is read on.
  static String settingValue(String key, num v) => switch (key) {
    'angleToleranceDeg' => '±${v.round()}°',
    'positionTolerance' => '${(v * 100).round()}% of the piece',
    'rotationSpeedDegPerS' => '${v.round()}° a second',
    'stickDeadZone' => '${(v * 100).round()}% push',
    'pickupRange' => "${(v * 100).round()}% of the worker's reach",
    'soloBigSpeed' => '${(v * 100).round()}% of normal',
    'timeLimitS' => '${v ~/ 60}:${(v.round() % 60).toString().padLeft(2, '0')}',
    _ => '${v % 1 == 0 ? v.round() : v.toStringAsFixed(1)} s',
  };

  // The Stats screen.
  static const stats = 'Stats';
  static const export = 'Export';
  static const sharingOn = 'Sharing: on';
  static const sharingOff = 'Sharing: off';
  static const now = 'Now';
  static const consentQuestion = 'Share anonymous gameplay stats?';
  static const consentBody =
      'For the adult in charge of this device.\n\n'
      'Thumb Party TV can send anonymous stats to its developer: how the phone controls are used (presses, '
      'missed taps, timing, which mode), how quick the connection is, and how the games go. They help make '
      'the controls better.\n\n'
      'No names, accounts, contacts, location, advertising IDs or Wi-Fi details are ever sent. The stats are '
      'kept on this device either way, and you can change this at any time on the Stats screen. The privacy '
      'policy explains it in full.';
  static const dontShare = 'Don\'t share';
  static const shareStats = 'Share stats';
  static const sessionHeaders = [
    'Player',
    'Mode',
    'Time playing',
    'Presses',
    'Empty taps',
    'Near misses',
    'Slide-offs',
    'Input delay',
    'Rating',
  ];
  static const noSessions = 'No sessions yet. Stats are recorded while phones are connected.';
  static const noPlayersYet = 'No players yet.';
  static const inputDelayNote =
      'Input delay is the median for the whole session. Near misses are taps within about 8 mm of a control '
      'that missed it; empty taps landed on no control.';

  /// Where the export went.
  static String savedTo(String path) => 'Session files saved to $path';

  /// Why the export failed.
  static String exportFailed(Object error) => 'Could not export: $error';

  /// What the stats are doing: saved, shared and uploaded.
  static String statusLine(StatsState s) {
    final saved = '${s.saved} session${s.saved == 1 ? '' : 's'} saved on this device';
    if (s.consent != true) return '$saved. Sharing is off: nothing leaves this device.';
    if (!s.uploadConfigured) return '$saved. Sharing is on, but this build has no upload set up.';
    final waiting = s.waiting == 0 ? 'none waiting' : '${s.waiting} waiting to upload';
    final error = s.lastError == null ? '' : ' (last try failed, trying again later)';
    return '$saved. Sharing is on: ${s.uploaded} uploaded, $waiting$error.';
  }

  /// A session's date and the start of its id, for the list.
  static String sessionTitle(Map<String, Object?> s) {
    final date = s['date'] as String? ?? '';
    final id = (s['id'] as String? ?? '').padRight(4).substring(0, 4);
    return '$date · $id';
  }

  /// A session's length, players and rounds, for the list.
  static String sessionDetail(Map<String, Object?> s) {
    final minutes = ((s['durationS'] as num? ?? 0) / 60).toStringAsFixed(1);
    final players = (s['players'] as List?)?.length ?? 0;
    final rounds = (s['rounds'] as List?)?.length ?? 0;
    return '$minutes min · $players player${players == 1 ? '' : 's'} · $rounds round${rounds == 1 ? '' : 's'}';
  }

  /// A session's length, rounds and late frames.
  static String sessionLine(Map<String, Object?> summary) {
    final rounds = (summary['rounds'] as List?)?.length ?? 0;
    final frames = summary['frames'] as Map<Object?, Object?>?;
    final late = frames == null || (frames['drawn'] as num? ?? 0) == 0
        ? ''
        : ' · ${frames['dropped']} late frames of ${frames['drawn']}';
    return '${((summary['durationS'] as num? ?? 0) / 60).toStringAsFixed(1)} min · '
        '$rounds arena round${rounds == 1 ? '' : 's'}$late';
  }

  /// A table row's player: its number and the kind of phone it played on.
  static String playerKind(Map<Object?, Object?>? player, String kind) => 'P${player?['player']} $kind';

  /// A table row's time playing: "1 min 0 s", or "42 s".
  static String timePlaying(int ms) {
    final s = (ms / 1000).round();
    return s >= 60 ? '${s ~/ 60} min ${s % 60} s' : '$s s';
  }

  /// A table row's input delay: "9 ms (p95 10)", or a dash for a p95 it never
  /// measured.
  static String inputDelayRow(int medianMs, int? p95Ms) => '$medianMs ms (p95 ${p95Ms ?? dash})';

  /// A table row's input mode, from the stats' name for it.
  static String modeRow(String mode) => switch (mode) {
    'dpad' => 'D-pad',
    'gyro' => 'Gyro',
    'sticks' => 'Sticks',
    'keyboard' => 'Keyboard',
    _ => mode,
  };

  // The Look and sound settings.
  static const lookAndSound = 'Look and sound';
  static const look = 'Look';
  static const auto = 'Auto';
  static const sunny = 'Sunny';
  static const night = 'Night';
  static const effects = 'Effects';
  static const effectsLine = 'Moving backgrounds, shading and bounces. Turn off on a slow device.';
  static const mute = 'Mute';
  static const muteLine = 'Silences the music and every sound on this device.';
  static const music = 'Music';
  static const musicLine = 'Plays on the game picker and join screen.';

  /// The Auto line, built from the setting's own hours.
  static String autoLine(int fromHour, int untilHour) =>
      'Auto: Sunny from $fromHour:00 to $untilHour:00, Night otherwise';

  /// A percentage, as the Sound volume row shows it: "80%".
  static String percent(int value) => '$value%';
}
