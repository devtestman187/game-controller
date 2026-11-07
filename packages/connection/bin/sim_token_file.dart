// The `--token-file` of the simulated tools: a pairing saved after the first
// connect, so a later run gets in without the pairing code.
import 'dart:convert';
import 'dart:io';

/// What a `--token-file` holds: the controller id the host knows, the host's
/// id (the client looks a token up by it) and the token the host gave.
typedef Pairing = ({String controllerId, String hostId, String token});

/// The pairing saved in [path], or null when the file isn't there yet (the
/// first run, which pairs with the code). It holds only the id, the host id
/// and the token: a file without all three is refused.
Pairing? readTokenFile(String path) {
  if (!File(path).existsSync()) return null;
  final Object? json;
  try {
    json = jsonDecode(_readText(path));
  } on FormatException catch (e) {
    throw FormatException('$path is not a saved pairing: ${e.message}');
  }
  if (json is! Map<Object?, Object?>) throw FormatException('$path is not a saved pairing');
  final id = json['id'];
  final host = json['host'];
  final token = json['token'];
  if (id is! String || id.isEmpty || host is! String || host.isEmpty || token is! String || token.isEmpty) {
    throw FormatException('$path is not a saved pairing (it needs "id", "host" and "token")');
  }
  return (controllerId: id, hostId: host, token: token);
}

/// The text of a token file, with the file system's own error as a message.
String _readText(String path) {
  try {
    return File(path).readAsStringSync();
  } on FileSystemException catch (e) {
    throw FormatException("Can't read $path: ${e.message}");
  }
}

/// Saves [pairing] to [path]. A failure is told to the user: the run itself
/// works without the file, only a later one can't use the saved pairing.
void writeTokenFile(String path, Pairing pairing) {
  final json = {'id': pairing.controllerId, 'host': pairing.hostId, 'token': pairing.token};
  try {
    File(path).writeAsStringSync(jsonEncode(json));
  } on FileSystemException catch (e) {
    stderr.writeln("  · Couldn't save the pairing to $path: ${e.message}");
  }
}
