// The stream sampler (M15 c2): every few seconds it reads the container's own
// counters and posts them to the host's automation interface, so a session's
// summary carries its CPU, memory, GPU and encoder numbers. It also reads
// GStreamer's latency tracer out of the pipeline's log and writes the host's
// stages where the web player picks them up, so one viewer row reads capture →
// display.
//
//   dart run metrics:stream_sampler --automation-url http://127.0.0.1:8787 \
//     --token <token> --pipeline-log /run/thumb-party/pipeline.log \
//     --out /run/thumb-party/pipeline.json --sessions 1
//
// The image compiles it to a native binary (`stream-sampler`) in the Flutter
// build stage; the entrypoint starts it with the session's settings. Every
// reading is optional: what the kernel or the driver won't answer is left out
// of the sample, never guessed.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:metrics/metrics.dart';

const _usage = '''
The stream sampler (M15 c2).

  --automation-url <url>  the host's automation interface (default http://127.0.0.1:8787)
  --token <token>         its shared token
  --pipeline-log <file>   the GStreamer log with the latency tracer's records
  --out <file>            where the host's stages are written for the player
  --interval-s <n>        seconds between samples (default 3)
  --sessions <n>          sessions this machine runs at once (default 1)
  --encoder <name>        the encoder element, without its instance number
                          (default nvautogpuh264enc, the image's)
  --sink <name>           the webrtcsink element's name (default ws, the entrypoint's)
  --help                  this text

The CPU readings are percent of one core, as `docker stats` prints them: a
container that fills one core reports 100.
''';

/// The cgroup v2 files a container's own use is read from.
const _cgroupDir = '/sys/fs/cgroup';

/// Where the kernel keeps a process's own numbers.
const _procDir = '/proc';

/// What the container's own processes are called, without their paths, so the
/// CPU can be split between the game and the pipeline (the sound server is a
/// third of the container's whole).
const _gameProgram = 'tvtest';
const _pipelineProgram = 'gst-launch-1.0';

/// The element the session's encoder is, when the session doesn't say.
const _defaultEncoder = 'nvautogpuh264enc';

/// The name the entrypoint gives `webrtcsink`, so its records are the send
/// stage.
const _defaultSink = 'ws';

/// The seconds' worth of microseconds, which `cpu.stat` counts in.
const _usPerS = 1000000;

/// Milliseconds a second, for a duration in ms.
const _msPerS = 1000;

Future<void> main(List<String> args) async {
  final options = _Options.parse(args);
  if (options == null) {
    stdout.write(_usage);
    exit(2);
  }
  final sampler = _Sampler(options);
  await sampler.prime();
  final interval = Duration(milliseconds: (options.intervalS * _msPerS).round());
  Timer.periodic(interval, (_) => unawaited(sampler.sample()));
  // A stop from the entrypoint ends the sampler with the session.
  ProcessSignal.sigterm.watch().listen((_) => exit(0));
  ProcessSignal.sigint.watch().listen((_) => exit(0));
  await Completer<void>().future;
}

/// What the entrypoint asked for.
final class _Options {
  const _Options({
    required this.automationUrl,
    required this.token,
    required this.pipelineLog,
    required this.out,
    required this.intervalS,
    required this.sessions,
    required this.encoderPrefix,
    required this.sinkName,
  });

  final Uri automationUrl;
  final String token;
  final File pipelineLog;
  final File out;
  final double intervalS;
  final int sessions;

  /// The encoder's element name, without its instance number.
  final String encoderPrefix;

  /// The webrtcsink element's name, as the pipeline gave it.
  final String sinkName;

