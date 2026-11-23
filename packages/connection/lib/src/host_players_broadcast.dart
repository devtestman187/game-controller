part of 'host_server.dart';

/// Who wears what, on the phones (M16 identity): the `players` message, the
/// characters a frame carries, and the round gate on a character change.
///
/// Part of `host_server.dart`, so it reads the server's own sessions and the
/// characters their controllers were given.
extension HostPlayersBroadcast on HostServer {
  /// One row for each paired controller, by number: the ID and number a frame
  /// uses, the nickname it shows, and the character it wears.
  List<PlayerRow> get playerRows {
    final rows = <PlayerRow>[];
    for (final s in _sessions) {
      final hello = s.hello;
      final number = s.player;
      final character = s.character;
      if (!s.paired || hello == null || number == null || character == null) continue;
      rows.add((id: hello.controllerId, number: number, name: nicknameOf(hello.name) ?? '', character: character));
    }
    rows.sort((a, b) => a.number.compareTo(b.number));
    return rows;
  }

  /// Sends `players` to every paired controller that listed
  /// [Capability.identity]: on joining, on leaving and when a player's
  /// character changes. A phone without the capability hears none of them.
  void broadcastPlayers() => sendToAll(PlayersMessage(players: playerRows));

  /// A round started: a character its players ask for now waits until
  /// [roundEnded], so a running round's players never change (M16 identity).
  void roundStarted() => _roundRunning = true;

  /// The round ended: the characters its players asked for during it take
  /// effect, and every phone hears how the players look now.
  void roundEnded() {
    _roundRunning = false;
    var changed = false;
    for (final s in _sessions.toList()) {
      if (s.heldCharacter case final wanted?) {
        if (_wear(s, wanted)) changed = true;
      }
    }
    if (changed) broadcastPlayers();
  }

  /// The player of [session] chose another character (M16 identity): in the
  /// lobby and between rounds it applies at once, during a round it waits,
  /// because a running round's players never change.
  void characterChosen(HostConnection session, PlayerCharacter wanted) {
    if (!session.paired) return;
    if (_roundRunning) {
      session.heldCharacter = wanted;
      _log('${session.who} wants another character: it takes effect next round');
      return;
    }
    if (_wear(session, wanted)) broadcastPlayers();
  }

  /// Gives [session]'s player [wanted], or the nearest free one when another
  /// player wears it, and says which in a `player` message. True when it
  /// changed how they look.
  bool _wear(HostConnection session, PlayerCharacter wanted) {
    session.heldCharacter = null;
    final number = session.player;
    if (number == null) return false;
    final before = session.character;
    session.character = _reserveCharacter(session, wanted);
    _log('${session.who} now wears ${session.character?.id}');
    session.send(PlayerMessage(number: number, character: session.character));
    if (session.character == before) return false;
    _emit();
    return true;
  }
}

/// True when the phone of [session] listed [Capability.identity] in its hello,
/// so it may be sent the characters a frame carries (M16 identity).
bool _takesIdentity(HostConnection session) => session.hello?.supports(Capability.identity) ?? false;

/// Sends [message] to [sessions], encoding it once (a frame at 60 Hz to
/// several viewers is why, m12 §2). A frame that carries characters goes
/// twice: with them to the phones that listed [Capability.identity] and
/// without to the rest, so a phone one build older gets today's frame.
/// Returns how many controllers it went to.
int _sendToAll(HostServer server, List<HostConnection> sessions, Message message) {
  if (message is! FrameMessage || message.characters.isEmpty) return _encodeTo(server, sessions, message);
  final identity = <HostConnection>[];
  final others = <HostConnection>[];
  for (final s in sessions) {
    (_takesIdentity(s) ? identity : others).add(s);
  }
  var sent = 0;
  if (identity.isNotEmpty) sent += _encodeTo(server, identity, message);
  if (others.isNotEmpty) sent += _encodeTo(server, others, _withoutCharacters(message));
  return sent;
}

/// Encodes [message] once and hands the same text to [sessions]. Returns how
/// many controllers it went to: none when it can't be encoded, which leaves
/// the host running.
int _encodeTo(HostServer server, List<HostConnection> sessions, Message message) {
  if (sessions.isEmpty) return 0;
  final String text;
  try {
    text = HostServer._codec.encode(message);
  } catch (e) {
    // A payload that can't be encoded (a game snapshot with something that
    // isn't JSON) goes to nobody, and the host carries on.
    server._log('Could not encode ${message.type} for ${sessions.length} controller(s): $e');
    return 0;
  }
  for (final s in sessions) {
    s.sendText(text);
  }
  return sessions.length;
}

/// [message] as [session] may see it (M16 identity): a frame's `chars` go only
/// to a controller that listed [Capability.identity], so every other phone
/// gets the frame it has always had.
Message _forSession(HostConnection session, Message message) {
  if (message is! FrameMessage || message.characters.isEmpty) return message;
  if (_takesIdentity(session)) return message;
  return _withoutCharacters(message);
}

/// [frame] without its characters, a field a phone without the identity
/// capability never learned.
FrameMessage _withoutCharacters(FrameMessage frame) => FrameMessage(
  n: frame.n,
  atMs: frame.atMs,
  snapshot: frame.snapshot,
  sounds: frame.sounds,
  acks: frame.acks,
  roster: frame.roster,
  timeLeftMs: frame.timeLeftMs,
);
