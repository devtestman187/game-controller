import 'dart:io';

/// Sends one session summary to the cloud store.
abstract class SessionUploader {
  /// Null on success (or if it was already there), otherwise why it failed.
  Future<String?> upload(Map<String, Object?> summary);
}

/// Firestore through its REST API, the same code on every host type (PRD v2
/// T19). Each session is one document in `sessions`, named by its ID, holding
/// the summary as JSON text plus a few fields the security rules check
/// (firebase/firestore.rules). The rules let apps create documents and
/// nothing else: no reads, no changes.
class FirestoreUploader implements SessionUploader {
  /// [project] and [apiKey] come from the shell's own build-time constants,
  /// so `party_host` holds no project or key of its own (S-e). [client] lets
  /// a test point it at a local server instead of Google.
  FirestoreUploader({required this.project, this.apiKey = '', HttpClient Function()? client});

  /// The Firebase project the stats go to.
  final String project;

  /// The project's web API key (optional for Firestore, which the security
  /// rules protect).
  final String apiKey;

  @override
  Future<String?> upload(Map<String, Object?> summary) => throw UnimplementedError();
}
