import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protocol/protocol.dart' show playerColor;
import 'package:toy_look/toy_look.dart';

void main() {
  test('a palette\'s tokens are the design table\'s colours', () {
    const sunny = ToyColors.sunny;
    expect(sunny.ink, const Color(0xFF1E1646));
    expect(sunny.background, const Color(0xFF7CC8F8));
    expect(sunny.backgroundGlow, const Color(0xFFC4EAFF));
    expect(sunny.onBackground, const Color(0xFF1E1646));
    expect(sunny.paper, const Color(0xFFFFF6E3));
    expect(sunny.board, const Color(0xFFFFEFD0));
    expect(sunny.tray, const Color(0xFFF5D9A8));
    expect(sunny.targetNeutral, const Color(0xFFB3A285));
    expect(sunny.field, const Color(0xFFA9DCFB));
    expect(sunny.wall, const Color(0xFF7F8FD1));

    const night = ToyColors.night;
    expect(night.ink, const Color(0xFF120D2E));
    expect(night.background, const Color(0xFF241C5E));
    expect(night.backgroundGlow, const Color(0xFF3B2F8F));
    expect(night.onBackground, const Color(0xFFFFFFFF));
    expect(night.paper, const Color(0xFFFFF6E3));
    expect(night.board, const Color(0xFF30297A));
    expect(night.tray, const Color(0xFF3D3592));
    expect(night.targetNeutral, const Color(0xFF9289D6));
    expect(night.field, const Color(0xFF2A2270));
    expect(night.wall, const Color(0xFF8C9BD8));
  });

  test('the shared tokens are the same in both palettes', () {
    for (final colors in [ToyColors.sunny, ToyColors.night]) {
      expect(colors.focus, const Color(0xFFFFD23F));
      expect(colors.good, const Color(0xFF2FCB74));
      expect(colors.caution, const Color(0xFFFFB020));
      expect(colors.bad, const Color(0xFFFF4D5E));
      expect(colors.faceA, const Color(0xFF2FCB74));
      expect(colors.faceB, const Color(0xFFFF4D5E));
      expect(colors.faceX, const Color(0xFF2E9BF0));
      expect(colors.faceY, const Color(0xFFFFD23F));
    }
  });

  test('a palette is looked up by its own name', () {
    expect(ToyColors.of(ToyPalette.sunny), same(ToyColors.sunny));
    expect(ToyColors.of(ToyPalette.night), same(ToyColors.night));
  });

  test('a player\'s colour is the protocol\'s colour for that number', () {
    for (var number = 1; number <= 7; number++) {
      expect(ToyColors.sunny.player(number), Color(playerColor(number)), reason: 'player $number');
      expect(ToyColors.night.player(number), Color(playerColor(number)), reason: 'player $number');
    }
    expect(ToyColors.sunny.player(7), ToyColors.sunny.player(1));
  });
}
