import 'package:puzzle_game/puzzle_game.dart' show Level;

import '../night/night_settings.dart';
import '../night/variant.dart';

/// Every word the night setup screen and the start card's setup buttons show (M17 night2b d2g), in one place like
/// [NightText]: short common words, for a child reading from the couch.
abstract final class NightSetupText {
  static const title = 'Set up your night';

  // The rows' labels.
  static const howLong = 'How long';
  static const games = 'Games';
  static const easiest = 'Easiest';
  static const hardest = 'Hardest';
  static const whoPicks = 'Who picks the next game';

  // The chips' names.
  static const threeRounds = '3 rounds';
  static const fiveRounds = '5 rounds';
  static const shapeRace = 'Shape Race';
  static const bumperRound = 'Bumper Round';
  static const arenaRace = 'Arena Race';
  static const easy = 'Easy';
  static const medium = 'Medium';
  static const hard = 'Hard';

  // The picker's names, and the one line under the row that says what the chosen one does.
  static const pickerHost = 'I pick';
  static const pickerDirector = 'Night director';
  static const pickerShuffle = 'Shuffle';
  static const pickerPlaylist = 'Playlist';
  static const pickerHostHelp = 'You choose each game yourself.';
  static const pickerDirectorHelp = 'The night director picks each game and says why.';
  static const pickerShuffleHelp = 'A game picked by luck, none twice until all have been played.';
  static const pickerPlaylistHelp = 'Your chosen games, one after another, in the order listed.';
  static const pickerRotating = 'Rotating';
  static const pickerVote = 'Vote';

  // The buttons.
  static const done = 'Done';
  static const kidsNight = 'Kids night';

  /// The cat's note: nights follow the host's own cat setting, so the screen has no cat row.
  static const catNote = 'The cat follows your Games settings';

  // The start card's.
  static const setUp = 'Set up';
  static const startTheNight = 'Start the night';
  static const gamesPickedForYou = 'Games are picked for you';

  /// What the chip for [game] says.
  static String gameName(VariantGame game) => switch (game) {
    VariantGame.shapeRace => shapeRace,
    VariantGame.bumperRound => bumperRound,
    VariantGame.arenaRace => arenaRace,
  };

  /// What a difficulty chip for [level] says.
  static String levelName(Level level) => switch (level) {
    Level.easy => easy,
    Level.medium => medium,
    Level.hard => hard,
  };

  /// What the chip for [picker] says.
  static String pickerName(NightPicker picker) => switch (picker) {
    NightPicker.host => pickerHost,
    NightPicker.director => pickerDirector,
    NightPicker.shuffle => pickerShuffle,
    NightPicker.playlist => pickerPlaylist,
    NightPicker.rotating => pickerRotating,
    NightPicker.vote => pickerVote,
  };

  /// The line that says what [picker] does, shown under the row.
  static String pickerHelp(NightPicker picker) => switch (picker) {
    NightPicker.host => pickerHostHelp,
    NightPicker.director => pickerDirectorHelp,
    NightPicker.shuffle => pickerShuffleHelp,
    NightPicker.playlist => pickerPlaylistHelp,
    NightPicker.rotating || NightPicker.vote => pickerHostHelp,
  };
}
