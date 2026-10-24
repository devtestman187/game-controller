import 'dart:async';
import 'dart:convert';

import 'package:connection/connection.dart';
import 'package:controller/main.dart';
import 'package:controller/src/discovery.dart';
import 'package:controller/src/haptics.dart';
import 'package:controller/src/providers.dart';
import 'package:controller/src/ui/controller_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protocol/protocol.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeClient extends ControllerClient {
  FakeClient({this.savedTokens = const {}})
    : super(
        identity: const ControllerIdentity(controllerId: 'test', name: 'Test', platform: 'test', appVersion: 't'),
      );

  final Map<String, String> savedTokens;
  final calls = <String>[];

  /// Every input state the pad sent, as "A+B dx,dy".
  final inputs = <String>[];
  ClientSnapshot _snap = const ClientSnapshot(status: ClientStatus.idle);
  final _changes = StreamController<ClientSnapshot>.broadcast();

  void emit(ClientSnapshot s) {
    _snap = s;
    _changes.add(s);
  }

  @override
  ClientSnapshot get snapshot => _snap;

  @override
  Stream<ClientSnapshot> get changes => _changes.stream;

  @override
  Map<String, String> get tokens => savedTokens;

  @override
  void connect(HostAddress target, {String? code}) =>
      calls.add('connect ${target.display}${code == null ? '' : ' $code'}');

  @override
  void submitCode(String code) => calls.add('code $code');

  @override
  void disconnect() => calls.add('disconnect');

  @override
  void updateAddress(HostAddress found) {}

  @override
  void sendInput(Set<ControllerButton> buttons, {int dx = 0, int dy = 0}) {
    final names = [
      for (final b in ControllerButton.values)
        if (buttons.contains(b)) b.name.toUpperCase(),
    ];
    inputs.add('${names.join('+')} $dx,$dy'.trim());
  }

  @override
  Future<void> dispose() => _changes.close();
}

class FakeDiscovery implements HostDiscovery {
  FakeDiscovery([this._state = const DiscoveryState(running: true)]);

  DiscoveryState _state;
  final _changes = StreamController<DiscoveryState>.broadcast();
  int restarts = 0;

  void emit(DiscoveryState s) {
    _state = s;
    _changes.add(s);
  }

  @override
  DiscoveryState get state => _state;

  @override
  Stream<DiscoveryState> get changes => _changes.stream;

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> restart() async => restarts++;

  @override
  Future<void> dispose() => _changes.close();
}

final tv = HostAddress(addresses: ['192.168.1.50'], port: 45780, hostId: 'tv-1', name: 'Controller Test (Android TV)');
final connected = ClientSnapshot(
  status: ClientStatus.connected,
  target: tv,
  hostName: 'Android TV',
  rttMs: 9,
  rttStats: const RttSummary(minMs: 5, avgMs: 22, maxMs: 130, samples: 30),
);

/// The app as a test sees it. Without a saved pairing it opens on the
/// Connect screen; with [paired] it stays on the controller.
class TestApp {
  TestApp(this.client, this.discovery, this.haptics, this.prefs);

  final FakeClient client;
  final FakeDiscovery discovery;
  final FakeHaptics haptics;
  final SharedPreferences prefs;
}

Future<TestApp> pumpApp(
  WidgetTester tester, {
  bool paired = false,
  bool isIOS = false,
  LogBuffer? log,
  FakeHaptics? haptics,
}) async {
  // A landscape phone (iPhone 15-ish).
  tester.view.physicalSize = const Size(852, 393);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues(paired ? {'lastHost': jsonEncode(tv.toJson())} : {});
  final prefs = await SharedPreferences.getInstance();
  final app = TestApp(
    FakeClient(savedTokens: paired ? {'tv-1': 'token'} : {}),
    FakeDiscovery(),
    haptics ?? FakeHaptics(),
    prefs,
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        prefsProvider.overrideWithValue(prefs),
        clientProvider.overrideWithValue(app.client),
        discoveryProvider.overrideWithValue(app.discovery),
        hapticsProvider.overrideWithValue(app.haptics),
        isIOSProvider.overrideWithValue(isIOS),
        if (log != null) logProvider.overrideWithValue(log),
      ],
      child: const ControllerApp(),
    ),
  );
  await settle(tester);
  return app;
}

/// pumpAndSettle never settles while a progress spinner turns, so pump
/// through page transitions instead.
Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

Offset _at(WidgetTester tester, Key key, Offset fraction) {
  final rect = tester.getRect(find.byKey(key));
  return rect.topLeft + Offset(rect.width * fraction.dx, rect.height * fraction.dy);
}