  /// The options the command line holds, or null when it asks for help or
  /// gives something this program doesn't have.
  static _Options? parse(List<String> args) {
    var url = Uri.parse('http://127.0.0.1:8787');
    var token = '';
    var log = '';
    var out = '';
    var encoder = _defaultEncoder;
    var sink = _defaultSink;
    var intervalS = 3.0;
    var sessions = 1;
    String value(int i) => i + 1 < args.length ? args[i + 1] : '';
    for (var i = 0; i < args.length; i++) {
      switch (args[i]) {
        case '--automation-url':
          url = Uri.parse(value(i));
          i++;
        case '--token':
          token = value(i);
          i++;
        case '--pipeline-log':
          log = value(i);
          i++;
        case '--out':
          out = value(i);
          i++;
        case '--encoder':
          encoder = value(i);
          i++;
        case '--interval-s':
          intervalS = double.tryParse(value(i)) ?? intervalS;
          i++;
        case '--sessions':
          sessions = int.tryParse(value(i)) ?? sessions;
          i++;
        case '--sink':
          sink = value(i);
          i++;
        case '--help':
        case '-h':
          return null;
        default:
          stderr.writeln('stream_sampler: unknown option "${args[i]}"');
          return null;
      }
    }
    if (log.isEmpty || out.isEmpty || encoder.isEmpty || sink.isEmpty) return null;
    return _Options(
      automationUrl: url,
      token: token,
      pipelineLog: File(log),
      out: File(out),
      intervalS: intervalS <= 0 ? 3.0 : intervalS,
      sessions: sessions < 1 ? 1 : sessions,
      encoderPrefix: encoder,
      sinkName: sink,
    );
  }
}

/// The sampler's own state between windows: the counters it compares against
/// and the pipeline log's last read position.
final class _Sampler {
  _Sampler(this.options) : window = PipelineWindow(encoderPrefix: options.encoderPrefix, sinkName: options.sinkName);

  final _Options options;
  final PipelineWindow window;
  final _cgroup = CgroupFiles(directory: _cgroupDir, warn: (message) => stderr.writeln(message));
  final _client = HttpClient()..connectionTimeout = const Duration(seconds: 2);

  int? _usageUsec;
  int? _logOffset;
  int? _drawn;
  DateTime? _previousAt;
  double? _peakMb;
  bool _wroteFirstFrame = false;
  final _previousTicks = <int, int>{};

  /// The number of the last probe press the player was given (M15 k1): the app
  /// keeps the last 32, so the next window takes the presses above it.
  int _legsN = 0;

  /// Reads the counters once, so the first window has something to compare
  /// against; nothing is sent from here.
  Future<void> prime() async {
    final usage = _cgroup.read('cpu.stat');
    _usageUsec = usage == null ? null : cgroupUsageUsec(usage);
    for (final process in _readProcesses()) {
      _previousTicks[process.pid] = process.ticks;
    }
    _drawn = _drawnOf(await _readStatus());
    _logOffset = options.pipelineLog.existsSync() ? options.pipelineLog.lengthSync() : 0;
    _previousAt = DateTime.now();
  }

  /// One window: reads the tracer's new records and every counter, sends the
  /// resources to the host and writes the host's stages for the player.
  Future<void> sample() async {
    final now = DateTime.now();
    final seconds = _secondsSince(now);
    _readTracer();
    final processes = _readProcesses();
    final status = await _readStatus();
    final resources = await _readResources(seconds, processes, status);
    final firstFrame = _wroteFirstFrame ? null : window.firstEncodedMs;
    if (resources.toJson().isNotEmpty) {
      await _post({
        'resources': [resources.toJson()],
      });
    }
    final legs = probeLegsOf(status ?? '', afterN: _legsN);
    if (legs.isNotEmpty) _legsN = legs.last.n;
    final hostLegs = hostLegStages(legs);
    _write(pipelineJson(window, seconds: seconds, includeFirstFrame: firstFrame != null, hostLegs: hostLegs));
    if (firstFrame != null) _wroteFirstFrame = true;
    window.clear();
    _previousAt = now;
  }

