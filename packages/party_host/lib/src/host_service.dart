import 'package:connection/connection.dart';

import 'host_view_state.dart';
import 'stats_service.dart';

/// What the host screens need from the host: the server, its advertising, the
/// game host and the stats (PRD v2 M12, design B1).
///
/// It was `HostController` in the TV app up to M11; the rename makes room for
/// the phone's own host mode. A fake implements it in tests.
abstract class HostService {
  /// Everything the host screens show.
  HostViewState get state;

  /// Fires whenever [state] changes.
  Stream<HostViewState> get changes;

  /// Makes a new pairing code, so phones need the code again (PRD T5).
  void newPairingCode();

  /// How many simulated controllers can run at once.
  static const maxSims = 3;

  /// Adds a simulated controller (up to [maxSims]): it pairs on its own and
  /// presses every button in a loop (M11).
  void addSimulatedController();

  /// Stops every simulated controller.
  void stopSimulatedControllers();

  /// Drops every controller, so each must enter the pairing code again.
  void dropAllConnections();

  /// Forgets paired phones that aren't connected, so they need the code
  /// again. Returns how many were forgotten.
  int forgetPairings();

  /// Saves the log (with a latency summary on top) to a file and returns its
  /// path (PRD T8).
  Future<String> exportLog();

  /// What every game and test screen uses (PRD v2 P3): players, their
  /// gamepads, haptics, latency and analytics records.
  GameHost get gameHost;

  /// Analytics collection, the session files, consent and upload (M9).
  StatsService get stats;

  /// Sounds the games ask for by name (PRD v2 S5), for the sound player.
  Stream<String> get gameSounds;

  /// Stops everything and releases the port.
  Future<void> dispose();
}
