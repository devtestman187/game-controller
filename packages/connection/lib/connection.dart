/// Host server and controller client for the game controller: WebSocket
/// transport, pairing, heartbeats and automatic reconnect.
///
/// Pure Dart (`dart:io`), so it runs in both Flutter apps, in the
/// command-line simulated controller and in `dart test` on Windows and CI.
library;

export 'src/controller_client.dart';
export 'src/host_address.dart';
export 'src/host_server.dart';
export 'src/log.dart';
