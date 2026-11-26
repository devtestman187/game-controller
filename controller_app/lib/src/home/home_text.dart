/// Home's user-facing strings (APP-START.md marks 1-3 and the three role names).
abstract final class HomeText {
  /// The join role's card on home.
  static const joinGame = 'Join a Game';

  /// The play role's card on home: this phone is the controller and the screen.
  static const playHere = 'Play here';

  /// The display role's card on home: this phone shows the game.
  static const displayHere = 'Display here';

  /// The discovery status line when a screen has been found.
  static const foundNearby = 'Found nearby';

  /// The discovery status line when no screen has been found.
  static const noScreenFound = 'No screen found';

  /// The chip while discovery is still searching, so a slow first answer is not
  /// read as a failed search.
  static const lookingForScreen = 'Looking for a screen…';

  /// The button that restarts discovery after a failed search.
  static const searchAgain = 'Search again';

  /// The hint in the name slot until the player has typed a name.
  static const tapToAddName = 'Tap to add your name';

  /// The label of the settings button on home.
  static const settings = 'Settings';

  /// The settings entry that shows the coach marks again.
  static const showTips = 'Show tips';

  /// The coach marks' button that ends the tour at any step.
  static const skip = 'Skip';

  /// The coach mark for the join role's card.
  static const tipJoin = "Join a friend's game";

  /// The coach mark for the play role's card.
  static const tipPlay = 'Play on this screen or host a game';

  /// The coach mark for the display role's card.
  static const tipDisplay = 'Create and watch the game here. Control from another screen';
}
