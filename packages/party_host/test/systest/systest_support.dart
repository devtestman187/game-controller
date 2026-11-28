import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:connection/connection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';
import 'package:party_host/src/night/night_pick_provider.dart';
import 'package:party_host/src/night/night_settings.dart';
import 'package:protocol/protocol.dart';

import '../support/fake_prefs.dart';
import '../support/host_harness.dart' show testMaps;
import '../support/night_harness.dart';

/// The seed of the night's random source in the system tests.
const systestSeed = 1;

/// The game host's players as the host reports them: the real roster, with no host service behind it.
final class _HostRoster extends GamePlayersNotifier {
  _HostRoster(this._host);

  final ServerGameHost _host;

  @override
  List<GamePlayer> build() {
    final sub = _host.playersChanged.listen((p) => state = p);
    ref.onDispose(sub.cancel);
    return _host.players;
  }
}

/// A real, paired phone: a [ControllerClient] that records the vote rounds it is offered.
final class SystestPhone {
  SystestPhone._(this.id, this.client);

  /// The controller (and player) id.
  final String id;

  /// The phone's connection to the host.
  final ControllerClient client;

  /// Every choice round the phone was offered, oldest first.
  final offers = <ChoicesMessage>[];

  /// Votes for the [index]th offered card of the latest round, as a tap on that card does.
  void vote(int index, {bool locked = true}) {
    final offer = offers.last;
    client.sendChoicePick(ChoicePickMessage(round: offer.round, pick: offer.cards[index].id, locked: locked));
  }
}

/// A phone of an old build that lists no [Capability.choices]: raw frames, as the connection tests' WirePhone.
final class SystestOldPhone {
  SystestOldPhone._(this.id, this._channel) {
    _channel.incoming.listen((data) {
      final message = _codec.decode(data);
      if (message != null) fromHost.add(message);
    });
  }

  static const _codec = MessageCodec();

  /// The controller (and player) id.
  final String id;
  final MessageChannel _channel;

  /// Every message the host sent this phone, oldest first.
  final fromHost = <Message>[];
  int _seq = 0;

  void _send(Message message) => _channel.send(_codec.encode(message));

  /// Presses each of [buttons], then lets go.
  void press(Set<ControllerButton> buttons) {
    _send(InputStateMessage(seq: ++_seq, buttons: buttons));
    _send(InputStateMessage(seq: ++_seq));
  }

  /// The labels of the latest game layout the host sent, or null when it sent none.
  Map<ControllerButton, String>? get latestLabels => fromHost.whereType<GameLayoutMessage>().lastOrNull?.labels;
}

/// A host with real phones on a real [HostServer], and a night over them: see [openSystest].
final class Systest {
  Systest._(this.tester, this.server, this.host, this.container, this.listener, this.address);

  final WidgetTester tester;
  final HostServer server;
  final ServerGameHost host;
  final ProviderContainer container;
  final ChannelListener listener;
  final HostAddress address;
  final phones = <SystestPhone>[];
  final oldPhones = <SystestOldPhone>[];
  final _subs = <StreamSubscription<ChoicesMessage>>[];
  bool _closed = false;

