/// Host server and controller client for the game controller: WebSocket
/// transport, pairing, heartbeats and automatic reconnect.
///
/// Pure Dart (`dart:io`), so it runs in both Flutter apps, in the
/// command-line simulated controller and in `dart test` on Windows and CI.
library;

export 'src/client_controls.dart'
    show HostAway, HostBack, PlayerAway, PlayerBack, ViewEnded, ViewEvent, ViewFrame, ViewStarted;
export 'src/client_types.dart' hide sameStrings;
export 'src/controller_client.dart';
export 'src/controller_identity.dart';
export 'src/demo_input.dart';
export 'src/game_host.dart' show GameHost, PlayerLatency;
export 'src/game_types.dart' show AwayEnd, AwayEnded, GamePlayer, GameRecord, LatencyStage, StageSample;
export 'src/gamepad.dart';
export 'src/host_address.dart';
export 'src/host_server.dart';
export 'src/host_types.dart';
export 'src/latency.dart';
export 'src/local_player.dart' show LocalPlayer;
export 'src/log.dart' hide noLog;
export 'src/memory_game_host.dart' show MemoryGameHost;
export 'src/rtt.dart';
export 'src/saved_pairing.dart';
export 'src/server_game_host.dart' show ServerGameHost;
export 'src/transport/channel_listener.dart';
export 'src/transport/connector.dart';
export 'src/transport/in_process_connector.dart';
export 'src/transport/in_process_link.dart';
export 'src/transport/in_process_listener.dart';
export 'src/transport/message_channel.dart';
export 'src/transport/web_socket_channel.dart';
export 'src/transport/web_socket_connector.dart';
export 'src/transport/web_socket_listener.dart';
export 'src/viewer_stats.dart';
export 'src/viewer_timing.dart';
