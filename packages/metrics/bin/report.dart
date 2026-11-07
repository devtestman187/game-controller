// The analytics report (PRD v2 M9): per-mode and per-device comparison
// tables, and CSV, from session summaries.
//
//   cd packages/metrics
//   dart run metrics:report <folder or .json files>          # exported from the TV app
//   dart run metrics:report --firestore <project-id> --token "$(gcloud auth print-access-token)"
//   ... --csv sessions.csv                                    # also write one CSV row per player and mode
//
// The TV app's Stats screen exports the session files (Export), and with
// consent uploads them to Firestore, where only the developer can read them
// (the security rules allow apps to create documents, nothing else).
import 'dart:convert';
import 'dart:io';

import 'package:metrics/metrics.dart';

const _usage = '''
Thumb Party analytics report.

Usage: dart run metrics:report [options] [folder or .json files ...]
  --firestore <project>  Download the uploaded sessions from this Firebase project
  --token <token>        OAuth access token for --firestore (gcloud auth print-access-token)
  --csv <file>           Also write one CSV row per player and input mode
  --help                 This text''';

Future<void> main(List<String> args) async {
  String? project;
  String? token;
  String? csvPath;
  final paths = <String>[];
  for (var i = 0; i < args.length; i++) {
    String value() => i + 1 < args.length ? args[++i] : (throw FormatException('${args[i]} needs a value'));
    switch (args[i]) {
      case '--firestore':
        project = value();
      case '--token':
        token = value();
      case '--csv':
        csvPath = value();
      case '--help' || '-h':
        stdout.writeln(_usage);
        return;
      default:
        paths.add(args[i]);
    }
  }
  if (project == null && paths.isEmpty) {
    stderr.writeln('Give a folder of session files, or --firestore.\n\n$_usage');
    exit(64);
  }

  final summaries = <Map<String, Object?>>[];
  var skipped = 0;
  for (final path in paths) {
    summaries.addAll(await readSummaries(path));
  }
  if (project != null) {
    if (token == null) {
      stderr.writeln('--firestore needs --token (run: gcloud auth print-access-token)');
      exit(64);
    }
    final downloaded = await downloadSummaries(project, token);
    summaries.addAll(downloaded.summaries);
    skipped = downloaded.skipped;
  }
  // The same session can be both exported and uploaded.
  final unique = {for (final s in summaries) s['id']: s}.values.toList();

  stdout.writeln('${unique.length} session${unique.length == 1 ? '' : 's'}\n');
  stdout.writeln(report(unique));
  if (csvPath != null) {
    await File(csvPath).writeAsString('${csv(unique)}\n');
    stdout.writeln('CSV written to $csvPath');
  }
  if (skipped > 0) stderr.writeln("Skipped $skipped summaries that couldn't be read");
}

/// Every session summary in a file or folder (non-summaries are skipped).
Future<List<Map<String, Object?>>> readSummaries(String path) async {
  final type = await FileSystemEntity.type(path);
  final files = switch (type) {
    FileSystemEntityType.directory => await Directory(
      path,
    ).list(recursive: true).where((e) => e is File && e.path.endsWith('.json')).cast<File>().toList(),
    FileSystemEntityType.file => [File(path)],
    _ => <File>[],
  };
  if (files.isEmpty) stderr.writeln('No session files at $path');
  final out = <Map<String, Object?>>[];
  for (final f in files) {
    try {
      final json = jsonDecode(await f.readAsString());
      if (json is Map<String, Object?> && json['schema'] == summarySchema) out.add(json);
    } catch (e) {
      stderr.writeln('Skipping ${f.path}: $e');
    }
  }
  return out;
}

/// The uploaded sessions, through the Firestore REST API. [skipped] counts
/// the documents whose summary text isn't valid JSON.
Future<({List<Map<String, Object?>> summaries, int skipped})> downloadSummaries(String project, String token) async {
  final client = HttpClient();
  final out = <Map<String, Object?>>[];
  var skipped = 0;
  String? pageToken;
  try {
    do {
      final uri = Uri.https(
        'firestore.googleapis.com',
        '/v1/projects/$project/databases/(default)/documents/sessions',
        {'pageSize': '300', 'pageToken': ?pageToken},
      );
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode != 200) {
        stderr.writeln('Firestore answered ${response.statusCode}: $body');
        exit(1);
      }
      final json = jsonDecode(body) as Map<String, Object?>;
      for (final doc in (json['documents'] as List?) ?? const []) {
        final text = (((doc as Map)['fields'] as Map?)?['json'] as Map?)?['stringValue'];
        if (text is! String) continue;
        try {
          final summary = jsonDecode(text);
          if (summary is Map<String, Object?>) out.add(summary);
        } on FormatException {
          // The summary is counted and reported at the end, not printed for
          // each document.
          skipped++;
        }
      }
      pageToken = json['nextPageToken'] as String?;
    } while (pageToken != null);
  } finally {
    client.close();
  }
  return (summaries: out, skipped: skipped);
}
