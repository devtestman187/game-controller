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

  /// How long one step of the rules is, in seconds: 1/60 s (m12 §3). Fixed, so
  /// the same game plays the same on any host.
  double get simStepS => _simStepS;

  // 60 steps a second (m12 §3).
  static const _simStepS = 1 / 60;

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
