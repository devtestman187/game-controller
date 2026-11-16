import 'dart:async';

import 'package:connection/connection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:protocol/protocol.dart';

import '../profile.dart';
import 'connection.dart';
import 'device.dart';

/// What this phone's player chose about themselves (M14 N13, design section
/// 9): the nickname and the character. Saving one changes the next hello
/// without a restart: the clients' identity is updated in place, so a running
/// link is not torn down and the TV learns it on the next join.
final profileProvider = NotifierProvider<ProfileNotifier, ControllerProfile>(ProfileNotifier.new);

class ProfileNotifier extends Notifier<ControllerProfile> {
  @override
  ControllerProfile build() => ControllerProfile.load(ref.watch(prefsProvider));

  /// Saves [nickname] (null when the field is blank), which the next hello
  /// sends as its name.
  void setNickname(String? nickname) => _save(ControllerProfile(nickname: nickname, character: state.character));

  /// Saves the colour and accessory the player picked, which the next hello
  /// sends for the host to give them (nearest free).
  void setCharacter(PlayerCharacter character) =>
      _save(ControllerProfile(nickname: state.nickname, character: character));

  void _save(ControllerProfile profile) {
    state = profile;
    profile.save(ref.read(prefsProvider));
    _apply(profile, ref.read(tvClientProvider));
    final own = ref.read(ownClientProvider);
    if (own != null) _apply(profile, own);
  }

  /// The next hello says the new profile: a client connects with the identity
  /// it holds, so it takes the name and the character here ("shows next time
  /// you join").
  void _apply(ControllerProfile profile, ControllerClient client) {
    client.identity = client.identity.copyWith(
      name: phoneName(nickname: profile.nickname, controllerId: client.identity.controllerId),
      character: profile.character,
    );
  }
}

/// The colour the last hello asked the host for and the one it answered (M14
/// design section 9, mock-up 18, B-028).
typedef TakenColours = ({PlayerCharacter asked, PlayerCharacter assigned});

/// How long the line that says the host took this phone's colour stays, in
/// seconds of the phone's own clock, unless the round moves on first (B-028).
const takenNoticeDuration = Duration(seconds: 5);

/// The line "Blue is taken tonight, you're Teal" (M14 design section 9,
/// mock-up 18): what this phone asked the host for and got instead, or null
/// while there is nothing to say.
///
/// It compares the host's answer ([ClientSnapshot.character]) with the colour
/// the last hello asked for ([ClientSnapshot.askedCharacter]), not with the
/// saved profile: a player who changes colour in Settings while joined sees no
/// line, and the new colour applies on the next join (B-028). The line goes
/// after [takenNoticeDuration], or as the round moves on — the game starting
/// or ending on this phone — whichever is first.
final takenNoticeProvider = NotifierProvider<TakenNoticeNotifier, TakenColours?>(TakenNoticeNotifier.new);

class TakenNoticeNotifier extends Notifier<TakenColours?> {
  Timer? _hide;

  @override
  TakenColours? build() {
    ref.onDispose(_cancel);
    final client = ref.watch(clientProvider);
    final sub = client.view.listen((event) {
      if (event is ViewStarted || event is ViewEnded) _hideNow();
    });
    ref.onDispose(sub.cancel);
    ref.listen(clientStateProvider, _onHostAnswer);
    return null;
  }

  /// The host answered the hello: a colour other than the asked one is said.
  void _onHostAnswer(ClientSnapshot? previous, ClientSnapshot next) {
    final asked = next.askedCharacter;
    final assigned = next.character;
    if (asked == null || assigned == null || asked.colourSlot == assigned.colourSlot) {
      _hideNow();
      return;
    }
    // Every heartbeat brings a snapshot: the same answer keeps the line's own
    // seconds rather than starting them again.
    if (state == (asked: asked, assigned: assigned)) return;
    state = (asked: asked, assigned: assigned);
    _hide?.cancel();
    _hide = Timer(takenNoticeDuration, _hideNow);
  }

  void _hideNow() {
    _cancel();
    if (state != null) state = null;
  }

  void _cancel() {
    _hide?.cancel();
    _hide = null;
  }
}
