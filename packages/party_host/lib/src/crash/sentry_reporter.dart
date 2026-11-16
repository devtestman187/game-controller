import 'dart:async';

import 'package:sentry_flutter/sentry_flutter.dart';

import 'crash_reporter.dart';
import 'scrub.dart';

/// The real reporter (design sentry-consent.md): Sentry, started only when the
/// instance answered yes to crash reports and its build has a DSN.
///
/// Reports carry the release and the environment, never the user or an IP, and
/// pass through [scrubEvent] on the way out so no player name is sent.
class SentryCrashReporter implements CrashReporter {
  /// [dsn] comes from the app's build (`--dart-define`); an empty one means
  /// the build has no Sentry project and [enable] does nothing.
  SentryCrashReporter({required this.dsn, required this.release, required this.environment});

  /// The Sentry project's address; never a secret in the repo.
  final String dsn;

  /// The app version the report belongs to.
  final String release;

  /// `debug` or `production`, as the app's build decides.
  final String environment;

  bool _isEnabled = false;

  @override
  bool get enabled => _isEnabled;

  @override
  Future<void> enable() async {
    if (dsn.isEmpty || _isEnabled) return;
    await SentryFlutter.init((options) {
      options
        ..dsn = dsn
        ..release = release
        ..environment = environment
        // No personal data, no pictures of the screen, no tracing: a report
        // says what went wrong, not who was playing (design sentry-consent.md).
        ..sendDefaultPii = false
        ..attachScreenshot = false
        ..attachViewHierarchy = false
        ..enableUserInteractionBreadcrumbs = false
        ..tracesSampleRate = null
        ..beforeSend = _scrubBeforeSend
        ..beforeBreadcrumb = _scrubBeforeBreadcrumb;
    });
    _isEnabled = true;
  }

  @override
  Future<void> disable() async {
    if (!_isEnabled) return;
    await Sentry.close();
    _isEnabled = false;
  }

  @override
  void capture(Object error, StackTrace? stack, {String? where}) {
    if (!_isEnabled) return;
    unawaited(
      Sentry.captureException(
        error,
        stackTrace: stack,
        withScope: (scope) async {
          if (where case final tag?) await scope.setTag('where', tag);
        },
      ),
    );
  }
}

/// Scrubs a report just before it leaves the device. A report that cannot be
/// scrubbed is dropped rather than sent as it is.
SentryEvent? _scrubBeforeSend(SentryEvent event, Hint hint) {
  try {
    return SentryEvent.fromJson(scrubEvent(event.toJson(), CrashReports.playerNames));
  } on Object {
    return null;
  }
}

/// Scrubs one breadcrumb just before it is kept, and drops it when that fails.
Breadcrumb? _scrubBeforeBreadcrumb(Breadcrumb? breadcrumb, Hint hint) {
  if (breadcrumb == null) return null;
  try {
    return Breadcrumb.fromJson(scrubEvent(breadcrumb.toJson(), CrashReports.playerNames));
  } on Object {
    return null;
  }
}
