import 'dart:io';

import 'package:connection/connection.dart';
import 'package:controller/src/host/host_overrides.dart';
import 'package:controller/src/host/hosting.dart';
import 'package:controller/src/host/phone_host.dart';
import 'package:controller/src/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart' as party;
import 'package:party_host/testing.dart' as party_test;
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fakes.dart';
import 'support/host_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the app starts a host, stops it, and starts another', () async {
    final dir = Directory.systemTemp.createTempSync('thumb-party-hosting-');
    addTearDown(() => dir.deleteSync(recursive: true));
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final discovery = FakeDiscovery();
    final container = ProviderContainer(
      overrides: [
        ...phoneHostOverrides(directories: TempHostDirectories(dir)),
        prefsProvider.overrideWithValue(prefs),
        identityProvider.overrideWithValue(
          const ControllerIdentity(controllerId: 'phone-1', name: 'Phone', platform: 'test', appVersion: 't'),
        ),
        tvClientProvider.overrideWithValue(FakeClient()),
        discoveryProvider.overrideWithValue(discovery),
        party.advertiserProvider.overrideWithValue(party_test.FakeAdvertiser()),
        party.soundPlayerProvider.overrideWithValue(party_test.FakeSoundPlayer()),
        party.screenAwakeProvider.overrideWithValue(party_test.FakeScreenAwake()),
      ],
    );
    addTearDown(container.dispose);

    // Nothing reads the host before the first "Host a game": the chip returns
    // early, so the provider may throw then (m12 §3).
    expect(container.read(hostingProvider), isNull);
    expect(
      () => container.read(phoneServiceProvider),
      throwsA(predicate((e) => '$e'.contains('No host is running in this app'))),
    );

    final hosting = container.read(hostingProvider.notifier);
    final host = hosting.start();
    expect(container.read(hostingProvider), same(host));
    // The screens use the own player's client from now on.
    expect(container.read(ownClientProvider), same(host.client));
    expect(container.read(clientProvider), same(host.client));
    // The search for a TV stops, since this phone is one now.
    expect(discovery.stops, 1);

    await waitFor(() => host.service.state.host.running, () => 'The host server did not start');
    await ownPlayerReady(host);
    await waitFor(() => host.service.state.players.length == 1, () => 'The own player did not join the host');
    expect(container.read(phoneServiceProvider), same(host.service));
    expect(container.read(party.hostServiceProvider), same(host.service));

    await hosting.stop();
    expect(host.live, isFalse);
    expect(host.client.snapshot.status, ClientStatus.idle);
    // Back to the TV client, and searching again for the next game.
    expect(container.read(ownClientProvider), isNull);
    expect(container.read(clientProvider), isNot(same(host.client)));
    expect(discovery.restarts, 1);
    // A second stop is a no-op: the host is already gone.
    await hosting.stop();
    expect(discovery.restarts, 1);

    // A second "Host a game" gives a host of its own, and the graph follows it.
    final again = hosting.start();
    expect(again, isNot(same(host)));
    expect(container.read(phoneServiceProvider), same(again.service));
    expect(container.read(party.hostServiceProvider), same(again.service));
    await ownPlayerReady(again);
    await waitFor(() => again.service.state.players.length == 1, () => 'The own player did not join again');
    await hosting.stop();
    expect(again.live, isFalse);
  });
}

/// Waits for the host's real work (its socket, its own player's link) in a
/// plain test: no widget clock to pump.
Future<void> waitFor(bool Function() done, String Function() why) async {
  for (var i = 0; i < 300; i++) {
    if (done()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail(why());
}

/// Waits until this phone's own player has paired on its host's link.
Future<void> ownPlayerReady(PhoneHost host) =>
    waitFor(() => host.client.snapshot.isConnected, () => 'The own player did not pair: ${host.client.snapshot}');
