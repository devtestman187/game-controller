import 'package:toy_look/toy_look.dart';

/// How much larger than its share of the field a marble's picture is drawn in
/// the TV's look (M14 bugs3 B-014, the owner's "players look too small on a
/// TV"): the TV is watched from three metres, so a player's body, face, coin
/// count and number are half again as big. Only the picture grows: the
/// marble's place, its radius in the rules and every speed stay the field's.
const tvPlayerScale = 1.5;

/// The factor a marble's picture is drawn at in [look] (M14 bugs3 B-014): a
/// TV's look draws it at [tvPlayerScale] and a phone's at its own size, so a
/// marble reads from the couch while the phone host's arena and a joined
/// phone's look as they did.
///
/// The look's sizes already say which screen this is, [ToySizes.tv] against
/// [ToySizes.menu] (M13), so a view needs no layout of its own for it.
double arenaPlayerScale(ToyLook look) => look.sizes == ToySizes.tv ? tvPlayerScale : 1;
