import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart' as party;

import 'support/pump_app.dart';

const _changeCharacter = Key('changeCharacter');
const _settingsPreview = Key('characterPreview');

/// A badge's "Player N" label, which a numbered badge speaks.
final _playerNumberLabel = RegExp(r'Player \d');

/// The square round the badge's middle, as a share of its diameter: the digit
/// a numbered badge draws is about 0.2 of the diameter either side of the
/// centre, so 0.25 holds all of it and stays inside the disc.
const _middleShare = 0.25;

/// A point above the middle square, as a share of the diameter, to read the
/// disc's colour from: inside the disc and above any digit.
const _discShare = 0.3;

/// The screen as the app drew it, one pixel per logical pixel (pumpApp's
/// device pixel ratio is 1), read back from the render tree's layer.
final class _Screen {
  const _Screen(this._bytes, this._width);

  final List<int> _bytes;
  final int _width;

  /// The red, green and blue of the pixel at ([x], [y]), 0 to 255.
  (int, int, int) at(int x, int y) {
    final i = (y * _width + x) * 4;
    return (_bytes[i], _bytes[i + 1], _bytes[i + 2]);
  }
}

/// Reads the whole screen the app has drawn.
Future<_Screen> _screen(WidgetTester tester) async {
  final size = tester.view.physicalSize / tester.view.devicePixelRatio;
  final layer = tester.binding.renderViews.first.debugLayer! as OffsetLayer;
  final image = (await tester.runAsync(() => layer.toImage(Offset.zero & size)))!;
  final data = (await tester.runAsync(() => image.toByteData()))!;
  image.dispose();
  return _Screen(data.buffer.asUint8List(), image.width);
}

/// Shows the join screen's badge and the Settings preview with no number: the
/// join line already names the character, and the phone has no player number
/// until the TV pairs (owner decision, Nov 23).
void main() {
  for (final tv in [false, true]) {
    final look = tv ? 'the TV look' : 'the menu look';
    group('the badge without a number, in $look', () {
      testWidgets('the join screen\'s badge draws no number and speaks no "Player N" label', (tester) async {
        final semantics = tester.ensureSemantics();
        await _pumpWithTealCrown(tester, tv: tv);
        expect(find.text('You: the Teal Crown'), findsOneWidget);

        final badges = tester.widgetList<party.ToyBadge>(find.byType(party.ToyBadge)).toList();
        expect(badges, hasLength(1), reason: 'the join screen has one badge: the phone\'s character');
        expect(badges.single.numbered, isFalse);
        expect(find.bySemanticsLabel(_playerNumberLabel), findsNothing);
        semantics.dispose();
      });

      testWidgets('the join screen\'s badge paints no digit: its middle is the disc\'s colour all through', (
        tester,
      ) async {
        await _pumpWithTealCrown(tester, tv: tv);
        // The badge can sit below the fold; the screen read only holds what is on it.
        await tester.ensureVisible(find.byType(party.ToyBadge));
        await settle(tester);
        final box = tester.getRect(find.byType(party.ToyBadge));
        final pixels = await _screen(tester);

        final centre = box.center;
        final half = box.width * _middleShare;
        final disc = pixels.at(centre.dx.round(), (centre.dy - box.width * _discShare).round());
        var mismatched = 0;
        for (var y = (centre.dy - half).round(); y <= (centre.dy + half).round(); y++) {
          for (var x = (centre.dx - half).round(); x <= (centre.dx + half).round(); x++) {
            if (pixels.at(x, y) != disc) mismatched++;
          }
        }
        expect(mismatched, 0, reason: 'a digit would be ink in the middle of the badge');
      });

      testWidgets('the Settings preview\'s figures draw no number and speak no "Player N" label', (tester) async {
        final semantics = tester.ensureSemantics();
        await _pumpWithTealCrown(tester, tv: tv);
        await tapVisible(tester, find.byKey(_changeCharacter));
        await settle(tester);

        final preview = find.byKey(_settingsPreview);
        expect(preview, findsOneWidget);
        final figures = tester
            .widgetList<party.ToyBadge>(find.descendant(of: preview, matching: find.byType(party.ToyBadge)))
            .toList();
        expect(figures, hasLength(2), reason: 'the worker and the marble');
        expect(figures.map((f) => f.numbered), [false, false]);
        expect(find.bySemanticsLabel(_playerNumberLabel), findsNothing);
        semantics.dispose();
      });
    });
  }
}

/// Mounts the app with a saved teal crown, on the menu or the TV look at a
/// size each look's type fits.
Future<void> _pumpWithTealCrown(WidgetTester tester, {required bool tv}) async {
  await pumpApp(
    tester,
    // The TV look's bigger type needs a tablet's room.
    screen: tv ? const Size(1180, 820) : const Size(852, 393),
    saved: {'profileCharacter': '{"c":4,"a":"crown"}'},
    extra: [if (tv) party.toyTvProvider.overrideWithValue(true)],
  );
}
