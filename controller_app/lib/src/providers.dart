import 'dart:async';
import 'dart:io';

import 'package:connection/connection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'discovery.dart';
import 'local_network.dart';
import 'storage.dart';

/// Overridden in main() with the loaded instance.
final prefsProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('prefsProvider must be overridden'),
);

/// Overridden in tests to check the iOS-only behavior on Windows.
final isIOSProvider = Provider<bool>((ref) => Platform.isIOS);

final logProvider = Provider<LogBuffer>((ref) {
  final log = LogBuffer();
  if (kDebugMode) {
    final sub = log.changes.listen((_) => debugPrint(log.lines.last.toString()));
    ref.onDispose(sub.cancel);
  }
  ref.onDispose(log.close);
  return log;
});

final storeProvider = Provider<ConnectionStore>((ref) => ConnectionStore(ref.watch(prefsProvider)));

final identityProvider = Provider<ControllerIdentity>((ref) => loadIdentity(ref.watch(prefsProvider)));

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

final clientProvider = Provider<ControllerClient>((ref) {
  final store = ref.watch(storeProvider);
  final identity = ref.watch(identityProvider);
  final log = ref.watch(logProvider);
  log.add(
    'app',
    'Controller ${identity.appVersion} on ${identity.platform}, ID ${identity.controllerId.substring(0, 6)}',
  );
  final client = ControllerClient(
    identity: identity,
    tokens: store.tokens,
    onTokenChanged: store.setToken,
    log: log.sink('client'),
  );
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

final logLinesProvider = NotifierProvider<LogLinesNotifier, List<LogLine>>(LogLinesNotifier.new);

class LogLinesNotifier extends Notifier<List<LogLine>> {
  @override
  List<LogLine> build() {
    final log = ref.watch(logProvider);
    final sub = log.changes.listen((_) => state = log.lines);
    ref.onDispose(sub.cancel);
    return log.lines;
  }
}

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

  /// On launch: reconnect to the last TV if this phone is still paired with it.
  void reconnectToLastHost() {
    final last = _store.lastHost;
    final id = last?.hostId;
    if (last != null && id != null && _client.tokens.containsKey(id)) _client.connect(last);
  }
}
