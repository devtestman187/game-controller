part of 'host_server.dart';

/// The player numbers and characters a controller gets while it is paired
/// (M14 L7), and the numbers local players hold: the number a controller had
/// or the lowest free one, and the colour and accessory it asked for or the
/// nearest free ones.
///
/// Part of `host_server.dart`, so it reads the server's own sessions and
/// pairing book.
extension HostCharacterReservation on HostServer {
  /// Takes the lowest free player number for a local player.
  int reserveLocalPlayer() {
    final n = _pairings.reserveLocalPlayer(taken: _takenPlayerNumbers);
    _emit();
    return n;
  }

  /// Frees [number] after a local player left; the host emits only when it
  /// was taken.
  void releaseLocalPlayer(int number) {
    if (_pairings.releaseLocalPlayer(number)) _emit();
  }

  /// The player numbers the live paired sessions hold.
  Set<int> get _takenPlayerNumbers {
    final numbers = <int>{};
    for (final s in _sessions) {
      final number = s.player;
      if (s.paired && number != null) numbers.add(number);
    }
    return numbers;
  }

  /// The controller's number from before if it's still free, otherwise the
  /// lowest free one.
  int _reservePlayerNumber(int? previous) => _pairings.pickPlayer(previous, taken: _takenPlayerNumbers);

  /// The character [session]'s controller wears (M14 L7): the one it asked
  /// for, or the nearest free colour and accessory among the other paired
  /// controllers. A phone that sends none gets its number's default, so it
  /// still looks as it did before M14.
  PlayerCharacter _reserveCharacter(HostConnection session, PlayerCharacter? wanted) {
    final taken = <PlayerCharacter>[];
    for (final s in _sessions) {
      final character = s.character;
      if (s != session && s.paired && character != null) taken.add(character);
    }
    // A dropped player's pick stays taken for the reserve minute, as its number does.
    taken.addAll(_pairings.recentCharacters(except: session.hello?.controllerId ?? '', live: _liveIds));
    final number = session.player ?? 1;
    return (wanted ?? PlayerCharacter.forPlayer(number)).nearestFreeIn(taken);
  }
}
