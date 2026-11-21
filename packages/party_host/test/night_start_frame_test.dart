import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';
import 'package:party_host/testing.dart';

import 'support/host_harness.dart';
import 'support/night_harness.dart';
import 'support/toy_fonts.dart';

/// The slack the frame's math is compared with, as `host_frame_screen_test.dart`
/// has it: [Size] is two doubles, and 1024 x 768 gives a frame width of 960
/// within one part in 10^15.
const _tolerance = 1e-9;

/// One device, with the scale and the frame the design's math gives it (DESIGN
/// section 2; the numbers are `host_frame_screen_test.dart`'s).
class _Case {
  const _Case({required this.label, required this.device, required this.scale, required this.frame});

  /// The device in the brief's words, for the test's name.
  final String label;

  /// The device's logical size: its physical size at a device pixel ratio of 1.
  final Size device;

  /// How many device logical pixels one frame pixel is drawn at.
  final double scale;

  /// The size the host lays out in, in frame px.
  final Size frame;
}

/// The five devices every slice of the phone-host layout is checked at:
///
/// * 640x360, a small phone: s = 640/960 = .667, frame 960x540, body 392.
/// * 852x393, a phone in landscape: s = 393/540 = .728, frame 1170.687x540,
///   body 392.
/// * 1024x768, a tablet: s = 1024/960 = 1.067, frame 960x720, body 572.
/// * 1280x800, a laptop: s = 1280/960 = 1.333, frame 960x600, body 452.
/// * 1920x1080, the TV: s = 1920/960 = 2, frame 960x540, body 392.
const _cases = [
  _Case(label: '640x360, a small phone', device: Size(640, 360), scale: 0.6666666666666666, frame: Size(960, 540)),
  _Case(
    label: '852x393, a phone in landscape',
    device: Size(852, 393),
    scale: 0.7277777777777777,
    frame: Size(1170.6870229007634, 540),
  ),
  _Case(label: '1024x768, a tablet', device: Size(1024, 768), scale: 1.0666666666666667, frame: Size(960, 720)),
  _Case(label: '1280x800, a laptop', device: Size(1280, 800), scale: 1.3333333333333333, frame: Size(960, 600)),
  _Case(label: '1920x1080, the TV', device: Size(1920, 1080), scale: 2, frame: Size(960, 540)),
];

/// The keys the frame's three regions and its footer's band are found by.
const _headerKey = Key('hostFrameHeader');
const _bodyKey = Key('hostFrameBody');
const _footerKey = Key('hostFrameFooter');
const _bandKey = Key('hostFrameFooterBand');

/// The night's two footer buttons.
const _shapeRaceKey = Key('nightShapeRace');
const _bumperKey = Key('nightBumper');

/// The four phones the start card is checked with: names at most 10 characters,
/// the longest a real host keeps, so the players' line shows what it shows with
/// real names.
const _playerNames = ['Bartholome', 'Maxi', 'Alexandria', 'Chris'];

/// The seed the start card's awards are drawn from: fixed, so a test knows
/// which three tiles it is showing.
const _seed = 7;

/// The night's start screen drawn in the host's frame, as the app draws every
/// screen (DESIGN section 5): [hostFrameBuilder] over it, so the screen lays
/// out at the frame's size with the frame's type.
class _NightInFrame extends StatelessWidget {
  const _NightInFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => hostFrameBuilder(context, child);
}

/// Mounts the host at [device]'s size on the night's start screen, in the
/// frame, with the four phones of [_playerNames] joined.
Future<FakeHostService> _pumpNight(WidgetTester tester, Size device) async {
  final fake = await pumpHost(
    tester,
    screen: const _NightInFrame(child: NightStartScreen(seed: _seed)),
    size: device,
  );
  // The sample state's own two phones make way for the four the card shows.
  fake.removeController('p1');
  fake.removeController('p2');
  var state = fake.state;
  for (var i = 0; i < _playerNames.length; i++) {
    state = withController(state, phoneInfo('p${i + 1}', i + 1, name: _playerNames[i]));
  }
  fake.state = state;
  fake.emit();
  await tester.pumpAndSettle();
  return fake;
}

/// The painter of the chip that says [label]: the look's pill, so a test can
/// read the fill the chip was drawn with.
ToyPillPainter _chipPainter(WidgetTester tester, String label) {
  final paint = tester.widget<CustomPaint>(
    find.ancestor(
      of: find.text(label),
      matching: find.byWidgetPredicate((widget) => widget is CustomPaint && widget.painter is ToyPillPainter),
    ),
  );
  return paint.painter! as ToyPillPainter;
}

