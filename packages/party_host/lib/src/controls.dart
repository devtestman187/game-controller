import 'package:protocol/protocol.dart';

/// What the players' controllers do right now: work the host app's menus like
/// the remote (PRD v2 T21), or play a game, which reads them itself.
final class Controls {
  /// Every screen's menus, for everyone, or only for the players in [only]
  /// (the pause menu: the player who paused and Player 1). [layout] replaces
  /// the usual menu buttons on the phones.
  const Controls.menus({this.only, this.layout}) : menus = true;

  /// A game is reading the controllers.
  const Controls.game() : menus = false, only = null, layout = null;

  final bool menus;
  final Set<String>? only;
  final GameLayoutMessage? layout;
}

/// The screens' claims on the controllers, newest on top. With none, the
/// controllers work the menus.
class ControlsClaims {
  final _claims = <ClaimHandle>[];

  /// What the controllers do now: the newest claim's, or the menus.
  Controls get current => _claims.lastOrNull?._controls ?? const Controls.menus();

  /// Lets [controls] stand for the calling screen until the handle is
  /// released.
  ClaimHandle claim(Controls controls) {
    final handle = ClaimHandle._(this, controls);
    _claims.add(handle);
    return handle;
  }
}

/// One screen's claim on the controllers ([ControlsClaims.claim]). The newest
/// claim wins; releasing it hands the controllers back to the one below.
final class ClaimHandle {
  ClaimHandle._(this._owner, this._controls);

  final ControlsClaims _owner;
  Controls _controls;

  /// Changes what the controllers do while this claim is on top.
  set controls(Controls value) => _controls = value;

  /// Ends the claim, as its screen goes. Releasing twice does nothing.
  void release() => _owner._claims.remove(this);
}
