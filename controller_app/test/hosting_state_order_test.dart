import 'dart:io';

import 'package:connection/connection.dart';
import 'package:controller/src/host/host_overrides.dart';
import 'package:controller/src/host/hosting.dart';
import 'package:controller/src/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart' as party;
import 'package:party_host/testing.dart' as party_test;
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fakes.dart';
import 'support/host_app.dart';

/// The host is in the app's state before the game-shown flag says it runs (the
/// run's review, f1 finding on hosting.dart:40): the flag is what the crash
/// lobby's names hang off, and their read goes through `phoneServiceProvider`,
/// which asks `hostingProvider` for the host. Set the other way round, the read
/// the flag causes found no host in the state and threw "No host is running in
/// this app".
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a lobby read while the host starts finds the host, not "No host is running"', () async {
    final dir = Directory.systemTemp.createTempSync('thumb-party-hosting-order-');
    addTearDown(() => dir.deleteSync(recursive: true));
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final flag = _LobbyReadingShown();
    final container = ProviderContainer(
      overrides: [
        ...phoneHostOverrides(directories: TempHostDirectories(dir)),
        prefsProvider.overrideWithValue(prefs),
        party.prefsProvider.overrideWith((ref) => ref.watch(prefsProvider)),
        identityProvider.overrideWithValue(
          const ControllerIdentity(controllerId: 'phone-1', name: 'Phone', platform: 'test', appVersion: 't'),
        ),
        tvClientProvider.overrideWithValue(FakeClient()),
        discoveryProvider.overrideWithValue(FakeDiscovery()),
        party.advertiserProvider.overrideWithValue(party_test.FakeAdvertiser()),
        party.soundPlayerProvider.overrideWithValue(party_test.FakeSoundPlayer()),
        party.screenAwakeProvider.overrideWithValue(party_test.FakeScreenAwake()),
        gameShownProvider.overrideWith(() => flag),
      ],
    );
    addTearDown(container.dispose);
    flag.container = container;

    final hosting = container.read(hostingProvider.notifier);
    final host = hosting.start(playsHere: false);

    expect(flag.lobbyRead, isNotNull, reason: 'the flag is what the lobby turns on from');
    expect(flag.lobbyRead, isEmpty, reason: 'no phone has joined yet');
    // Nothing threw: the lobby went through this phone's service, the host's.
    expect(container.read(phoneServiceProvider), same(host.service));
    expect(container.read(hostingProvider), same(host));

    await hosting.stop();
    expect(host.live, isFalse);
  });
}

/// The game-shown flag that reads the crash lobby the moment it turns on, as a
/// synchronous reader of it does: on a phone that hosts, the lobby's names hang
/// off this flag (phoneCrashLobbyProvider), and reading them asks
/// `phoneServiceProvider` for the host the start is setting.
class _LobbyReadingShown extends GameShownNotifier {
  /// The container the read goes through: the notifier's own ref cannot read a
  /// provider that depends on this one (Riverpod calls it a cycle).
  ProviderContainer? container;

  /// The lobby as the flip read it, for the test to check.
  List<GamePlayer>? lobbyRead;

  @override
  void set(bool shown) {
    super.set(shown);
    final container = this.container;
    if (!shown || container == null) return;
    lobbyRead = container.read(phoneCrashLobbyProvider);
  }
}
