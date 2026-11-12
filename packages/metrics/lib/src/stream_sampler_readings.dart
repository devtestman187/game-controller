/// Reads the container's and the GPU's own counters for a streamed session
/// (M15 c2): the text `/proc` and `nvidia-smi` print, turned into numbers the
/// sampler sends every few seconds. Pure functions, so the parsing is tested
/// against fixture text rather than a live machine.
library;

/// The nanoseconds in a millisecond, the unit a stage is recorded in.
const _nsPerMs = 1000000.0;

/// The clock ticks a second `/proc/<pid>/stat` counts with (USER_HZ).
const processTicksPerS = 100;

/// Reads the `usage_usec` line of a cgroup v2 `cpu.stat`: the CPU time the
/// container's cgroup has used, in microseconds.
int? cgroupUsageUsec(String cpuStat) => _numberAfter(cpuStat, 'usage_usec ');

/// Reads a cgroup v2 file that holds one byte count (`memory.current`,
/// `memory.peak`), or null when it holds nothing usable (`memory.peak` is
/// missing on older kernels).
int? cgroupBytes(String text) => _wholeNumber(text.trim());

/// The user plus system clock ticks of one process, from `/proc/<pid>/stat`:
/// the fields after the command, whose spaces would otherwise shift them.
int? processTicks(String stat) {
  final close = stat.lastIndexOf(')');
  if (close < 0 || close + 2 >= stat.length) return null;
  final fields = stat.substring(close + 2).split(' ');
  // utime is field 14 and stime 15 of the whole line; after the command and
  // the state that follows it, they are the 12th and 13th here.
  const utime = 11;
  const stime = 12;
  if (fields.length <= stime) return null;
  final user = _wholeNumber(fields[utime]);
  final system = _wholeNumber(fields[stime]);
  return user == null || system == null ? null : user + system;
}

/// The programme a `/proc/<pid>/cmdline` starts with (its words are separated
/// by nulls), so a process can be told apart without its pid.
String programOf(String cmdline) {
  final end = cmdline.indexOf('\u0000');
  final first = end < 0 ? cmdline : cmdline.substring(0, end);
  return first.split('/').last.trim();
}

/// One GPU reading: what `nvidia-smi --query-gpu` prints, per GPU (M15 c2).
final class GpuReading {
  /// [utilPct] is the GPU's own use, [encoderPct] its video encoder's (absent
  /// on a driver whose `nvidia-smi` doesn't offer it) and [memUsedMb] what
  /// every process on the card uses.
  const GpuReading({this.utilPct, this.encoderPct, this.memUsedMb});

  final num? utilPct;
  final num? encoderPct;
  final num? memUsedMb;
}

/// Reads one line of `nvidia-smi --query-gpu=utilization.gpu,utilization.encoder,memory.used
/// --format=csv,noheader,nounits`: three numbers, `[N/A]` where the driver
/// doesn't give one.
GpuReading? gpuReadingOf(String line) {
  final parts = line.split(',').map((part) => part.trim()).toList();
  if (parts.isEmpty || parts.length > 3) return null;
  num? at(int index) => index < parts.length ? _numberOrNull(parts[index]) : null;
  final reading = GpuReading(utilPct: at(0), encoderPct: at(1), memUsedMb: at(2));
  return reading.utilPct == null && reading.encoderPct == null && reading.memUsedMb == null ? null : reading;
}

/// The GPU memory [pids] use, summed from
/// `nvidia-smi --query-compute-apps=pid,used_memory --format=csv,noheader,nounits`:
/// the encoder's and the game's own share of the card, in MB.
num? processesMemoryMb(String lines, Set<int> pids) {
  num total = 0;
  var seen = false;
  for (final line in lines.split('\n')) {
    final parts = line.split(',').map((part) => part.trim()).toList();
    if (parts.length < 2) continue;
    final pid = _wholeNumber(parts[0]);
    final mb = _numberOrNull(parts[1]);
    if (pid == null || mb == null || !pids.contains(pid)) continue;
    total += mb;
    seen = true;
  }
  return seen ? total : null;
}

/// One record of GStreamer's latency tracer: which element it is and how long
/// the buffer took inside it.
final class TracerRecord {
  /// [ms] is the element's time in milliseconds; [pipelineMs] is the time since
  /// the pipeline started (the tracer's `ts`), used once for the first frame.
  const TracerRecord(this.element, this.ms, this.pipelineMs);

