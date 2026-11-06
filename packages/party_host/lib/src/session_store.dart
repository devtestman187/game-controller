import 'dart:convert';
import 'dart:io';

import 'package:connection/connection.dart';
import 'package:metrics/metrics.dart';
import 'package:path/path.dart' as p;

import 'stats_service.dart';

/// The session summaries on the host's disk (PRD v2 T17, T18): writes the
/// running session (through a temporary file), lists the saved ones newest
/// first, and copies them to the export folder.
///
/// Split from [LiveStats], which decides when to save, upload or export. The
/// folders come from the host service's [HostDirectories] (S-g), so this class
/// has no platform code.
class SessionStore {
  /// [exportDirectory] is where Export copies the files; [now] names the
  /// exported folder and is injected so tests can fix it; [log] gets the
  /// short lines about a file that couldn't be written or read.
  SessionStore({required this.exportDirectory, required this.now, LogSink? log}) : _log = log ?? ((_) {});

  /// Where Export copies the session files.
  final Future<Directory> Function() exportDirectory;

  /// The clock the exported folder's name comes from.
  final DateTime Function() now;
  final LogSink _log;

  /// Writes [summary] to [path]; null means the host had no session folder,
  /// so nothing is saved. A failed write is logged (the session still plays).
  Future<void> save(String? path, Map<String, Object?> summary) async {
    if (path == null) return;
    try {
      final tmp = File('$path.tmp');
      await tmp.writeAsString(jsonEncode(summary));
      await tmp.rename(path);
    } catch (e) {
      _log('Stats: could not save the session: $e');
    }
  }

  /// The session files in [dir] with the current schema, newest first. A file
  /// that can't be read is skipped.
  Future<List<SessionFile>> sessions(Directory? dir) async {
    if (dir == null || !await dir.exists()) return const [];
    final files = await dir.list().where((e) => e is File && e.path.endsWith('.json')).cast<File>().toList();
    final out = <SessionFile>[];
    for (final f in files) {
      try {
        final json = jsonDecode(await f.readAsString());
        if (json is Map<String, Object?> && json['schema'] == summarySchema) out.add(SessionFile(f.path, json));
      } catch (e) {
        _log('Stats: could not read ${p.basename(f.path)}: $e');
      }
    }
    out.sort((a, b) => b.path.compareTo(a.path));
    return out;
  }

  /// Copies every session file in [dir] to a dated folder under
  /// [exportDirectory] and returns the folder's path (PRD v2 T18).
  Future<String> exportAll(Directory? dir) async {
    final base = await exportDirectory();
    final time = now();
    String two(int n) => n.toString().padLeft(2, '0');
    final folder = Directory(
      p.join(
        base.path,
        'thumb-party-sessions-${time.year}${two(time.month)}${two(time.day)}-${two(time.hour)}${two(time.minute)}',
      ),
    );
    await folder.create(recursive: true);
    final files = await sessions(dir);
    for (final f in files) {
      await File(f.path).copy(p.join(folder.path, p.basename(f.path)));
    }
    _log('Stats: exported ${files.length} session file${files.length == 1 ? '' : 's'} to ${folder.path}');
    return folder.path;
  }
}
