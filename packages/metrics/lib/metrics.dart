/// Analytics for Thumb Party (PRD v2 M9): the phone's touch counters per
/// mode segment ([SegmentRecorder]), the host's session summary
/// ([SessionCollector]) and the report ([report], [csv]).
///
/// Pure Dart (no Flutter), so it runs in both apps, on the command line and
/// in `dart test`.
library;

export 'src/geometry.dart';
export 'src/host_device_sample.dart';
export 'src/paste.dart';
export 'src/report.dart';
export 'src/report_games.dart';
export 'src/report_rounds.dart';
export 'src/report_stream.dart';
export 'src/report_stream_csv.dart';
export 'src/report_table.dart';
export 'src/report_watched.dart';
export 'src/segment.dart';
export 'src/session.dart';
export 'src/session_stats.dart';
export 'src/stream_names.dart';
export 'src/stream_resource_sample.dart';
export 'src/stream_sampler.dart';
export 'src/stream_sampler_readings.dart';
export 'src/stream_stats.dart';
