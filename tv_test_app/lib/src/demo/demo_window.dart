import 'package:flutter/services.dart';

/// The Windows runner's demo-only window channel
/// (`tv_test_app/windows/runner/flutter_window.cpp`). Nothing else uses it, and
/// it does nothing on other platforms: tests and store builds never call it.
const _channel = MethodChannel('thumbparty/demo_window');

/// Makes the window fill the primary display with no border or title bar, for
/// the demo video (runbook 2.1). Returns false if the runner didn't do it, so
/// the caller can log that instead of pretending it worked.
Future<bool> demoFullScreen() async {
  try {
    return await _channel.invokeMethod<bool>('fullscreen') ?? false;
  } on MissingPluginException {
    return false; // Not the Windows demo runner (a test, another platform).
  } on PlatformException {
    return false; // The runner refused: check its console output.
  }
}