  /// Every reading of the window, with whatever it couldn't read left out.
  /// [status] is the host's own answer, which carries the game's frame times.
  Future<StreamResourceSample> _readResources(double seconds, List<_Process> processes, String? status) async {
    final usage = _cgroup.read('cpu.stat');
    final usageUsec = usage == null ? null : cgroupUsageUsec(usage);
    final cpuPct = _share(_usageUsec, usageUsec, seconds);
    _usageUsec = usageUsec;
    final shares = _processShares(processes, seconds);
    final memory = cgroupBytes(_cgroup.read('memory.current') ?? '');
    final peak = cgroupBytes(_cgroup.read('memory.peak') ?? '');
    final memMb = memory == null ? null : memory / _bytesPerMb;
    final peakMb = peak == null ? null : peak / _bytesPerMb;
    final highest = _highest(_peakMb, memMb);
    _peakMb = highest;
    final gpu = _readGpu([for (final process in processes) process.pid]);
    final drawn = _drawnOf(status);
    final frames = frameWindowOf(status ?? '');
    return StreamResourceSample(
      cpuPct: cpuPct,
      gameCpuPct: shares.gamePct,
      encoderCpuPct: shares.pipelinePct,
      memMb: _round(memMb),
      memPeakMb: _round(peakMb ?? highest),
      gpuPct: gpu?.utilPct,
      encoderPct: gpu?.encoderPct,
      gpuMemMb: gpu?.memUsedMb,
      gameFps: _gameFps(drawn, seconds),
      frameBuildMs: frames?.buildMs,
      frameRasterMs: frames?.rasterMs,
      gameFrameMs: frames?.gameFrameMs,
      slowFramePct: frames?.slowFramePct,
      encodedFps: _round(window.encodedFps(seconds)),
      pipelineMs: _round(window.pipelineMs),
      sessionsAtOnce: options.sessions,
      // The host keeps the first non-null reading, so every window may carry
      // it; the pipeline's first record never changes once it has one.
      firstFrameMs: window.firstEncodedMs?.round(),
    );
  }

  /// The game's frame rate between this window and the last, from the frames
  /// the host app drew while a round runs.
  num? _gameFps(int? drawn, double seconds) {
    final before = _drawn;
    _drawn = drawn;
    if (drawn == null || before == null || seconds <= 0) return null;
    final frames = drawn - before;
    return frames < 0 ? null : _round(frames / seconds);
  }

  /// The game's and the pipeline's CPU, each as percent of one core like the
  /// container's own.
  ({num? gamePct, num? pipelinePct}) _processShares(List<_Process> processes, double seconds) {
    num? game;
    num? pipeline;
    for (final process in processes) {
      final before = _previousTicks[process.pid];
      _previousTicks[process.pid] = process.ticks;
      if (before == null || seconds <= 0) continue;
      final pct = (process.ticks - before) / (seconds * processTicksPerS) * 100;
      if (process.program == _gameProgram) game = _round(pct);
      if (process.program == _pipelineProgram) pipeline = _round((pipeline ?? 0) + pct);
    }
    return (gamePct: game, pipelinePct: pipeline);
  }

  /// The container's own processes: their ids, programmes and clock ticks.
  List<_Process> _readProcesses() {
    final found = <_Process>[];
    try {
      for (final entry in Directory(_procDir).listSync()) {
        final pid = int.tryParse(entry.path.split('/').last);
        if (pid == null) continue;
        final cmdline = _readFile('$_procDir/$pid/cmdline');
        final stat = _readFile('$_procDir/$pid/stat');
        if (cmdline == null || stat == null) continue;
        final ticks = processTicks(stat);
        if (ticks == null) continue;
        found.add(_Process(pid, programOf(cmdline), ticks));
      }
    } on FileSystemException catch (e) {
      stderr.writeln('stream_sampler: cannot read /proc: ${e.message}');
    }
    return found;
  }

  /// The GPU's use and memory, and the share of the memory this container's
  /// own processes hold.
  GpuReading? _readGpu(List<int> pids) {
    final line = _run('nvidia-smi', [
      '--query-gpu=utilization.gpu,utilization.encoder,memory.used',
      '--format=csv,noheader,nounits',
    ]);
    final reading = line == null ? null : gpuReadingOf(line.split('\n').first);
    if (reading == null) return null;
    final apps = _run('nvidia-smi', ['--query-compute-apps=pid,used_memory', '--format=csv,noheader,nounits']);
    final mine = apps == null ? null : processesMemoryMb(apps, pids.toSet());
    return GpuReading(utilPct: reading.utilPct, encoderPct: reading.encoderPct, memUsedMb: mine ?? reading.memUsedMb);
  }

  /// The host's own answer to `GET status`, or null when it didn't answer: it
  /// carries the drawn frames, the press legs and the game's frame times.
  Future<String?> _readStatus() => _request('GET', '/automation/v1/status');

  /// The frames the host app has drawn, from [status]: null while the host is
  /// home, since a frame rate means nothing without a round.
  int? _drawnOf(String? status) => status == null || !roundRunningIn(status) ? null : drawnFramesOf(status);

