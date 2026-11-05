import 'dart:io';

/// Where the work folder and the external tools come from (runbook E1/E3).
///
/// Nothing in the demo tooling names a user or a machine: the pipeline moves
/// between PCs (docs/demo-pc-move.md), so `WORK` is read from the environment
/// and ffmpeg/ffprobe are found on `PATH`. A missing tool or an unset `WORK`
/// says so instead of falling back to a path that exists on one computer only.
class DemoEnvError implements Exception {
  DemoEnvError(this.message);

  final String message;

  @override
  String toString() => message;
}

/// `$WORK`: the folder outside the repository that holds footage, logs and
/// backups (E4). Throws [DemoEnvError] with what to type when it is not set, so
/// a script fails before it writes anything.
String workDir([Map<String, String>? environment]) {
  final env = environment ?? Platform.environment;
  final work = (env['WORK'] ?? '').trim();
  if (work.isEmpty) {
    throw DemoEnvError(
      'WORK is not set. Point it at the work folder first, e.g. '
      'export WORK=\$HOME/thumbparty-demo in Git Bash, or '
      r'$env:WORK = "C:\Users\<you>\thumbparty-demo" in PowerShell '
      '(runbook E1/E3).',
    );
  }
  return work;
}

/// A path inside the work folder, in the platform's separator.
String workPath(String name, [Map<String, String>? environment]) =>
    '${workDir(environment)}${Platform.pathSeparator}$name';

/// The executable's path as `where`/`which` would report it, or null. Nothing
/// machine-specific is tried: only the directories in `PATH`.
String? findOnPath(String name, [Map<String, String>? environment]) {
  final env = environment ?? Platform.environment;
  final path = env['PATH'] ?? env['Path'] ?? '';
  if (path.trim().isEmpty) return null;
  for (final raw in path.split(Platform.isWindows ? ';' : ':')) {
    var dir = raw.trim();
    if (dir.length >= 2 && dir.startsWith('"') && dir.endsWith('"')) {
      dir = dir.substring(1, dir.length - 1);
    }
    if (dir.isEmpty) continue;
    for (final file in _candidates(name, env)) {
      final candidate = dir.endsWith(Platform.pathSeparator)
          ? '$dir$file'
          : '$dir${Platform.pathSeparator}$file';
      if (File(candidate).existsSync()) return candidate;
    }
  }
  return null;
}

/// [name], then [name] with each executable extension: `PATHEXT` on Windows
/// (`;.COM;.EXE;.BAT;.CMD`), nothing elsewhere.
List<String> _candidates(String name, Map<String, String> env) {
  if (!Platform.isWindows) return [name];
  final extensions = (env['PATHEXT'] ?? '.COM;.EXE;.BAT;.CMD')
      .split(';')
      .map((extension) => extension.trim().toLowerCase())
      .where((extension) => extension.isNotEmpty);
  return [name, for (final extension in extensions) '$name$extension'];
}

/// The tool's path, or a [DemoEnvError] that names the tool and the fix.
String toolOnPath(String name, [Map<String, String>? environment]) {
  final found = findOnPath(name, environment);
  if (found != null) return found;
  throw DemoEnvError(
    '$name is not on PATH. Install it (runbook E2) or add its folder to PATH; '
    'there is no machine-specific fallback.',
  );
}

/// Git Bash, for the shell scripts the showrunner calls (`emulator.sh
/// connect`).
///
/// `bash` is not on the PATH of a Windows session even where Git Bash is
/// installed (measured Nov 5, 2026: `bash tools/emulator.sh connect` threw
/// "The system cannot find the file specified" and lost every M1 retake), so
/// `BASH`, then the two usual Git install folders, then `bash` on the PATH.
String get bashBinary {
  final fromEnv = Platform.environment['BASH'];
  if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;
  for (final candidate in const [
    r'C:\Program Files\Git\bin\bash.exe',
    r'C:\Program Files\Git\usr\bin\bash.exe',
  ]) {
    if (File(candidate).existsSync()) return candidate;
  }
  return 'bash';
}

/// The `--self-test` check for `$WORK`: an unset or blank value is an error
/// that names WORK, and a set value is used as given.
void workDirSelfTest(void Function(String what, bool pass) check) {
  try {
    final work = workDir({'WORK': '   '});
    check('an unset WORK is an error (got "$work")', false);
  } on DemoEnvError catch (e) {
    check('an unset WORK is an error: $e', e.message.contains('WORK'));
  }
  check(
    r'WORK is used as given: D:\work',
    workDir({'WORK': r'D:\work'}) == r'D:\work',
  );
}

/// The `--self-test` checks for the tool lookup: a tool that is on PATH is
/// found, one that is not is null, and a missing tool is an error rather than
/// a fallback path.
void toolLookupSelfTest(void Function(String what, bool pass) check) {
  final temp = Directory.systemTemp.createTempSync('demo_paths_');
  try {
    final name = Platform.isWindows ? 'demo_tool.exe' : 'demo_tool';
    final tool = File('${temp.path}${Platform.pathSeparator}$name')
      ..writeAsStringSync('');
    final env = {'PATH': temp.path};
    check(
      'a tool on PATH is found: ${findOnPath('demo_tool', env)}',
      findOnPath('demo_tool', env) == tool.path,
    );
    check(
      'a tool that is not on PATH is null',
      findOnPath('demo_tool_missing', env) == null,
    );
    try {
      toolOnPath('demo_tool_missing', env);
      check('a missing tool is an error, not a fallback path', false);
    } on DemoEnvError {
      check('a missing tool is an error, not a fallback path', true);
    }
  } finally {
    try {
      temp.deleteSync(recursive: true);
    } on Object {
      // A leftover temp folder is harmless.
    }
  }
}
