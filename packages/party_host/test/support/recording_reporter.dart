import 'package:party_host/party_host.dart';
import 'package:party_host/testing.dart';

/// A crash reporter for tests that keeps every report it is handed, even
/// while reports are off: unlike [FakeCrashReporter], which drops them like
/// the real one, it shows that `CrashReports.capture` has its own enabled
/// check, so removing that check fails a test instead of passing it (the run's
/// review).
class RecordingReporter implements CrashReporter {
  /// Every report this reporter was handed, in order, whatever its state.
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
  void capture(Object error, StackTrace? stack, {String? where}) => captures.add(RecordedCrash(error, stack, where));
}
