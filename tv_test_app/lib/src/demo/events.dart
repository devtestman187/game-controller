import 'dart:convert';
import 'dart:io';

/// The director's event log for one take (docs/demo-video-runbook.md 2.3):
/// one JSON object per line, with the wall-clock time, written to
/// `<take>_events.jsonl` in the folder `DEMO_LOG_DIR` names. The edit cuts on
/// these times, so every event is appended as it happens.
final class EventLog {
  EventLog({required this.take, this.dir, DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final String take;

  /// Where the `.jsonl` goes; null keeps it in memory only (tests).
  final String? dir;

  final DateTime Function() _clock;
  final _events = <Map<String, Object?>>[];

  /// Everything logged so far, oldest first.
  List<Map<String, Object?>> get events => List.unmodifiable(_events);

  File? get file => dir == null ? null : File('$dir/${take}_events.jsonl');

  void add(String name, [Map<String, Object?>? data]) {
    final event = <String, Object?>{'wall': _clock().millisecondsSinceEpoch, 'name': name, ...?data};
    _events.add(event);
    file?.writeAsStringSync('${jsonEncode(event)}\n', mode: FileMode.append, flush: true);
  }

  /// The names logged, for tests.
  List<String> get names => [for (final e in _events) e['name'] as String];
}
