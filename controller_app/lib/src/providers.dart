import 'package:connection/connection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

export 'providers/connection.dart';
export 'providers/device.dart';
export 'providers/feedback.dart';
export 'providers/game_feedback.dart';
export 'providers/haptics.dart';
export 'providers/metrics.dart';
export 'providers/pad.dart';

// The app's providers: each responsibility has a file of its own under
// providers/, exported here so every caller still imports this one file.
// The log buffer stays in this file on purpose: the debug build echoes every
// line to the console, and that console line is a leftover to remove on its
// own, not to copy into a new file with a split.

final logProvider = Provider<LogBuffer>((ref) {
  final log = LogBuffer();
  if (kDebugMode) {
    final sub = log.changes.listen((_) => debugPrint(log.lines.last.toString()));
    ref.onDispose(sub.cancel);
  }
  ref.onDispose(log.close);
  return log;
});

final logLinesProvider = NotifierProvider<LogLinesNotifier, List<LogLine>>(LogLinesNotifier.new);

class LogLinesNotifier extends Notifier<List<LogLine>> {
  @override
  List<LogLine> build() {
    final log = ref.watch(logProvider);
    final sub = log.changes.listen((_) => state = log.lines);
    ref.onDispose(sub.cancel);
    return log.lines;
  }
}
