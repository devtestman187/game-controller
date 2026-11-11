import 'dart:math';
import 'dart:ui' as ui;

import 'package:controller/src/gyro.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart' as party;
import 'package:party_host/testing.dart' as party_test;
import 'package:protocol/protocol.dart';
import 'package:puzzle_game/puzzle_game.dart';

import 'support/site_shots.dart';
import 'support/test_font.dart';

/// The tester guide's pictures (m13.4, tester-guide): each one the TV's screen
/// and the phone's, drawn by the apps themselves, framed side by side in the
/// look's Sunny colours and written to `site/shots/`. A family reads them
/// before touching a device, so they show what build 345 really does: a phone
/// joins with the code, the pad's three modes, a race with two players, the
/// TV's menus worked from the phone, and the results.
void main() {
  setUpAll(loadHostFonts);

  // The pictures show icons (the Start and Back buttons, the pad's mode tabs,
  // the bar's own buttons), and the test bundle has no icon font of its own.
  setUpAll(loadIconFont);

  // The join screen's sides are headed `◀ Left` and `Right ▶`, which no font
  // the apps bundle has: the machine's own symbol face fills the pictures'
  // fallback, and a machine without one draws boxes and says so.
  setUpAll(loadSymbolFont);

  const teams = {'p1': PuzzleSide.left, 'p2': PuzzleSide.right};
  const choice = party.PuzzleChoice(level: Level.medium, puzzleId: 'train');

  /// The round the pictures of play show: the Train, a phone on each side, from
  /// a fixed seed so every run lays the trays out the same.
  PuzzleMatch race() => PuzzleMatch(shotPuzzles.byId('train')!, teams: teams, random: Random(7));

  /// The first [count] pieces of [side] placed on its board, as the players
  /// would have left them: the boards of a round in play.
  void place(PuzzleMatch match, PuzzleSide side, int count) {
    final game = match.gameOf(side);
    for (var i = 0; i < count; i++) {
      game.pieces[i]
        ..state = PieceState.locked
        ..pos = game.targetAt(i);
    }
  }

  /// The TV's screen showing [screen], and the fake host behind it (whose
  /// layouts are what its round tells the phones).
  Future<(ui.Image, party_test.FakeHostService)> tvOf(WidgetTester tester, Widget screen) async {
    final key = GlobalKey(debugLabel: 'tv');
    final fake = await pumpTv(tester, key);
    await openTv(tester, screen);
    return (await captureSteady(tester, key), fake);
  }

  /// The phone's screen as [pumpPhone] mounts it.
  Future<ui.Image> phoneOf(
    WidgetTester tester, {
    bool paired = true,
    PadMode mode = PadMode.dpad,
    GameLayoutMessage? layout,
    String? code,
  }) async {
    final key = GlobalKey(debugLabel: 'phone');
    await pumpPhone(tester, key, paired: paired, mode: mode, layout: layout, code: code);
    return captureSteady(tester, key);
  }

  /// The TV's screen of a round: [left] and [right] pieces placed on the two
  /// boards, in play.
  party.PuzzleScreen round({int left = 4, int right = 2}) {
    final match = race();
    place(match, PuzzleSide.left, left);
    place(match, PuzzleSide.right, right);
    return party.PuzzleScreen(choice: choice, teams: teams, match: match);
  }

  testWidgets('the pictures draw their icons: each one has a glyph, not a box', (tester) async {
    for (final icon in pictureIcons) {
      final drawn = await glyphShot(tester, icon, fromFont: true);
      final box = await glyphShot(tester, icon, fromFont: false);
      final drawnBytes = await png(tester, drawn);
      final boxBytes = await png(tester, box);
      drawn.dispose();
      box.dispose();
      expect(
        drawnBytes,
        isNot(boxBytes),
        reason:
            '${icon.fontFamily} draws U+${icon.codePoint.toRadixString(16)} as its shape, '
            'not as the box a font that has none gives',
      );
    }
  });

  testWidgets('join.png: the TV asks for players and a phone types the code', (tester) async {
    final (tv, _) = await tvOf(tester, const party.JoinScreen(choice: choice, teams: teams));
    final phone = await phoneOf(tester, paired: false, code: '0427');
    await writeShot(tester, 'join', tv: tv, phone: phone);
  });

  testWidgets('dpad.png: a race on the TV, the D-pad on the phone', (tester) async {
    final (tv, fake) = await tvOf(tester, round());
    final phone = await phoneOf(tester, layout: fake.gameHost.layouts['p1']);
    await writeShot(tester, 'dpad', tv: tv, phone: phone);
  });

  testWidgets('tilt.png: a race on the TV, the tilt view on the phone', (tester) async {
    final (tv, fake) = await tvOf(tester, round());
    final phone = await phoneOf(tester, mode: PadMode.gyro, layout: fake.gameHost.layouts['p1']);
    await writeShot(tester, 'tilt', tv: tv, phone: phone);
  });

  testWidgets('sticks.png: a race on the TV, the sticks on the phone', (tester) async {
    final (tv, fake) = await tvOf(tester, round());
    final phone = await phoneOf(tester, mode: PadMode.sticks, layout: fake.gameHost.layouts['p1']);
    await writeShot(tester, 'sticks', tv: tv, phone: phone);
  });

  testWidgets('menus.png: the TV\'s game picker, worked from the phone', (tester) async {
    final (tv, _) = await tvOf(tester, const party.GamesScreen());
    final phone = await phoneOf(tester, layout: party.menuLayout);
    await writeShot(tester, 'menus', tv: tv, phone: phone);
  });

  testWidgets('results.png: the round ends and the TV offers a rematch', (tester) async {
    final key = GlobalKey(debugLabel: 'tv');
    final fake = await pumpTv(tester, key);
    // The round runs its half-second first, then both sides finish: the time
    // and the clock the results show are half a second in, where a frame's
    // difference in the first step can't show.
    final match = race();
    await openTv(tester, party.PuzzleScreen(choice: choice, teams: teams, match: match));
    for (final side in PuzzleSide.values) {
      place(match, side, match.gameOf(side).pieces.length);
    }
    await tester.pump(const Duration(milliseconds: 16));
    // The results' card and the focus on its first button settle.
    await tester.pump(const Duration(milliseconds: 500));
    final tv = await captureSteady(tester, key);
    final phone = await phoneOf(tester, layout: fake.gameHost.layouts['p1']);
    await writeShot(tester, 'results', tv: tv, phone: phone);
  });
}
