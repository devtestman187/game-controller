import 'dart:io';

import 'package:protocol/protocol.dart';

/// Where a host can be reached: one or more IP addresses (or hostnames) and a
/// port. Discovery fills in [hostId] and [name]; manual entry doesn't.
///
/// [HostAddress.local] is the exception: it names the host phone's own player
/// (D1), which is reached in this process and has no address at all.
final class HostAddress {
  HostAddress({required List<String> addresses, required int port, String? hostId, String? name})
    : this._(addresses: addresses, port: port, hostId: hostId, name: name, isLocal: false);

  /// The target for the host phone's own player (D1). Its two ends run in one
  /// process, so there is no address and no port: [display] and [label] are
  /// the host's [name].
  factory HostAddress.local({required String hostId, required String name}) =>
      HostAddress._(addresses: const [], port: 0, hostId: hostId, name: name, isLocal: true);

  HostAddress._({required List<String> addresses, required this.port, this.hostId, this.name, required this.isLocal})
    : addresses = List.unmodifiable(addresses) {
    if (addresses.isEmpty && !isLocal) throw ArgumentError.value(addresses, 'addresses', 'must not be empty');
  }

  /// Parses what the user typed: `192.168.1.50`, `192.168.1.50:45780`,
  /// `[fe80::1]:45780`, `fe80::1` or a hostname like `tv.local`.
  ///
  /// Throws [FormatException] with a message that can be shown to the user.
  factory HostAddress.parse(String input) {
    var text = input.trim();
    for (final prefix in ['ws://', 'http://']) {
      if (text.toLowerCase().startsWith(prefix)) text = text.substring(prefix.length);
    }
    if (text.endsWith('/')) text = text.substring(0, text.length - 1);
    if (text.isEmpty) throw const FormatException('Enter the address shown on the TV');
    if (text.contains(RegExp(r'\s'))) throw const FormatException('The address can\'t contain spaces');

    String host;
    String? portText;
    if (text.startsWith('[')) {
      final end = text.indexOf(']');
      if (end < 0) throw const FormatException('Missing "]" in the IPv6 address');
      host = text.substring(1, end);
      final rest = text.substring(end + 1);
      if (rest.isNotEmpty) {
        if (!rest.startsWith(':')) throw const FormatException('Expected ":port" after "]"');
        portText = rest.substring(1);
      }
    } else if (':'.allMatches(text).length == 1) {
      final i = text.indexOf(':');
      host = text.substring(0, i);
      portText = text.substring(i + 1);
    } else {
      host = text; // No port, or a bare IPv6 address.
    }
    if (host.isEmpty) throw const FormatException('Enter the address shown on the TV');

    var port = defaultPort;
    if (portText != null) {
      final parsed = int.tryParse(portText);
      if (parsed == null || parsed < 1 || parsed > 65535) {
        throw FormatException('"$portText" is not a valid port (1-65535)');
      }
      port = parsed;
    }
    return HostAddress(addresses: [host], port: port);
  }

  /// Reads a saved address. `isLocal` is written only for [HostAddress.local],
  /// so JSON saved before it existed decodes as a network address.
  factory HostAddress.fromJson(Map<String, Object?> json) {
    if (json['isLocal'] == true) {
      final hostId = json['hostId'];
      final name = json['name'];
      if (hostId is! String) throw const FormatException('A local address needs a "hostId"');
      if (name is! String) throw const FormatException('A local address needs a "name"');
      return HostAddress.local(hostId: hostId, name: name);
    }
    return HostAddress(
      addresses: (json['addresses'] as List).cast<String>(),
      port: json['port'] as int,
      hostId: json['hostId'] as String?,
      name: json['name'] as String?,
    );
  }

  final List<String> addresses;
  final int port;

  /// The host's stable ID, from the mDNS TXT record or the welcome message.
  final String? hostId;

  /// The advertised name, e.g. `Thumb Party TV (Android TV)`. Always known
  /// for a local address, where it is also the display text.
  final String? name;

  /// True for [HostAddress.local]: the peer is the host phone's own player
  /// (D1), in this process. Such an address has no [addresses] and port 0.
  final bool isLocal;

  /// The address to show the user, e.g. `192.168.1.50:45780`; for a local
  /// address, its [name].
  String get display {
    final name = this.name;
    if (isLocal && name != null) return name;
    return '${_hostForDisplay(ordered.first)}:$port';
  }

  /// [name] if known, otherwise [display].
  String get label => name ?? display;

  /// Addresses in the order to try: IPv4 first (most reliable on home
  /// networks), then hostnames and global IPv6, then link-local IPv6.
  List<String> get ordered {
    int rank(String a) {
      final ip = InternetAddress.tryParse(a);
      if (ip == null) return 1;
      if (ip.type == InternetAddressType.IPv4) return 0;
      return ip.isLinkLocal ? 3 : 2;
    }

    final list = [...addresses];
    // List.sort isn't stable, so break ties by the original position.
    final index = {for (var i = 0; i < addresses.length; i++) addresses[i]: i};
    list.sort((a, b) {
      final r = rank(a).compareTo(rank(b));
      return r != 0 ? r : index[a]!.compareTo(index[b]!);
    });
    return list;
  }

  Uri uriFor(String address) => Uri(scheme: 'ws', host: address, port: port, path: webSocketPath);

  /// True when both refer to the same host by ID (addresses may differ, for
  /// example after the TV got a new IP address).
  bool sameHostAs(HostAddress other) => hostId != null && hostId == other.hostId;

  HostAddress copyWith({List<String>? addresses, int? port, String? hostId, String? name}) => HostAddress._(
    addresses: addresses ?? this.addresses,
    port: port ?? this.port,
    hostId: hostId ?? this.hostId,
    name: name ?? this.name,
    isLocal: isLocal,
  );

  Map<String, Object?> toJson() => {
    'addresses': addresses,
    'port': port,
    'hostId': ?hostId,
    'name': ?name,
    if (isLocal) 'isLocal': true,
  };

  @override
  bool operator ==(Object other) =>
      other is HostAddress &&
      other.port == port &&
      other.hostId == hostId &&
      other.name == name &&
      other.isLocal == isLocal &&
      other.addresses.length == addresses.length &&
      Iterable.generate(addresses.length).every((i) => other.addresses[i] == addresses[i]);

  @override
  int get hashCode => Object.hash(Object.hashAll(addresses), port, hostId, name, isLocal);

  @override
  String toString() => isLocal
      ? 'HostAddress.local(${name ?? '-'}, id ${hostId ?? '-'})'
      : 'HostAddress(${name ?? '-'}, ${addresses.join(' ')}, port $port, id ${hostId ?? '-'})';
}

String _hostForDisplay(String address) => address.contains(':') ? '[$address]' : address;

/// Shows IPv4-mapped IPv6 addresses (`::ffff:192.168.1.5`) as plain IPv4.
String displayIp(String address) =>
    address.startsWith('::ffff:') && address.contains('.') ? address.substring(7) : address;
