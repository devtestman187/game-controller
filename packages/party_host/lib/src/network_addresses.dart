import 'dart:io';

import 'host_view_state.dart';

/// This device's IPv4 addresses, to show for manual entry on a phone
/// (PRD T6), Wi-Fi and Ethernet first and virtual adapters (WSL, Hyper-V,
/// VPNs) last.
///
/// Split from the host service because it reads the network interfaces; the
/// caller logs a failure (a laptop with no network still hosts by address
/// once Wi-Fi returns, so it keeps the list fresh).
Future<List<LocalAddress>> networkAddresses() async {
  final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
  return [
    for (final i in interfaces)
      for (final a in i.addresses)
        if (!a.isLoopback && !a.isLinkLocal) LocalAddress(a.address, i.name),
  ]..sort((a, b) => _interfaceRank(a.interfaceName).compareTo(_interfaceRank(b.interfaceName)));
}

/// True when [a] and [b] hold the same addresses in the same order, so a
/// refresh that changed nothing doesn't reach the screen.
bool sameAddresses(List<LocalAddress> a, List<LocalAddress> b) =>
    a.length == b.length && Iterable.generate(a.length).every((i) => a[i] == b[i]);

/// Wi-Fi and Ethernet first, virtual adapters (WSL, Hyper-V, VPNs) last.
int _interfaceRank(String name) {
  final n = name.toLowerCase();
  if (n.contains('vethernet') ||
      n.contains('virtual') ||
      n.contains('vmware') ||
      n.contains('docker') ||
      n.contains('vpn') ||
      n.contains('tun') ||
      n.contains('tailscale')) {
    return 2;
  }
  if (n.contains('wi-fi') || n.contains('wifi') || n.contains('wlan') || n.contains('wireless')) return 0;
  if (n.contains('eth')) return 1;
  return 1;
}