void main() {
  group('connecting', () {
    testWidgets('opens the Connect screen when there is no saved TV', (tester) async {
      final app = await pumpApp(tester);
      expect(find.text('Connect to a TV'), findsOneWidget);
      expect(find.textContaining('Searching'), findsOneWidget);

      app.discovery.emit(DiscoveryState(running: true, everFound: true, hosts: [DiscoveredHost(address: tv)]));
      await tester.pump();
      await tester.tap(find.text('Controller Test (Android TV)'));
      expect(app.client.calls, ['connect 192.168.1.50:45780']);
    });

    testWidgets('manual entry checks the address before connecting', (tester) async {
      final app = await pumpApp(tester);
      await tester.enterText(find.byKey(const Key('manualAddress')), '192.168.1.50:99999');
      await tester.tap(find.text('Connect'));
      await tester.pump();
      expect(find.textContaining('not a valid port'), findsOneWidget);
      expect(app.client.calls, isEmpty);

      await tester.enterText(find.byKey(const Key('manualAddress')), '192.168.1.77');
      await tester.tap(find.text('Connect'));
      await tester.pump();
      expect(app.client.calls, ['connect 192.168.1.77:45780']);
    });

    testWidgets('asks for the code, explains a wrong code and sends four digits', (tester) async {
      final app = await pumpApp(tester);
      app.client.emit(
        ClientSnapshot(
          status: ClientStatus.waitingForCode,
          target: tv,
          hostName: 'Android TV',
          problem: ClientProblem.wrongCode,
        ),
      );
      await tester.pump();
      expect(find.text('Enter the code shown on Android TV'), findsOneWidget);
      expect(find.textContaining('Wrong code'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('pairingCode')), '0427');
      expect(app.client.calls, ['code 0427']);
    });

    testWidgets('goes back to the controller once connected, with ping and 30 s stats', (tester) async {
      final app = await pumpApp(tester);
      app.client.emit(connected);
      await settle(tester);
      expect(find.text('Connect to a TV'), findsNothing);
      expect(find.text('Android TV · 9 ms'), findsOneWidget);
      expect(find.text('30 s: min 5 · avg 22 · max 130 ms'), findsOneWidget);

      // The chip opens the Connect screen again, where Disconnect lives.
      await tester.tap(find.byKey(const Key('connectionChip')));
      await settle(tester);
      expect(find.text('Connected to Android TV'), findsOneWidget);
      await tester.tap(find.text('Disconnect'));
      expect(app.client.calls, ['disconnect']);
    });

    testWidgets('shows reconnecting, and a way to retry after a failure', (tester) async {
      final app = await pumpApp(tester);
      app.client.emit(
        ClientSnapshot(status: ClientStatus.reconnecting, target: tv, hostName: 'Android TV', attempt: 3),
      );
      await tester.pump();
      expect(find.textContaining('Reconnecting to Android TV'), findsOneWidget);
      expect(find.text('Attempt 3'), findsOneWidget);

      app.client.emit(
        ClientSnapshot(
          status: ClientStatus.failed,
          target: tv,
          problem: ClientProblem.unreachable,
          detail: 'Connection refused',
        ),
      );
      await tester.pump();
      expect(find.textContaining('Couldn\'t reach'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      expect(app.client.calls, ['connect 192.168.1.50:45780']);
    });

    testWidgets('reconnects to the last TV on launch and stays on the controller', (tester) async {
      final app = await pumpApp(tester, paired: true);
      expect(app.client.calls, ['connect 192.168.1.50:45780']);
      expect(find.text('Connect to a TV'), findsNothing);
      expect(find.byKey(const Key('dpad')), findsOneWidget);
    });
  });

  group('the pad', () {
    testWidgets('holds a direction and buttons at once, ticking on each change', (tester) async {
      final app = await pumpApp(tester, paired: true);
      app.client.emit(connected);
      await tester.pump();

      final thumb = await tester.startGesture(_at(tester, const Key('dpad'), const Offset(0.95, 0.5)));
      await tester.pump();
      final a = await tester.startGesture(_at(tester, const Key('faceButtons'), const Offset(0.5, 0.81)));
      await tester.pump();
      final b = await tester.startGesture(_at(tester, const Key('faceButtons'), const Offset(0.81, 0.5)));
      await tester.pump();
      expect(app.client.inputs, ['1,0', 'A 1,0', 'A+B 1,0']);
      expect(find.text('A+B · D-pad right'), findsOneWidget);

      // Slide the D-pad thumb to down without lifting: a direction change.
      await thumb.moveTo(_at(tester, const Key('dpad'), const Offset(0.5, 0.95)));
      await a.up();
      await b.up();
      await thumb.up();
      await tester.pump();
      expect(app.client.inputs.skip(3), ['A+B 0,1', 'B 0,1', '0,1', '0,0']);
      // One tick per change: 3 presses, 1 direction change, 3 releases.
      expect(app.haptics.ticks.length, 7);
    });

    testWidgets('Start and Select work, and sliding off releases', (tester) async {
      final app = await pumpApp(tester, paired: true);
      final g = await tester.startGesture(tester.getCenter(find.text('Start')));
      await tester.pump();
      await g.moveBy(const Offset(0, 120));
      await g.up();
      await tester.tap(find.text('Select'));
      await tester.pump();
      expect(app.client.inputs, ['START 0,0', '0,0', 'SELECT 0,0', '0,0']);
    });

    testWidgets('leaving the app releases everything', (tester) async {
      final app = await pumpApp(tester, paired: true);
      final g = await tester.startGesture(_at(tester, const Key('faceButtons'), const Offset(0.19, 0.5)));
      await tester.pump();
      expect(app.client.inputs.last, 'X 0,0');

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(app.client.inputs.last, '0,0');
      await g.up();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      expect(app.discovery.restarts, 1);
    });

    testWidgets('the Gyro mode is shown but not available yet', (tester) async {
      await pumpApp(tester, paired: true);
      final modes = tester.widget<SegmentedButton<PadMode>>(find.byType(SegmentedButton<PadMode>));
      expect(modes.selected, {PadMode.dpad});
      expect(modes.segments.last.enabled, isFalse);
    });
  });

  group('haptics', () {
    testWidgets('turning haptics off stops the ticks and is saved', (tester) async {
      final app = await pumpApp(tester, paired: true);
      await tester.tap(find.byTooltip('Haptics'));
      await tester.pumpAndSettle();
      expect(find.text('fake'), findsOneWidget); // The engine name from the capabilities.
      await tester.tap(find.byKey(const Key('hapticsSwitch')));
      await tester.pump();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(app.prefs.getBool('hapticsEnabled'), isFalse);

      await tester.tapAt(_at(tester, const Key('faceButtons'), const Offset(0.5, 0.81)));
      await tester.pump();
      expect(app.client.inputs, ['A 0,0', '0,0'], reason: 'input still flows');
      expect(app.haptics.ticks, isEmpty);
    });

    testWidgets('the Test button plays one tick at the chosen intensity', (tester) async {
      final app = await pumpApp(tester, paired: true);
      await tester.tap(find.byTooltip('Haptics'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Test'));
      await tester.pump();
      expect(app.haptics.ticks, [0.7]);
    });

    testWidgets('without haptics hardware the pad still works', (tester) async {
      final app = await pumpApp(tester, paired: true, haptics: FakeHaptics(caps: HapticsCapabilities.none));
      await tester.tap(find.text('Start'));
      await tester.pump();
      expect(app.client.inputs, ['START 0,0', '0,0']);
      expect(app.haptics.ticks, isEmpty);

      await tester.tap(find.byTooltip('Haptics'));
      await tester.pumpAndSettle();
      expect(find.textContaining('no haptics'), findsOneWidget);
    });
  });

  testWidgets('Diagnostics shows the connection, permission, haptics and log', (tester) async {
    final log = LogBuffer()..add('client', 'Connecting to ws://192.168.1.50:45780/ws');
    final app = await pumpApp(tester, isIOS: true, log: log);
    app.client.emit(
      ClientSnapshot(
        status: ClientStatus.failed,
        target: tv,
        problem: ClientProblem.unreachable,
        detail: 'No route to host (OS error 65)',
        osErrorCode: 65,
      ),
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Diagnostics'));
    await settle(tester);

    expect(find.text('Diagnostics'), findsOneWidget);
    expect(find.text('Probably denied'), findsOneWidget);
    expect(find.text('tv-1'), findsOneWidget);
    final pageList = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.text('Ticks played'), 200, scrollable: pageList);
    expect(find.text('fake'), findsOneWidget);
    // Each SelectableText is scrollable too, so name the page's list.
    final logLine = find.textContaining('[client] Connecting to ws://192.168.1.50');
    await tester.scrollUntilVisible(logLine, 300, scrollable: pageList);
    expect(logLine, findsOneWidget);
  });
}
