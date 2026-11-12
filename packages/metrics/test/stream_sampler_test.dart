import 'dart:convert';

import 'package:metrics/metrics.dart';
import 'package:test/test.dart';

/// The container's own counters for a streamed session (M15 c2): the text
/// `/proc`, cgroup v2, `nvidia-smi` and GStreamer's latency tracer print,
/// read into the numbers the sampler sends. The fixtures are lines lifted
/// from a real session (the latency tracer's own records, a container's
/// `cpu.stat`, `/proc/<pid>/stat`), so a change in their shape shows up here
/// rather than as a missing column in the report.
void main() {
  group('cgroup', () {
    test('cpu.stat gives the microseconds the container has used', () {
      const stat = 'usage_usec 12345678\nuser_usec 9000000\nsystem_usec 3345678\nnr_periods 0\n';

      expect(cgroupUsageUsec(stat), 12345678, reason: 'the line the sampler tells time by');
    });

    test('a memory file gives its bytes, and an empty one nothing', () {
      expect(cgroupBytes('536870912\n'), 536870912);
      expect(cgroupBytes(''), isNull, reason: 'memory.peak is missing on older kernels');
    });
  });

  group('processes', () {
    test('stat gives the user and system ticks after the command name', () {
      // The command's name may hold spaces and brackets; the fields after it
      // are what count, and utime/stime are the 12th and 13th of them.
      const stat = '1234 (tv test) S 1 1234 1234 0 -1 4194560 100 0 0 0 250 50 0 0 20 0 100 0 1234 0';

      expect(processTicks(stat), 300);
      expect(processTicks('1234 (tvtest) S 1'), isNull, reason: 'a truncated line has no ticks');
    });

    test('cmdline gives the programme without its path or arguments', () {
      expect(programOf('/app/tvtest\u0000--flag\u0000'), 'tvtest');
      expect(programOf('gst-launch-1.0\u0000-e\u0000'), 'gst-launch-1.0');
    });
  });

  test('nvidia-smi gives the GPU, its encoder and its memory', () {
    final reading = gpuReadingOf('46, 6, 1447');

    expect(reading?.utilPct, 46);
    expect(reading?.encoderPct, 6, reason: 'the encoder engine the pipeline uses');
    expect(reading?.memUsedMb, 1447);
    expect(gpuReadingOf('not a reading'), isNull);
  });

  test('nvidia-smi lists what each process holds, and only ours count', () {
    const apps = '1234, 900\n5678, 300\n9999, 50\n';

    expect(processesMemoryMb(apps, {1234, 5678}), 1200);
    expect(processesMemoryMb(apps, {42}), isNull, reason: 'a GPU another container uses is not ours');
  });

  group('the latency tracer', () {
    // One element record and one whole-pipeline record, as a session's log
    // holds them (§13 of docs/protocol.md): the element record times the work
    // inside one element, the pipeline record goes from the source to the
    // sink.
    const element =
        '0:00:02.294285211    42 0x731c20008aa0 TRACE             GST_TRACER :0:: '
        'element-latency, element-id=(string)0x5ab11ed0cdf0, element=(string)nvautogpuh264enc0, '
        'src=(string)src, time=(guint64)247223903, ts=(guint64)2294268410;';
    const pipeline =
        '0:00:02.294676571    42 0x731c20008aa0 TRACE             GST_TRACER :0:: '
        'latency, src-element-id=(string)0x5ab11e7bf680, src-element=(string)waylanddisplaysrc0, '
        'src=(string)src, sink-element-id=(string)0x5ab11ebbe750, sink-element=(string)ws, '
        'sink=(string)video_0, time=(guint64)253507916, ts=(guint64)2294660761;';

    test('an element record gives its element, its time and its stamp', () {
      final record = tracerRecordOf(element);

      expect(record?.element, 'nvautogpuh264enc0');
      expect(record?.ms, closeTo(247.22, 0.01), reason: 'the record counts nanoseconds');
      expect(record?.pipelineMs, closeTo(2294.27, 0.01));
    });

    test('a whole-pipeline record is not an element record', () {
      expect(tracerRecordOf(pipeline), isNull, reason: 'it names two elements, not one');
      expect(pipelineRecordOf(element), isNull, reason: 'an element record has no two ends');
      expect(tracerRecordOf('0:00:01.079314119    58 0x64bb0b9d71c0 DEBUG GST_TRACER record'), isNull);
    });

    test('a whole-pipeline record names its branch and its time', () {
      final record = pipelineRecordOf(pipeline);

      expect(record?.srcElement, 'waylanddisplaysrc0');
      expect(record?.sinkElement, 'ws');
      expect(record?.ms, closeTo(253.51, 0.01), reason: 'the capture plugin to webrtcsink');
    });

    test('records sort into the capture, encode and send stages', () {
      final window = PipelineWindow(encoderPrefix: 'nvautogpuh264enc');
      window.add(TracerRecord('capsfilter0', 1, 100));
      window.add(TracerRecord('videoconvert0', 3, 104));
      window.add(TracerRecord('nvautogpuh264enc0', 24, 128));
      window.add(TracerRecord('ws', 2, 130));
      window.add(TracerRecord('capsfilter1', 250, 380));
      window.add(TracerRecord('pulsasrc0', 250, 380));

      expect(window.stages(), {
        StreamStage.capture: 2,
        StreamStage.encode: 24,
        StreamStage.send: 2,
      }, reason: 'the caps and the converter carry the captured frame; the sound path does not');
    });

    test('the video branch is the host path end to end, once a frame', () {
      final window = PipelineWindow(encoderPrefix: 'nvautogpuh264enc');
      window.addPipeline(const PipelineRecord('waylanddisplaysrc0', 'ws', 30));
      window.addPipeline(const PipelineRecord('waylanddisplaysrc0', 'ws', 34));
      window.addPipeline(const PipelineRecord('pulsasrc0', 'ws', 200));
      window.addPipeline(const PipelineRecord('waylanddisplaysrc0', 'appsink1', 5));

      expect(window.pipelineMs, closeTo(32, 0.001), reason: 'the sound and the preview are another branch');
      window.clear();
      expect(window.pipelineMs, isNull, reason: 'a window starts empty');
    });

    test('the encoder gives the encoded frame rate and the first frame', () {
      final window = PipelineWindow(encoderPrefix: 'nvautogpuh264enc');
      for (var i = 0; i < 60; i++) {
        window.add(TracerRecord('nvautogpuh264enc0', 2, 500 + i.toDouble()));
      }

      expect(window.encodedFps(1), 60);
      expect(window.firstEncodedMs, 500, reason: 'the first record the window saw');
      expect(window.encodedFps(0), isNull);
    });

    test('the pipelined stages become one JSON the player adds', () {
      final window = PipelineWindow(encoderPrefix: 'nvautogpuh264enc');
      window.add(TracerRecord('videoconvert0', 4, 100));
      window.add(TracerRecord('nvautogpuh264enc0', 24, 124));
      for (var i = 0; i < 30; i++) {
        window.add(TracerRecord('nvautogpuh264enc0', 24, 124));
      }

      final json = jsonDecode(jsonEncode(pipelineJson(window, seconds: 1, includeFirstFrame: true)));

      expect(json, {
        'stages': [
          {'name': StreamStage.capture, 'ms': 4},
          {'name': StreamStage.encode, 'ms': 24},
        ],
        'encodedFps': 31.0,
        // The first record of the encoder, not of the capture: the pipeline's
        // own stamp when a frame first left the encoder.
        'firstFrameMs': 124.0,
      });
    });
  });

  group('the host status', () {
    // The host's own answer, as the app writes it: one line, no spaces.
    const playing =
        '{"ok":true,"version":"0.14.0","screen":"game","round":true,"game":"arena","ready":false,'
        '"hostMs":412345,"frames":{"drawn":850},"players":[{"id":"local-1"}]}';
    const home = '{"ok":true,"version":"0.14.0","screen":"home","ready":true,"hostMs":900,"frames":{"drawn":12}}';

    test('the drawn frames come out of the frames object', () {
      expect(drawnFramesOf(playing), 850);
      expect(drawnFramesOf(home), 12);
      expect(drawnFramesOf('{"ok":true}'), isNull);
    });

    test('a round is what makes a frame rate mean something', () {
      expect(roundRunningIn(playing), isTrue);
      expect(roundRunningIn(home), isFalse);
      expect(roundRunningIn('{"screen":"game"}'), isTrue, reason: 'a body written with spaces too');
    });
  });
}
