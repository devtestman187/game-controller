import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'crash_reporter.dart';
import 'sentry_reporter.dart';

/// The preferences key that holds this instance's answer to the crash
/// question: true (yes), false (no), or absent (not asked yet). The consent
/// notifier is the only writer (design sentry-consent.md).
const crashConsentKey = 'crashConsent';

/// The tag a Flutter framework error is reported with.
const _whereFlutterError = 'flutterError';

/// The tag an uncaught platform error is reported with.
const _wherePlatformError = 'platformError';

/// Makes Flutter's two global error handlers report through [CrashReports]
/// before they do what they did before (design sentry-consent.md): everything
/// that went wrong while nobody caught it then reaches Sentry exactly when
/// reports are on, and the app's old behaviour stays.
void installCrashHandlers() {
  final previousFlutterError = FlutterError.onError;
  final previousPlatformError = PlatformDispatcher.instance.onError;

  FlutterError.onError = (details) {
    CrashReports.capture(details.exception, details.stack, where: _whereFlutterError);
    previousFlutterError?.call(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    CrashReports.capture(error, stack, where: _wherePlatformError);
    return previousPlatformError?.call(error, stack) ?? false;
  };
}

/// Starts crash reporting for this app instance at startup (design
/// sentry-consent.md): makes [reporter] (or a [SentryCrashReporter] for this
/// build) the one [CrashReports] reports through, installs the error handlers,
/// and sends reports only when this instance said yes and [dsn] is not empty.
///
/// [prefs] holds the instance's answer, [release] and [environment] describe
/// the build, and the returned reporter is the one now in use.
Future<CrashReporter> startCrashReporting({
  required SharedPreferences prefs,
  required String dsn,
  required String release,
  required String environment,
  CrashReporter? reporter,
}) async {
  final chosen = reporter ?? SentryCrashReporter(dsn: dsn, release: release, environment: environment);
  CrashReports.use(chosen);
  installCrashHandlers();
  if (prefs.getBool(crashConsentKey) == true && dsn.isNotEmpty) {
    await chosen.enable();
  }
  return chosen;
}
