import 'report_stream.dart';
import 'report_stream_rows.dart';
import 'stream_names.dart';

/// The stream CSV's columns (M15): one row per session and viewer, the stages
/// in pipeline order, the totals, sound, quality, and the session's container
/// readings repeated on each of its viewers' rows. Each container reading has
/// its mean and its p95 (`cpu_pct`, `cpu_pct_p95`), as the report's table
/// prints them, and `pipeline_ms` is the tracer's whole host path. An empty
/// cell means the viewer or the container gave no such number.
const streamCsvHeader =
    'session,viewer,kind,platform,'
    'input_median_ms,input_p95_ms,host_median_ms,host_p95_ms,'
    'host_tick_median_ms,host_tick_p95_ms,host_build_median_ms,host_build_p95_ms,'
    'host_raster_median_ms,host_raster_p95_ms,'
    'capture_median_ms,capture_p95_ms,encode_median_ms,encode_p95_ms,'
    'send_median_ms,send_p95_ms,network_median_ms,network_p95_ms,'
    'jitter_median_ms,jitter_p95_ms,decode_median_ms,decode_p95_ms,'
    'display_median_ms,display_p95_ms,total_median_ms,total_p95_ms,'
    'press_median_ms,press_p95_ms,press_source,'
    'audio_median_ms,audio_p95_ms,sync_mean_ms,concealed_mean_pct,audio_jitter_ms,'
    'bitrate_sent_kbps,bitrate_recv_kbps,loss_pct,rtt_ms,jitter_ms,fps,'
    'frames_sent,frames_recv,frames_decoded,frames_dropped,frames_late,'
    'keyframes,nacks,plis,firs,freezes,freeze_ms,first_frame_ms,reconnects,'
    'relay,codec,encoder,'
    'sessions_at_once,cpu_pct,cpu_pct_p95,game_cpu_pct,game_cpu_pct_p95,'
    'enc_cpu_pct,enc_cpu_pct_p95,mem_mb,mem_mb_p95,gpu_pct,gpu_pct_p95,'
    'encoder_pct,encoder_pct_p95,gpu_mem_mb,gpu_mem_mb_p95,game_fps,game_fps_p95,'
    'frame_build_ms,frame_build_ms_p95,frame_raster_ms,frame_raster_ms_p95,'
    'game_frame_ms,game_frame_ms_p95,slow_frame_pct,slow_frame_pct_p95,'
    'encoded_fps,encoded_fps_p95,encode_queue,encode_queue_p95,'
    'pipeline_ms,pipeline_ms_p95,mem_peak_mb';

/// The stream CSV: one row per session and viewer of every session that
/// streamed (M15). A report whose sessions never streamed has only the header.
String streamCsv(List<Map<String, Object?>> summaries) {
  final hosts = {for (final host in streamHosts(summaries)) host.session: host};
  return [
    streamCsvHeader,
    for (final viewer in streamViewers(summaries)) _row(viewer, hosts[viewer.session]),
  ].join('\n');
}

/// One viewer's row: its stage medians and p95s, then its numbers, then its
/// session's container readings.
String _row(StreamViewerRow viewer, StreamHostRow? host) => [
  _csv(viewer.session),
  _csv(viewer.id),
  _csv(viewer.kind),
  _csv(viewer.platform),
  for (final name in [
    StreamStage.controller[0],
    StreamStage.controller[1],
    ...StreamStage.hostLegs,
    ...StreamStage.pipeline,
  ])
    ..._pair(viewer, name),
  ..._pair(viewer, StreamStage.total),
  ..._pair(viewer, StreamStage.pressToScreen),
  _csv(_source(viewer)),
  ..._pair(viewer, 'audio_capture_to_play'),
  _mean(viewer, 'audioSyncMs'),
  _mean(viewer, 'audioConcealedPct'),
  _mean(viewer, 'audioJitterMs'),
  _mean(viewer, 'bitrateSentKbps'),
  _mean(viewer, 'bitrateReceivedKbps'),
  _mean(viewer, 'lossPct'),
  _mean(viewer, 'rttMs'),
  _mean(viewer, 'jitterMs'),
  _mean(viewer, 'deliveredFps'),
  for (final name in const [
    'framesSent',
    'framesReceived',
    'framesDecoded',
    'framesDropped',
    'framesLate',
    'keyframes',
    'nacks',
    'plis',
    'firs',
    'freezes',
    'freezeMs',
    'firstFrameMs',
    'reconnects',
  ])
    _whole(viewer.counter(name)),
  _csv(viewer.facts['relay']),
  _csv(viewer.facts['codec']),
  _csv(viewer.facts['encoder']),
  _whole(host?.sessionsAtOnce),
  for (final name in const [
    StreamResource.cpuPct,
    StreamResource.gameCpuPct,
    StreamResource.encoderCpuPct,
    StreamResource.memMb,
    StreamResource.gpuPct,
    StreamResource.encoderPct,
    StreamResource.gpuMemMb,
    StreamResource.gameFps,
    StreamResource.frameBuildMs,
    StreamResource.frameRasterMs,
    StreamResource.gameFrameMs,
    StreamResource.slowFramePct,
    StreamResource.encodedFps,
    StreamResource.encodeQueue,
    StreamResource.pipelineMs,
  ])
    ..._resourcePair(host, name),
  _text(host?.memPeakMb),
].join(',');

/// A stage's median and p95 as two cells (either empty when it has none).
List<String> _pair(StreamViewerRow viewer, String name) => [
  _text(viewer.stageField(name, 'median')),
  _text(viewer.stageField(name, 'p95')),
];

/// A gauge's mean, or an empty cell.
String _mean(StreamViewerRow viewer, String name) => _text(viewer.gaugeField(name, 'mean'));

/// A container gauge's mean and p95 as two cells (either empty when it has
/// none), as the report's table prints them.
List<String> _resourcePair(StreamHostRow? host, String name) => [
  _text(host?.gaugeField(name, 'mean')),
  _text(host?.gaugeField(name, 'p95')),
];

/// The source of a derived total (`stages`, `measured` or `probe`).
String _source(StreamViewerRow viewer) {
  final source = viewer.stageField(StreamStage.pressToScreen, 'source');
  return source is String ? source : '';
}

/// A value as a cell, as the summary wrote it: nothing for none.
String _text(Object? value) => value == null ? '' : '$value';

/// A count as a cell, whole, or nothing for none.
String _whole(num? value) => value == null ? '' : '${value.round()}';

/// A text as a cell: quoted when it holds a comma or a quote, as the mode CSV
/// does, so the columns stay lined up.
String _csv(String? value) {
  if (value == null || value.isEmpty) return '';
  return value.contains(',') || value.contains('"') ? '"${value.replaceAll('"', '""')}"' : value;
}
