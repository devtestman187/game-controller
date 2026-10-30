import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:connection/connection.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_info.dart';

/// Loads this phone's identity, creating a random controller ID on first run.
ControllerIdentity loadIdentity(SharedPreferences prefs, {bool isTablet = false}) {
  var id = prefs.getString(_controllerIdKey);
  if (id == null) {
    final r = Random.secure();
    id = List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
    prefs.setString(_controllerIdKey, id);
  }
  final (platform, base) = Platform.isIOS
      ? ('ios', isTablet ? 'iPad' : 'iPhone')
      : Platform.isAndroid
      ? ('android', isTablet ? 'Android tablet' : 'Android phone')
      : (Platform.operatingSystem, 'Controller');
  // The short suffix tells two phones of the same kind apart on the TV.
  return ControllerIdentity(
    controllerId: id,
    name: '$base ${id.substring(0, 4).toUpperCase()}',
    platform: platform,
    appVersion: appVersion,
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
