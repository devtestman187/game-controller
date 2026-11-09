import 'package:flutter/widgets.dart';
import 'package:toy_look/toy_look.dart';

/// The look the puzzle's tests draw in: Sunny, as the look's own tests start,
/// on a phone with the effects on (so the pieces boing and wobble).
final sunny = ToyLook.build(palette: ToyPalette.sunny, tv: false);

/// Sunny's other palette, for the tests that check a board is drawn from the
/// look rather than from a theme of its own.
final night = ToyLook.build(palette: ToyPalette.night, tv: false);

/// [child] under a [ToyLookScope] of [look], as both apps put one above every
/// screen: a view drawn with none is a wiring mistake (`ToyLookScope.of`).
Widget withLook(Widget child, {ToyLook? look}) => ToyLookScope(look: look ?? sunny, child: child);
