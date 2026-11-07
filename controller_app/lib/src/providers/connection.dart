import 'dart:async';

import 'package:connection/connection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_info.dart';
import '../discovery.dart';
import '../local_network.dart';
import '../providers.dart';
import '../storage.dart';

final discoveryProvider = Provider<HostDiscovery>((ref) {
  final discovery = BonsoirHostDiscovery(log: ref.watch(logProvider).sink('discovery'));
  unawaited(discovery.start());
  ref.onDispose(discovery.dispose);
  return discovery;
});

final discoveryStateProvider = NotifierProvider<DiscoveryStateNotifier, DiscoveryState>(DiscoveryStateNotifier.new);

class DiscoveryStateNotifier extends Notifier<DiscoveryState> {
  @override
  DiscoveryState build() {
    final discovery = ref.watch(discoveryProvider);
    final sub = discovery.changes.listen((s) => state = s);
    ref.onDispose(sub.cancel);
    return discovery.state;
  }
}

/// The client this phone pairs with a TV over the network.
final tvClientProvider = Provider<ControllerClient>((ref) {
  final store = ref.watch(storeProvider);
  final identity = ref.watch(identityProvider);
  final log = ref.watch(logProvider);
  log.add('app', 'Thumb Party $versionLabel on ${identity.platform}, ID ${identity.controllerId.substring(0, 6)}');
  final client = ControllerClient(
    identity: identity,
    connector: WebSocketConnector(log: log.sink('client')),
    tokens: store.tokens,
    onTokenChanged: store.setToken,
    log: log.sink('client'),
  );
  unawaited(_addDeviceDetails(ref, client));
  // Remember the TV once paired (with its ID, even if it was typed in), so
  // the app reconnects to it on the next launch.
  final sub = client.changes.listen((s) {
    if (s.isConnected) store.lastHost = s.target;
  });
  ref.onDispose(() async {
    await sub.cancel();
    await client.dispose();
  });
  return client;
});

/// The client this phone's own player pairs with the host it runs (m12 §3):
/// null while the app isn't hosting, so the screens use the TV client then.
final ownClientProvider = NotifierProvider<OwnClientNotifier, ControllerClient?>(OwnClientNotifier.new);

/// Holds the own player's client, from the moment a host starts until it stops.
class OwnClientNotifier extends Notifier<ControllerClient?> {
  @override
  ControllerClient? build() => null;

  /// The own player's client, before the host route opens.
  void set(ControllerClient client) => state = client;

  /// Back to the TV client, from the moment the host stops.
  void clear() => state = null;
}

/// The client the screens use: the own player's while this phone hosts
/// (m12 §3), the TV's otherwise. It owns neither — each owner disposes its
/// own ([tvClientProvider]'s the TV one, the host the own one).
final clientProvider = Provider<ControllerClient>((ref) => ref.watch(ownClientProvider) ?? ref.watch(tvClientProvider));

/// Puts the model, OS and haptics into the next hello once they are known.
Future<void> _addDeviceDetails(Ref ref, ControllerClient client) async {
  final details = await ref.read(deviceDetailsProvider.future);
  if (!ref.mounted) return;
  bool? haptics;
  try {
    haptics = (await ref.read(hapticsCapabilitiesProvider.future)).supported;
  } catch (_) {
    // Devices without the haptics API fail this check; unknown (null) is
    // the right answer then.
  }
  if (!ref.mounted) return;
  client.identity = withDeviceDetails(client.identity, model: details.model, os: details.os, haptics: haptics);
}

final clientStateProvider = NotifierProvider<ClientStateNotifier, ClientSnapshot>(ClientStateNotifier.new);

class ClientStateNotifier extends Notifier<ClientSnapshot> {
  @override
  ClientSnapshot build() {
    final client = ref.watch(clientProvider);
    final sub = client.changes.listen((s) => state = s);
    ref.onDispose(sub.cancel);
    return client.snapshot;
  }
}

/// "Try without a TV" (v2 C23): the controls work with no host, and the
/// screen shows what a TV would receive. For app reviewers and new testers.
/// Ends by itself once a TV connects.
final demoProvider = NotifierProvider<DemoNotifier, bool>(DemoNotifier.new);

class DemoNotifier extends Notifier<bool> {
  @override
  bool build() {
    ref.listen(clientStateProvider, (_, next) {
      if (next.isConnected) state = false;
    });
    return false;
  }

  void start() => state = true;

  void stop() => state = false;
}

/// True once the phone has been connected to a TV since launch.
final everConnectedProvider = NotifierProvider<EverConnectedNotifier, bool>(EverConnectedNotifier.new);

class EverConnectedNotifier extends Notifier<bool> {
  @override
  bool build() {
    ref.listen(clientStateProvider, (_, next) {
      if (next.isConnected) state = true;
    });
    return ref.read(clientStateProvider).isConnected;
  }
}

final localNetworkStatusProvider = Provider<LocalNetworkStatus>(
  (ref) => localNetworkStatus(
    isIOS: ref.watch(isIOSProvider),
    discovery: ref.watch(discoveryStateProvider),
    client: ref.watch(clientStateProvider),
    everConnected: ref.watch(everConnectedProvider),
  ),
);

/// What the screens do. Keeps "remember the last TV" next to connecting.
final connectionActionsProvider = Provider<ConnectionActions>(
  (ref) => ConnectionActions(ref.watch(clientProvider), ref.watch(storeProvider)),
);

class ConnectionActions {
  ConnectionActions(this._client, this._store);

  final ControllerClient _client;
  final ConnectionStore _store;

  void connect(HostAddress host, {String? code}) => _client.connect(host, code: code);

  void submitCode(String code) => _client.submitCode(code);

  /// Disconnects and forgets the last TV, so the next launch doesn't
  /// reconnect on its own.
  void disconnect() {
    _store.lastHost = null;
    _client.disconnect();
  }

  /// On launch: reconnect to the last TV if this phone is still paired with
  /// it. Returns false if there is nothing to reconnect to.
  bool reconnectToLastHost() {
    final last = _store.lastHost;
    final id = last?.hostId;
    if (last == null || id == null || !_client.tokens.containsKey(id)) return false;
    _client.connect(last);
    return true;
  }
}

/// One time the connection dropped and came back (or hasn't yet).
typedef Outage = ({DateTime from, Duration? length, String reason});

/// The latest connection drops, newest first, for Diagnostics: how long
/// each one took to recover (PRD M6 reconnect hardening).
final outagesProvider = NotifierProvider<OutagesNotifier, List<Outage>>(OutagesNotifier.new);

class OutagesNotifier extends Notifier<List<Outage>> {
  static const keep = 10;

  @override
  List<Outage> build() {
    ref.listen(clientStateProvider, (prev, next) {
      final wasUp = prev?.isConnected ?? false;
      if (wasUp && next.status == ClientStatus.reconnecting) {
        final reason = next.detail ?? next.problem?.name ?? 'connection lost';
        state = [(from: DateTime.now(), length: null, reason: reason), ...state].take(keep).toList();
      } else if (next.isConnected && state.isNotEmpty && state.first.length == null) {
        final o = state.first;
        state = [(from: o.from, length: DateTime.now().difference(o.from), reason: o.reason), ...state.skip(1)];
        ref
            .read(logProvider)
            .add('client', 'Back after ${(state.first.length!.inMilliseconds / 1000).toStringAsFixed(1)} s');
      }
    });
    return const [];
  }
}
