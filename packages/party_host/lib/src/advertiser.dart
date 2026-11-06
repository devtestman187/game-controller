import 'dart:async';

import 'package:bonsoir/bonsoir.dart';
import 'package:connection/connection.dart';
import 'package:protocol/protocol.dart';

/// Where advertising the host's game service stands (PRD T6).
enum AdvertiseState {
  /// Started, but the network hasn't confirmed the name yet.
  starting,

  /// Phones can find this host by name.
  advertising,

  /// Advertising didn't work: phones can still join by address and code.
  failed,
}

/// The latest advertising status: everything [Advertiser] reports at once.
final class AdvertiserStatus {
  const AdvertiserStatus({required this.state, this.advertisedName, this.error});

  /// Where advertising stands.
  final AdvertiseState state;

  /// The mDNS name phones see (it can change if another host on the network
  /// has the same name).
  final String? advertisedName;

  /// Why advertising failed, if it did.
  final String? error;
}

/// Advertises the host's server over mDNS, so phones find it without typing
/// an address (PRD T6). The state is the latest [AdvertiserStatus].
///
/// The implementation is a platform adapter: [BonsoirAdvertiser] in the apps,
/// a fake in tests, so `party_host`'s host service never touches the network
/// stack or the plugin (coding guidelines §1, M12 design §2.9).
abstract interface class Advertiser {
  /// Starts advertising [serviceName] on [port], with [txt] records for the
  /// phones (the host ID and the protocol version). The network may rename
  /// the service if the name is taken; the name in use is in
  /// [AdvertiserStatus.advertisedName].
  Future<void> start({required String serviceName, required int port, required Map<String, String> txt});

  /// Stops advertising. Safe to call when it never started or already failed.
  Future<void> stop();

  /// The latest status, [AdvertiseState.starting] before [start].
  AdvertiserStatus get status;

  /// Fires on every status change.
  Stream<AdvertiserStatus> get changes;
}

/// Advertises through `package:bonsoir` (Bonjour on Apple, NSD on Android and
/// Windows), the same plugin the phone apps use to find hosts.
///
/// The `bonsoir` plugin is the only platform code here: a build without the
/// plugin fails advertising ([AdvertiseState.failed]) and phones can still
/// join by address and code. [stop] closes [changes], as nothing is left
/// listening after it.
class BonsoirAdvertiser implements Advertiser {
  /// [log] gets short lines about advertising, tagged `host`.
  BonsoirAdvertiser({LogSink? log}) : _log = log ?? ((_) {});

  final LogSink _log;
  final _changes = StreamController<AdvertiserStatus>.broadcast();
  AdvertiserStatus _status = const AdvertiserStatus(state: AdvertiseState.starting);
  BonsoirBroadcast? _broadcast;
  StreamSubscription<BonsoirBroadcastEvent>? _sub;

  @override
  AdvertiserStatus get status => _status;

  @override
  Stream<AdvertiserStatus> get changes => _changes.stream;

  @override
  Future<void> start({required String serviceName, required int port, required Map<String, String> txt}) async {
    final service = BonsoirService(name: serviceName, type: serviceType, port: port, attributes: txt);
    final broadcast = BonsoirBroadcast(service: service);
    _broadcast = broadcast;
    try {
      await broadcast.initialize();
      _sub = broadcast.eventStream?.listen((event) {
        switch (event) {
          case BonsoirBroadcastStartedEvent():
            _set(AdvertiserStatus(state: AdvertiseState.advertising, advertisedName: event.service.name));
            _log('Advertising "${event.service.name}" ($serviceType, port ${event.service.port})');
          case BonsoirBroadcastNameAlreadyExistsEvent():
            _set(AdvertiserStatus(state: _status.state, advertisedName: event.service.name, error: _status.error));
            _log('Name already taken on the network, now advertising as "${event.service.name}"');
          case BonsoirBroadcastStoppedEvent():
            _log('Advertising stopped');
            _set(_status);
          default:
            _set(_status);
        }
      }, onError: _failed);
      await broadcast.start();
    } catch (e) {
      _failed(e);
    }
  }

  @override
  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    try {
      await _broadcast?.stop();
    } catch (e) {
      _log('Could not stop advertising: $e');
    }
    _broadcast = null;
    await _changes.close();
  }

  void _failed(Object error) {
    _set(AdvertiserStatus(state: AdvertiseState.failed, advertisedName: _status.advertisedName, error: '$error'));
    _log('Advertising failed: $error');
  }

  void _set(AdvertiserStatus s) {
    _status = s;
    if (!_changes.isClosed) _changes.add(s);
  }
}
