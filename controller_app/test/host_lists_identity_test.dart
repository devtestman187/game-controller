import 'dart:async';
import 'dart:io';

import 'package:connection/connection.dart';
import 'package:controller/src/host/phone_host.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metrics/metrics.dart';
import 'package:party_host/party_host.dart' as party;
import 'package:party_host/testing.dart' as party_test;
import 'package:protocol/protocol.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The identity a desktop build supplies, as the TV host tests use it.
const _tvIdentity = party.HostIdentity(
  appVersion: '0.16.0',
  versionLabel: '0.16.0 (1)',
  hostType: HostType.windows,
  kind: party.HostKind.pc,
  hostOs: 'windows',
  defaultHostName: 'PC',
  serviceName: 'Thumb Party TV (PC)',
);

/// The identity of a phone that hosts ("Play on this phone", m12 §2.7).
const _phoneIdentity = party.HostIdentity(
  appVersion: '0.16.0',
  versionLabel: '0.16.0 (1)',
  hostType: HostType.phone,
  kind: party.HostKind.phone,
  hostOs: 'android',
  defaultHostName: 'Phone',
  serviceName: 'Thumb Party (phone)',
);

/// The character the test phone joins with: slot 4's crown.
const _crown = PlayerCharacter(colourSlot: 4, accessory: PlayerAccessory.crown);

/// The pick it changes to in Settings: slot 2's bow.
const _bow = PlayerCharacter(colourSlot: 2, accessory: PlayerAccessory.bow);

/// How long a pairing or an answer may take before the test calls it lost.
const _timeout = Duration(seconds: 5);

/// A joined phone, as the app's library builds it: it pairs on [link] with the
/// code and, like the app, tells the host a changed pick on its next heartbeat
/// (M16 identity).
ControllerClient _joinedPhone(InProcessListener link) {
  final phone = ControllerClient(
    identity: const ControllerIdentity(
      controllerId: 'phone-1',
      name: 'Mia',
      platform: 'test',
      appVersion: '0.16.0',
      character: _crown,
    ),
    connector: InProcessConnector(link),
    // The app's own beat is a second; a test's clock has no reason to wait.
    heartbeatInterval: const Duration(milliseconds: 50),
  );
  addTearDown(phone.dispose);
  return phone;
}

/// [phone] paired with a host on [link], and its welcome's capabilities.
Future<List<String>> _paired(ControllerClient phone, {required String code}) async {
  phone.connect(
    HostAddress.local(hostId: 'joined-phone', name: 'Test host'),
    code: code,
  );
  final joined = await phone.changes
      .firstWhere((s) => s.isConnected)
      .timeout(_timeout, onTimeout: () => throw TimeoutException('The phone never paired: ${phone.snapshot}'));
  return joined.hostCapabilities;
}

/// The character the host gave [phone] after the player picked [wanted] in the
/// phone's settings: the answer to the `set_character` the next heartbeat
/// sends.
Future<PlayerCharacter?> _changeTo(ControllerClient phone, PlayerCharacter wanted) async {
  phone.identity = phone.identity.copyWith(character: wanted);
  final answer = await phone.changes
      .firstWhere((s) => s.askedCharacter == wanted && s.character != _crown)
      .timeout(_timeout, onTimeout: () => throw TimeoutException('No answer to the pick: ${phone.snapshot}'));
  return answer.character;
}

/// The app's own host mode as "Play on this phone" builds it: the server, the
/// fake advertiser and folders in a temp folder, and this phone's own player.
Future<PhoneHost> _startPhoneHost() async {
  SharedPreferences.setMockInitialValues({});
  final dir = await Directory.systemTemp.createTemp('phone-host-identity-test');
  addTearDown(() => dir.delete(recursive: true));
  final log = LogBuffer();
  final host = PhoneHost.live((
    prefs: await SharedPreferences.getInstance(),
    log: log,
    identity: _phoneIdentity,
    directories: party_test.FakeHostDirectories(dir),
    advertiser: party_test.FakeAdvertiser(),
    controller: const ControllerIdentity(
      controllerId: 'own-player',
      name: 'Phone',
      platform: 'test',
      appVersion: '0.16.0',
    ),
    monitor: const party.NoHostDeviceMonitor(),
    uploader: null,
    start: party.HostStartLog(log.sink('start')),
  ), playsHere: true);
  addTearDown(host.dispose);
  await host.start();
  // Paired before the test's phone joins, so this phone's own player is player
  // 1 and the numbers (and the characters they get) are the test's.
  final own = host.client;
  if (own == null) fail('The hosting phone plays no own player');
  await own.changes
      .firstWhere((s) => s.isConnected)
      .timeout(_timeout, onTimeout: () => throw TimeoutException('The own player never paired: ${own.snapshot}'));
  return host;
}

/// The TV/PC host's service, as the host harness starts it: a fake advertiser,
/// the folders in a temp folder, and [link] for the phones of this test.
Future<party.LiveHostService> _startTvHost(InProcessListener link) async {
  SharedPreferences.setMockInitialValues({});
  final dir = await Directory.systemTemp.createTemp('tv-host-identity-test');
  addTearDown(() => dir.delete(recursive: true));
  final service = party.LiveHostService(
    prefs: await SharedPreferences.getInstance(),
    log: LogBuffer(),
    identity: _tvIdentity,
    directories: party_test.FakeHostDirectories(dir),
    advertiser: party_test.FakeAdvertiser(),
    inProcess: link,
  );
  addTearDown(service.dispose);
  await service.start();
  return service;
}

void main() {
  // The phone's own host mode watches the app lifecycle; a binding is needed
  // for that listener even though no widget is drawn here.
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a phone that hosts lists identity in its welcome, and answers the character its phone picks', () async {
    final host = await _startPhoneHost();
    final link = host.listener;
    if (link == null) fail('The hosting phone has no link for its phones');
    final phone = _joinedPhone(link);

    final welcome = await _paired(phone, code: host.service.state.host.pairingCode);

    expect(welcome, contains(Capability.identity), reason: 'a phone that hosts takes a character change');
    expect(await _changeTo(phone, _bow), _bow, reason: 'the own player wears slot 1, so slot 2 and the bow are free');
  });

  test('the TV host lists identity in its welcome, and answers the character its phone picks', () async {
    final link = InProcessListener();
    final host = await _startTvHost(link);
    final phone = _joinedPhone(link);

    final welcome = await _paired(phone, code: host.state.host.pairingCode);

    expect(welcome, contains(Capability.identity), reason: 'the TV host takes a character change');
    expect(
      await _changeTo(phone, _bow),
      _bow,
      reason: 'the phone is player 1, wearing the crown; slot 2 and the bow are free',
    );
  });
}
