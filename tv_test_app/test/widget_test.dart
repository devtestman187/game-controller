import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connection/connection.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_assets/asset_manifest.dart';
import 'package:metrics/metrics.dart';
import 'package:protocol/protocol.dart';
import 'package:puzzle_game/puzzle_game.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test_game/test_game.dart' show feedsOf;
import 'package:tvtest/main.dart';
import 'package:tvtest/src/analytics.dart';
import 'package:tvtest/src/host_controller.dart';
import 'package:tvtest/src/providers.dart';
import 'package:tvtest/src/screen_awake.dart';
import 'package:tvtest/src/sound.dart';
import 'package:tvtest/src/keyboard_player.dart';
import 'package:tvtest/src/ui/game_screen.dart';
import 'package:tvtest/src/ui/games_screen.dart';
import 'package:tvtest/src/ui/home_screen.dart';
import 'package:tvtest/src/ui/puzzle_screen.dart';
import 'package:tvtest/src/ui/puzzle_settings_screen.dart';
import 'package:tvtest/src/ui/haptic_panel_screen.dart';
import 'package:tvtest/src/ui/join_screen.dart';
import 'package:tvtest/src/ui/input_visualizer.dart';
import 'package:tvtest/src/ui/latency_screen.dart';
import 'package:tvtest/src/ui/stats_screen.dart';
import 'package:tvtest/src/ui/tv_button.dart';

class FakeHostController implements HostController {
  FakeHostController(this.state, {bool? consent = true}) : stats = FakeStats(consent: consent) {
    gameHost = FakeGameHost(this);
  }

  @override
  late final FakeGameHost gameHost;

  @override
  final FakeStats stats;

  @override
  Stream<String> get gameSounds => gameHost.soundStream;

  @override
  HostViewState state;
  final _changes = StreamController<HostViewState>.broadcast();
  int newCodes = 0;
  int simAdds = 0;
  int simStops = 0;
  int drops = 0;

  @override
  Stream<HostViewState> get changes => _changes.stream;

  void emit() => _changes.add(state);

  @override
  void newPairingCode() => newCodes++;

  @override
  void addSimulatedController() => simAdds++;

  @override
  void stopSimulatedControllers() => simStops++;

  @override
  void dropAllConnections() => drops++;

  /// Haptic events the game host sent: (event, player ID).
  final haptics = <(HapticEventMessage, String?)>[];

  int forgets = 0;
  int exports = 0;

  @override
  int forgetPairings() {
    forgets++;
    return 1;
  }

  @override
  Future<String> exportLog() async {
    exports++;
    return 'D:/logs/controller-test-log.txt';
  }

  @override
  Future<void> dispose() => _changes.close();
}

/// The game host over the fake host state: its connected controllers are the
/// players, plus any local ones.
class FakeGameHost implements GameHost {
  FakeGameHost(this.fake) {
    fake._changes.stream.listen((_) => _changes.add(players));
  }

  final FakeHostController fake;
  final locals = <String, LocalPlayer>{};
  final records = <GameRecord>[];
  final stages = <StageSample>[];
  final asks = <(String, String)>[];
  final _changes = StreamController<List<GamePlayer>>.broadcast();
  final _clock = Stopwatch()..start();

  ControllerInfo? _info(String id) => fake.state.players.where((c) => c.controllerId == id).firstOrNull;

  @override
  int get nowMs => _clock.elapsedMilliseconds;

  @override
  List<GamePlayer> get players => [
    for (final (i, c) in fake.state.players.indexed)
      GamePlayer(
        id: c.controllerId,
        number: c.player ?? i + 1,
        nickname: c.name,
        mode: InputMode.of(c.input),
        simulated: c.platform == 'sim',
      ),
    for (final l in locals.values)
      GamePlayer(id: l.id, number: l.number, nickname: l.nickname, local: true, mode: InputMode.keyboard),
  ]..sort((a, b) => a.number.compareTo(b.number));

  @override
  Stream<List<GamePlayer>> get playersChanged => _changes.stream;

  @override
  GamepadState gamepad(String playerId) =>
      locals[playerId]?.state ?? pads[playerId] ?? GamepadState.fromInput(_info(playerId)?.input);

  /// A phone's buttons, set by the test.
  final pads = <String, GamepadState>{};

  void setGamepad(String id, GamepadState state) => pads[id] = state;

  @override
  int? inputArrivedAtMs(String playerId) => null;

  @override
  bool haptic(String playerId, HapticEventMessage event) {
    if (_info(playerId) == null) return false;
    fake.haptics.add((event, playerId));
    return true;
  }

  @override
  bool askRating(String playerId, {required String id, required String game}) {
    asks.add((playerId, id));
    return true;
  }

  @override
  PlayerLatency? latency(String playerId) {
    final c = _info(playerId);
    if (c == null) return null;
    return (
      ping: c.rttStats,
      pingNowMs: c.rttMs,
      inputDelay: c.inputLatency,
      inputDelaySession: c.inputLatencySession,
      errorMs: c.latencyErrorMs,
    );
  }

  @override
  RttSummary? stageSummary(String playerId, String stage) =>
      stage == LatencyStage.sentToReceived ? _info(playerId)?.inputLatency : null;

  @override
  void record(GameRecord record) => records.add(record);

  @override
  void reportStage(String playerId, String stage, int ms) => stages.add((playerId: playerId, stage: stage, ms: ms));

  final _sounds = StreamController<String>.broadcast();
  Stream<String> get soundStream => _sounds.stream;

  /// Each player's layout and status panel, as the game set them.
  final layouts = <String, GameLayoutMessage>{};
  final statuses = <String, StatusMessage>{};

  @override
  void playSound(String name) => _sounds.add(name);

  @override
  void setLayout(String playerId, GameLayoutMessage layout) => layouts[playerId] = layout;

  @override
  void setStatus(String playerId, StatusMessage status) => statuses[playerId] = status;

  @override
  LocalPlayer addLocalPlayer({String? nickname}) {
    final n = players.fold(0, (a, p) => p.number > a ? p.number : a) + 1;
    final p = LocalPlayer(
      'local-$n',
      n,
      nickname: nickname,
      onRemove: (p) {
        locals.remove(p.id);
        _changes.add(players);
      },
    );
    locals[p.id] = p;
    _changes.add(players);
    return p;
  }
}

/// Analytics for the tests: [summaries] are the saved sessions.
class FakeStats implements StatsService {
  FakeStats({bool? consent}) : _state = StatsState(consent: consent, uploadConfigured: true);

  StatsState _state;
  final _changes = StreamController<StatsState>.broadcast();
  final summaries = <Map<String, Object?>>[];
  final consents = <bool>[];
  int exports = 0;

  void emit(StatsState s) {
    _state = s;
    _changes.add(s);
  }

  @override
  StatsState get state => _state;

  @override
  Stream<StatsState> get changes => _changes.stream;

  @override
  Future<List<SessionFile>> sessions() async => [
    for (final (i, s) in summaries.indexed) SessionFile('/sessions/s$i.json', s),
  ];

  @override
  Future<String> exportAll() async {
    exports++;
    return 'D:/Downloads/thumb-party-sessions';
  }

  @override
  void setConsent(bool share) {
    consents.add(share);
    emit(_state.copyWith(consent: share));
  }

  @override
  Future<void> uploadNow() async {}
}

HostViewState sampleState() => HostViewState(
  hostName: 'Android TV',
  host: HostSnapshot(
    running: true,
    port: 45780,
    pairingCode: '0427',
    controllers: [
      ControllerInfo(
        controllerId: 'p1',
        name: 'iPhone 3F1C',
        platform: 'ios',
        appVersion: '0.1.0',
        remoteAddress: '192.168.1.20',
        state: ControllerState.connected,
        since: DateTime(2026),
        rttMs: 12,
        rttStats: const RttSummary(minMs: 8, avgMs: 20, maxMs: 140, samples: 30, p95Ms: 60),
        input: InputStateMessage(seq: 3, buttons: {ControllerButton.a}, dx: 1),
        player: 1,
        inputLatency: const RttSummary(minMs: 3, avgMs: 9, maxMs: 41, samples: 900, p95Ms: 18),
        inputLatencySession: const RttSummary(minMs: 2, avgMs: 10, maxMs: 80, samples: 5400),
        latencyErrorMs: 4,
      ),
      ControllerInfo(
        controllerId: 'p2',
        name: 'Pixel',
        platform: 'android',
        appVersion: '0.1.0',
        remoteAddress: '192.168.1.21',
        state: ControllerState.pairing,
        since: DateTime(2026),
      ),
    ],
  ),
  addresses: const [LocalAddress('192.168.1.50', 'wlan0')],
  advertise: AdvertiseState.advertising,
  advertisedName: 'Thumb Party TV (Android TV)',
);

