import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The host's preferences, which its settings are saved in. Overridden in each
/// app's `main()` with the loaded instance.
///
/// It lives in a file of its own so the settings kept on this device (the
/// look's, and since M13 the sound's) can be saved through the same prefs as the
/// host's own without the provider files importing each other in a circle.
final prefsProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('prefsProvider must be overridden'),
);
