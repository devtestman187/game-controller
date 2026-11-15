import 'stats_state.dart';

/// A saved session summary: one JSON file on the host (PRD v2 T17).
final class SessionFile {
  const SessionFile(this.path, this.summary);

  /// The file's full path.
  final String path;

  /// The summary as it was saved, with the schema number in `schema`.
  final Map<String, Object?> summary;

  /// The session ID, which the upload queue uses to skip files it already
  /// sent.
  String get id => summary['id'] as String? ?? '';
}

/// What the host screens need from the analytics. A fake implements it in
/// tests.
abstract class StatsService {
  /// What the Stats screen shows.
  StatsState get state;

  /// Fires on every change to [state].
  Stream<StatsState> get changes;

  /// Saved sessions, newest first (PRD v2 T18).
  Future<List<SessionFile>> sessions();

  /// Copies every session file to the export folder and returns its path
  /// (PRD v2 T18).
  Future<String> exportAll();

  /// The adult's answer to the consent prompt, or a change in Stats.
  void setConsent(bool share);

  /// Tries the upload queue now (PRD v2 T19).
  Future<void> uploadNow();

  /// The host app is no longer in front, so the session ends now and its file
  /// is saved and queued (B-019): a hidden app's timers stop, and waiting out
  /// the session gap would leave the record on disk until the next start.
  Future<void> pause();

  /// The host app is in front again (B-019): retries the queue [pause] left.
  Future<void> resume();
}