/// A connected phone, like the sample state's first controller, without input.
ControllerInfo phoneInfo(String id, int player, {String platform = 'android'}) => ControllerInfo(
  controllerId: id,
  name: 'Phone $player',
  platform: platform,
  appVersion: '0.1.0',
  remoteAddress: '192.168.1.2$player',
  state: ControllerState.connected,
  since: DateTime(2026),
  player: player,
);

/// [s] with [c] added to its controllers, as the host reports a new phone.
HostViewState withController(HostViewState s, ControllerInfo c) => HostViewState(
  hostName: s.hostName,
  host: HostSnapshot(
    running: s.host.running,
    port: s.host.port,
    pairingCode: s.host.pairingCode,
    controllers: [...s.host.controllers, c],
  ),
  addresses: s.addresses,
  advertise: s.advertise,
  advertisedName: s.advertisedName,
  advertiseError: s.advertiseError,
  serverError: s.serverError,
  sims: s.sims,
);

late FakeSoundPlayer sounds;
late FakeScreenAwake awake;

class FakeScreenAwake implements ScreenAwake {
  final calls = <bool>[];

  bool get on => calls.isNotEmpty && calls.last;

  @override
  Future<void> set(bool on) async => calls.add(on);
}

/// Scrolls a button into view first: the pairing panel scrolls at TV size.
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
}

Future<FakeHostController> pumpApp(
  WidgetTester tester, {
  Size size = const Size(960, 540),
  bool? consent = true,
  List<Map<String, Object?>> sessions = const [],
}) async {
  sounds = FakeSoundPlayer();
  awake = FakeScreenAwake();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final fake = FakeHostController(sampleState(), consent: consent);
  fake.stats.summaries.addAll(sessions);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        prefsProvider.overrideWithValue(prefs),
        puzzleLibraryProvider.overrideWith((ref) => testPuzzles()),
        hostControllerProvider.overrideWithValue(fake),
        soundPlayerProvider.overrideWithValue(sounds),
        screenAwakeProvider.overrideWithValue(awake),
      ],
      child: const TvTestApp(),
    ),
  );
  await tester.pumpAndSettle();
  return fake;
}

