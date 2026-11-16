import '../crash/crash_reporter.dart';

/// One report a [FakeCrashReporter] was given.
class RecordedCrash {
  /// A report of [error] with [stack], from [where].
  const RecordedCrash(this.error, this.stack, this.where);

  /// The error that was reported.
  final Object error;

  /// The stack that came with it, if any.
  final StackTrace? stack;

  /// The tag that names where the error came from, if any.
  final String? where;
}

/// A crash reporter for tests: it records every report it is handed while
/// reports are on, and the test turns it on and off to check what the app
/// reports while each (design sentry-consent.md).
///
/// Like `SentryCrashReporter`, it drops a report handed over while off, so a
/// test that sees nothing recorded also covers a missing enabled check at
/// this boundary.
class FakeCrashReporter implements CrashReporter {
  /// Every report this reporter took, in order: only those handed over while
  /// it was on.
  final captures = <RecordedCrash>[];

  /// How many times the app turned reports on.
  int enableCount = 0;

  /// How many times the app turned reports off.
  int disableCount = 0;

  bool _isEnabled = false;

  @override
  bool get enabled => _isEnabled;

  @override
  Future<void> enable() async {
    enableCount++;
    _isEnabled = true;
  }

  @override
  Future<void> disable() async {
    disableCount++;
    _isEnabled = false;
  }

  @override
  void capture(Object error, StackTrace? stack, {String? where}) {
    if (!_isEnabled) return;
    captures.add(RecordedCrash(error, stack, where));
  }
}
