import 'package:toy_look/toy_look.dart';

/// How this device shows the look (M13, docs/design/look-and-sound.md D1 and
/// D8): which palette the Look setting picks, and whether the effects are on.
///
/// Both are this device's own: a joined phone on an older device turns its
/// effects off without changing anyone else's screen, and each device follows
/// its own clock.
final class LookSettings {
  const LookSettings({this.choice = LookChoice.auto, this.effects = true});

  /// The Look setting: Auto (by the device's local time), Sunny or Night.
  final LookChoice choice;

  /// The effects setting: the shaders and the menu motion, on this device
  /// only (D8). Off, every shape and colour is the same on the Canvas
  /// fallback.
  final bool effects;

  /// The same settings with the given ones changed.
  LookSettings copyWith({LookChoice? choice, bool? effects}) =>
      LookSettings(choice: choice ?? this.choice, effects: effects ?? this.effects);

  @override
  bool operator ==(Object other) => other is LookSettings && other.choice == choice && other.effects == effects;

  @override
  int get hashCode => Object.hash(choice, effects);
}
