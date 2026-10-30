import 'package:shared_preferences/shared_preferences.dart';

/// Feedback for devices without vibration (PRD v2 C33): every iPad and many
/// Android tablets. Controls flash when pressed, and a click can play.
final class PressFeedbackSettings {
  const PressFeedbackSettings({this.flash, this.click = false});

  /// Flash each control as it's pressed. Null means automatic: on when the
  /// device has no haptics.
  final bool? flash;

  /// Play the system click on every press and new D-pad direction. It uses
  /// the system sound, so on Android it needs "Touch sounds" turned on.
  final bool click;

  /// Whether controls flash, given whether the device has haptics.
  bool flashes({required bool hasHaptics}) => flash ?? !hasHaptics;

  PressFeedbackSettings copyWith({bool? flash, bool? click}) =>
      PressFeedbackSettings(flash: flash ?? this.flash, click: click ?? this.click);

  static PressFeedbackSettings load(SharedPreferences prefs) =>
      PressFeedbackSettings(flash: prefs.getBool(_flashKey), click: prefs.getBool(_clickKey) ?? false);

  Future<void> save(SharedPreferences prefs) async {
    final f = flash;
    if (f == null) {
      await prefs.remove(_flashKey);
    } else {
      await prefs.setBool(_flashKey, f);
    }
    await prefs.setBool(_clickKey, click);
  }

  @override
  bool operator ==(Object other) => other is PressFeedbackSettings && other.flash == flash && other.click == click;

  @override
  int get hashCode => Object.hash(flash, click);
}

const _flashKey = 'pressFlash';
const _clickKey = 'pressClick';