  /// Reads the tracer's new lines out of the pipeline's log and takes them
  /// into the window; a log that shrank starts over.
  void _readTracer() {
    try {
      if (!options.pipelineLog.existsSync()) return;
      final length = options.pipelineLog.lengthSync();
      final read = _logOffset;
      final from = read == null || read > length ? 0 : read;
      if (from == length) return;
      final handle = options.pipelineLog.openSync();
      try {
        handle.setPositionSync(from);
        final bytes = handle.readSync(length - from);
        _logOffset = length;
        for (final line in const Utf8Decoder(allowMalformed: true).convert(bytes).split('\n')) {
          final record = tracerRecordOf(line);
          if (record != null) window.add(record);
          final pipeline = pipelineRecordOf(line);
          if (pipeline != null) window.addPipeline(pipeline);
        }
      } finally {
        handle.closeSync();
      }
    } on FileSystemException catch (e) {
      stderr.writeln('stream_sampler: cannot read the pipeline log: ${e.message}');
    }
  }

  /// The host's stages for the player, written where the player's web server
  /// serves them; the player adds them to its own batch under its viewer id.
  void _write(Map<String, Object?> body) {
    final temporary = File('${options.out.path}.tmp');
    try {
      temporary.writeAsStringSync(const JsonEncoder().convert(body));
      temporary.renameSync(options.out.path);
    } on FileSystemException catch (e) {
      stderr.writeln('stream_sampler: cannot write ${options.out.path}: ${e.message}');
    }
  }

  /// Sends one `stats/stream` body to the host. A host that isn't up yet or
  /// answers nothing is logged and skipped: the next window tries again.
  Future<void> _post(Map<String, Object?> body) async {
    final answer = await _request('POST', '/automation/v1/stats/stream', const JsonEncoder().convert(body));
    if (answer == null) stderr.writeln('stream_sampler: the host did not take the sample');
  }

  /// One automation call, answering its body's text, or null when the host
  /// didn't answer or answered a refusal.
  Future<String?> _request(String method, String path, [String? body]) async {
    final uri = options.automationUrl.replace(path: path);
    try {
      final request = await _client.openUrl(method, uri);
      if (options.token.isNotEmpty) request.headers.set('x-automation-token', options.token);
      if (body != null) {
        request.headers.contentType = ContentType.json;
        request.write(body);
      }
      final response = await request.close();
      final text = await const Utf8Decoder(allowMalformed: true).bind(response).join();
      if (response.statusCode != HttpStatus.ok) {
        stderr.writeln('stream_sampler: $path answered ${response.statusCode}: $text');
        return null;
      }
      return text;
    } on Object catch (e) {
      stderr.writeln('stream_sampler: $path failed: $e');
      return null;
    }
  }

  /// A program's output, or null when it isn't installed or failed.
  String? _run(String program, List<String> arguments) {
    try {
      final result = Process.runSync(program, arguments);
      return result.exitCode == 0 ? result.stdout as String : null;
    } on ProcessException catch (e) {
      stderr.writeln('stream_sampler: $program failed: ${e.message}');
      return null;
    }
  }

  String? _readFile(String path) {
    try {
      return File(path).readAsStringSync();
    } on FileSystemException {
      return null;
    }
  }

  double _secondsSince(DateTime now) {
    final before = _previousAt;
    final ms = before == null ? 0 : now.difference(before).inMilliseconds;
    return ms <= 0 ? options.intervalS : ms / _msPerS;
  }

  /// The container's CPU over [seconds] as percent of one core, or null for
  /// the first window.
  num? _share(int? before, int? now, double seconds) {
    if (before == null || now == null || seconds <= 0) return null;
    return _round((now - before) / (seconds * _usPerS) * 100);
  }
}

/// One process the sampler found: its id, the programme it runs and its clock
/// ticks so far.
final class _Process {
  const _Process(this.pid, this.program, this.ticks);

  final int pid;
  final String program;
  final int ticks;
}

/// The bytes in a megabyte.
const _bytesPerMb = 1024.0 * 1024.0;

/// A number rounded to two decimals, as a gauge keeps it.
num? _round(num? value) => value == null ? null : (value * 100).round() / 100;

/// The higher of two optional readings.
double? _highest(double? a, double? b) {
  if (a == null) return b;
  if (b == null) return a;
  return a >= b ? a : b;
}