  final String element;
  final double ms;
  final double pipelineMs;
}

/// Reads one `element-latency` line of GStreamer's latency tracer
/// (`GST_TRACERS=latency(flags=pipeline+element)`), or null for any other
/// line of the log: the record names its element and gives `time` and `ts` in
/// nanoseconds.
TracerRecord? tracerRecordOf(String line) {
  if (!line.contains('element-latency, ')) return null;
  final element = _valueAfter(line, 'element=(string)');
  final time = _numberAfter(line, 'time=(guint64)');
  final ts = _numberAfter(line, 'ts=(guint64)');
  if (element == null || time == null) return null;
  return TracerRecord(element, time / _nsPerMs, (ts ?? 0) / _nsPerMs);
}

/// One record of the tracer's pipeline latency: how long a buffer took from
/// the source element's pad to a sink element (M15 c2). A pipeline writes one
/// series of records per branch (the video to `webrtcsink`, the sound to it,
/// the video to the preview's app sink), so the two element names say which
/// branch a record belongs to.
final class PipelineRecord {
  const PipelineRecord(this.srcElement, this.sinkElement, this.ms);

  /// The element the buffer started at, as GStreamer named it (`waylanddisplaysrc0`).
  final String srcElement;

  /// The element the buffer ended at (`ws` for `webrtcsink`).
  final String sinkElement;

  /// The buffer's time through the branch, in milliseconds.
  final double ms;
}

/// Reads one `latency` line of GStreamer's latency tracer, or null for any
/// other line of the log. Unlike an `element-latency` record a pipeline
/// record spans a whole branch, which is what lets the sampler report the
/// host's path end to end.
PipelineRecord? pipelineRecordOf(String line) {
  if (!line.contains(': latency, ') || line.contains('element-latency')) return null;
  final src = _valueAfter(line, 'src-element=(string)');
  final sink = _valueAfter(line, 'sink-element=(string)');
  final time = _numberAfter(line, 'time=(guint64)');
  if (src == null || sink == null || time == null) return null;
  return PipelineRecord(src, sink, time / _nsPerMs);
}

/// The frames the host app has drawn, from `GET status`'s
/// `"frames": {"drawn": …}`, so the sampler reads the game's own frame rate
/// between two calls. Null when the body doesn't say.
int? drawnFramesOf(String statusJson) {
  final frames = _objectAfter(statusJson, '"frames":');
  if (frames == null) return null;
  return _wholeNumber(_valueAfter(frames, '"drawn":'));
}

/// Whether a round is running, from `GET status`'s `"screen"` (`game` while
/// one runs): a frame rate means nothing on the home screen.
bool roundRunningIn(String statusJson) => RegExp(r'"screen":\s*"game"').hasMatch(statusJson);

/// The whole number right after [marker] in [text], or null: the tracer writes
/// its numbers in brackets (`time=(guint64)11168`), so a marker names them.
int? _numberAfter(String text, String marker) {
  final match = RegExp('${RegExp.escape(marker)}([0-9]+)').firstMatch(text);
  return match == null ? null : int.tryParse(match.group(1) ?? '');
}

/// The text after [marker] up to [stop] (a comma or a closing bracket), or
/// null when the marker isn't there.
String? _valueAfter(String text, String marker, {String stop = ','}) {
  final at = text.indexOf(marker);
  if (at < 0) return null;
  final from = at + marker.length;
  var end = text.indexOf(stop, from);
  if (end < 0) end = text.length;
  final value = text.substring(from, end).trim();
  return value.isEmpty ? null : value;
}

/// The brace-delimited object after [marker] in [text], or null when there is
/// no such object.
String? _objectAfter(String text, String marker) {
  final at = text.indexOf(marker);
  if (at < 0) return null;
  final open = text.indexOf('{', at + marker.length);
  if (open < 0) return null;
  var depth = 0;
  for (var i = open; i < text.length; i++) {
    final char = text[i];
    if (char == '{') depth++;
    if (char != '}') continue;
    depth--;
    if (depth == 0) return text.substring(open, i + 1);
  }
  return null;
}

/// A whole number, with whatever punctuation a fixture line left around it,
/// or null for no text at all.
int? _wholeNumber(String? text) {
  if (text == null) return null;
  final match = RegExp('[0-9]+').firstMatch(text);
  return match == null ? null : int.tryParse(match.group(0) ?? '');
}

double? _numberOrNull(String text) => double.tryParse(text.trim());
