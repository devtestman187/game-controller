import 'dart:math';

import 'package:protocol/protocol.dart';

import 'host_types.dart';
import 'saved_pairing.dart';

/// One pairing the host remembers: the controller's last hello, its token,
/// its last network address and the player number it had (internal to the
/// package, [PairingBook]'s entry).
final class KnownPairing {
  KnownPairing(this.hello, this.token, this.remoteAddress);

  final HelloMessage hello;
  final String token;
  final String remoteAddress;

  /// When this controller last connected or disconnected; the order saved
  /// pairings are kept in.
  DateTime lastSeen = DateTime.now();

  /// The player number it was given, kept reserved for a minute after it
  /// drops so a short Wi-Fi drop doesn't swap players.
  int? player;

  /// The row the host UI shows while this controller is away.
  ControllerInfo toInfo() => ControllerInfo(
    controllerId: hello.controllerId,
    name: hello.name,
    platform: hello.platform,
    appVersion: hello.appVersion,
    remoteAddress: remoteAddress,
    state: ControllerState.disconnected,
    since: lastSeen,
  );
}

/// Everything the host remembers about pairings (internal to the package):
/// the pairings themselves, the code on screen, the wrong codes in a row and
/// the player numbers the local players hold.
///
/// It holds no sessions, so the caller passes in what only it knows: the
/// controllers connected right now ([live]) and the numbers they hold
/// ([taken]).
final class PairingBook {
  PairingBook({
    required Random random,
    required this.maxSavedPairings,
    required this.maxWrongCodes,
    Iterable<SavedPairing> pairings = const [],
  }) : _random = random,
       _code = _codeFrom(random) {
    for (final p in pairings) {
      _known[p.controllerId] = KnownPairing(
        HelloMessage(controllerId: p.controllerId, name: p.name, platform: p.platform, appVersion: p.appVersion),
        p.token,
        p.remoteAddress,
      );
    }
  }

  /// Only the most recently seen pairings are kept.
  final int maxSavedPairings;

  /// After this many wrong codes in a row, the code changes.
  final int maxWrongCodes;

  final Random _random;
  final _known = <String, KnownPairing>{};
  final _localNumbers = <int>{};
  String _code;
  int _wrongCodes = 0;

  /// The code that pairs a new controller, as shown on the TV.
  String get code => _code;

  /// Wrong codes in a row since the last right one.
  int get wrongCodes => _wrongCodes;

  /// The pairing saved for [controllerId], or null when it isn't known.
  KnownPairing? known(String controllerId) => _known[controllerId];

  /// Every remembered pairing, oldest first.
  Iterable<KnownPairing> get all => _known.values;

  /// The saved pairings, most recently seen first.
  List<SavedPairing> get saved {
    // Newest first. The clock can give two pairings the same time (Windows'
    // clock is coarse), so a tie goes to the one added later.
    final entries = _known.entries.toList();
    final order = {for (final (i, e) in entries.indexed) e.key: i};
    final known = entries
      ..sort((a, b) {
        final byTime = b.value.lastSeen.compareTo(a.value.lastSeen);
        return byTime != 0 ? byTime : order[b.key]!.compareTo(order[a.key]!);
      });
    return [
      for (final MapEntry(key: id, value: k) in known)
        SavedPairing(
          controllerId: id,
          token: k.token,
          name: k.hello.name,
          platform: k.hello.platform,
          appVersion: k.hello.appVersion,
          remoteAddress: k.remoteAddress,
        ),
    ];
  }

  /// Shows a new code and starts the wrong-code count again. Controllers
  /// that are already paired stay paired. Returns the new code.
  String newCode() {
    _code = _codeFrom(_random, previous: _code);
    _wrongCodes = 0;
    return _code;
  }

  /// Starts counting wrong codes again, after a right one.
  void clearWrongCodes() => _wrongCodes = 0;

  /// Counts one wrong code. Returns true when that was [maxWrongCodes] in a
  /// row: the code has then changed and the count started again.
  bool countWrongCode() {
    _wrongCodes++;
    if (_wrongCodes < maxWrongCodes) return false;
    _wrongCodes = 0;
    _code = _codeFrom(_random, previous: _code);
    return true;
  }

  /// A new pairing token for a controller.
  String newToken() => List.generate(16, (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();

  /// Saves [hello]'s pairing as the newest one and forgets the oldest if
  /// there are too many ([live] are the controllers connected right now,
  /// which are never forgotten). Returns true when this is a new pairing or
  /// one whose token or name changed, so the app has something new to save.
  bool remember(
    HelloMessage hello,
    String token, {
    required String remoteAddress,
    required int player,
    required Set<String> live,
  }) {
    final previous = _known[hello.controllerId];
    _known[hello.controllerId] = KnownPairing(hello, token, remoteAddress)..player = player;
    _trim(live);
    return previous == null || previous.token != token || previous.hello.name != hello.name;
  }

  /// Notes that [controllerId]'s connection ended just now, so its player
  /// number stays reserved for a minute.
  void markSeen(String controllerId) {
    final k = _known[controllerId];
    if (k != null) k.lastSeen = DateTime.now();
  }

  /// Forgets every pairing whose controller isn't in [live], so those
  /// phones need the code again. Returns how many were forgotten.
  int forgetDisconnected(Set<String> live) {
    final gone = _known.keys.where((id) => !live.contains(id)).toList();
    for (final id in gone) {
      _known.remove(id);
    }
    return gone.length;
  }

  /// The controller's number from before if it's still free, otherwise the
  /// lowest free one. [taken] are the numbers of the live paired sessions;
  /// the numbers local players hold are counted as well.
  int pickPlayer(int? previous, {required Set<int> taken}) {
    final used = {...taken, ..._localNumbers};
    final cutoff = DateTime.now().subtract(const Duration(minutes: 1));
    final reserved = {
      for (final k in _known.values)
        if (k.player != null && k.lastSeen.isAfter(cutoff) && !used.contains(k.player)) k.player!,
    };
    if (previous != null && !used.contains(previous)) return previous;
    var n = 1;
    while (used.contains(n) || reserved.contains(n)) {
      n++;
    }
    return n;
  }

  /// Takes the lowest free player number for a local player and keeps it.
  int reserveLocalPlayer({required Set<int> taken}) {
    final n = pickPlayer(null, taken: taken);
    _localNumbers.add(n);
    return n;
  }

  /// Frees [number] after a local player left. Returns true when it was
  /// taken, so the caller knows whether anything changed.
  bool releaseLocalPlayer(int number) => _localNumbers.remove(number);

  void _trim(Set<String> live) {
    if (_known.length <= maxSavedPairings) return;
    final oldest = _known.entries.where((e) => !live.contains(e.key)).toList()
      ..sort((a, b) => a.value.lastSeen.compareTo(b.value.lastSeen));
    for (final e in oldest.take(_known.length - maxSavedPairings)) {
      _known.remove(e.key);
    }
  }
}

/// A four-digit code, different from [previous] so a wrong guess never shows
/// the same code again.
String _codeFrom(Random random, {String? previous}) {
  String code;
  do {
    code = random.nextInt(10000).toString().padLeft(4, '0');
  } while (code == previous);
  return code;
}
