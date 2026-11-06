import 'package:connection/connection.dart';

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
/// The implementation comes at G3; this is the declaration the host service
/// is written against.
class BonsoirAdvertiser implements Advertiser {
  /// [log] gets short lines about advertising, tagged `host`.
  BonsoirAdvertiser({LogSink? log});

  @override
  Future<void> start({required String serviceName, required int port, required Map<String, String> txt}) =>
      throw UnimplementedError();

  @override
  Future<void> stop() => throw UnimplementedError();

  @override
  AdvertiserStatus get status => throw UnimplementedError();

  @override
  Stream<AdvertiserStatus> get changes => throw UnimplementedError();
}
