import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../crash/crash_reporter.dart';
import '../crash/crash_start.dart';
import '../prefs.dart';
import '../providers.dart';

/// The preferences key that holds this instance's answer to the stats
/// question. It is the key the host's LiveStats has always read, so an answer
/// given before M14 is this instance's answer (design sentry-consent.md).
const statsConsentKey = 'statsConsent';

/// This app instance's two consent answers (design sentry-consent.md): crash
/// reports and usage stats. Each is true (yes), false (no), or null (not asked
/// yet), and one device's answer never decides for another.
class InstanceConsent {
  /// An instance's answers; [crash] and [stats] are null until they are given.
  const InstanceConsent({this.crash, this.stats});

  /// The answer to the crash reports question, or null until it is asked.
  final bool? crash;

  /// The answer to the usage stats question, or null until it is asked.
  final bool? stats;

  /// These answers with the stats one given.
  InstanceConsent withStats(bool share) => InstanceConsent(crash: crash, stats: share);

  /// These answers with the crash reports one given.
  InstanceConsent withCrash(bool send) => InstanceConsent(crash: send, stats: stats);
}

/// Whether this build can send crash reports at all (design sentry-consent.md):
/// true only for an app build with a DSN, so the crash question is asked and a
/// crash row shown only where an answer can do something. False in dev, tests
/// and local builds; each app's `main()` overrides it with its own build.
final crashAvailableProvider = Provider<bool>((ref) => false);

/// The crash reporter this instance's answer turns on and off
/// (design sentry-consent.md): the one `startCrashReporting` made, which an
/// app's `main()` provides. It is the no-op reporter until then, so a build
/// with no reporter reports nothing whatever the answer.
final crashReporterProvider = Provider<CrashReporter>((ref) => const NoopCrashReporter());

/// This instance's consent answers, saved on the device (design
/// sentry-consent.md). It changes them whenever an answer is given.
final consentProvider = NotifierProvider<ConsentNotifier, InstanceConsent>(ConsentNotifier.new);

/// Keeps this instance's two answers and carries each one out as soon as it is
/// given: the stats one reaches the host's running stats, and the crash one
/// turns reports on or off live.
class ConsentNotifier extends Notifier<InstanceConsent> {
  @override
  InstanceConsent build() {
    final prefs = ref.watch(prefsProvider);
    return InstanceConsent(crash: prefs.getBool(crashConsentKey), stats: prefs.getBool(statsConsentKey));
  }

  /// Records the adult's answer about usage stats, and tells the host's stats
  /// when a host service is running: its LiveStats follows the answer at once,
  /// and the sessions it uploads from then on are as the answer says.
  Future<void> setStats(bool share) async {
    state = state.withStats(share);
    await ref.read(prefsProvider).setBool(statsConsentKey, share);
    if (ref.exists(hostServiceProvider)) ref.read(statsServiceProvider).setConsent(share);
  }

  /// Records the adult's answer about crash reports, and turns the reporter on
  /// or off at once: while it is off, nothing is reported (design
  /// sentry-consent.md).
  Future<void> setCrash(bool send) async {
    state = state.withCrash(send);
    await ref.read(prefsProvider).setBool(crashConsentKey, send);
    final reporter = ref.read(crashReporterProvider);
    if (send) {
      await reporter.enable();
    } else {
      await reporter.disable();
    }
  }
}
