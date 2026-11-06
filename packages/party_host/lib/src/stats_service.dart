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
  String get id => throw UnimplementedError();
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
}
