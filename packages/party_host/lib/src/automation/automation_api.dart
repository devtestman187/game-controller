/// What the automation HTTP server asks the host to do (M15 a2). The server
/// owns the wire (paths, JSON, the token); this owns the actions, so a test
/// can drive either side on its own.
///
/// Every call takes the request body as it was decoded, validated here where
/// the host knows what it has: a body it can't use throws [AutomationError]
/// with a short plain message, which the server sends as a 400.
abstract interface class AutomationApi {
  /// The app's version, host type, the screen now, whether a round runs, the
  /// players, the pairing code, the controller and automation ports, and
  /// whether the host is ready for a session.
  Map<String, Object?> status();

  /// Adds a simulated player, or removes one with `remove`.
  Map<String, Object?> players(Map<String, Object?> body);

  /// A press, a release or a stick position for a simulated player.
  Map<String, Object?> input(Map<String, Object?> body);

  /// Starts a game without the menus.
  Map<String, Object?> startGame(Map<String, Object?> body);

  /// Stops the game a round is running, back to the home screen.
  Map<String, Object?> stopGame();

  /// The look, the frame rate, sound and the stats answer.
  Map<String, Object?> settings(Map<String, Object?> body);

  /// The current round: its game and its latest frame (the JSON a viewer
  /// draws), and the result of the round that ended last.
  Map<String, Object?> state();

  /// Shows or hides the latency test card.
  void flashProbe({required bool on});

  /// Injects a press for a simulated player and returns the host's clock at
  /// that moment, so a viewer can time press to pixel change.
  Map<String, Object?> pressProbe(Map<String, Object?> body);

  /// Feeds a viewer's stream measurements to the session collector and
  /// returns the viewer id they went to.
  Map<String, Object?> ingestStream(Map<String, Object?> body);

  /// The live session's summary so far, or null when no session runs.
  Map<String, Object?> session();

  /// A PNG of the host's frame, or null where the platform can't draw one
  /// (a host with no rendering surface, or a frame not drawn yet).
  Future<List<int>?> screenshotPng();
}

/// A request the host can't use: the server turns it into a 400 with the
/// message, which says what to change.
final class AutomationError implements Exception {
  const AutomationError(this.message);

  /// What was wrong, in words an 8-year-old reads (coding guidelines §7).
  final String message;

  @override
  String toString() => message;
}
