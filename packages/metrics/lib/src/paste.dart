import 'dart:convert';

import 'session.dart';

/// The line before a session summary in a phone host's Diagnostics text (m12
/// §0.6): the phone writes it and the report finds the summary by it.
const sessionSummaryMarker = 'Session summary (for the report):';

/// Every session summary in a pasted Diagnostics text (m12 §0.6): the line
/// with [sessionSummaryMarker] and the JSON on the line after it, for each one
/// the text holds.
///
/// The rest of the text, and a marker whose next line isn't a summary of this
/// schema, are skipped: a pasted chat message or bug report works as it is.
List<Map<String, Object?>> summariesInPaste(String text) {
  final lines = const LineSplitter().convert(text);
  final out = <Map<String, Object?>>[];
  for (var i = 0; i + 1 < lines.length; i++) {
    if (lines[i].trim() != sessionSummaryMarker) continue;
    try {
      final json = jsonDecode(lines[i + 1].trim());
      if (json is Map<String, Object?> && json['schema'] == summarySchema) out.add(json);
    } on FormatException {
      // Junk after a marker is not a failure: the owner pastes a whole text.
    }
  }
  return out;
}
