import 'package:shared_preferences/shared_preferences.dart';

/// How the controls look over a game on this phone (m12 §2.7, PRD v2 C28),
/// saved between launches like the stick settings.
final class ControlsSettings {
  const ControlsSettings({this.opacity = defaultOpacity});

  /// How opaque the controls are over a game until the player changes it.
  static const double defaultOpacity = 0.6;

  /// The faintest the controls go: below this the game hides them.
  static const double minOpacity = 0.2;

  /// Fully opaque: the controls as they are in controller mode.
  static const double maxOpacity = 1.0;

  /// 0.2 to 1: how opaque the controls are while a game shows behind them.
  /// Sizes and touch areas don't change with it (C14 to C16).
  final double opacity;

  ControlsSettings copyWith({double? opacity}) => ControlsSettings(opacity: opacity ?? this.opacity);

  static ControlsSettings load(SharedPreferences prefs) =>
      ControlsSettings(opacity: (prefs.getDouble('controlsOpacity') ?? defaultOpacity).clamp(minOpacity, maxOpacity));

  Future<void> save(SharedPreferences prefs) async {
    await prefs.setDouble('controlsOpacity', opacity);
  }
}
