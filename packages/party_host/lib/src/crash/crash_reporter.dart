import 'dart:async';

/// A crash reporter a host app starts once its crash answer is known (design
/// sentry-consent.md): [enable] sends reports from then on, [disable] stops
/// them live, and [capture] hands one error over.
abstract interface class CrashReporter {
  /// Starts sending reports. Does nothing when they are already on.
  Future<void> enable();

  /// Stops sending reports. Does nothing when they are already off.
  Future<void> disable();

  /// Whether reports are being sent now.
  bool get enabled;

  /// Hands one error over as a report; [where] names the place it came from,
  /// and [stack] is the stack to send with it.
  void capture(Object error, StackTrace? stack, {String? where});
}

/// The reporter an app has before it has a real one: it sends nothing.
class NoopCrashReporter implements CrashReporter {
  /// The one no-op reporter there is.
  const NoopCrashReporter();

  @override
  bool get enabled => false;

  @override
  Future<void> enable() async {}

  @override
  Future<void> disable() async {}

  @override
  void capture(Object error, StackTrace? stack, {String? where}) {}
}

/// The reporter the app's own code calls (design sentry-consent.md): the app
/// sets it once at startup with [use], and everything else reports through
/// [capture] and [guard] without knowing which reporter it is.
///
/// Player names that must never reach a report are kept here with
/// [playerNames], so the reporter can strip them.
abstract final class CrashReports {
  static CrashReporter _reporter = const NoopCrashReporter();
  static Set<String> _playerNames = const {};

  /// The names the players of this instance are using, which a report must
  /// never carry.
  static Set<String> get playerNames => _playerNames;

  /// Replaces the names to strip; called when the lobby's players change.
  static set playerNames(Set<String> names) {
    _playerNames = Set.unmodifiable(names);
  }

  /// Makes [reporter] the one every report goes to. Called once at startup.
  static void use(CrashReporter reporter) {
    _reporter = reporter;
  }

  /// Reports [error] with [stack] when reports are on, and does nothing when
  /// they are off. [where] names the place it came from.
  ///
  /// Never throws: a report that fails must not raise a second error in the
  /// code it was watching.
  static void capture(Object error, StackTrace? stack, {String? where}) {
    try {
      if (!_reporter.enabled) return;
      _reporter.capture(error, stack, where: where);
    } on Object {
      // Reporting is best effort (design sentry-consent.md): a reporter that
      // fails must leave the caller running as if it had reported.
    }
  }

  /// Watches [future] and reports the error it fails with once, when reports
  /// are on; the returned future never fails, so a fire-and-forget call can be
  /// awaited or not. [where] names the place it came from.
  static Future<void> guard(Future<void> future, {String? where}) async {
    try {
      await future;
    } catch (error, stack) {
      capture(error, stack, where: where);
    }
  }
}
