import 'dart:io';

import 'package:connection/connection.dart';
import 'package:controller/src/host/host_overrides.dart';
import 'package:controller/src/host/hosting.dart';
import 'package:controller/src/host/hosting_frame_rate.dart';
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
    expect(container.read(party.hostingSettingsProvider).frameRateHz, 60, reason: 'the default rate for tests');
    expect(
      () => container.read(phoneServiceProvider),
      throwsA(predicate((e) => '$e'.contains('No host is running in this app'))),
    );

    final hosting = container.read(hostingProvider.notifier);
    final host = hosting.start(playsHere: true);
    expect(container.read(hostingProvider), same(host));
    // The screens use the own player's client from now on.
    expect(container.read(ownClientProvider), same(ownClientOf(host)));
    expect(container.read(clientProvider), same(ownClientOf(host)));
    // The search for a TV stops, since this phone is one now.
    expect(discovery.stops, 1);

    await waitFor(() => host.service.state.host.running, () => 'The host server did not start');
    await ownPlayerReady(host);
    await waitFor(() => host.service.state.players.length == 1, () => 'The own player did not join the host');
    expect(container.read(phoneServiceProvider), same(host.service));
    expect(container.read(party.hostServiceProvider), same(host.service));

    await hosting.stop();
    expect(host.live, isFalse);
    expect(ownClientOf(host).snapshot.status, ClientStatus.idle);
    // Back to the TV client, and searching again for the next game.
    expect(container.read(ownClientProvider), isNull);
    expect(container.read(clientProvider), isNot(same(ownClientOf(host))));
    expect(discovery.restarts, 1);
    // A second stop is a no-op: the host is already gone.
    await hosting.stop();
    expect(discovery.restarts, 1);

    // A second "Host a game" gives a host of its own, and the graph follows it.
    final again = hosting.start(playsHere: true);
    expect(again, isNot(same(host)));
    expect(container.read(phoneServiceProvider), same(again.service));
    expect(container.read(party.hostServiceProvider), same(again.service));
    await ownPlayerReady(again);
    await waitFor(() => again.service.state.players.length == 1, () => 'The own player did not join again');
    await hosting.stop();
    expect(again.live, isFalse);
  });

  test('"Show on this device" pairs no own player, so the first phone to join is P1', () async {
    final dir = Directory.systemTemp.createTempSync('thumb-party-hosting-');
    addTearDown(() => dir.deleteSync(recursive: true));
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final discovery = FakeDiscovery();
    final tv = FakeClient();
    final container = ProviderContainer(
      overrides: [
        ...phoneHostOverrides(directories: TempHostDirectories(dir)),
        prefsProvider.overrideWithValue(prefs),
        identityProvider.overrideWithValue(
          const ControllerIdentity(controllerId: 'phone-1', name: 'Phone', platform: 'test', appVersion: 't'),
        ),
        tvClientProvider.overrideWithValue(tv),
        discoveryProvider.overrideWithValue(discovery),
        party.advertiserProvider.overrideWithValue(party_test.FakeAdvertiser()),
        party.soundPlayerProvider.overrideWithValue(party_test.FakeSoundPlayer()),
        party.screenAwakeProvider.overrideWithValue(party_test.FakeScreenAwake()),
      ],
    );
    addTearDown(container.dispose);

    final hosting = container.read(hostingProvider.notifier);
    final host = hosting.start(playsHere: false);

    // No own player on the link, and the screens keep the TV client, so the
    // bar falls back to what it shows without a player (m12 bug 1108a A, B).
    expect(host.client, isNull);
    expect(host.listener, isNull);
    expect(container.read(ownClientProvider), isNull);
    expect(container.read(clientProvider), same(tv));
    expect(container.read(party.ownPlayerIdProvider), isNull, reason: 'this phone is the screen, not a player');
    // The phones that join keep the game on this screen (m12-joined-view §0.1).
    expect(host.service.shareView, isFalse);

    await waitFor(() => host.service.state.host.running, () => 'The host server did not start');
    expect(host.service.state.host.controllers, isEmpty);
    expect(host.service.gameHost.players, isEmpty);
    // The first player to take a number gets P1, as a pairing phone does.
    final joiner = host.service.gameHost.addLocalPlayer(nickname: 'Ada');
    expect(joiner.number, 1);

    await hosting.stop();
    expect(host.live, isFalse);
    expect(discovery.restarts, 1);

    // "Play on this phone" after it pairs the own player again (rule C).
    final again = hosting.start(playsHere: true);
    expect(container.read(ownClientProvider), same(ownClientOf(again)));
    expect(container.read(party.ownPlayerIdProvider), 'phone-1');
    await waitFor(() => again.service.state.host.running, () => 'The host server did not start again');
    await ownPlayerReady(again);
    await waitFor(() => again.service.gameHost.players.length == 1, () => 'The own player did not join again');
    await hosting.stop();
  });

  test('a game this phone hosts runs at the frame rate saved for tests', () async {
    final dir = Directory.systemTemp.createTempSync('thumb-party-hosting-');
    addTearDown(() => dir.deleteSync(recursive: true));
    SharedPreferences.setMockInitialValues({'hostingFrameRateHz': 30});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        ...phoneHostOverrides(directories: TempHostDirectories(dir)),
        prefsProvider.overrideWithValue(prefs),
        identityProvider.overrideWithValue(
          const ControllerIdentity(controllerId: 'phone-1', name: 'Phone', platform: 'test', appVersion: 't'),
        ),
      ],
    );
    addTearDown(container.dispose);

    // The game screens read this when they start a round (m12 §0.5).
    expect(container.read(party.hostingSettingsProvider).frameRateHz, 30);
    container.read(hostingFrameRateProvider.notifier).set(20);
    expect(container.read(party.hostingSettingsProvider).frameRateHz, 20, reason: 'a change needs no restart');
    expect(prefs.getInt('hostingFrameRateHz'), 20);
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

/// Waits until this phone's own player has paired on its host's link; a host
/// that shows the game on this device pairs none (m12 bug 1108a rule A).
Future<void> ownPlayerReady(PhoneHost host) => waitFor(
  () => ownClientOf(host).snapshot.isConnected,
  () => 'The own player did not pair: ${ownClientOf(host).snapshot}',
);
