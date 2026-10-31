/// Analytics for Thumb Party (PRD v2 M9): the phone's touch counters per
/// mode segment ([SegmentRecorder]), the host's session summary
/// ([SessionCollector]) and the report ([report], [csv]).
///
/// Pure Dart (no Flutter), so it runs in both apps, on the command line and
/// in `dart test`.
library;

export 'src/geometry.dart';
export 'src/report.dart';
export 'src/segment.dart';
export 'src/session.dart';
