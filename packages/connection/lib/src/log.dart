import 'dart:async';
import 'dart:collection';

/// Where the host and client write human-readable log lines.
typedef LogSink = void Function(String message);

/// One log line with its time and source (e.g. `client`, `host`, `discovery`).
final class LogLine {
  LogLine(this.time, this.source, this.message);

  final DateTime time;
  final String source;
  final String message;

  @override
  String toString() => '${time.toIso8601String().substring(11, 23)} [$source] $message';
}

/// Keeps the most recent log lines in memory for the Diagnostics screen and
/// for sharing. Old lines are dropped once [capacity] is reached.
class LogBuffer {
  LogBuffer({this.capacity = 500});

  final int capacity;
  final _lines = ListQueue<LogLine>();
  final _changes = StreamController<void>.broadcast();

  /// Fires after every new line.
  Stream<void> get changes => _changes.stream;

  List<LogLine> get lines => List.unmodifiable(_lines);

  /// A [LogSink] that tags every line with [source].
  LogSink sink(String source) => (message) => add(source, message);

  void add(String source, String message) {
    _lines.addLast(LogLine(DateTime.now(), source, message));
    while (_lines.length > capacity) {
      _lines.removeFirst();
    }
    if (!_changes.isClosed) _changes.add(null);
  }

  /// All lines as plain text, oldest first.
  String export() => _lines.join('\n');

  Future<void> close() => _changes.close();
}
