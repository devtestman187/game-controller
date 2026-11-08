import 'package:flutter/foundation.dart';

/// The host's frame rate a debug build may start with, in frames a second
/// (`--dart-define=FRAME_RATE_HZ=30`): 0 when the build didn't pass one. A
/// release build ignores it (m12 §6).
const int startFrameRateHz = int.fromEnvironment('FRAME_RATE_HZ', defaultValue: 0);

/// How a host runs a game (m12 §3): the step of its rules and how often it
/// sends frames to the controllers showing it. Range-checked like
/// `PuzzleSettings`: the values a settings screen may offer are in [ranges].
final class HostingSettings {
  const HostingSettings({this.frameRateHz = defaultFrameRateHz, this.maxPlayoutFrames = defaultMaxPlayoutFrames})
    : assert(
        frameRateHz >= minFrameRateHz && frameRateHz <= maxFrameRateHz,
        'frameRateHz must be $minFrameRateHz to $maxFrameRateHz',
      ),
      assert(
        maxPlayoutFrames >= minPlayoutFrameLimit && maxPlayoutFrames <= maxPlayoutFrameLimit,
        'maxPlayoutFrames must be $minPlayoutFrameLimit to $maxPlayoutFrameLimit',
      );

  /// The settings a game runs with when the caller passes none: this build's
  /// debug start option in a debug build ([startFrameRateHz]), the usual
  /// values otherwise. A release build can't be affected by the option.
  factory HostingSettings.fromEnvironment() =>
      kReleaseMode ? defaults : HostingSettings.fromFrameRate(startFrameRateHz);

  /// The settings for the debug start option's [hz]: 0 (no option) is
  /// [defaultFrameRateHz], and a rate the settings screen can't offer is
  /// refused loudly, so a typo in the option fails at once.
  factory HostingSettings.fromFrameRate(int hz) {
    if (hz == 0) return HostingSettings(frameRateHz: defaultFrameRateHz);
    if (hz < minFrameRateHz || hz > maxFrameRateHz) {
      throw ArgumentError.value(hz, 'hz', 'hz must be $minFrameRateHz to $maxFrameRateHz (or 0 for unset)');
    }
    return HostingSettings(frameRateHz: hz);
  }

  /// Steps a second the rules run (m12 §3): a frame goes out for every step of
  /// them a frame rate counts.
  static const simHz = 60;

  /// How long one step of the rules is, in seconds: 1/60 s (m12 §3). Fixed, so
  /// the same game plays the same on any host.
  double get simStepS => _simStepS;

  static const _simStepS = 1 / simHz;

  /// Frames a second the host publishes to viewers (m12 §3).
  final int frameRateHz;

  /// How many frames a phone may buffer before it draws (m12 §4).
  final int maxPlayoutFrames;

  static const defaultFrameRateHz = 60;
  static const minFrameRateHz = 20;
  static const maxFrameRateHz = 60;

  static const defaultMaxPlayoutFrames = 2;
  static const minPlayoutFrameLimit = 0;
  static const maxPlayoutFrameLimit = 4;

  static const defaults = HostingSettings();

  /// Each setting's range and step, for a settings screen.
  static const ranges = {'frameRateHz': (min: 20, max: 60, step: 10), 'maxPlayoutFrames': (min: 0, max: 4, step: 1)};
}
