import 'package:metrics/metrics.dart';
import 'package:test/test.dart';

/// A Diagnostics text as the phone app builds it (m12 §0.6): the report's own
/// lines, two session summaries, and junk a chat app may add.
String diagnosticsText() => '''
Controller diagnostics, 2026-11-07T10:00:00.000
Connection: connected, TV Android TV, 192.168.1.50 port 45780, ping 9 ms
Session summary (for the report):
{"schema":1,"id":"ph-1","host":{"type":"phone"},"rounds":[]}
Gyro: dpad, available, side landscapeRight
Session summary (for the report):
{"schema":1,"id":"ph-2","host":{"type":"phone"},"rounds":[]}
[10:00:03] the app closed
''';

void main() {
  group('a pasted Diagnostics text (m12 §0.6)', () {
    test('gives every session it holds, junk lines and all', () {
      final summaries = summariesInPaste(diagnosticsText());
      expect([for (final s in summaries) s['id']], ['ph-1', 'ph-2']);
      expect(summaries.first['schema'], summarySchema);
    });

    test('a marker whose next line is not a summary of this schema is skipped', () {
      final text = [
        sessionSummaryMarker,
        'this line is not JSON',
        sessionSummaryMarker,
        '{"schema":2,"id":"from-a-newer-app"}',
        sessionSummaryMarker,
        '{"schema":1,"id":"ph-3"}',
      ].join('\n');
      expect([for (final s in summariesInPaste(text)) s['id']], ['ph-3']);
    });

    test('a marker on the last line, and a text with no marker, hold nothing', () {
      expect(summariesInPaste('just text\n$sessionSummaryMarker'), isEmpty);
      expect(summariesInPaste('a session file was exported to D:/Downloads'), isEmpty);
      expect(summariesInPaste(''), isEmpty);
    });

    test("the JSON may be indented, as a chat app's line wrapping leaves it", () {
      final text = '  $sessionSummaryMarker  \n  {"schema":1,"id":"ph-4"}  \n';
      expect([for (final s in summariesInPaste(text)) s['id']], ['ph-4']);
    });
  });
}
