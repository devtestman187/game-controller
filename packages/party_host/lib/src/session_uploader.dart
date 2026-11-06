import 'dart:convert';
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
  FirestoreUploader({required this.project, this.apiKey = '', HttpClient Function()? client})
    : _client = client ?? HttpClient.new;

  /// The Firebase project the stats go to.
  final String project;

  /// The project's web API key (optional for Firestore, which the security
  /// rules protect).
  final String apiKey;
  final HttpClient Function() _client;

  /// How long the upload may take to connect (M9: a phone's summary is
  /// small, so a slow network is a failure worth retrying later).
  static const connectTimeout = Duration(seconds: 10);

  /// How long the upload waits for the store's answer.
  static const responseTimeout = Duration(seconds: 20);

  @override
  Future<String?> upload(Map<String, Object?> summary) async {
    final id = summary['id'];
    if (id is! String || id.isEmpty) return 'no session ID';
    final uri = Uri.https('firestore.googleapis.com', '/v1/projects/$project/databases/(default)/documents/sessions', {
      'documentId': id,
      if (apiKey.isNotEmpty) 'key': apiKey,
    });
    final body = jsonEncode({
      'fields': {
        'json': {'stringValue': jsonEncode(summary)},
        'schema': {'integerValue': '${summary['schema']}'},
        'date': {'stringValue': '${summary['date']}'},
        'app': {'stringValue': '${(summary['host'] as Map?)?['app'] ?? ''}'},
        'host': {'stringValue': '${(summary['host'] as Map?)?['type'] ?? ''}'},
      },
    });
    final client = _client()..connectionTimeout = connectTimeout;
    try {
      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType.json;
      request.write(body);
      final response = await request.close().timeout(responseTimeout);
      final text = await response.transform(utf8.decoder).join();
      if (response.statusCode == 200) return null;
      if (response.statusCode == 409) return null; // Already uploaded.
      return 'HTTP ${response.statusCode}: ${text.length > 200 ? text.substring(0, 200) : text}';
    } catch (e) {
      return '$e';
    } finally {
      client.close();
    }
  }
}
