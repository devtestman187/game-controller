import 'dart:ui' show FontVariation;

import 'package:flutter/painting.dart' show FontWeight, TextStyle;

/// Fredoka's and Nunito's families, as the package's pubspec declares them; the
/// `package` on each style is what the asset key needs.
const _fredoka = 'Fredoka';
const _nunito = 'Nunito';
const _package = 'toy_look';

/// The design's type sizes, in logical pixels (design section 3): the TV's for
/// reading from 3 metres, a phone's at arm's length.
const _titleTvPx = 56.0;
const _buttonTvPx = 28.0;
const _bodyTvPx = 22.0;
const _titlePhonePx = 32.0;
const _buttonPhonePx = 18.0;
const _bodyPhonePx = 15.0;

/// The `wght` axis values: Fredoka is asked for 600 and Nunito for 700.
const _semibold = 600.0;
const _bold = 700.0;

/// Fredoka 600 at the TV's title size: the titles and the clock.
const _titleTv = TextStyle(
  fontFamily: _fredoka,
  package: _package,
  fontSize: _titleTvPx,
  fontWeight: FontWeight.w600,
  fontVariations: [FontVariation('wght', _semibold)],
);

/// Fredoka 600 at the TV's button size.
const _buttonTv = TextStyle(
  fontFamily: _fredoka,
  package: _package,
  fontSize: _buttonTvPx,
  fontWeight: FontWeight.w600,
  fontVariations: [FontVariation('wght', _semibold)],
);

/// Nunito 700 at the TV's body size.
const _bodyTv = TextStyle(
  fontFamily: _nunito,
  package: _package,
  fontSize: _bodyTvPx,
  fontWeight: FontWeight.w700,
  fontVariations: [FontVariation('wght', _bold)],
);

/// Fredoka 600 at a phone's title size: the titles and the clock.
const _titlePhone = TextStyle(
  fontFamily: _fredoka,
  package: _package,
  fontSize: _titlePhonePx,
  fontWeight: FontWeight.w600,
  fontVariations: [FontVariation('wght', _semibold)],
);

/// Fredoka 600 at a phone's button size.
const _buttonPhone = TextStyle(
  fontFamily: _fredoka,
  package: _package,
  fontSize: _buttonPhonePx,
  fontWeight: FontWeight.w600,
  fontVariations: [FontVariation('wght', _semibold)],
);

/// Nunito 700 at a phone's body size.
const _bodyPhone = TextStyle(
  fontFamily: _nunito,
  package: _package,
  fontSize: _bodyPhonePx,
  fontWeight: FontWeight.w700,
  fontVariations: [FontVariation('wght', _bold)],
);

/// The look's type (M13, docs/design/look-and-sound.md section 3): Fredoka 600
/// for titles, buttons and the clock, Nunito 700 for body text, at a size for
/// reading from 3 metres ([tv]) or at arm's length ([phone]).
///
/// The two fonts travel with this package (design D7), so a style names it as
/// `package: 'toy_look'`. A variable font picks its weight from its axis on
/// some platforms, so every style sets the weight and the matching
/// [FontVariation] (`wght`).
///
/// The type carries no colour: the theme and the widgets add it, because the
/// same title is ink on paper and onBackground on the background.
final class ToyType {
  const ToyType._({required this.title, required this.button, required this.clock, required this.body});

  /// The TV's sizes: Fredoka 56 for titles and the clock, 28 for buttons,
  /// Nunito 22 for body text.
  static const tv = ToyType._(title: _titleTv, button: _buttonTv, clock: _titleTv, body: _bodyTv);

  /// A phone's sizes: Fredoka 32 for titles and the clock, 18 for buttons,
  /// Nunito 15 for body text.
  static const phone = ToyType._(title: _titlePhone, button: _buttonPhone, clock: _titlePhone, body: _bodyPhone);

  /// A screen's title and the finished card's heading.
  final TextStyle title;

  /// A button's label.
  final TextStyle button;

  /// A round's clock.
  final TextStyle clock;

  /// Everything else a player reads.
  final TextStyle body;
}
