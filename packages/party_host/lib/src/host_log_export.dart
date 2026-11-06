import 'package:connection/connection.dart';

import 'host_view_state.dart';

/// The exported log: a header with the app, the time and each controller's
/// latency (PRD T8), then every log line, oldest first.
///
/// [now] is the time written in the header, so tests can fix it.
String buildLogExport(HostViewState state, LogBuffer log, {required DateTime now}) => throw UnimplementedError();

/// "avg 8 · p95 14 · max 30 ms (± 3 ms); session avg 9 ms", or why it isn't
/// measured.
String latencyText(ControllerInfo c) => throw UnimplementedError();
