/// How this host's automation interface is switched on (M15 a2, the owner's
/// rule of Nov 11, 2026): one API for every build, off unless a launch tells
/// it otherwise, and never on in a store build.
///
/// The values come from the shell, which alone may read the environment and
/// the build's defines (`--dart-define=AUTOMATION`), so `party_host` has no
/// platform code (coding guidelines §1). [enabled] is false by default, which
/// is what a store build and every ordinary launch get: the code is compiled
/// in, and inert until a launch says otherwise.
final class AutomationSettings {
  const AutomationSettings({
    this.enabled = false,
    this.bindAddress = loopbackAddress,
    this.port = defaultPort,
    this.token = '',
    this.controllerPort,
    this.statsConsent,
    this.marker = false,
  });

  /// The address the interface listens on unless told otherwise: this machine
  /// only, so nothing on the network can reach it.
  static const loopbackAddress = '127.0.0.1';

  /// The port the interface listens on unless told otherwise.
  static const defaultPort = 8787;

  /// The environment variables a launch sets (desktop hosts; a phone passes
  /// the build define instead, since it has no environment of its own).
  static const envEnabled = 'THUMBPARTY_AUTOMATION';
  static const envBind = 'THUMBPARTY_AUTOMATION_BIND';
  static const envToken = 'THUMBPARTY_AUTOMATION_TOKEN';
  static const envPort = 'THUMBPARTY_AUTOMATION_PORT';

  /// What the value of [envEnabled] must be to switch it on.
  static const enabledValue = '1';

  /// The controller port a launch may pin (job c1's finding): the host listens
  /// on exactly this port, and fails loudly if it is taken, instead of taking
  /// any free one. Unset asks for today's behaviour.
  static const envControllerPort = 'THUMBPARTY_PORT';

  /// Answers the first-run stats question at start (job c1's finding): `no`
  /// keeps the home screen clear in a session without a person. There is no
  /// value that answers yes: sharing stays an adult's choice.
  static const envStatsConsent = 'THUMBPARTY_STATS_CONSENT';
  static const statsConsentNo = 'no';

  /// Whether the app draws the marker row into its picture (M15 fix8), from
  /// `THUMBPARTY_MARKER=1`, which a session's `SESSION_MARKER=on` passes. A
  /// bench measurement of the stream's own latency (docs/streaming-marker.md);
  /// off in every other launch, and a phone's build has no environment to say
  /// otherwise.
  static const envMarker = 'THUMBPARTY_MARKER';

  /// Whether the interface runs at all.
  final bool enabled;

  /// The address it listens on ([loopbackAddress] unless a launch says
  /// otherwise).
  final String bindAddress;

  /// The port it listens on; 0 asks the system for a free one (tests do).
  final int port;

  /// The shared token every request must carry, or '' for none. Required
  /// whenever [bindAddress] isn't loopback ([problem] says so).
  final String token;

  /// The port the controller server is pinned to, or null for any free one.
  final int? controllerPort;

  /// The answer to give the first-run stats question at start, or null to
  /// leave it to the person at the host.
  final bool? statsConsent;

  /// Whether the app draws the marker row over its picture (M15 fix8), so a
  /// player can read frames and the host's clock out of the video. False in
  /// every ordinary launch.
  final bool marker;

  /// The settings a launch asks for, from its environment and its build.
  ///
  /// [env] reads a variable, and the shell passes the platform's environment
  /// (a test passes a map); [buildEnabled] is the build's
  /// `--dart-define=AUTOMATION`. Everything else is read here.
  factory AutomationSettings.fromSources({required String? Function(String) env, bool buildEnabled = false}) {
    final switched = env(envEnabled)?.trim() == enabledValue;
    final bind = env(envBind)?.trim();
    final port = _portOf(env(envPort));
    return AutomationSettings(
      enabled: buildEnabled || switched,
      bindAddress: bind == null || bind.isEmpty ? loopbackAddress : bind,
      port: port ?? defaultPort,
      token: (env(envToken) ?? '').trim(),
      controllerPort: _portOf(env(envControllerPort)),
      statsConsent: switch (env(envStatsConsent)?.trim().toLowerCase()) {
        statsConsentNo => false,
        _ => null,
      },
      marker: env(envMarker)?.trim() == enabledValue,
    );
  }

  /// Whether the interface only listens on this machine.
  bool get isLoopback => bindAddress == loopbackAddress;

  /// Why these settings can't be used, or null when they can. A bind beyond
  /// this machine without a token would let anyone on the network drive the
  /// host, so it is refused rather than started weakly.
  String? get problem {
    if (!enabled) return null;
    if (!isLoopback && token.isEmpty) {
      return 'automation listens on $bindAddress, so it needs a token ($envToken)';
    }
    return null;
  }

  /// Whether a request carrying [given] may be served. A launch with no token
  /// accepts any request on its loopback address ([problem] refuses a bind
  /// beyond the machine without one).
  bool authorized(String? given) => token.isEmpty || given == token;

  /// The settings a test or a shell reads back, without the token.
  Map<String, Object?> describe() => {
    'enabled': enabled,
    'bind': bindAddress,
    'port': port,
    'token': token.isEmpty ? 'none' : 'set',
    if (controllerPort != null) 'controllerPort': controllerPort,
    if (statsConsent != null) 'statsConsent': statsConsent,
    'marker': marker,
  };

  /// A whole port number from [raw], or null when it isn't one.
  static int? _portOf(String? raw) {
    final text = raw?.trim();
    if (text == null || text.isEmpty) return null;
    final port = int.tryParse(text);
    if (port == null || port < 0 || port > maxPort) return null;
    return port;
  }

  /// The highest port number a socket takes.
  static const maxPort = 65535;
}
