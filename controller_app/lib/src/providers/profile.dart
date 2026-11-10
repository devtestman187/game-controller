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
