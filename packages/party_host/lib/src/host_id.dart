import 'dart:async';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import 'crash/crash_reporter.dart';

/// The preferences key the host id is saved under.
const hostIdKey = 'hostId';

/// How many random bytes a new host id holds: 16, so the id is 32 hex
/// characters and two hosts almost never share one (M11).
const hostIdBytes = 16;

/// How many times the first run's host id write is tried (bugs15): a store
/// that is still busy at startup usually answers a moment later.
const hostIdWriteTries = 3;

/// How long the host waits between two tries of the host id write.
const hostIdRetryDelay = Duration(seconds: 1);

/// The tag a failed host id write is reported under (design
/// sentry-consent.md).
const hostIdWriteWhere = 'host_id_write';

/// How many values one byte of the id can take: [Random.nextInt] takes the
/// bound, so this is what turns one draw into one byte.
const _byteValues = 256;

/// The base the id's bytes are written in: hex, two digits a byte.
const _hexRadix = 16;

/// How [persistHostId] waits between two tries; tests pass one that returns
/// at once, so no test waits a real second.
typedef HostIdWait = Future<void> Function(Duration delay);

/// The id this host runs with (M11): the one saved in [prefs], or a fresh
/// random one that it starts saving at once, so the next launch keeps the
/// phones' saved pairings (bugs15).
///
/// It returns before the write finishes: the host runs with the id as today,
/// and [persistHostId] reports a write that keeps failing rather than holding
/// the host up. [random] makes a new id; the app passes `Random.secure()`.
String loadOrMakeHostId(SharedPreferences prefs, Random random, {HostIdWait wait = _waitOneRetry}) {
  final saved = prefs.getString(hostIdKey);
  if (saved != null) return saved;
  final id = _randomHex(random, hostIdBytes);
  // The constructor can't await, and a write that fails must not stop the
  // host: it reports, and the host runs with the id it has in memory (bugs15).
  unawaited(CrashReports.guard(persistHostId(prefs, id, wait: wait), where: hostIdWriteWhere));
  return id;
}

/// Saves [id] in [prefs] (bugs15), trying [hostIdWriteTries] times with
/// [hostIdRetryDelay] between tries: a false answer and a thrown error both
/// count as a failure, since either means the next launch mints a new id and
/// the phones' saved pairings stop matching.
///
/// After the last failure it reports the error once (design
/// sentry-consent.md) and returns: it never throws, so the host keeps running
/// with [id] in memory.
Future<void> persistHostId(SharedPreferences prefs, String id, {HostIdWait wait = _waitOneRetry}) async {
  Object? failure;
  StackTrace? failureStack;
  for (var tryNumber = 1; tryNumber <= hostIdWriteTries; tryNumber++) {
    try {
      if (await prefs.setString(hostIdKey, id)) return;
      failure = StateError('Saving the host id answered false');
      failureStack = null;
    } catch (error, stack) {
      // A thrown write is a failed try, not the end: the next one may work.
      failure = error;
      failureStack = stack;
    }
    if (tryNumber < hostIdWriteTries) await wait(hostIdRetryDelay);
  }
  if (failure != null) CrashReports.capture(failure, failureStack, where: hostIdWriteWhere);
}

Future<void> _waitOneRetry(Duration delay) => Future<void>.delayed(delay);

String _randomHex(Random random, int bytes) =>
    List.generate(bytes, (_) => random.nextInt(_byteValues).toRadixString(_hexRadix).padLeft(2, '0')).join();
