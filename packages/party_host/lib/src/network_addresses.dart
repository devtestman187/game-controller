import 'dart:io';

import 'host_view_state.dart';

/// What one read of this device's interfaces found: the addresses to show, in
/// the order the host chip and the pairing panel use ([shown]), and the ones
/// no phone on this network can reach ([dropped]), kept for the log.
typedef AddressScan = ({List<LocalAddress> shown, List<LocalAddress> dropped});

/// This device's IPv4 addresses, to show for manual entry on a phone
/// (PRD T6), Wi-Fi first, wired or hotspot next, virtual adapters (WSL,
/// Hyper-V, VPNs) last, and cellular addresses left out (bug 1107b).
///
/// Split from the host service because it reads the network interfaces; the
/// caller logs a failure (a laptop with no network still hosts by address
/// once Wi-Fi returns, so it keeps the list fresh).
Future<AddressScan> networkAddresses() async {
  final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
  final all = [
    for (final i in interfaces)
      for (final a in i.addresses)
        if (!a.isLoopback && !a.isLinkLocal) LocalAddress(a.address, i.name),
  ];
  return (
    shown: orderedAddresses(all),
    dropped: [
      for (final a in all)
        if (_interfaceRank(a.interfaceName) == _cellularRank) a,
    ],
  );
}

/// The addresses to show, in order, without the cellular ones (bug 1107b).
///
/// The order is by rank: Wi-Fi (0), wired or hotspot (1), virtual, VPN or
/// peer-to-peer (2). Inside a rank the input order stays, because the OS's
/// order is the only tie-break left between two interfaces of the same kind:
/// Dart's `List.sort` isn't stable, so the index is compared too.
List<LocalAddress> orderedAddresses(Iterable<LocalAddress> addresses) {
  final kept = [
    for (final (i, a) in addresses.indexed)
      if (_interfaceRank(a.interfaceName) != _cellularRank) (i, a),
  ];
  kept.sort((a, b) {
    final byRank = _interfaceRank(a.$2.interfaceName).compareTo(_interfaceRank(b.$2.interfaceName));
    return byRank != 0 ? byRank : a.$1.compareTo(b.$1);
  });
  return [for (final (_, a) in kept) a];
}

/// True when [a] and [b] hold the same addresses in the same order, so a
/// refresh that changed nothing doesn't reach the screen.
bool sameAddresses(List<LocalAddress> a, List<LocalAddress> b) =>
    a.length == b.length && Iterable.generate(a.length).every((i) => a[i] == b[i]);

/// The ranks [orderedAddresses] sorts by: Wi-Fi first, then a wired or
/// hotspot interface, then virtual, VPN or peer-to-peer; [_cellularRank] is
/// not a rank but the mark that the address is dropped (bug 1107b): a phone
/// on the same Wi-Fi can't reach a carrier's address, so it is left out
/// rather than sorted last.
const _wiFiRank = 0;
const _wiredRank = 1;
const _virtualRank = 2;
const _cellularRank = 3;

/// The names an interface gets per platform, lowercased before matching
/// (bug 1107b). iOS: `en0` is the Wi-Fi one and `pdp_ip0` the cellular one;
/// Android: `wlan0`, `rmnet_data0`, `ccmni0`; Windows: "Wi-Fi", "Ethernet",
/// "vEthernet (WSL)", "Tailscale". A wired interface ("Ethernet", `eth0`,
/// `bridge100`) needs no entry: it ranks with everything else.
const _wiFiNames = ['wi-fi', 'wifi', 'wlan', 'wireless'];
const _virtualNames = [
  'vethernet',
  'virtual',
  'vmware',
  'docker',
  'vpn',
  'tun',
  'tailscale',
  'ipsec',
  'wg',
  'p2p',
  'awdl',
  'llw',
  'anpi',
];
const _cellularNames = ['pdp_ip', 'rmnet', 'ccmni', 'wwan', 'cellular'];

/// Wi-Fi first, wired or hotspot next, virtual adapters (WSL, Hyper-V, VPNs,
/// peer-to-peer) last, and [_cellularRank] for an address that is dropped.
///
/// The names are the only source Dart offers, so the phone platforms' names
/// are ranked here too. Before bug 1107b only Windows names matched, so an
/// iPhone's `en0` and `pdp_ip0` both fell through to rank 1, kept the OS's
/// order, and the chip showed the carrier address.
int _interfaceRank(String name) {
  final n = name.toLowerCase();
  if (_cellularNames.any(n.contains)) return _cellularRank;
  if (_virtualNames.any(n.contains)) return _virtualRank;
  // `en0` exactly: on an iPhone and a Mac it is the Wi-Fi interface, while
  // `en1`, `en2` and the rest are other ones.
  if (_wiFiNames.any(n.contains) || n == 'en0') return _wiFiRank;
  return _wiredRank;
}