void main() {
  testWidgets('shows the pairing code, address and controllers with ping', (tester) async {
    await pumpApp(tester);
    expect(find.text('0 4 2 7'), findsOneWidget);
    expect(find.textContaining('192.168.1.50:45780'), findsOneWidget);
    expect(find.textContaining('Thumb Party TV (Android TV)'), findsOneWidget);
    expect(find.text('iPhone 3F1C'), findsOneWidget);
    expect(find.text('Connected'), findsOneWidget);
    expect(find.text('12 ms'), findsOneWidget);
    expect(find.text('Waiting for code'), findsOneWidget);
    expect(
      find.textContaining('devtestman187.github.io/game-controller'),
      findsOneWidget,
      reason: 'guide and privacy link',
    );
    expect(find.textContaining('Version 0.'), findsOneWidget, reason: 'testers can say which build they have');
    expect(find.text('Controllers · 1 connected'), findsOneWidget);
    expect(find.text('avg 20 ms'), findsOneWidget);
    expect(find.text('max 140 ms'), findsOneWidget);
    final shown = tester.widget<InputVisualizer>(find.byKey(const Key('visualizer-p1')));
    expect(shown.gamepad?.buttons, {GamepadButton.a, GamepadButton.dpadRight});
    expect(shown.gamepad?.dpadX, 1);
    // A controller still pairing shows nothing pressed.
    expect(tester.widget<InputVisualizer>(find.byKey(const Key('visualizer-p2'))).gamepad, isNull);
  });

  testWidgets('the remote reaches and presses every button', (tester) async {
    final fake = await pumpApp(tester);
    String? focused() => FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<TvButton>()?.label;

    final pressed = <String>{};
    final opened = <Type>[];
    Future<void> key(LogicalKeyboardKey k) async {
      await tester.sendKeyEvent(k);
      await tester.pumpAndSettle();
    }

    // Presses OK on the focused button. A new screen is closed again with Esc
    // (Back on the remote), which returns focus to the button.
    Future<void> pressFocused() async {
      final label = focused();
      if (label == null || !pressed.add(label)) return;
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      // The game animates every frame, so pump through the page transition.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      for (final screen in [GamesScreen, HapticPanelScreen, LatencyScreen, StatsScreen]) {
        if (find.byType(screen).evaluate().isNotEmpty) {
          opened.add(screen);
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));
        }
      }
      await tester.pumpAndSettle();
    }

    // "New code" is focused on launch. Find every button the arrows reach:
    // from each one found, try all four arrows (going back to it by focusing
    // it directly before each try). Then press each one with OK.
    void focusButton(String label) =>
        Focus.of(tester.element(find.descendant(of: find.widgetWithText(TvButton, label), matching: find.text(label))))
            .requestFocus();
    const directions = [
      LogicalKeyboardKey.arrowDown,
      LogicalKeyboardKey.arrowRight,
      LogicalKeyboardKey.arrowUp,
      LogicalKeyboardKey.arrowLeft,
    ];
    final reached = <String>{focused()!};
    final queue = [focused()!];
    while (queue.isNotEmpty) {
      final from = queue.removeLast();
      for (final d in directions) {
        focusButton(from);
        await tester.pump();
        await key(d);
        final to = focused();
        if (to != null && reached.add(to)) queue.add(to);
      }
    }
    for (final label in reached) {
      focusButton(label);
      await tester.pump();
      await pressFocused();
    }

    expect(pressed, {
      'New code',
      'Simulate controller',
      'Drop connections',
      'Forget phones',
      'Save log',
      'Play',
      'Haptic test',
      'Latency',
      'Stats',
    });
    expect([fake.newCodes, fake.simAdds, fake.drops, fake.forgets, fake.exports], [1, 1, 1, 1, 1]);
    expect(opened.toSet(), {GamesScreen, HapticPanelScreen, LatencyScreen, StatsScreen});
  });

  testWidgets('updates when the host state changes', (tester) async {
    final fake = await pumpApp(tester);
    final s = fake.state;
    fake.state = HostViewState(
      hostName: s.hostName,
      host: HostSnapshot(running: true, port: 45780, pairingCode: '9001', controllers: const []),
      addresses: s.addresses,
      advertise: AdvertiseState.failed,
      advertiseError: 'mDNS unavailable',
    );
    fake._changes.add(fake.state);
    await tester.pumpAndSettle();
    expect(find.text('9 0 0 1'), findsOneWidget);
    expect(find.textContaining('No controllers yet'), findsOneWidget);
    expect(find.textContaining('mDNS unavailable'), findsOneWidget);
  });

  testWidgets('shows gyro tilt as numbers and a stick', (tester) async {
    final fake = await pumpApp(tester);
    fake.state = HostViewState(
      hostName: 'Android TV',
      host: HostSnapshot(
        running: true,
        port: 45780,
        pairingCode: '0427',
        controllers: [
          ControllerInfo(
            controllerId: 'g1',
            name: 'iPhone 3F1C',
            platform: 'ios',
            appVersion: '0.3.0',
            remoteAddress: '192.168.1.20',
            state: ControllerState.connected,
            since: DateTime(2026),
            rttMs: 8,
            input: InputStateMessage(seq: 9, buttons: {ControllerButton.b}, ax: 0.25, ay: -0.5),
          ),
        ],
      ),
    );
    fake.emit();
    await tester.pumpAndSettle();
    expect(find.text('Tilt x 0.25  y -0.50'), findsOneWidget);
    final shown = tester.widget<InputVisualizer>(find.byKey(const Key('visualizer-g1')));
    expect([shown.gamepad?.tiltX, shown.gamepad?.tiltY], [0.25, -0.5]);
    expect(shown.gamepad?.mode, InputMode.gyro);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows both sticks and the shoulder buttons in stick mode', (tester) async {
    final fake = await pumpApp(tester);
    fake.state = HostViewState(
      hostName: 'Android TV',
      host: HostSnapshot(
        running: true,
        port: 45780,
        pairingCode: '0427',
        controllers: [
          ControllerInfo(
            controllerId: 's1',
            name: 'iPhone 3F1C',
            platform: 'ios',
            appVersion: '0.4.0',
            remoteAddress: '192.168.1.20',
            state: ControllerState.connected,
            since: DateTime(2026),
            rttMs: 8,
            input: InputStateMessage(
              seq: 4,
              buttons: {ControllerButton.lb, ControllerButton.a},
              lx: -0.5,
              ly: 0.25,
              rx: 1,
              ry: 0,
            ),
          ),
        ],
      ),
    );
    fake.emit();
    await tester.pumpAndSettle();
    expect(find.text('L -0.50, 0.25   R 1.00, 0.00'), findsOneWidget);
    final shown = tester.widget<InputVisualizer>(find.byKey(const Key('visualizer-s1')));
    expect(shown.gamepad?.mode, InputMode.sticks);
    expect(shown.gamepad?.buttons, {GamepadButton.lb, GamepadButton.a});
    expect(tester.takeException(), isNull);
  });

  testWidgets('fits a small laptop window without overflow', (tester) async {
    await pumpApp(tester, size: const Size(600, 800));
    expect(tester.takeException(), isNull);
    expect(find.text('0 4 2 7'), findsOneWidget);
  });

  testWidgets('fits a 1080p TV (960 x 540 logical pixels) without overflow', (tester) async {
    await pumpApp(tester);
    expect(tester.takeException(), isNull);
    expect(find.byType(Center), findsWidgets);
  });

  testWidgets('shows that the four event sounds loaded', (tester) async {
    await pumpApp(tester);
    expect(
      find.text('${SoundKey.values.length} of ${SoundKey.values.length} event sounds loaded (fake)'),
      findsOneWidget,
    );
  });

  group('haptic test panel', () {
    Future<FakeHostController> openPanel(WidgetTester tester) async {
      final fake = await pumpApp(tester);
      await tapVisible(tester, find.text('Haptic test'));
      await tester.pumpAndSettle();
      return fake;
    }

    testWidgets('each button sends its event to the connected controllers and plays its sound', (tester) async {
      final fake = await openPanel(tester);
      expect(find.text('Sends to P1 iPhone 3F1C'), findsOneWidget);
      for (final e in HapticEvent.values) {
        await tester.tap(find.byKey(Key('fire-${e.name}')));
        await tester.pump();
      }
      expect(fake.haptics.map((h) => h.$1), [for (final e in HapticEvent.values) HapticEventMessage(event: e)]);
      expect(fake.haptics.every((h) => h.$2 == 'p1'), isTrue, reason: 'to every connected controller');
      expect(sounds.played, [for (final e in HapticEvent.values) e.name]);
      await tester.scrollUntilVisible(find.byKey(const Key('lastSent')), 200);
      expect(find.text('Last: tick, 100%, 30 ms (panel) → 1 controller'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('intensity and duration steppers change what is sent', (tester) async {
      final fake = await openPanel(tester);
      // Nine events: the steppers are further down, as on the TV.
      await tester.scrollUntilVisible(find.byTooltip('More Duration'), 200);
      await tester.tap(find.byTooltip('Less Intensity'));
      await tester.tap(find.byTooltip('Less Intensity'));
      await tester.tap(find.byTooltip('More Duration'));
      await tester.tap(find.byTooltip('More Duration'));
      await tester.pump();
      expect(find.text('80%'), findsOneWidget);
      expect(find.text('200 ms'), findsOneWidget);
      await tapVisible(tester, find.byKey(const Key('fire-error')));
      await tester.pump();
      expect(fake.haptics.single.$1, HapticEventMessage(event: HapticEvent.error, intensity: 0.8, durationMs: 200));

      // The limits hold, and the buttons stay usable there.
      await tester.scrollUntilVisible(find.byTooltip('More Duration'), 200);
      for (var i = 0; i < 12; i++) {
        await tester.tap(find.byTooltip('More Intensity'));
        await tester.tap(find.byTooltip('Less Duration'));
      }
      await tester.pump();
      expect(find.text('100%'), findsOneWidget);
      expect(find.text('Natural'), findsOneWidget);
    });

    testWidgets('works with the remote: Hit has focus and OK fires it', (tester) async {
      final fake = await openPanel(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pump();
      expect(fake.haptics.single.$1.event, HapticEvent.hit);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pump();
      expect(fake.haptics.last.$1.event, HapticEvent.success);
    });

    testWidgets('without a controller the sounds still play', (tester) async {
      final fake = await pumpApp(tester);
      fake.state = HostViewState(
        hostName: 'Android TV',
        host: HostSnapshot(running: true, port: 45780, pairingCode: '0427', controllers: const []),
      );
      fake.emit();
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Haptic test'));
      await tester.pumpAndSettle();
      expect(find.textContaining('No controller connected'), findsOneWidget);
      await tester.tap(find.byKey(const Key('fire-hit')));
      await tester.pump();
      expect(sounds.played, ['hit']);
      await tester.scrollUntilVisible(find.byKey(const Key('lastSent')), 200);
      expect(find.textContaining('→ no controller'), findsOneWidget);
    });
  });

  group('test game', () {
    Future<void> frames(WidgetTester tester, int n) async {
      for (var i = 0; i < n; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    }

    Future<FakeHostController> openGame(WidgetTester tester, {Size size = const Size(960, 540)}) async {
      final fake = await pumpApp(tester, size: size);
      await openArena(tester);
      return fake;
    }

    testWidgets('the connected controller drives it; events go to it with their sounds', (tester) async {
      // The sample controller holds A and right: it dashes at once, then
      // walks into the first wall.
      final fake = await openGame(tester);
      await frames(tester, 90);
      final sent = fake.haptics.map((h) => (h.$1.event, h.$2)).toList();
      expect(sent.first, (HapticEvent.rumble, 'p1'));
      expect(sent, contains((HapticEvent.hit, 'p1')));
      expect(sounds.played.take(2), ['rumble', 'hit']);
      expect(find.text('Dashes 1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('OK or D shows the debug overlay, and again hides it', (tester) async {
      await openGame(tester);
      expect(find.byKey(const Key('debugOverlay')), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
      await frames(tester, 5);
      expect(find.byKey(const Key('debugOverlay')), findsOneWidget);
      expect(find.text('iPhone 3F1C'), findsOneWidget);
      expect(find.text('P1'), findsOneWidget);
      expect(find.textContaining('12 ms'), findsOneWidget);
      expect(find.text('~9 ms avg (± 4 ms)'), findsOneWidget);
      expect(find.text('D-pad'), findsOneWidget);
      expect(find.text('D-pad 1, 0'), findsOneWidget);
      expect(find.textContaining('rumble (game: dash, P1)'), findsOneWidget);
      expect(find.text('${SoundKey.values.length} of ${SoundKey.values.length} loaded'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await frames(tester, 2);
      expect(find.byKey(const Key('debugOverlay')), findsNothing);
    });

    testWidgets('Escape goes back to the game picker, and again to the main screen', (tester) async {
      await openGame(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(GameScreen), findsNothing);
      expect(find.byType(GamesScreen), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('0 4 2 7'), findsOneWidget);
    });

    testWidgets('fills a small laptop window without overflow', (tester) async {
      await openGame(tester, size: const Size(600, 800));
      await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
      await frames(tester, 10);
      expect(tester.takeException(), isNull);
    });
  });

  group('several controllers (M6)', () {
    ControllerInfo c(String id, int? player, {InputStateMessage? input, String name = 'Phone'}) => ControllerInfo(
      controllerId: id,
      name: '$name $id',
      platform: 'ios',
      appVersion: '0.6.0',
      remoteAddress: '192.168.1.2$player',
      state: player == null ? ControllerState.disconnected : ControllerState.connected,
      since: DateTime(2026),
      rttMs: 10,
      player: player,
      input: input,
    );
    HostViewState s(List<ControllerInfo> list) => HostViewState(
      hostName: 'TV',
      host: HostSnapshot(running: true, port: 45780, pairingCode: '1234', controllers: list),
    );

    test('players are the connected controllers in player order, each with its colour', () {
      final fake = FakeHostController(s([c('b', 2), c('gone', null), c('a', 1)]));
      final feeds = feedsOf(fake.gameHost);
      expect(feeds.map((f) => (f.id, f.number)), [('a', 1), ('b', 2)]);
      expect(feeds.map((f) => f.color), [Color(playerColors[0]), Color(playerColors[1])]);
    });

    testWidgets('each controller drives its own sprite, and feels only its own events', (tester) async {
      final fake = await pumpApp(tester);
      // Player 1 dashes, player 2 walks left into the edge of the field.
      fake.state = s([
        c('a', 1, input: InputStateMessage(seq: 1, buttons: {ControllerButton.a})),
        c('b', 2, input: InputStateMessage(seq: 1, dx: -1)),
      ]);
      fake.emit();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('player-a')), findsOneWidget);
      expect(find.byKey(const Key('player-b')), findsOneWidget);
      await openArena(tester);
      for (var i = 0; i < 90; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      final sent = fake.haptics.map((h) => (h.$1.event, h.$2)).toList();
      expect(sent.where((e) => e.$2 == 'a').map((e) => e.$1).first, HapticEvent.rumble);
      expect(sent.where((e) => e.$2 == 'b').map((e) => e.$1), contains(HapticEvent.hit));
      expect(sent.map((e) => e.$2).toSet(), {'a', 'b'}, reason: 'game events go to their own player only');
      expect(find.text('P1 Phone a'), findsOneWidget);
      expect(find.text('P2 Phone b'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('latency and the log (M6)', () {
    testWidgets('the screen stays on while a controller is connected, and may sleep after', (tester) async {
      final fake = await pumpApp(tester);
      expect(awake.on, isTrue, reason: 'the sample state has one connected controller');
      fake.state = HostViewState(
        hostName: 'Android TV',
        host: HostSnapshot(running: true, port: 45780, pairingCode: '0427', controllers: const []),
      );
      fake.emit();
      await tester.pumpAndSettle();
      expect(awake.on, isFalse);
      expect(awake.calls, [true, false]);
    });

    testWidgets('the main screen shows the player badge and the input delay', (tester) async {
      await pumpApp(tester);
      expect(find.byKey(const Key('player-p1')), findsOneWidget);
      expect(find.text('input ~9 ms'), findsOneWidget);
    });

    testWidgets('the latency screen shows ping and input delay against the target', (tester) async {
      final fake = await pumpApp(tester);
      await tapVisible(tester, find.text('Latency'));
      await tester.pumpAndSettle();
      expect(find.byType(LatencyScreen), findsOneWidget);
      expect(find.text('iPhone 3F1C'), findsOneWidget);
      expect(find.text('Within the 50 ms target'), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('inputDelay-p1'))).data, '9 ms');
      expect(find.text('p95 18 · max 41 ms · ± 4 ms'), findsOneWidget);
      expect(find.text('10 ms'), findsOneWidget, reason: 'session average');
      expect(find.text('min 8 · p95 60 · max 140 ms'), findsOneWidget);
      // Save log is focused: OK saves and says where.
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      expect(fake.exports, 1);
      expect(find.textContaining('Log saved to D:/logs/controller-test-log.txt'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the latency screen fits a small window', (tester) async {
      await pumpApp(tester, size: const Size(600, 800));
      await tapVisible(tester, find.text('Latency'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    test('the exported log starts with each controller\'s latency, then every line', () {
      final log = LogBuffer()
        ..add('host', 'Listening on port 45780')
        ..add('host', 'iPhone 3F1C connected');
      final text = buildLogExport(sampleState(), log, now: DateTime(2026, 10, 25, 20, 15));
      expect(text, startsWith('Thumb Party TV '));
      expect(text, contains('2026-10-25T20:15:00.000'));
      expect(text, contains('P1 iPhone 3F1C (ios 0.1.0), connected'));
      expect(text, contains('Ping: min 8 · avg 20 · max 140 ms, p95 60 ms'));
      expect(
        text,
        contains(
          'Input delay (estimated, one way): avg 9 · p95 18 · max 41 ms (± 4 ms); session avg 10 ms over 5400 states',
        ),
      );
      expect(text, contains('Pixel (android 0.1.0), pairing'));
      expect(text, contains('[host] iPhone 3F1C connected'));
    });

    test('pairings are saved and loaded; broken data is ignored', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      expect(loadPairings(prefs), isEmpty);
      savePairings(prefs, const [
        SavedPairing(controllerId: 'p1', token: 'tok', name: 'iPhone 3F1C', platform: 'ios', appVersion: '0.6.0'),
      ]);
      expect(loadPairings(prefs).single.token, 'tok');
      await prefs.setString('pairings', '[{"id": "x"}, 5, {"id": "p2", "token": "t2"}]');
      expect(loadPairings(prefs).map((p) => p.controllerId), ['p2']);
      await prefs.setString('pairings', 'not json');
      expect(loadPairings(prefs), isEmpty);
    });
  });

  group('stats (M9)', stats);
  group('puzzle (M10)', puzzle);
  group('M11', m11);
}

/// A small saved session: one phone, D-pad then sticks.
Map<String, Object?> sampleSession() {
  final c = SessionCollector(
    id: 'abcd1234',
    hostType: HostType.androidTv,
    hostApp: '0.9.0',
    startedAt: DateTime.utc(2026, 10, 31),
    startMs: 0,
  );
  c.joined(
    'p1',
    number: 1,
    atMs: 0,
    platform: 'ios',
    device: const DeviceInfo(kind: DeviceInfo.phone),
  );
  c.metrics(
    'p1',
    MetricsMessage(
      segment: 's1',
      index: 0,
      mode: 'dpad',
      durationMs: 60000,
      ended: true,
      data: {
        'start': 0,
        'presses': {'a': 40, 'b': 2},
        'empty': {'5,1': 3},
        'near': {'b': 4},
        'slide': {'a': 1},
      },
    ),
  );
  c.metrics(
    'p1',
    MetricsMessage(
      segment: 's2',
      index: 0,
      mode: 'sticks',
      durationMs: 30000,
      data: {
        'start': 60000,
        'presses': {'ls': 5},
      },
    ),
  );
  for (final ms in [8, 9, 10]) {
    c.stage('p1', LatencyStage.sentToReceived, ms);
  }
  c.mode('p1', 'sticks');
  c.rating(
    'p1',
    RatingMessage(id: 'r', face: RatingFace.good),
    game: 'arena',
  );
  return c.summary(90000);
}

void stats() {
  testWidgets('the first launch asks the adult about sharing; nothing is shared by default', (tester) async {
    final fake = await pumpApp(tester, consent: null);
    expect(find.byKey(const Key('consentDialog')), findsOneWidget);
    expect(find.textContaining('No names, accounts'), findsOneWidget);
    // "Don't share" has the remote's focus.
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(fake.stats.consents, [false]);
    expect(find.byKey(const Key('consentDialog')), findsNothing);
  });

  testWidgets('once answered, the prompt does not come back', (tester) async {
    await pumpApp(tester);
    expect(find.byKey(const Key('consentDialog')), findsNothing);
  });

  testWidgets('the Stats screen shows each mode with presses, empty taps, near misses and input delay', (tester) async {
    await pumpApp(tester, sessions: [sampleSession()]);
    await tapVisible(tester, find.byKey(const Key('openStats')));
    await tester.pumpAndSettle();
    expect(find.byType(StatsScreen), findsOneWidget);
    expect(find.byKey(const Key('sessionTable')), findsOneWidget);
    expect(find.text('D-pad'), findsOneWidget);
    expect(find.text('Sticks'), findsOneWidget);
    expect(find.text('1 min 0 s'), findsOneWidget);
    expect(find.text('42'), findsOneWidget, reason: 'presses in D-pad mode');
    expect(find.text('4'), findsOneWidget, reason: 'near misses');
    expect(find.text('9 ms (p95 10)'), findsNWidgets(2));
    expect(find.text('1 good'), findsOneWidget);
    expect(find.textContaining('Sharing is on'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Export saves the session files and says where; Sharing changes the choice', (tester) async {
    final fake = await pumpApp(tester, sessions: [sampleSession()]);
    await tapVisible(tester, find.byKey(const Key('openStats')));
    await tester.pumpAndSettle();
    // Export has the remote's focus.
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(fake.stats.exports, 1);
    expect(find.textContaining('D:/Downloads/thumb-party-sessions'), findsOneWidget);

    await tester.tap(find.byKey(const Key('statsSharing')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('consentNo')));
    await tester.pumpAndSettle();
    expect(fake.stats.consents, [false]);
    expect(find.text('Sharing: off'), findsOneWidget);
    expect(find.textContaining('nothing leaves this device'), findsOneWidget);
  });

  testWidgets('the Stats screen with no sessions, and in a small window', (tester) async {
    await pumpApp(tester, size: const Size(700, 700));
    await tapVisible(tester, find.byKey(const Key('openStats')));
    await tester.pumpAndSettle();
    expect(find.textContaining('No sessions yet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('on Windows the arrow keys add a keyboard player, who leaves with the screen', (tester) async {
    keyboardPlayerAvailable = true;
    addTearDown(() => keyboardPlayerAvailable = false);
    final fake = await pumpApp(tester);
    await openArena(tester);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowLeft);
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(fake.gameHost.locals, hasLength(1));
    final keyboard = fake.gameHost.locals.values.single;
    expect(keyboard.number, 2);
    expect(keyboard.state.pressed(GamepadButton.dpadLeft), isTrue);
    expect(find.text('P2 Keyboard'), findsOneWidget);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump(const Duration(milliseconds: 16));
    expect(keyboard.state.buttons, isEmpty);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(fake.gameHost.locals, isEmpty);
  });

  testWidgets('the arena reports its rounds and events to the game host', (tester) async {
    final fake = await pumpApp(tester);
    await openArena(tester);
    for (var i = 0; i < 90; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final names = fake.gameHost.records.map((r) => r.name).toSet();
    expect(names, containsAll(['round_start', 'dash', 'wall_hit']));
  });

  testWidgets('the latency screen breaks the delay into stages', (tester) async {
    await pumpApp(tester);
    await tapVisible(tester, find.text('Latency'));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const Key('stageSent-p1'))).data, '9 ms');
    expect(tester.widget<Text>(find.byKey(const Key('stageDrawn-p1'))).data, '–');
  });
}

/// Home → Play → Arena.
Future<void> openArena(WidgetTester tester) async {
  await tapVisible(tester, find.byKey(const Key('openPlay')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('pickArena')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void puzzle() {
  Future<FakeHostController> openShapeRace(WidgetTester tester) async {
    final fake = await pumpApp(tester);
    await tapVisible(tester, find.byKey(const Key('openPlay')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pickShapeRace')));
    await tester.pumpAndSettle();
    return fake;
  }

  testWidgets('the game picker offers Shape Race and the Arena; Shape Race lists each level\'s puzzles', (
    tester,
  ) async {
    await openShapeRace(tester);
    expect(find.byType(ShapeRaceScreen), findsOneWidget);
    for (final name in ['House', 'Rocket', 'Tree and sun', 'Boat']) {
      expect(find.text(name), findsOneWidget, reason: name);
    }
    expect(find.text('Any Easy puzzle'), findsOneWidget);
    expect(find.text('Any Medium puzzle'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    // The arena is still there.
    await tester.tap(find.byKey(const Key('pickArena')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(GameScreen), findsOneWidget);
  });

  testWidgets('players join a side first; the puzzle gives the phone Pick up and Rotate, and the panel; '
      'leaving gives the menu buttons back', (tester) async {
    final fake = await openShapeRace(tester);
    final host = fake.gameHost;
    // In the menus the phone says A "OK", B "Back".
    expect(host.layouts['p1']!.labels[ControllerButton.a], 'OK');
    await tester.tap(find.byKey(const Key('puzzle-house')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(JoinScreen), findsOneWidget);
    expect(host.layouts['p1']!.labels[ControllerButton.a], 'Join');
    Future<void> phone(Set<GamepadButton> buttons) async {
      host.setGamepad('p1', GamepadState(buttons: buttons, mode: InputMode.dpad));
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));
    }

    await phone({});
    await phone({GamepadButton.a});
    await phone({});
    expect(find.descendant(of: find.byKey(const Key('side-left')), matching: find.text('P1 iPhone 3F1C')), findsOne);
    expect(find.text('1 player. Press A or Start to begin.'), findsOneWidget);
    expect(host.layouts['p1']!.labels[ControllerButton.a], 'Start', reason: 'once joined, A begins');
    // A again begins (Start does too: tested in the M11 group).
    await phone({GamepadButton.a});
    await phone({});
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(PuzzleScreen), findsOneWidget);
    expect(find.byKey(const Key('puzzleView')), findsOneWidget);
    final layout = fake.gameHost.layouts['p1']!;
    expect(layout.labels[ControllerButton.a], 'Pick up');
    expect(layout.labels[ControllerButton.x], startsWith('Rotate'));
    expect(layout.hidden, contains(ControllerButton.b));
    expect(fake.gameHost.statuses['p1']!.progress, isNotNull);
    expect(layout.labels[ControllerButton.start], 'Pause');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    // The menus take the buttons back on their next look, once the screen's gone.
    await tester.pump(const Duration(milliseconds: 16));
    expect(fake.gameHost.layouts['p1']!.labels[ControllerButton.a], 'OK');
    expect(tester.takeException(), isNull);
  });

  testWidgets('a finished puzzle shows the time; Play again starts another', (tester) async {
    final house = Puzzle.parse(File('../packages/puzzle_game/puzzles/house.json').readAsStringSync());
    final match = PuzzleMatch(house, teams: const {'p1': PuzzleSide.left});
    final game = match.sides.single.game;
    await pumpApp(tester);
    final nav = tester.state<NavigatorState>(find.byType(Navigator));
    nav.push(
      MaterialPageRoute<void>(
        builder: (_) => PuzzleScreen(
          choice: const PuzzleChoice(level: Level.easy),
          teams: const {'p1': PuzzleSide.left},
          match: match,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    // Put every piece in place by hand, then let a frame run.
    for (var i = 0; i < game.pieces.length; i++) {
      final p = game.pieces[i];
      p
        ..state = PieceState.locked
        ..pos = game.targetAt(i);
    }
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.text('Done!'), findsOneWidget);
    expect(find.textContaining('seconds'), findsOneWidget);
    expect(find.byKey(const Key('playAgain')), findsOneWidget);
    expect(sounds.played, contains('success'));
    // The remote's OK button works at once: Play again has the focus.
    await tester.pump();
    final again = find.descendant(of: find.byKey(const Key('playAgain')), matching: find.byType(Focus)).first;
    expect(Focus.of(tester.element(find.descendant(of: again, matching: find.byType(Text)).first)).hasFocus, isTrue);
  });

  testWidgets('on the results the phone works the menu: left/right, A and B; the A that finished does nothing', (
    tester,
  ) async {
    final house = Puzzle.parse(File('../packages/puzzle_game/puzzles/house.json').readAsStringSync());
    final match = PuzzleMatch(house, teams: const {'p1': PuzzleSide.left});
    final game = match.sides.single.game;
    final fake = await pumpApp(tester);
    final host = fake.gameHost;
    tester
        .state<NavigatorState>(find.byType(Navigator))
        .push(
          MaterialPageRoute<void>(
            builder: (_) => PuzzleScreen(
              choice: const PuzzleChoice(level: Level.easy),
              teams: const {'p1': PuzzleSide.left},
              match: match,
            ),
          ),
        );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    Future<void> phone(Set<GamepadButton> buttons) async {
      host.setGamepad('p1', GamepadState(buttons: buttons, mode: InputMode.dpad));
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));
    }

    bool focused(String key) =>
        Focus.of(tester.element(find.descendant(of: find.byKey(Key(key)), matching: find.byType(Text)).first)).hasFocus;

    // The last piece goes in while A is held.
    host.setGamepad('p1', const GamepadState(buttons: {GamepadButton.a}, mode: InputMode.dpad));
    for (var i = 0; i < game.pieces.length; i++) {
      game.pieces[i]
        ..state = PieceState.locked
        ..pos = game.targetAt(i);
    }
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.text('Done!'), findsOneWidget);
    // The phone now says A "OK", B "Back".
    final layout = host.layouts['p1']!;
    expect(layout.labels[ControllerButton.a], 'OK');
    expect(layout.labels[ControllerButton.b], 'Back');
    expect(layout.hidden, containsAll([ControllerButton.x, ControllerButton.y]));

    // Still holding A, then letting go: nothing happens.
    await phone({GamepadButton.a});
    await phone({});
    expect(find.text('Done!'), findsOneWidget);
    expect(focused('playAgain'), isTrue);
    // Right moves to Change teams, then Back; left comes back.
    await phone({GamepadButton.dpadRight});
    await phone({});
    expect(focused('changeTeams'), isTrue);
    await phone({GamepadButton.dpadRight});
    await phone({});
    expect(focused('resultsBack'), isTrue);
    await phone({GamepadButton.dpadLeft});
    await phone({});
    await phone({GamepadButton.dpadLeft});
    await phone({});
    expect(focused('playAgain'), isTrue);
    // A presses Play again: a new puzzle starts.
    await phone({GamepadButton.a});
    await phone({});
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Done!'), findsNothing);
    expect(find.byType(PuzzleScreen), findsOneWidget);
    expect(host.layouts['p1']!.labels[ControllerButton.a], 'Pick up');
  });

  // m10.2 device test: in stick mode, moving the stick lost the focus and
  // then A did nothing.
  testWidgets('on the results the stick in any direction keeps the focus on a button', (tester) async {
    final house = Puzzle.parse(File('../packages/puzzle_game/puzzles/house.json').readAsStringSync());
    final match = PuzzleMatch(house, teams: const {'p1': PuzzleSide.left});
    final game = match.sides.single.game;
    final fake = await pumpApp(tester);
    final host = fake.gameHost;
    tester
        .state<NavigatorState>(find.byType(Navigator))
        .push(
          MaterialPageRoute<void>(
            builder: (_) => PuzzleScreen(
              choice: const PuzzleChoice(level: Level.easy),
              teams: const {'p1': PuzzleSide.left},
              match: match,
            ),
          ),
        );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    for (var i = 0; i < game.pieces.length; i++) {
      game.pieces[i]
        ..state = PieceState.locked
        ..pos = game.targetAt(i);
    }
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.text('Done!'), findsOneWidget);

    Future<void> phone(GamepadState s) async {
      host.setGamepad('p1', s);
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));
    }

    bool focused(String key) =>
        Focus.of(tester.element(find.descendant(of: find.byKey(Key(key)), matching: find.byType(Text)).first)).hasFocus;

    await phone(const GamepadState(mode: InputMode.sticks));
    const pushes = [(0.0, -1.0), (0.0, 1.0), (1.0, 0.0), (-1.0, 0.0), (0.8, -0.8), (-0.8, 0.8), (0.8, 0.8)];
    for (final (x, y) in pushes) {
      await phone(GamepadState(leftX: x, leftY: y, mode: InputMode.sticks));
      await phone(const GamepadState(mode: InputMode.sticks));
      expect(
        focused('playAgain') || focused('changeTeams') || focused('resultsBack'),
        isTrue,
        reason: 'after a push to ($x, $y)',
      );
    }
    // Back on Play again with the stick, A starts a new puzzle.
    for (var i = 0; i < 2; i++) {
      await phone(const GamepadState(leftX: -1, mode: InputMode.sticks));
      await phone(const GamepadState(mode: InputMode.sticks));
    }
    expect(focused('playAgain'), isTrue);
    await phone(const GamepadState(buttons: {GamepadButton.a}, mode: InputMode.sticks));
    await phone(const GamepadState(mode: InputMode.sticks));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Done!'), findsNothing);
  });

  testWidgets('on the results B on the phone goes back', (tester) async {
    final house = Puzzle.parse(File('../packages/puzzle_game/puzzles/house.json').readAsStringSync());
    final match = PuzzleMatch(house, teams: const {'p1': PuzzleSide.left});
    final game = match.sides.single.game;
    final fake = await pumpApp(tester);
    tester
        .state<NavigatorState>(find.byType(Navigator))
        .push(
          MaterialPageRoute<void>(
            builder: (_) => PuzzleScreen(
              choice: const PuzzleChoice(level: Level.easy),
              teams: const {'p1': PuzzleSide.left},
              match: match,
            ),
          ),
        );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    for (var i = 0; i < game.pieces.length; i++) {
      game.pieces[i]
        ..state = PieceState.locked
        ..pos = game.targetAt(i);
    }
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.text('Done!'), findsOneWidget);
    fake.gameHost.setGamepad('p1', const GamepadState(buttons: {GamepadButton.b}, mode: InputMode.dpad));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(PuzzleScreen), findsNothing);
  });

  testWidgets('time-up shows the pieces placed', (tester) async {
    final house = Puzzle.parse(File('../packages/puzzle_game/puzzles/house.json').readAsStringSync());
    final match = PuzzleMatch(
      house,
      teams: const {'p1': PuzzleSide.left},
      settings: const PuzzleSettings(timeLimitS: 30),
    );
    final game = match.sides.single.game;
    await pumpApp(tester);
    tester
        .state<NavigatorState>(find.byType(Navigator))
        .push(
          MaterialPageRoute<void>(
            builder: (_) => PuzzleScreen(
              choice: const PuzzleChoice(level: Level.easy),
              teams: const {'p1': PuzzleSide.left},
              match: match,
            ),
          ),
        );
    await tester.pump();
    game.pieces[0]
      ..state = PieceState.locked
      ..pos = game.targetAt(0);
    game.timeLeftS = 0.01;
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(find.text('Time\'s up!'), findsOneWidget);
    expect(find.text('1 of 4 pieces placed'), findsOneWidget);
  });

  testWidgets('the puzzle settings change straight away, are saved, and reset to the defaults', (tester) async {
    await pumpApp(tester);
    await tapVisible(tester, find.byKey(const Key('openPlay')));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byKey(const Key('openPuzzleSettings')));
    await tester.pumpAndSettle();
    expect(find.text('±15°'), findsOneWidget);
    // The remote: − is focused first; Right goes to the value's +.
    await tester.tap(find.byTooltip('More Angle tolerance'));
    await tester.pump();
    expect(find.text('±16°'), findsOneWidget);
    final container = ProviderScope.containerOf(tester.element(find.byType(PuzzleSettingsScreen)));
    expect(container.read(puzzleSettingsProvider).angleToleranceDeg, 16);
    final prefs = container.read(prefsProvider);
    expect(prefs.getString('puzzleSettings'), contains('"angleToleranceDeg":16'));
    await tester.scrollUntilVisible(find.byKey(const Key('setting-dropReadyHighlight')), 200);
    await tester.ensureVisible(find.byKey(const Key('setting-dropReadyHighlight')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: find.byKey(const Key('setting-dropReadyHighlight')), matching: find.byType(Switch)),
    );
    await tester.pump();
    expect(container.read(puzzleSettingsProvider).dropReadyHighlight, isFalse);
    await tester.tap(find.byKey(const Key('resetPuzzleSettings')));
    await tester.pump();
    expect(container.read(puzzleSettingsProvider).angleToleranceDeg, 15);
    expect(container.read(puzzleSettingsProvider).dropReadyHighlight, isTrue);
  });
}

void m11() {
  /// A phone's buttons, read by the menus two frames later.
  Future<void> phone(WidgetTester tester, FakeHostController fake, String id, Set<GamepadButton> buttons) async {
    fake.gameHost.setGamepad(id, GamepadState(buttons: buttons, mode: InputMode.dpad));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
  }

  /// A press: the button held, then let go (the menus act on the change).
  Future<void> press(WidgetTester tester, FakeHostController fake, String id, GamepadButton button) async {
    await phone(tester, fake, id, {button});
    await phone(tester, fake, id, {});
  }

  /// A new player counts as holding what it holds now: settle it first.
  Future<void> neutral(WidgetTester tester, FakeHostController fake, Iterable<String> ids) async {
    for (final id in ids) {
      await phone(tester, fake, id, {});
    }
  }

  /// Lets a push, a pop or a replacement finish.
  Future<void> navigated(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  Finder focusText(String key) => find.descendant(of: find.byKey(Key(key)), matching: find.byType(Text)).first;

  bool focused(WidgetTester tester, String key) => Focus.of(tester.element(focusText(key))).hasFocus;

  /// The tooltip of the button under the focus (the settings screen's steps).
  String? focusedTooltip() =>
      FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<Tooltip>()?.message;

  testWidgets('the phone alone works the menus: the game picker, Shape Race, Puzzle settings and back home', (
    tester,
  ) async {
    final fake = await pumpApp(tester);
    final host = fake.gameHost;
    // The sample phone starts holding A and right: let it go first.
    await neutral(tester, fake, ['p1']);
    // In the menus the phone says A "OK", B "Back".
    expect(host.layouts['p1']!.labels[ControllerButton.a], 'OK');
    expect(host.layouts['p1']!.labels[ControllerButton.b], 'Back');

    // Play has the focus, so A on the phone opens the game picker.
    Focus.of(tester.element(focusText('openPlay'))).requestFocus();
    await tester.pump();
    await press(tester, fake, 'p1', GamepadButton.a);
    await navigated(tester);
    expect(find.byType(GamesScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);

    // Shape Race has the focus on the picker.
    await press(tester, fake, 'p1', GamepadButton.a);
    await navigated(tester);
    expect(find.byType(ShapeRaceScreen), findsOneWidget);
    // B goes back to the picker.
    await press(tester, fake, 'p1', GamepadButton.b);
    await navigated(tester);
    expect(find.byType(ShapeRaceScreen), findsNothing);
    expect(find.byType(GamesScreen), findsOneWidget);

    // The arrows reach Puzzle settings.
    for (var i = 0; i < 3 && !focused(tester, 'openPuzzleSettings'); i++) {
      await press(tester, fake, 'p1', GamepadButton.dpadDown);
    }
    expect(focused(tester, 'openPuzzleSettings'), isTrue, reason: 'down reaches the settings button');
    await press(tester, fake, 'p1', GamepadButton.a);
    await navigated(tester);
    expect(find.byType(PuzzleSettingsScreen), findsOneWidget);
    // The first − has the focus; right reaches the value's +.
    expect(focusedTooltip(), 'Less Angle tolerance');
    for (var i = 0; i < 3 && !(focusedTooltip()?.startsWith('More') ?? false); i++) {
      await press(tester, fake, 'p1', GamepadButton.dpadRight);
    }
    expect(focusedTooltip(), startsWith('More'));
    await press(tester, fake, 'p1', GamepadButton.a);
    await tester.pump();
    expect(find.text('±16°'), findsOneWidget);

    // B twice: the settings, then the picker, back to the main screen.
    await press(tester, fake, 'p1', GamepadButton.b);
    await navigated(tester);
    expect(find.byType(PuzzleSettingsScreen), findsNothing);
    expect(find.byType(GamesScreen), findsOneWidget);
    await press(tester, fake, 'p1', GamepadButton.b);
    await navigated(tester);
    expect(find.byType(GamesScreen), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('a held direction repeats, and the focus never ends up where A cannot press', (tester) async {
    final fake = await pumpApp(tester);
    await neutral(tester, fake, ['p1']);
    await tapVisible(tester, find.byKey(const Key('openPlay')));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byKey(const Key('openPuzzleSettings')));
    await tester.pumpAndSettle();
    expect(find.byType(PuzzleSettingsScreen), findsOneWidget);

    /// The settings row whose button has the focus ("Less Angle tolerance"
    /// → "Angle tolerance").
    String? row() => focusedTooltip()?.split(' ').skip(1).join(' ');

    final start = row();
    expect(start, 'Angle tolerance');
    await phone(tester, fake, 'p1', {GamepadButton.dpadDown});
    final once = row();
    expect(once, isNot(start), reason: 'a press moves the focus');
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    expect(row(), once, reason: 'a held direction waits before it repeats');

    // Still held for a second more: the focus keeps moving down the list.
    final rows = <String>{?start, ?once};
    for (var i = 0; i < 63; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      final r = row();
      if (r != null) rows.add(r);
    }
    expect(rows.length, greaterThanOrEqualTo(3), reason: 'the held direction kept moving: $rows');

    // A direction never leaves the focus where A cannot press.
    await phone(tester, fake, 'p1', {});
    const directions = [GamepadButton.dpadUp, GamepadButton.dpadDown, GamepadButton.dpadLeft, GamepadButton.dpadRight];
    for (var i = 0; i < 8; i++) {
      await press(tester, fake, 'p1', directions[i % directions.length]);
      final context = FocusManager.instance.primaryFocus?.context;
      expect(context, isNotNull, reason: 'after ${directions[i % directions.length].name}');
      expect(
        Actions.maybeFind<ActivateIntent>(context!),
        isNotNull,
        reason: 'the focus after ${directions[i % directions.length].name} must be pressable',
      );
    }
  });

  testWidgets('simulated controllers never work the menus', (tester) async {
    final fake = await pumpApp(tester);
    final host = fake.gameHost;
    await neutral(tester, fake, ['p1']);
    fake.state = withController(fake.state, phoneInfo('sim1', 2, platform: 'sim'));
    fake.emit();
    await tester.pump();
    await neutral(tester, fake, ['sim1']);
    expect(host.players.map((p) => (p.id, p.simulated)), [('p1', false), ('sim1', true)]);

    await tapVisible(tester, find.byKey(const Key('openPlay')));
    await tester.pumpAndSettle();
    expect(find.byType(GamesScreen), findsOneWidget);
    // B back and A on the Simulated controller's phone: nothing happens.
    await press(tester, fake, 'sim1', GamepadButton.b);
    await navigated(tester);
    expect(find.byType(GamesScreen), findsOneWidget);
    await press(tester, fake, 'sim1', GamepadButton.a);
    await navigated(tester);
    expect(find.byType(GamesScreen), findsOneWidget);
    expect(find.byType(ShapeRaceScreen), findsNothing);
    expect(find.byType(PuzzleSettingsScreen), findsNothing);
    // It never gets the menu's buttons either.
    expect(host.layouts['sim1']?.labels[ControllerButton.a], isNot('OK'));
  });

  testWidgets('on the join screen A joins the side with fewer players, left and right switch sides, B leaves, '
      'at most two a side', (tester) async {
    final fake = await pumpApp(tester);
    fake.state = withController(fake.state, phoneInfo('p3', 2));
    fake.state = withController(fake.state, phoneInfo('p4', 3));
    fake.state = withController(fake.state, phoneInfo('p5', 4));
    fake.emit();
    await neutral(tester, fake, ['p1', 'p3', 'p4', 'p5']);
    await tapVisible(tester, find.byKey(const Key('openPlay')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pickShapeRace')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('puzzle-house')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(JoinScreen), findsOneWidget);

    Finder onSide(String side, String label) =>
        find.descendant(of: find.byKey(Key('side-$side')), matching: find.text(label));

    // The first player goes left, the next right, then left, then right.
    await press(tester, fake, 'p1', GamepadButton.a);
    expect(onSide('left', 'P1 iPhone 3F1C'), findsOneWidget);
    await press(tester, fake, 'p3', GamepadButton.a);
    expect(onSide('right', 'P2 Phone 2'), findsOneWidget);
    await press(tester, fake, 'p4', GamepadButton.a);
    expect(onSide('left', 'P3 Phone 3'), findsOneWidget);
    // Two against one while three have joined.
    expect(tester.widget<Text>(find.byKey(const Key('joinFormat'))).data, startsWith('2 vs 1'));
    await press(tester, fake, 'p5', GamepadButton.a);
    expect(onSide('right', 'P4 Phone 4'), findsOneWidget);

    // The right side is full: pushing right keeps player 1 on the left.
    await press(tester, fake, 'p1', GamepadButton.dpadRight);
    expect(onSide('left', 'P1 iPhone 3F1C'), findsOneWidget);

    // B leaves a side; again, not joined, it goes back.
    await press(tester, fake, 'p3', GamepadButton.b);
    expect(onSide('right', 'P2 Phone 2'), findsNothing);
    expect(find.byType(JoinScreen), findsOneWidget);
    await press(tester, fake, 'p3', GamepadButton.b);
    await navigated(tester);
    expect(find.byType(JoinScreen), findsNothing);
    expect(find.byType(ShapeRaceScreen), findsOneWidget);
  });

  testWidgets('Start begins the match with the teams; simulated controllers join by themselves', (tester) async {
    final fake = await pumpApp(tester);
    await neutral(tester, fake, ['p1']);
    await tapVisible(tester, find.byKey(const Key('openPlay')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pickShapeRace')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('puzzle-house')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await press(tester, fake, 'p1', GamepadButton.a);
    expect(find.descendant(of: find.byKey(const Key('side-left')), matching: find.text('P1 iPhone 3F1C')), findsOne);

    // The simulated controller joins the side with fewer players by itself.
    fake.state = withController(fake.state, phoneInfo('sim1', 2, platform: 'sim'));
    fake.emit();
    await tester.pump();
    await neutral(tester, fake, ['sim1']);
    expect(
      find.descendant(of: find.byKey(const Key('side-right')), matching: find.text('P2 Phone 2 (simulated)')),
      findsOne,
    );

    // Start on player 1's phone begins the match: two sides, the split screen.
    await press(tester, fake, 'p1', GamepadButton.start);
    await navigated(tester);
    expect(find.byType(PuzzleScreen), findsOneWidget);
    expect(find.byType(MatchView), findsOneWidget);
    expect(tester.widget<CustomPaint>(find.byKey(const Key('puzzleView'))).painter, isA<MatchPainter>());
  });

  testWidgets('Start pauses for everyone; only the player who paused or Player 1 can resume; Quit goes to the '
      'game picker', (tester) async {
    final fake = await pumpApp(tester);
    final host = fake.gameHost;
    fake.state = withController(fake.state, phoneInfo('p2', 2));
    fake.emit();
    await neutral(tester, fake, ['p1', 'p2']);
    await tapVisible(tester, find.byKey(const Key('openPlay')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pickShapeRace')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('puzzle-house')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    // P1 on the left, P2 on the right, then Start on P1's phone.
    await press(tester, fake, 'p1', GamepadButton.a);
    await press(tester, fake, 'p2', GamepadButton.a);
    await press(tester, fake, 'p1', GamepadButton.start);
    await navigated(tester);
    expect(find.byType(PuzzleScreen), findsOneWidget);
    expect(find.byType(JoinScreen), findsNothing);

    // P2 pauses: the menu shows, and the phones offer Resume.
    await press(tester, fake, 'p2', GamepadButton.start);
    await navigated(tester);
    expect(find.byKey(const Key('pauseMenu')), findsOneWidget);
    expect(host.layouts['p2']!.labels[ControllerButton.start], 'Resume');
    expect(find.text('P2 or P1 can resume, with Start or Resume.'), findsOneWidget);

    // The clock stops for everyone.
    int timeLeft() => tester.state<PuzzlePlayViewState>(find.byType(PuzzlePlayView)).snapshot.boards.first.timeLeftMs;
    final before = timeLeft();
    for (var i = 0; i < 63; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(timeLeft(), before);

    // A phone that hasn't joined can't work the menu.
    fake.state = withController(fake.state, phoneInfo('p3', 3));
    fake.emit();
    await tester.pump();
    await neutral(tester, fake, ['p3']);
    await press(tester, fake, 'p3', GamepadButton.start);
    await press(tester, fake, 'p3', GamepadButton.a);
    await navigated(tester);
    expect(find.byKey(const Key('pauseMenu')), findsOneWidget);

    // The player who paused resumes with Start.
    await press(tester, fake, 'p2', GamepadButton.start);
    await navigated(tester);
    expect(find.byKey(const Key('pauseMenu')), findsNothing);

    // P2 pauses again, and P1 resumes with A on Resume.
    await press(tester, fake, 'p2', GamepadButton.start);
    await navigated(tester);
    expect(find.byKey(const Key('pauseMenu')), findsOneWidget);
    await press(tester, fake, 'p1', GamepadButton.a);
    await navigated(tester);
    expect(find.byKey(const Key('pauseMenu')), findsNothing);

    // P1 pauses: now P2 can't resume any more.
    await press(tester, fake, 'p1', GamepadButton.start);
    await navigated(tester);
    expect(find.byKey(const Key('pauseMenu')), findsOneWidget);
    expect(find.text('P1 can resume, with Start or Resume.'), findsOneWidget);
    await press(tester, fake, 'p2', GamepadButton.start);
    await navigated(tester);
    expect(find.byKey(const Key('pauseMenu')), findsOneWidget);

    // Left to Quit, and A quits to the game picker.
    await press(tester, fake, 'p1', GamepadButton.dpadLeft);
    expect(focused(tester, 'pauseQuit'), isTrue);
    await press(tester, fake, 'p1', GamepadButton.a);
    await navigated(tester);
    expect(find.byType(GamesScreen), findsOneWidget);
    expect(find.byType(PuzzleScreen), findsNothing);
  });

  testWidgets('the Arena pauses with Start too', (tester) async {
    final fake = await pumpApp(tester);
    final host = fake.gameHost;
    await neutral(tester, fake, ['p1']);
    await openArena(tester);
    expect(find.byType(GameScreen), findsOneWidget);
    expect(host.layouts['p1']!.labels[ControllerButton.start], 'Pause');

    await press(tester, fake, 'p1', GamepadButton.start);
    await navigated(tester);
    expect(find.byKey(const Key('pauseMenu')), findsOneWidget);
    expect(host.layouts['p1']!.labels[ControllerButton.start], 'Resume');

    await press(tester, fake, 'p1', GamepadButton.start);
    await navigated(tester);
    expect(find.byKey(const Key('pauseMenu')), findsNothing);
    expect(host.layouts['p1']!.labels[ControllerButton.start], 'Pause');
  });

  testWidgets('a race shows the winner, and Rematch keeps the teams; Change teams goes back to the join screen', (
    tester,
  ) async {
    const teams = {'p1': PuzzleSide.left, 'p2': PuzzleSide.right};

    // A race with every piece of the left board put in place by hand.
    Future<void> finishedRace() async {
      final house = Puzzle.parse(File('../packages/puzzle_game/puzzles/house.json').readAsStringSync());
      final match = PuzzleMatch(house, teams: teams);
      final game = match.gameOf(PuzzleSide.left);
      final fake = await pumpApp(tester);
      fake.state = withController(fake.state, phoneInfo('p2', 2));
      fake.emit();
      await neutral(tester, fake, ['p1', 'p2']);
      tester
          .state<NavigatorState>(find.byType(Navigator))
          .push(
            MaterialPageRoute<void>(
              builder: (_) => PuzzleScreen(
                choice: const PuzzleChoice(level: Level.easy),
                teams: teams,
                match: match,
              ),
            ),
          );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      for (var i = 0; i < game.pieces.length; i++) {
        game.pieces[i]
          ..state = PieceState.locked
          ..pos = game.targetAt(i);
      }
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    }

    await finishedRace();
    expect(tester.widget<Text>(find.byKey(const Key('puzzleResultTitle'))).data, 'Left wins!');
    expect(tester.widget<Text>(find.byKey(const Key('puzzleResultLine-left'))).data, endsWith('seconds'));
    expect(tester.widget<Text>(find.byKey(const Key('puzzleResultLine-right'))).data, '0 of 4 pieces placed');
    expect(focused(tester, 'rematch'), isTrue, reason: 'Rematch has the focus for the phone and the remote');

    // Rematch starts another race with the same teams.
    await tester.tap(find.byKey(const Key('rematch')));
    await navigated(tester);
    expect(find.byType(PuzzleScreen), findsOneWidget);
    expect(tester.widget<PuzzleScreen>(find.byType(PuzzleScreen)).teams, teams);
    expect(find.byKey(const Key('puzzleResultTitle')), findsNothing);

    // A second run: Change teams goes back to the join screen, teams kept.
    await tester.pumpWidget(const SizedBox());
    await finishedRace();
    await tester.tap(find.byKey(const Key('changeTeams')));
    await navigated(tester);
    expect(find.byType(JoinScreen), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('side-left')), matching: find.text('P1 iPhone 3F1C')), findsOne);
    expect(find.descendant(of: find.byKey(const Key('side-right')), matching: find.text('P2 Phone 2')), findsOne);
  });

  testWidgets('Add simulated controller adds up to three; Stop simulations shows once there are some', (tester) async {
    final fake = await pumpApp(tester);
    await tapVisible(tester, find.byKey(const Key('addSim')));
    await tester.pump();
    expect(fake.simAdds, 1);
    expect(find.byKey(const Key('stopSims')), findsNothing);

    // Three simulated controllers: no room for more, and a way to stop them.
    final s = fake.state;
    fake.state = HostViewState(
      hostName: s.hostName,
      host: s.host,
      addresses: s.addresses,
      advertise: s.advertise,
      advertisedName: s.advertisedName,
      sims: [
        for (var i = 0; i < HostController.maxSims; i++) ClientSnapshot(status: ClientStatus.connected, player: i + 2),
      ],
    );
    fake.emit();
    await tester.pumpAndSettle();
    expect(tester.widget<TvButton>(find.byKey(const Key('addSim'))).onPressed, isNull);
    expect(find.byKey(const Key('stopSims')), findsOneWidget);
    await tapVisible(tester, find.byKey(const Key('stopSims')));
    await tester.pump();
    expect(fake.simStops, 1);
  });
}

/// The puzzles, read straight from the package's data files (the asset
/// bundle loads them outside the test's clock).
PuzzleLibrary testPuzzles() {
  const dir = '../packages/puzzle_game/puzzles';
  final index = jsonDecode(File('$dir/index.json').readAsStringSync()) as Map<String, Object?>;
  return PuzzleLibrary([
    for (final id in (index['puzzles'] as List).cast<String>()) Puzzle.parse(File('$dir/$id.json').readAsStringSync()),
  ]);
}
