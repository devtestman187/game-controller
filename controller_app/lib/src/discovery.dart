import 'dart:async';

import 'package:bonsoir/bonsoir.dart';
import 'package:connection/connection.dart';
import 'package:protocol/protocol.dart';

/// A TV found on the network.
final class DiscoveredHost {
  const DiscoveredHost({required this.address, this.advertisedVersion});

  final HostAddress address;

  /// Protocol version from the TXT record. Null if the host didn't say.
  final int? advertisedVersion;

  bool get compatible => advertisedVersion == null || advertisedVersion == protocolVersion;

  String get name => address.name ?? address.display;
}

final class DiscoveryState {
  const DiscoveryState({
    this.running = false,
    this.hosts = const [],
    this.error,
    this.everFound = false,
    this.startedAt,
  });

  final bool running;
  final List<DiscoveredHost> hosts;
  final String? error;

  /// True once any TV was found since the app started. On iOS that proves
  /// local network access is allowed.
  final bool everFound;
  final DateTime? startedAt;

  DiscoveryState copyWith({
    bool? running,
    List<DiscoveredHost>? hosts,
    Object? error = _keep,
    bool? everFound,
    Object? startedAt = _keep,
  }) => DiscoveryState(
    running: running ?? this.running,
    hosts: hosts ?? this.hosts,
    error: identical(error, _keep) ? this.error : error as String?,
    everFound: everFound ?? this.everFound,
    startedAt: identical(startedAt, _keep) ? this.startedAt : startedAt as DateTime?,
  );
}

const Object _keep = Object();

/// Finds TVs on the local network. A fake implements it in tests.
abstract class HostDiscovery {
  DiscoveryState get state;
  Stream<DiscoveryState> get changes;
  Future<void> start();
  Future<void> stop();

  /// Starts a fresh search, for example when the app comes back to the
  /// foreground or after the local network permission was granted.
  Future<void> restart();
  Future<void> dispose();
}

/// mDNS discovery with bonsoir (NSD on Android, Bonjour on iOS).
class BonsoirHostDiscovery implements HostDiscovery {
  BonsoirHostDiscovery({LogSink? log}) : _log = log ?? ((_) {});

  final LogSink _log;
  final _changes = StreamController<DiscoveryState>.broadcast();
  final _hosts = <String, DiscoveredHost>{}; // By service name.
  DiscoveryState _state = const DiscoveryState();
  BonsoirDiscovery? _discovery;
  StreamSubscription<BonsoirDiscoveryEvent>? _sub;
  bool _disposed = false;

  @override
  DiscoveryState get state => _state;

  @override
  Stream<DiscoveryState> get changes => _changes.stream;

  @override
  Future<void> start() async {
    if (_discovery != null || _disposed) return;
    final discovery = BonsoirDiscovery(type: serviceType);
    _discovery = discovery;
    try {
      await discovery.initialize();
      _sub = discovery.eventStream?.listen(
        (event) => _onEvent(discovery, event),
        onError: (Object e) {
          _log('Discovery error: $e');
          _set(_state.copyWith(error: '$e'));
        },
      );
      await discovery.start();
      _set(_state.copyWith(running: true, error: null, startedAt: DateTime.now()));
    } catch (e) {
      _log('Discovery could not start: $e');
      _discovery = null;
      _set(_state.copyWith(running: false, error: '$e'));
    }
  }

  @override
  Future<void> stop() async {
    final discovery = _discovery;
    _discovery = null;
    await _sub?.cancel();
    _sub = null;
    if (discovery != null) {
      try {
        await discovery.stop();
      } catch (e) {
        _log('Discovery stop failed: $e');
      }
    }
    _hosts.clear();
    _set(_state.copyWith(running: false, hosts: const []));
  }

  @override
  Future<void> restart() async {
    _log('Restarting discovery');
    await stop();
    await start();
  }

  @override
  Future<void> dispose() async {
    await stop();
    _disposed = true;
    await _changes.close();
  }

  void _onEvent(BonsoirDiscovery discovery, BonsoirDiscoveryEvent event) {
    switch (event) {
      case BonsoirDiscoveryStartedEvent():
        _log('Searching for $serviceType');
      case BonsoirDiscoveryServiceFoundEvent(:final service):
        _log('Found "${service.name}", resolving its address');
        service.resolve(discovery.serviceResolver).catchError((Object e) => _log('Resolve failed: $e'));
      case BonsoirDiscoveryServiceResolvedEvent(:final service):
        _update(service);
      case BonsoirDiscoveryServiceUpdatedEvent(:final service):
        _update(service);
      case BonsoirDiscoveryServiceResolveFailedEvent():
        _log('A TV was found but its address could not be resolved');
      case BonsoirDiscoveryServiceLostEvent(:final service):
        if (_hosts.remove(service.name) != null) {
          _log('Lost "${service.name}"');
          _publish();
        }
      case BonsoirDiscoveryStoppedEvent():
        _set(_state.copyWith(running: false));
      default:
    }
  }

  void _update(BonsoirService service) {
    final addresses = service.hostAddresses.isNotEmpty ? service.hostAddresses : [?service.hostname];
    if (addresses.isEmpty || service.port == 0) return;
    final host = DiscoveredHost(
      address: HostAddress(
        addresses: addresses,
        port: service.port,
        hostId: service.attributes[txtHostId],
        name: service.name,
      ),
      advertisedVersion: int.tryParse(service.attributes[txtProtocolVersion] ?? ''),
    );
    _log('Resolved "${service.name}" at ${addresses.join(', ')} port ${service.port}');
    _hosts[service.name] = host;
    _publish(found: true);
  }

  void _publish({bool found = false}) {
    final hosts = _hosts.values.toList()..sort((a, b) => a.name.compareTo(b.name));
    _set(_state.copyWith(hosts: hosts, everFound: found || _state.everFound));
  }

  void _set(DiscoveryState next) {
    _state = next;
    if (!_changes.isClosed) _changes.add(next);
  }
}
