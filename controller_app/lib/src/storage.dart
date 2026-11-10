import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' show Size;

import 'package:connection/connection.dart';
import 'package:protocol/protocol.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_info.dart';
import 'profile.dart';

/// Loads this phone's identity, creating a random controller ID on first run.
/// [screenMm] is the physical screen size, for analytics (M9). The model and
/// OS version are added once the native side has answered
/// ([withDeviceDetails]).
///
/// The hello's name is the player's saved [profile] nickname, or the phone's
/// own "Phone 1A2B" when they saved none (M14 N13), and its `character` is
/// their saved choice (design section 9).
ControllerIdentity loadIdentity(
  SharedPreferences prefs, {
  bool isTablet = false,
  Size? screenMm,
  ControllerProfile? profile,
}) {
  var id = prefs.getString(_controllerIdKey);
  if (id == null) {
    final r = Random.secure();
    id = List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
    prefs.setString(_controllerIdKey, id);
  }
  final platform = Platform.isIOS
      ? 'ios'
      : Platform.isAndroid
      ? 'android'
      : Platform.operatingSystem;
  final saved = profile ?? ControllerProfile.load(prefs);
  // The short suffix tells two phones of the same kind apart on the TV, and
  // the phone's own name is "Phone 1A2B" (M14 N13): ten characters, so the
  // host's game roster keeps it whole.
  // Every phone lists `view`: it can show the game its host sends it (m12
  // §0.1). The host's own player takes it out again in `host/hosting.dart`.
  return ControllerIdentity(
    controllerId: id,
    name: phoneName(nickname: saved.nickname, controllerId: id),
    character: saved.character,
    platform: platform,
    appVersion: appVersion,
    capabilities: const [Capability.metrics, Capability.rating, Capability.layout, Capability.status, Capability.view],
    device: DeviceInfo(
      kind: isTablet ? DeviceInfo.tablet : DeviceInfo.phone,
      // Landscape: the long side is the width.
      widthMm: screenMm?.longestSide.round(),
      heightMm: screenMm?.shortestSide.round(),
    ),
  );
}

/// The identity with the model, OS version and haptics added, once known.
ControllerIdentity withDeviceDetails(ControllerIdentity identity, {String? model, String? os, bool? haptics}) {
  final d = identity.device ?? const DeviceInfo(kind: DeviceInfo.phone);
  return identity.copyWith(
    device: DeviceInfo(
      kind: d.kind,
      model: model ?? d.model,
      os: os ?? d.os,
      widthMm: d.widthMm,
      heightMm: d.heightMm,
      haptics: haptics ?? d.haptics,
    ),
  );
}

/// Saved pairings (so reconnects and relaunches need no code) and the last
/// TV, which the app reconnects to on launch.
class ConnectionStore {
  ConnectionStore(this._prefs);

  final SharedPreferences _prefs;

  Map<String, String> get tokens {
    final raw = _prefs.getString(_tokensKey);
    if (raw == null) return {};
    try {
      return (jsonDecode(raw) as Map).cast<String, String>();
    } catch (_) {
      return {};
    }
  }

  void setToken(String hostId, String? token) {
    final all = tokens;
    if (token == null) {
      all.remove(hostId);
    } else {
      all[hostId] = token;
    }
    _prefs.setString(_tokensKey, jsonEncode(all));
  }

  HostAddress? get lastHost {
    final raw = _prefs.getString(_lastHostKey);
    if (raw == null) return null;
    try {
      return HostAddress.fromJson((jsonDecode(raw) as Map).cast<String, Object?>());
    } catch (_) {
      return null;
    }
  }

  set lastHost(HostAddress? host) {
    if (host == null) {
      _prefs.remove(_lastHostKey);
    } else {
      _prefs.setString(_lastHostKey, jsonEncode(host.toJson()));
    }
  }
}

const _controllerIdKey = 'controllerId';
const _tokensKey = 'pairingTokens';
const _lastHostKey = 'lastHost';
