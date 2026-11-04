import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Prints the TV's game port and pairing code from the demo director
/// (runbook 2.6/2.7): `{"t":"hello"}` on ws://127.0.0.1:47900/director.
Future<void> main() async {
  final socket = await WebSocket.connect('ws://127.0.0.1:47900/director')
      .timeout(const Duration(seconds: 10));
  socket.add(jsonEncode({'t': 'hello'}));
  final reply = jsonDecode(await socket.first.timeout(const Duration(seconds: 10)) as String) as Map<String, dynamic>;
  if (reply['t'] != 'state') {
    stderr.writeln('unexpected reply: $reply');
    exit(1);
  }
  stdout.writeln('${reply['port']} ${reply['code']}');
  await socket.close();
}
