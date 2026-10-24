import 'dart:async';
import 'dart:convert';

import 'package:connection/connection.dart';
import 'package:controller/main.dart';
import 'package:controller/src/discovery.dart';
import 'package:controller/src/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeClient extends ControllerClient {
  FakeClient({this.savedTokens = const {}})
    : super(
        identity: const ControllerIdentity(controllerId: 'test', name: 'Test', platform: 'test', appVersion: 't'),
      );

  final Map<String, String> savedTokens;
  final calls = <String>[];
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

Future<(FakeClient, FakeDiscovery)> pumpApp(
  WidgetTester tester, {
  FakeClient? client,
  FakeDiscovery? discovery,
  Map<String, Object> prefs = const {},
  bool isIOS = false,
  LogBuffer? log,
}) async {
  // A landscape phone (iPhone 15-ish).
  tester.view.physicalSize = const Size(852, 393);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues(prefs);
  final loaded = await SharedPreferences.getInstance();
  final c = client ?? FakeClient();
  final d = discovery ?? FakeDiscovery();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        prefsProvider.overrideWithValue(loaded),
        clientProvider.overrideWithValue(c),
        discoveryProvider.overrideWithValue(d),
        isIOSProvider.overrideWithValue(isIOS),
        if (log != null) logProvider.overrideWithValue(log),
      ],
      child: const ControllerApp(),
    ),
  );
  await tester.pump();
  return (c, d);
}

void main() {
  testWidgets('lists discovered TVs and connects to the one tapped', (tester) async {
    final (client, discovery) = await pumpApp(tester);
    expect(find.text('Not connected'), findsWidgets);
    expect(find.textContaining('Searching'), findsOneWidget);

    discovery.emit(DiscoveryState(running: true, everFound: true, hosts: [DiscoveredHost(address: tv)]));
    await tester.pump();
    await tester.tap(find.text('Controller Test (Android TV)'));
    expect(client.calls, ['connect 192.168.1.50:45780']);
  });

  testWidgets('manual entry checks the address before connecting', (tester) async {
    final (client, _) = await pumpApp(tester);
    await tester.enterText(find.byKey(const Key('manualAddress')), '192.168.1.50:99999');
    await tester.tap(find.text('Connect'));
    await tester.pump();
    expect(find.textContaining('not a valid port'), findsOneWidget);
    expect(client.calls, isEmpty);

    await tester.enterText(find.byKey(const Key('manualAddress')), '192.168.1.77');
    await tester.tap(find.text('Connect'));
    await tester.pump();
    expect(client.calls, ['connect 192.168.1.77:45780']);
  });

  testWidgets('asks for the code, explains a wrong code and sends four digits', (tester) async {
    final (client, _) = await pumpApp(tester);
    client.emit(
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
    expect(client.calls, ['code 0427']);
  });

  testWidgets('shows Connected with the ping', (tester) async {
    final (client, _) = await pumpApp(tester);
    client.emit(ClientSnapshot(status: ClientStatus.connected, target: tv, hostName: 'Android TV', rttMs: 9));
    await tester.pump();
    expect(find.text('Connected to Android TV'), findsOneWidget);
    expect(find.text('Ping 9 ms'), findsOneWidget);
    expect(find.text('Connected · 9 ms'), findsOneWidget);

    await tester.tap(find.text('Disconnect'));
    expect(client.calls, ['disconnect']);
  });

  testWidgets('shows reconnecting, and a way to retry after a failure', (tester) async {
    final (client, _) = await pumpApp(tester);
    client.emit(ClientSnapshot(status: ClientStatus.reconnecting, target: tv, hostName: 'Android TV', attempt: 3));
    await tester.pump();
    expect(find.textContaining('Reconnecting to Android TV'), findsOneWidget);
    expect(find.text('Attempt 3'), findsOneWidget);

    client.emit(
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
    expect(client.calls, ['connect 192.168.1.50:45780']);
  });

  testWidgets('reconnects to the last TV on launch when still paired', (tester) async {
    final (client, _) = await pumpApp(
      tester,
      client: FakeClient(savedTokens: {'tv-1': 'token'}),
      prefs: {'lastHost': jsonEncode(tv.toJson())},
    );
    await tester.pump();
    expect(client.calls, ['connect 192.168.1.50:45780']);
  });

  testWidgets('does not reconnect on launch without a saved pairing', (tester) async {
    final (client, _) = await pumpApp(tester, prefs: {'lastHost': jsonEncode(tv.toJson())});
    await tester.pump();
    expect(client.calls, isEmpty);
  });

  testWidgets('Diagnostics shows the connection, permission status and log', (tester) async {
    final log = LogBuffer()..add('client', 'Connecting to ws://192.168.1.50:45780/ws');
    final (client, _) = await pumpApp(tester, isIOS: true, log: log);
    client.emit(
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
    await tester.pumpAndSettle();

    expect(find.text('Diagnostics'), findsOneWidget);
    expect(find.text('Probably denied'), findsOneWidget);
    expect(find.text('tv-1'), findsOneWidget);
    final logLine = find.textContaining('[client] Connecting to ws://192.168.1.50');
    // Each SelectableText is scrollable too, so name the page's list.
    await tester.scrollUntilVisible(logLine, 300, scrollable: find.byType(Scrollable).first);
    expect(logLine, findsOneWidget);
  });
}
