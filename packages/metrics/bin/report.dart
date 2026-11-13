// The analytics report (PRD v2 M9): per-mode and per-device comparison
// tables, the host and frame-rate tables, and CSV, from session summaries.
//
//   cd packages/metrics
//   dart run metrics:report <folder or .json files>          # exported from the TV app
//   dart run metrics:report --firestore <project-id> --token "$(gcloud auth print-access-token)"
//   dart run metrics:report --paste diagnostics.txt           # a phone host's copied Diagnostics
//   ... --csv sessions.csv                                    # also write one CSV row per player and mode
//   ... --csv-rounds rounds.csv                               # also write one CSV row per round
//   ... --csv-stream stream.csv                               # also write one CSV row per streaming viewer
//
// The TV app's Stats screen exports the session files (Export), and with
// consent uploads them to Firestore, where only the developer can read them
// (the security rules allow apps to create documents, nothing else). A phone
// that hosts has neither: its last session leaves in the Diagnostics text,
// which --paste reads back (m12 §0.6).
import 'dart:convert';
import 'dart:io';

import 'package:metrics/metrics.dart';

const _usage = '''
Thumb Party analytics report.

Usage: dart run metrics:report [options] [folder or .json files ...]
  --firestore <project>  Download the uploaded sessions from this Firebase project
  --token <token>        OAuth access token for --firestore (gcloud auth print-access-token)
  --paste <file>         Read the sessions in a pasted text, such as a phone host's Diagnostics
  --csv <file>           Also write one CSV row per player and input mode
  --csv-rounds <file>    Also write one CSV row per round
  --csv-stream <file>    Also write one CSV row per streaming viewer
  --help                 This text

The by-mode tables count a row per mode: a player's view counts (frames,
gaps, late, touch ms) repeat on each of their mode rows. The tables after
them count each player once, and the frame-rate table counts rounds.

The Streaming section (M15) covers the sessions that streamed a game to a
screen. Its stages are milliseconds, each as median/p95:
  Streaming pipeline  input and host: the controller stages a summary already
                      has; capture, encode, send, network, jitter, decode and
                      display: the video's, in the order a frame goes through
                      them; total: capture to shown; press>screen: a press to
                      the frame that shows it; src: stages (added up from the
                      stages), measured (a probe measured the total) or probe
                      (the probe measured press to screen only).
  Independent check   the player's own read of the host's marker row (M15
                      fix8): the marker's glass time and its own press beside
                      the card's press and the chain's total, the two presses'
                      difference and a one-line verdict, the clock offset and
                      its uncertainty, the frames read and unreadable by
                      reason, and the rVFC fields the browser gave. A run
                      whose page read no marker row has no such table.
  Streaming quality   kbit/s sent and received, packet loss %, round trip and
                      jitter in ms, frames a second delivered, frames sent,
                      received, decoded, dropped and late, freezes (count and
                      ms), the first frame's time in ms, reconnects, whether a
                      relay was used, and the codec.
  Streaming sound     the audio capture-to-play delay (median/p95), the
                      audio/video sync offset in ms (signed, mean) and the
                      share of concealed audio (mean %).
  Streaming resources one container per session: CPU whole, game and encoder,
                      memory in MB, GPU, its encoder and its memory, the game's
                      frame rate and frame build and raster times, the
                      encoder's frame rate and queue, the time to the first
                      frame and the memory peak.
  Streaming by sessions at once  the same sessions grouped by how many ran on
                      the machine together, so capacity shows.''';

Future<void> main(List<String> args) async {
  String? project;
  String? token;
  String? csvPath;
  String? roundsPath;
  String? streamPath;
  String? pastePath;
  final paths = <String>[];
  for (var i = 0; i < args.length; i++) {
    String value() => i + 1 < args.length ? args[++i] : (throw FormatException('${args[i]} needs a value'));
    switch (args[i]) {
      case '--firestore':
        project = value();
      case '--token':
        token = value();
      case '--paste':
        pastePath = value();
      case '--csv':
        csvPath = value();
      case '--csv-rounds':
        roundsPath = value();
      case '--csv-stream':
        streamPath = value();
      case '--help' || '-h':
        stdout.writeln(_usage);
        return;
      default:
        paths.add(args[i]);
    }
  }
  if (project == null && pastePath == null && paths.isEmpty) {
    stderr.writeln('Give a folder of session files, --paste, or --firestore.\n\n$_usage');
    exit(64);
  }

  final summaries = <Map<String, Object?>>[];
  var skipped = 0;
  for (final path in paths) {
    summaries.addAll(await readSummaries(path));
  }
  if (pastePath != null) {
    if (!await File(pastePath).exists()) {
      stderr.writeln('No file at $pastePath');
      exit(66);
    }
    final pasted = summariesInPaste(await File(pastePath).readAsString());
    if (pasted.isEmpty) stderr.writeln('No session summaries found in $pastePath');
    summaries.addAll(pasted);
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
  if (roundsPath != null) {
    await File(roundsPath).writeAsString('${csvRounds(unique)}\n');
    stdout.writeln('Round CSV written to $roundsPath');
  }
  if (streamPath != null) {
    await File(streamPath).writeAsString('${streamCsv(unique)}\n');
    stdout.writeln('Stream CSV written to $streamPath');
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