  /// Lets go of everything the host holds, so no timer is left running (a widget test fails on one).
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    container.dispose();
    await tester.runAsync(() async {
      for (final sub in _subs) {
        await sub.cancel();
      }
      for (final phone in phones) {
        await phone.client.dispose();
      }
      await host.dispose();
      await server.dispose();
    });
    await tester.pump(const Duration(seconds: 1));
  }

  /// Lets what is in flight arrive: the in-process link needs only the clock to move; a socket also needs the real
  /// event loop, which is given up to [_socketWait] and left early once [done] holds. [time] is the clock step.
  Future<void> settle({Duration time = _settleStep, bool Function()? done}) async {
    if (listener is! InProcessListener) {
      await tester.runAsync(() => _waitForSocket(done));
    }
    await tester.pump(time);
  }

  /// The clock step of one settle, used by [settle] by default and by [until] each time round.
  static const _settleStep = Duration(milliseconds: 50);

  /// The real time a socket reply needs. Without [done] it is waited in one go, as before the poll existed. With
  /// [done] it is polled in [_socketPollSlice] steps and ends as soon as [done] holds; it never waits more than
  /// [_socketWait] in total.
  static const _socketWait = Duration(milliseconds: 40);
  static const _socketPollSlice = Duration(milliseconds: 10);

  static Future<void> _waitForSocket(bool Function()? done) async {
    if (done == null) {
      await Future<void>.delayed(_socketWait);
      return;
    }
    final clock = Stopwatch()..start();
    while (clock.elapsed < _socketWait) {
      if (done()) return;
      final left = _socketWait - clock.elapsed;
      await Future<void>.delayed(left < _socketPollSlice ? left : _socketPollSlice);
    }
  }

  /// Moves the clock on by [total] in steps of [step], letting everything in flight arrive in between.
  Future<void> elapse(Duration total, {Duration step = const Duration(milliseconds: 500)}) async {
    for (var left = total; left > Duration.zero; left -= step) {
      await settle(time: left < step ? left : step);
    }
  }

  /// Settles until [done] holds, or fails after about [limit] of the clock.
  Future<void> until(bool Function() done, {Duration limit = const Duration(seconds: 10)}) async {
    for (var spent = Duration.zero; !done(); spent += _settleStep) {
      if (spent > limit) fail('the state was not reached in $limit');
      await settle(done: done);
    }
  }

  /// Adds a phone with the vote capability that connects and pairs; it returns once the host lists it. With [reuse]
  /// the phone is the [id]'s earlier one coming back.
  Future<SystestPhone> addPhone(String id) async {
    final client = ControllerClient(
      identity: ControllerIdentity(
        controllerId: id,
        name: 'Phone $id',
        platform: 'android',
        appVersion: 'test',
        capabilities: const [Capability.choices],
      ),
      connector: listener is InProcessListener
          ? InProcessConnector(listener as InProcessListener)
          : WebSocketConnector(connectTimeout: const Duration(seconds: 1)),
      heartbeatInterval: const Duration(milliseconds: 100),
      heartbeatTimeout: const Duration(milliseconds: 1500),
      retryDelays: const [Duration(minutes: 30)],
    );
    final phone = SystestPhone._(id, client);
    final sub = client.choices.listen(phone.offers.add);
    _subs.add(sub);
    client.connect(address, code: server.pairingCode);
    await until(() => client.snapshot.isConnected && host.players.any((p) => p.id == id && !p.away));
    phones.add(phone);
    return phone;
  }

  /// Brings a phone that dropped back: the same client connects again.
  Future<void> rejoin(SystestPhone phone) async {
    phone.client.connect(address, code: server.pairingCode);
    await until(() => phone.client.snapshot.isConnected && host.players.any((p) => p.id == phone.id && !p.away));
  }

  /// Adds an old phone (no vote capability) that pairs on the in-process link.
  Future<SystestOldPhone> addOldPhone(String id) async {
    final link = listener as InProcessListener;
    final phone = SystestOldPhone._(id, link.connect());
    // An old build lists the layout and status it can show, and not the choices.
    phone._send(
      HelloMessage(
        controllerId: id,
        name: 'Old $id',
        platform: 'android',
        appVersion: 'test',
        capabilities: const [Capability.layout, Capability.status],
      ),
    );
    await until(() => phone.fromHost.any((m) => m is WelcomeMessage));
    phone._send(PairRequestMessage(code: server.pairingCode));
    await until(() => host.players.any((p) => p.id == id));
    oldPhones.add(phone);
    return phone;
  }

  /// The player ids the host lists now, in number order.
  List<String> get playerIds => [for (final p in host.players) p.id];

  /// Plays one round for the night: [points] by player id, the first of them the winner.
  void recordRound(Map<String, int> points) {
    container.read(partyNightProvider.notifier).recordRound(roundResult(points: points, winners: {points.keys.first}));
  }
}

/// A host on the in-process link (or, with [webSocket], on localhost) with a night's providers over it, prefs
/// [prefs] and the picker [picker]. Every timer runs on the test's fake clock.
Future<Systest> openSystest(
  WidgetTester tester, {
  NightPicker picker = NightPicker.vote,
  FakePrefs? prefs,
  bool webSocket = false,
}) async {
  // The test binding answers every HTTP request itself; the phones need the real socket.
  if (webSocket) HttpOverrides.global = null;
  final ChannelListener listener = webSocket
      ? WebSocketListener(preferredPort: 0, hostName: 'Test TV')
      : InProcessListener();
  final server = HostServer(
    hostId: 'host-1',
    hostName: 'Test TV',
    appVersion: 'test',
    listeners: [listener],
    heartbeatInterval: const Duration(milliseconds: 100),
    heartbeatTimeout: const Duration(milliseconds: 1500),
    capabilities: const [Capability.choices],
  );
  await tester.runAsync(server.start);
  final host = ServerGameHost(server);
  final container = ProviderContainer(
    overrides: [
      prefsProvider.overrideWithValue(prefs ?? FakePrefs()),
      gameHostProvider.overrideWithValue(host),
      gamePlayersProvider.overrideWith(() => _HostRoster(host)),
      arenaMapLibraryProvider.overrideWith((ref) => testMaps()),
      nightRandomProvider.overrideWithValue(Random(systestSeed)),
    ],
  );
  container.read(nightSettingsProvider.notifier).update(NightSettings(picker: picker));
  final address = webSocket
      ? HostAddress(addresses: ['127.0.0.1'], port: server.port!)
      : HostAddress.local(hostId: server.hostId, name: server.hostName);
  final systest = Systest._(tester, server, host, container, listener, address);
  _open.add(systest);
  return systest;
}

final _open = <Systest>[];

/// A widget test whose hosts are closed at its end, however it ends.
void systestWidgets(String description, Future<void> Function(WidgetTester tester) body) {
  testWidgets(description, (tester) async {
    try {
      await body(tester);
    } finally {
      for (final systest in _open) {
        await systest.close();
      }
      _open.clear();
    }
  });
}

/// Prefs that keep every string in a JSON file under [directory], so a second instance on the same directory reads
/// what the first saved, as a host that restarts does.
final class DiskPrefs extends FakePrefs {
  /// Opens the prefs file in [directory], loading what an earlier instance saved there.
  DiskPrefs(this.directory) {
    if (file.existsSync()) {
      final json = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
      saved.addAll({for (final e in json.entries) e.key: e.value! as String});
    }
  }

  /// The real directory the file lives in.
  final Directory directory;

  /// The prefs file.
  File get file => File('${directory.path}${Platform.pathSeparator}prefs.json');

  void _flush() => file.writeAsStringSync(jsonEncode(saved));

  @override
  Future<bool> setString(String key, String value) {
    final ok = super.setString(key, value);
    _flush();
    return ok;
  }

  @override
  Future<bool> remove(String key) {
    final ok = super.remove(key);
    _flush();
    return ok;
  }
}
