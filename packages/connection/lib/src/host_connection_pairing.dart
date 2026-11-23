part of 'host_connection.dart';

/// The hello, the pair request and the pairing's acceptance of one [HostConnection].
///
/// Part of `host_connection.dart`, so it reads the connection's own fields. The members moved here unchanged to
/// keep that file under its size cap.
extension HostConnectionPairing on HostConnection {
  void _onHello(HelloMessage hello) {
    if (this.hello != null) return close(CloseCodes.protocolError, 'Duplicate hello');
    this.hello = hello;
    final caps = hello.capabilities.isEmpty ? '' : ', supports ${hello.capabilities.join(', ')}';
    _host.log(
      '${hello.name} (${hello.platform} ${hello.appVersion}$caps) says hello from ${remoteAddress ?? localPeerLabel}',
    );
    final details = _host.details;
    send(
      WelcomeMessage(
        hostId: details.hostId,
        hostName: details.hostName,
        appVersion: details.appVersion,
        capabilities: details.capabilities,
      ),
    );
    _host.emit();
  }

  void _onPair(PairRequestMessage request) {
    final hello = this.hello;
    if (hello == null) return close(CloseCodes.protocolError, 'Pair request before hello');
    final book = _host.pairingBook;
    if (paired) {
      send(PairResultMessage.accepted(token: book.known(hello.controllerId)!.token));
      return;
    }

    final token = request.token;
    if (token != null) {
      if (book.known(hello.controllerId)?.token == token) {
        _accept(token, how: 'saved pairing');
      } else {
        _host.log('${hello.name}: saved pairing not recognized, waiting for the code');
        send(const PairResultMessage.refused(PairFailure.unknownToken));
      }
      return;
    }

    if (request.code == book.code) {
      book.clearWrongCodes();
      _accept(book.newToken(), how: 'pairing code');
      return;
    }

    if (book.countWrongCode()) {
      _host.log('${hello.name}: wrong code, ${book.maxWrongCodes} in a row. New pairing code ${book.code}');
      send(const PairResultMessage.refused(PairFailure.tooManyAttempts));
    } else {
      _host.log('${hello.name}: wrong code (${book.wrongCodes} of ${book.maxWrongCodes})');
      send(const PairResultMessage.refused(PairFailure.wrongCode));
    }
    close(CloseCodes.pairingFailed, 'Wrong pairing code');
  }

  void _accept(String token, {required String how}) {
    final hello = this.hello!;
    // One live connection per controller. An older one is usually half-open
    // after a Wi-Fi drop, so replace it.
    _host.replaceOther(this, CloseCodes.replaced, 'Replaced by a newer connection');
    final book = _host.pairingBook;
    final number = _host.reservePlayerNumber(book.known(hello.controllerId)?.player);
    paired = true;
    since = DateTime.now();
    player = number;
    // A phone that drops mid-round and pairs again keeps the look it wore; the look its hello asks for waits
    // for the round's end, like a set_character (M16 identity).
    final worn = _host.roundRunning ? book.known(hello.controllerId)?.character : null;
    final picked = _host.reserveCharacter(this, worn ?? hello.character);
    if (worn != null && hello.character != null && hello.character != worn) heldCharacter = hello.character;
    character = picked;
    final changed = book.remember(
      hello,
      token,
      remoteAddress: remoteAddress,
      player: number,
      live: _host.pairedControllerIds,
    );
    book.noteCharacter(hello.controllerId, picked);
    send(PairResultMessage.accepted(token: token));
    send(PlayerMessage(number: number, character: character));
    _host.log('${hello.name} connected ($how), player $player');
    if (changed) _host.pairingsChanged();
    _host.emit();
    _host.playersChanged();
  }
}
