import 'dart:io';

import 'stream_names.dart';
import 'stream_sampler_readings.dart';

/// The latency tracer's records of one sampling window, sorted into the
/// pipeline's stages (M15 c2). The tracer says how long each buffer spent in
/// each element; a window's mean per element is one sample of the stage that
/// element does, and the encoder's records give the encoded frame rate.
///
/// What each stage does and does not include is written down in
/// docs/protocol.md §13: the tracer times an element's own work, not a frame
/// from the game's draw to the encoder's output, and it writes no record for
/// the source or the sink (a source has no sink pad and a sink no src pad), so
/// [pipelineMs] carries the whole host path the stage sums can't.
final class PipelineWindow {
  /// [encoderPrefix] is the encoder element's name without its instance number
  /// (`nvautogpuh264enc` for `nvautogpuh264enc0`), so the encode stage follows
  /// the encoder the session was started with; [sinkName] is the name the
  /// pipeline gave `webrtcsink` (`ws` in the session image);
  /// [captureElements] are the elements the captured frame passes before the
  /// encoder (the session image's caps filter and converter).
  PipelineWindow({
    required this.encoderPrefix,
    this.captureElements = _defaultCaptureElements,
    this.sinkName = _defaultSinkName,
  });

  /// The encoder's element name, without the number GStreamer appends.
  final String encoderPrefix;

  /// The elements between the captured frame and the encoder's input, by the
  /// names the session image's pipeline gives them.
  final Set<String> captureElements;

  /// The `webrtcsink` element's name, as the pipeline named it.
  final String sinkName;

  final _byStage = <String, List<double>>{};
  final _pipelineMs = <double>[];
  var _encoded = 0;
  double? _firstEncodedMs;

  /// The stage [element] does, or null for an element that isn't one of the
  /// pipeline's own (the sound path, a queue, the app sinks inside
  /// `webrtcsink`).
  String? stageOf(String element) {
    if (captureElements.contains(element)) return StreamStage.capture;
    if (element.startsWith(encoderPrefix)) return StreamStage.encode;
    if (element == sinkName || element.startsWith(_sinkElement)) return StreamStage.send;
    return null;
  }

  /// Takes one pipeline record: the video branch's, from the capture plugin to
  /// `webrtcsink`, is the host's whole path; the other branches (sound, the
  /// preview's app sink) are left out.
  void addPipeline(PipelineRecord record) {
    if (!record.srcElement.startsWith(_captureElement) || record.sinkElement != sinkName) return;
    _pipelineMs.add(record.ms);
  }

  /// The mean time a frame took from the capture plugin's output to
  /// `webrtcsink`'s input in this window, in ms, or null when the tracer wrote
  /// no pipeline record.
  double? get pipelineMs => _pipelineMs.isEmpty ? null : _pipelineMs.reduce((a, b) => a + b) / _pipelineMs.length;

  /// Takes one tracer record; a record of an element outside the pipeline's
  /// stages is ignored.
  void add(TracerRecord record) {
    final stage = stageOf(record.element);
    if (stage == null) return;
    (_byStage[stage] ??= []).add(record.ms);
    if (stage != StreamStage.encode) return;
    _encoded++;
    _firstEncodedMs ??= record.pipelineMs;
  }

  /// One sample a stage: the mean time a frame spent there in this window, in
  /// whole ms. A stage with no record is left out.
  Map<String, int> stages() => {
    for (final MapEntry(key: stage, value: times) in _byStage.entries)
      if (times.isNotEmpty) stage: (times.reduce((a, b) => a + b) / times.length).round(),
  };

  /// The frames the encoder produced in [seconds], or null when it produced
  /// none.
  double? encodedFps(double seconds) => _encoded == 0 || seconds <= 0 ? null : _encoded / seconds;

  /// Time from the pipeline starting to its first encoded frame, in ms: the
  /// tracer's own stamp of that frame. This is the pipeline's start, which the
  /// entrypoint logs at the same moment as the session's.
  double? get firstEncodedMs => _firstEncodedMs;

  /// Forgets the window's records, so the next one starts empty.
  void clear() {
    _byStage.clear();
    _pipelineMs.clear();
    _encoded = 0;
  }

  /// The element that draws the virtual screen the game is captured from.
  static const _captureElement = 'waylanddisplaysrc';

  /// The element that puts the encoded frames on the wire, by its factory
  /// name when the pipeline didn't name the instance.
  static const _sinkElement = 'webrtcsink';

  /// The name the session image's pipeline gives `webrtcsink`.
  static const _defaultSinkName = 'ws';

  /// The session image's elements between the capture and the encoder:
  /// `build_pipeline` in streaming/entrypoint.sh writes the caps filter first
  /// and the converter after it, and GStreamer numbers them from zero.
  static const _defaultCaptureElements = {'capsfilter0', 'videoconvert0'};
}

/// The container's own counter files (M15 c2): a cgroup v2 directory's
/// `cpu.stat`, `memory.current` and `memory.peak`, read with one warning per
/// file that can't be read. A container started with the wrong cgroup path
/// would otherwise report a stream with no CPU or memory and say nothing;
/// an older kernel's missing `memory.peak` is a file that can't be read too,
/// and is reported once the same way (its reading is then simply absent).
final class CgroupFiles {
  /// [directory] is the cgroup to read (`/sys/fs/cgroup` in the session
  /// image); [warn] takes one line per file that can't be read, at most once
  /// for each.
  CgroupFiles({required this.directory, required this.warn});

  /// The cgroup directory the container's numbers are read from.
  final String directory;

  /// Where a file that can't be read is reported: the sampler writes it to
  /// stderr, so a run's log says why a reading is missing.
  final void Function(String message) warn;

  final _reported = <String>{};

  /// The text of [name] in the cgroup, or null when it can't be read; the
  /// first failure for that file is reported through [warn].
  String? read(String name) {
    final path = '$directory/$name';
    try {
      return File(path).readAsStringSync();
    } on FileSystemException catch (e) {
      if (_reported.add(name)) warn('stream_sampler: cannot read $path: ${e.osError?.message ?? e.message}');
      return null;
    }
  }
}

/// What the sampler writes for the player to add to its batch (M15 c2): the
/// host pipeline's stage means and the numbers the player can't see. The
/// player owns the viewer id, so the host's stages land on the same row.
Map<String, Object?> pipelineJson(PipelineWindow window, {required double seconds, bool includeFirstFrame = false}) => {
  'stages': [
    for (final MapEntry(key: name, value: ms) in window.stages().entries) {'name': name, 'ms': ms},
  ],
  'encodedFps': ?window.encodedFps(seconds),
  'firstFrameMs': ?(includeFirstFrame ? window.firstEncodedMs : null),
};