/// The award a tile stands for, from its own widget.
NightAward _awardOf(WidgetTester tester, int index) => tester.widget<AwardTile>(find.byType(AwardTile).at(index)).award;

void main() {
  setUpAll(loadLookFonts);

  for (final frameCase in _cases) {
    testWidgets('${frameCase.label}: the night start fits its body, so nothing scrolls, and its footer fits', (
      tester,
    ) async {
      await _pumpNight(tester, frameCase.device);

      // The body has room for the card, so it holds no list at all: a host
      // screen never scrolls (DESIGN section 1, rule 6), and the frame is now
      // the only layout the apps draw the night start in (fstart).
      expect(
        find.descendant(of: find.byKey(_bodyKey), matching: find.byType(Scrollable)),
        findsNothing,
        reason: 'the body has room for the card, so it needs no scrollable (DESIGN section 1, rule 6)',
      );
      expect(tester.takeException(), isNull, reason: 'nothing overflows the frame');

      for (final key in [_shapeRaceKey, _bumperKey]) {
        final rect = tester.getRect(find.byKey(key));
        expect(rect.left, greaterThanOrEqualTo(0), reason: '$key is on screen');
        expect(rect.top, greaterThanOrEqualTo(0), reason: '$key is on screen');
        expect(rect.right, lessThanOrEqualTo(frameCase.device.width), reason: '$key is on screen');
        expect(rect.bottom, lessThanOrEqualTo(frameCase.device.height + _tolerance), reason: '$key is on screen');
        expect(find.byKey(key).hitTestable(), findsOneWidget, reason: '$key can be pressed');
      }
    });

    testWidgets('${frameCase.label}: every text on the night start is at least 20 frame px', (tester) async {
      await _pumpNight(tester, frameCase.device);
      final texts = find.descendant(of: find.byType(NightStartScreen), matching: find.byType(Text));
      expect(texts, findsWidgets);
      for (final element in texts.evaluate()) {
        final text = element.widget as Text;
        final style = DefaultTextStyle.of(element).style.merge(text.style);
        expect(
          style.fontSize,
          greaterThanOrEqualTo(20),
          reason: '"${text.data ?? text.textSpan?.toPlainText()}" is a frame size (DESIGN rule 3)',
        );
      }
    });

    testWidgets('${frameCase.label}: the round segment sits inside the 64 px header', (tester) async {
      await _pumpNight(tester, frameCase.device);

      final header = tester.getRect(find.byKey(_headerKey));
      expect(header.height, moreOrLessEquals(64 * frameCase.scale, epsilon: _tolerance));
      final segment = find.byType(RoundSegment);
      expect(tester.getSize(segment).height, moreOrLessEquals(roundChipHeightPx, epsilon: _tolerance));
      final chip = tester.getRect(segment);
      expect(chip.top, greaterThanOrEqualTo(header.top), reason: 'the chip is inside the header');
      expect(chip.bottom, lessThanOrEqualTo(header.bottom), reason: 'the chip is inside the header');
      expect(find.descendant(of: find.byKey(_headerKey), matching: find.text('3 rounds')), findsOneWidget);
      expect(find.descendant(of: find.byKey(_headerKey), matching: find.text('5 rounds')), findsOneWidget);
    });

    testWidgets('${frameCase.label}: the three awards are one row of equal tiles', (tester) async {
      await _pumpNight(tester, frameCase.device);

      expect(find.byType(AwardTile), findsNWidgets(3));
      final widths = [for (var i = 0; i < 3; i++) tester.getSize(find.byType(AwardTile).at(i)).width];
      for (final width in widths) {
        expect(width, moreOrLessEquals(widths.first, epsilon: _tolerance), reason: 'the tiles are equal');
      }
      // The row shares the stage's width: the frame less its 24 px gutter each
      // side, less the two gaps between the tiles.
      final stage = frameCase.frame.width - 2 * hostFrameGutterPx;
      expect(widths.first, moreOrLessEquals((stage - 2 * awardTileGapPx) / 3, epsilon: _tolerance));
      final tops = [for (var i = 0; i < 3; i++) tester.getRect(find.byType(AwardTile).at(i)).top];
      expect(tops.toSet().length, 1, reason: 'the three tiles stand in one row');
    });

    testWidgets('${frameCase.label}: the footer is a paper band with an ink line above it', (tester) async {
      await _pumpNight(tester, frameCase.device);

      final look = ToyLookScope.of(tester.element(find.byKey(_bandKey)));
      final band = tester.widget<DecoratedBox>(find.byKey(_bandKey));
      final decoration = band.decoration as BoxDecoration;
      expect(decoration.color, look.colors.paper, reason: 'the buttons stand on the look\'s paper');
      final border = decoration.border as Border?;
      expect(border?.top.color, look.colors.ink, reason: 'the band is closed by a line of ink');
      expect(border?.top.width, greaterThan(0));
      expect(
        tester.getRect(find.byKey(_bandKey)),
        tester.getRect(find.byKey(_footerKey)),
        reason: 'the band fills the footer, edge to edge',
      );
    });
  }

  testWidgets('the players who joined stand on one line under the awards', (tester) async {
    await _pumpNight(tester, const Size(640, 360));

    for (final name in _playerNames) {
      expect(find.text(name), findsOneWidget, reason: '$name joined, so the card names them');
    }
    expect(find.byType(PlayerBadge), findsNWidgets(_playerNames.length));
    final tops = [for (final name in _playerNames) tester.getRect(find.text(name)).top];
    expect(tops.toSet().length, 1, reason: 'the names share one line (DESIGN section 4)');
  });

  testWidgets('the "i" on an award opens its explanation, and Escape, a tap outside or its button closes it', (
    tester,
  ) async {
    await _pumpNight(tester, const Size(640, 360));
    final award = _awardOf(tester, 0);
    final info = find.byKey(Key('awardInfo-${award.name}'));

    await tester.tap(info);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('awardExplanation')), findsOneWidget);
    expect(find.text(award.line), findsOneWidget, reason: 'the explanation is the award\'s own line');

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('awardExplanation')), findsNothing);

    await tester.tap(info);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('awardExplanationClose')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('awardExplanation')), findsNothing);

    await tester.tap(info);
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('awardExplanation')), findsNothing, reason: 'a tap outside closes it');
  });

  testWidgets('a night already under way leaves the round chips unpickable', (tester) async {
    await _pumpNight(tester, const Size(640, 360));
    appContainer(tester).read(partyNightProvider.notifier).start(length: NightLength.five, awards: threeAwards);
    await tester.pumpAndSettle();

    final segment = tester.widget<RoundSegment>(find.byType(RoundSegment));
    expect(segment.value, 5, reason: 'the running night\'s length is the one shown');
    expect(segment.onChanged, isNull, reason: 'a night under way keeps its length (M14 r5 12)');
    final look = ToyLookScope.of(tester.element(find.byType(RoundSegment)));
    expect(_chipPainter(tester, '5 rounds').fill, look.colors.focus);

    await tester.tap(find.text('3 rounds'));
    await tester.pumpAndSettle();
    expect(tester.widget<RoundSegment>(find.byType(RoundSegment)).value, 5, reason: 'a press changes nothing');
  });

  testWidgets('the Shape Race footer button starts the night and its first round', (tester) async {
    await _pumpNight(tester, const Size(640, 360));
    final container = appContainer(tester);
    expect(container.read(partyNightProvider), isNull);

    await tester.tap(find.byKey(_shapeRaceKey));
    await tester.pumpAndSettle();

    expect(container.read(partyNightProvider), isNotNull, reason: 'the night is on');
    expect(find.byType(ShapeRaceScreen), findsOneWidget);
  });

  testWidgets('a Bumper Round with nothing to start is a disabled footer button', (tester) async {
    await pumpHost(
      tester,
      screen: const Scaffold(
        body: Center(child: NightFooterButtons(onShapeRace: _ignore, onBumperRound: null)),
      ),
    );

    expect(tester.widget<HostButton>(find.byKey(_shapeRaceKey)).onPressed, isNotNull);
    expect(tester.widget<HostButton>(find.byKey(_bumperKey)).onPressed, isNull);
  });

  testWidgets('the header shows a back arrow only where the route can pop, and it pops', (tester) async {
    await pumpHost(
      tester,
      screen: const _NightInFrame(child: NightStartScreen(seed: _seed)),
    );
    expect(find.byKey(const Key('hostTitleBarBack')), findsNothing, reason: 'home has nothing to pop to');

    await pumpHost(tester, screen: const StubHome());
    await openNight(tester);
    expect(find.byType(NightStartScreen), findsOneWidget);
    expect(find.byKey(const Key('hostTitleBar')), findsOneWidget, reason: 'the header keeps the title bar\'s key');
    final back = find.byKey(const Key('hostTitleBarBack'));
    expect(back, findsOneWidget);

    await tester.tap(back);
    await tester.pumpAndSettle();
    expect(find.byType(NightStartScreen), findsNothing);
    expect(find.byType(GamesScreen), findsOneWidget, reason: 'the arrow goes back to the picker');
  });
}

void _ignore() {}
