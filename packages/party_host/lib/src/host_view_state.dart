import 'package:connection/connection.dart';

import 'advertiser.dart';

/// An IPv4 address of this device, to show for manual entry on the phone.
final class LocalAddress {
  const LocalAddress(this.address, this.interfaceName);

  /// e.g. `192.168.1.50`.
  final String address;

  /// The interface it belongs to, e.g. `wlan0`.
  final String interfaceName;

  @override
  bool operator ==(Object other) =>
      other is LocalAddress && other.address == address && other.interfaceName == interfaceName;

  @override
  int get hashCode => Object.hash(address, interfaceName);
}

/// Everything the host screens show.
final class HostViewState {
  const HostViewState({
    required this.hostName,
    required this.host,
    this.addresses = const [],
    this.advertise = AdvertiseState.starting,
    this.advertisedName,
    this.advertiseError,
    this.serverError,
    this.sims = const [],
  });

  /// The name phones see for this host, before advertising renames it.
  final String hostName;

  /// The server's snapshot: whether it runs, its port, the pairing code and
  /// every controller (PRD T9).
  final HostSnapshot host;

  /// This device's IPv4 addresses, to type in on a phone by hand.
  final List<LocalAddress> addresses;

  /// Where advertising stands.
  final AdvertiseState advertise;

  /// The mDNS name phones see (it can change if the name is taken).
  final String? advertisedName;

  /// Why advertising failed, if it did.
  final String? advertiseError;

  /// Set if the server couldn't start at all.
  final String? serverError;

  /// The built-in simulated controllers (up to three, `HostService.maxSims`),
  /// for checking 4-player layouts with fewer phones (M11).
  final List<ClientSnapshot> sims;

  /// Connected controllers by player number (PRD T9).
  List<ControllerInfo> get players =>
      host.connected.toList()..sort((a, b) => (a.player ?? 99).compareTo(b.player ?? 99));
}
