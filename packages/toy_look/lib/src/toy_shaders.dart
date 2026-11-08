import 'dart:ui' show FragmentProgram;

/// The look's fragment programs (M13, docs/design/look-and-sound.md section
/// 6), loaded once at start and kept.
///
/// A device whose driver can't load or run a shader keeps the Canvas
/// fallback, so no screen has to check anything: [shade] is simply null and
/// [error] says what went wrong, for the TV's spike screen to show.
final class ToyShaders {
  const ToyShaders._({this.shade, this.error, this.loadMs = 0});

  /// The asset key of [shade]: the shader as the build ships it, under the
  /// package's own name.
  static const shadeAsset = 'packages/toy_look/shaders/toy_shade.frag';

  /// No shaders at all: what "effects off" and a device without shaders use.
  static const none = ToyShaders._();

  /// The shader that paints a game object's body, or null when it couldn't
  /// be loaded ([error] says why).
  final FragmentProgram? shade;

  /// Why [shade] is null, in words for a test screen; null when it loaded.
  final String? error;

  /// How long the load took, in milliseconds, as the spike reports it.
  final int loadMs;

  /// Loads [shade] and times it. Never throws: a shader that is missing, or
  /// that the driver refuses, comes back as [error] with no [shade], which is
  /// the same state as [none].
  ///
  /// [asset] is there for a test that asks for a key that isn't there.
  static Future<ToyShaders> load({String asset = shadeAsset}) async {
    final watch = Stopwatch()..start();
    try {
      final program = await FragmentProgram.fromAsset(asset);
      return ToyShaders._(shade: program, loadMs: watch.elapsedMilliseconds);
    } catch (e) {
      // The documented boundary: the engine's shader loader, which can refuse
      // a shader on any device for reasons Dart can't inspect. The caller gets
      // a state it handles, not an exception.
      return ToyShaders._(
        error: e.toString(),
        loadMs: watch.elapsedMilliseconds,
      );
    }
  }
}
