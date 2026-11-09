import 'package:flutter/widgets.dart';
import 'package:toy_look/toy_look.dart';

/// The look the arena's tests draw in: Sunny, as the look's own tests start,
/// on a phone with the effects on (so a recovering marble fades).
final sunny = ToyLook.build(palette: ToyPalette.sunny, tv: false);

/// Sunny's other palette, for the tests that check the arena is drawn from the
/// look rather than from the M12 colours.
final night = ToyLook.build(palette: ToyPalette.night, tv: false);

/// Sunny with the effects setting off (design D8): the same colours and shapes,
/// and nothing moving.
final sunnyStill = ToyLook.build(palette: ToyPalette.sunny, tv: false, effects: false);

/// [child] under a [ToyLookScope] of [look], as both apps put one above every
/// screen: a view drawn with none draws in the board's own default.
Widget withLook(Widget child, {ToyLook? look}) => ToyLookScope(look: look ?? sunny, child: child);
