import 'dart:io';

import 'package:connection/connection.dart';

import 'discovery.dart';

enum LocalNetworkAccess { notNeeded, allowed, probablyDenied, unknown }

/// iOS's local network permission, as far as the app can tell. iOS has no
/// API to read it, so it's inferred from what discovery and connections do.
final class LocalNetworkStatus {
  const LocalNetworkStatus(this.access, this.explanation);

  final LocalNetworkAccess access;
  final String explanation;

  String get label => switch (access) {
    LocalNetworkAccess.notNeeded => 'Not needed',
    LocalNetworkAccess.allowed => 'Allowed',
    LocalNetworkAccess.probablyDenied => 'Probably denied',
    LocalNetworkAccess.unknown => 'Unknown',
  };
}

const _settingsPath = 'Settings → Privacy & Security → Local Network → Controller';

/// iOS reports EHOSTUNREACH (65, "No route to host") when the local network
/// permission blocks a connection.
const _noRouteToHost = 65;

LocalNetworkStatus localNetworkStatus({
  required bool isIOS,
  required DiscoveryState discovery,
  required ClientSnapshot client,
  required bool everConnected,
  DateTime? now,
}) {
  if (!isIOS) {
    return const LocalNetworkStatus(LocalNetworkAccess.notNeeded, 'Android doesn\'t ask for local network access.');
  }
  if (discovery.everFound || everConnected) {
    return const LocalNetworkStatus(
      LocalNetworkAccess.allowed,
      'A TV was found or connected, so local network access is on.',
    );
  }
  final target = client.target;
  if (client.osErrorCode == _noRouteToHost && target != null && target.addresses.any(_isLocal)) {
    return const LocalNetworkStatus(
      LocalNetworkAccess.probablyDenied,
      'Connecting failed with "No route to host", which iOS reports when local network access is off. '
      'Turn it on in $_settingsPath.',
    );
  }
  final started = discovery.startedAt;
  if (discovery.running && started != null && (now ?? DateTime.now()).difference(started).inSeconds >= 10) {
    return const LocalNetworkStatus(
      LocalNetworkAccess.unknown,
      'No TV found yet. If you tapped "Don\'t Allow" when iOS asked, turn it on in $_settingsPath. '
      'Otherwise check that the TV app is open and on the same Wi-Fi.',
    );
  }
  return const LocalNetworkStatus(
    LocalNetworkAccess.unknown,
    'iOS doesn\'t tell apps. This shows "Allowed" as soon as a TV is found.',
  );
}

bool _isLocal(String address) {
  final ip = InternetAddress.tryParse(address);
  if (ip == null) return address.endsWith('.local');
  if (ip.isLinkLocal) return true;
  if (ip.type == InternetAddressType.IPv4) {
    final b = ip.rawAddress;
    return b[0] == 10 || (b[0] == 172 && b[1] >= 16 && b[1] < 32) || (b[0] == 192 && b[1] == 168);
  }
  return (ip.rawAddress[0] & 0xfe) == 0xfc; // IPv6 unique local (fc00::/7).
}
