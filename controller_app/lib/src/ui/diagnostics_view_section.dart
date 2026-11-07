import 'package:connection/connection.dart';
import 'package:flutter/material.dart';

/// The "Game view" section of Diagnostics (m12-joined-view §5): what this
/// phone measured while a host showed it a game, one line per frame rate.
///
/// This is how the owner sends the phone measurement back: the same lines go
/// into the text "Copy report" shares ([viewReport]).
class DiagnosticsViewSection extends StatelessWidget {
  const DiagnosticsViewSection({super.key, required this.summary});

  /// One summary per frame rate this phone showed a game at.
  final Map<int, ViewSummary> summary;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Game view', style: text.titleMedium),
            const SizedBox(height: 4),
            for (final line in viewSummaryLines(summary))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: SelectableText(line, style: text.bodyMedium),
              ),
          ],
        ),
      ),
    );
  }
}

/// One line per frame rate, the fastest first, e.g. `60 Hz: touch-to-frame
/// 41 ms median, 58 ms p95 (1834 samples) · jitter 3/9 ms · frames 7210,
/// late 12, gaps 0`.
List<String> viewSummaryLines(Map<int, ViewSummary> summary) {
  final entries = summary.entries.toList()..sort((a, b) => b.key.compareTo(a.key));
  return [for (final MapEntry(key: hz, value: summary) in entries) viewSummaryLine(hz, summary)];
}

/// One frame rate's line: the wait from a touch to the frame that shows it,
/// the frames' jitter, and what was counted.
String viewSummaryLine(int hz, ViewSummary summary) {
  final touch = summary.touchToFrame;
  final jitter = summary.jitter;
  return '$hz Hz: touch-to-frame ${_ms(touch.medianMs)} median, ${_ms(touch.p95Ms)} p95 (${touch.count} samples) · '
      'jitter ${_bare(jitter.medianMs)}/${_bare(jitter.p95Ms)} ms · '
      'frames ${summary.frames}, late ${summary.late}, gaps ${summary.gaps}';
}

/// The "Game view" part of the report (m12 §5), empty when this phone was
/// shown no game, so the report only has the section when there is one.
String viewReport(Map<int, ViewSummary>? summary) {
  if (summary == null || summary.isEmpty) return '';
  return 'Game view:\n${viewSummaryLines(summary).map((line) => '  $line\n').join()}';
}

String _ms(int? value) => value == null ? '–' : '$value ms';

String _bare(int? value) => value == null ? '–' : '$value';
