import 'package:controller/src/home/coach_marks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart' as party;
import 'package:shared_preferences/shared_preferences.dart';

/// The phone sizes the box must stay inside: two landscape, two portrait.
const screens = {
  '568x320': Size(568, 320),
  '640x360': Size(640, 360),
  '320x640': Size(320, 640),
  '375x667': Size(375, 667),
};

/// The text scale a user who asks for bigger text gets.
const largeTextScale = 1.3;

const tipOne = 'First tip';
const tipTwo = 'Second tip';
const tipThree = 'Third tip';

/// What a test counts: how often the marks said they were done or skipped.
class Calls {
  int done = 0;
  int skipped = 0;
}

/// The phone a test runs on: its screen in dp, its look and its text scale.
class Phone {
  const Phone({this.screen = const Size(568, 320), this.tv = false, this.textScale = 1});

  final Size screen;
  final bool tv;
  final double textScale;
}

/// Mounts a host screen with three anchors (top left, middle, bottom right, so
/// the box goes below some and above others) and the marks over it. With
/// [settle] false it stops after the first frame, with the anchor read but the
/// box not yet shown.
Future<Calls> pumpMarks(
  WidgetTester tester, {
  Phone phone = const Phone(),
  List<GlobalKey>? anchors,
  List<CoachStep>? steps,
  bool settle = true,
}) async {
  tester.view.physicalSize = phone.screen;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.textScaleFactorTestValue = phone.textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final keys = anchors ?? [GlobalKey(), GlobalKey(), GlobalKey()];
  final calls = Calls();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        party.lookPrefsProvider.overrideWithValue(prefs),
        party.lookClockProvider.overrideWithValue(() => DateTime(2026, 11, 8, 12)),
        if (phone.tv) party.toyTvProvider.overrideWithValue(true),
      ],
      child: Consumer(
        builder: (context, ref, _) {
          final look = ref.watch(party.toyLookProvider);
          return party.ToyLookScope(
            look: look,
            child: MaterialApp(
              theme: party.toyTheme(look),
              home: Scaffold(
                body: Stack(
                  children: [
                    Positioned.fill(child: _Host(keys: keys)),
                    Positioned.fill(
                      child: CoachMarks(
                        steps:
                            steps ??
                            [
                              CoachStep(anchor: keys[0], text: tipOne),
                              CoachStep(anchor: keys[1], text: tipTwo),
                              CoachStep(anchor: keys[2], text: tipThree),
                            ],
                        onDone: () => calls.done++,
                        onSkip: () => calls.skipped++,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
  if (settle) await settleMarks(tester);
  return calls;
}

/// Pumps twice: the marks read their anchor after the frame that laid it out,
/// and show the box on the frame after that.
Future<void> settleMarks(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

class _Host extends StatelessWidget {
  const _Host({required this.keys});

  final List<GlobalKey> keys;

  @override
  Widget build(BuildContext context) {
    Widget anchor(GlobalKey key, Alignment alignment) => Align(
      alignment: alignment,
      child: SizedBox(key: key, width: 80, height: 48),
    );
    return Stack(
      children: [
        Positioned.fill(child: anchor(keys[0], Alignment.topLeft)),
        Positioned.fill(child: anchor(keys[1], Alignment.center)),
        Positioned.fill(child: anchor(keys[2], Alignment.bottomRight)),
      ],
    );
  }
}

/// The sizes of every CustomPaint on the screen, in the order they are in the tree.
List<Size> paintSizes(WidgetTester tester) {
  final paints = find.byType(CustomPaint);
  return [for (var i = 0; i < paints.evaluate().length; i++) tester.getSize(paints.at(i))];
}

void main() {
  group('the coach marks go through their steps', () {
    testWidgets('a tap goes from step 1 to step 2 to step 3 and the last tap calls onDone once', (tester) async {
      final calls = await pumpMarks(tester);
      expect(find.text(tipOne), findsOneWidget);
      expect(find.text(tipTwo), findsNothing);

      await tester.tap(find.text(tipOne));
      await settleMarks(tester);
      expect(find.text(tipTwo), findsOneWidget);

      await tester.tap(find.text(tipTwo));
      await settleMarks(tester);
      expect(find.text(tipThree), findsOneWidget);
      expect(calls.done, 0);

      await tester.tap(find.text(tipThree));
      await settleMarks(tester);
      expect(calls.done, 1);
      expect(calls.skipped, 0);
    });

    testWidgets('a tap on the dimmed screen goes on like a tap on the box', (tester) async {
      await pumpMarks(tester);
      await tester.tapAt(const Offset(284, 5));
      await settleMarks(tester);
      expect(find.text(tipTwo), findsOneWidget);
    });

    testWidgets('Skip at step 2 calls onSkip and not onDone', (tester) async {
      final calls = await pumpMarks(tester);
      await tester.tap(find.text(tipOne));
      await settleMarks(tester);
      await tester.tap(find.text('Skip'));
      await settleMarks(tester);
      expect(calls.skipped, 1);
      expect(calls.done, 0);
    });

    testWidgets('a step whose anchor has no render box is skipped over, not a crash', (tester) async {
      final keys = [GlobalKey(), GlobalKey(), GlobalKey()];
      final lost = GlobalKey();
      final calls = await pumpMarks(
        tester,
        anchors: keys,
        steps: [
          CoachStep(anchor: lost, text: tipOne),
          CoachStep(anchor: keys[1], text: tipTwo),
        ],
      );
      expect(tester.takeException(), isNull);
      expect(find.text(tipOne), findsNothing);
      expect(find.text(tipTwo), findsOneWidget);
      expect(calls.done, 0);
    });

    testWidgets('marks with no step that has an anchor call onDone once', (tester) async {
      final calls = await pumpMarks(
        tester,
        steps: [CoachStep(anchor: GlobalKey(), text: tipOne)],
      );
      expect(calls.done, 1);
      expect(calls.skipped, 0);
    });
  });

  group('the box sits below or above its anchor, with the arrow between them', () {
    testWidgets('on the bottom right anchor the box lies above the anchor, and its bottom is above the anchor top', (
      tester,
    ) async {
      final keys = [GlobalKey(), GlobalKey(), GlobalKey()];
      await pumpMarks(
        tester,
        phone: const Phone(screen: Size(640, 360)),
        anchors: keys,
      );
      await tester.tap(find.text(tipOne));
      await settleMarks(tester);
      await tester.tap(find.text(tipTwo));
      await settleMarks(tester);
      expect(find.text(tipThree), findsOneWidget);
      final box = tester.getRect(find.byType(party.ToyCard));
      final anchor = tester.getRect(find.byKey(keys[2]));
      expect(box.bottom, lessThanOrEqualTo(anchor.top), reason: 'box $box, anchor $anchor');
    });

    testWidgets('with room below the top left anchor the box lies below it and an arrow is drawn', (tester) async {
      final keys = [GlobalKey(), GlobalKey(), GlobalKey()];
      await pumpMarks(
        tester,
        phone: const Phone(screen: Size(640, 360)),
        anchors: keys,
      );
      final box = tester.getRect(find.byType(party.ToyCard));
      final anchor = tester.getRect(find.byKey(keys[0]));
      // The box sits one hole padding and one arrow height below the anchor.
      expect(box.top, anchor.bottom + coachHolePaddingDp + coachArrowHeightDp, reason: 'box $box, anchor $anchor');
      expect(paintSizes(tester), contains(const Size(coachArrowWidthDp, coachArrowHeightDp)));
    });
  });

  group('the marks stop cleanly and the tap after the end does nothing', () {
    testWidgets('unmounting the marks after their first frame calls neither onDone nor onSkip', (tester) async {
      final calls = await pumpMarks(tester, settle: false);
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(calls.done, 0);
      expect(calls.skipped, 0);
    });

    testWidgets('a tap after onDone does not call onDone again', (tester) async {
      final calls = await pumpMarks(tester);
      await tester.tap(find.text(tipOne));
      await settleMarks(tester);
      await tester.tap(find.text(tipTwo));
      await settleMarks(tester);
      await tester.tap(find.text(tipThree));
      await settleMarks(tester);
      expect(calls.done, 1);
      await tester.tapAt(const Offset(284, 5));
      await settleMarks(tester);
      await tester.tapAt(const Offset(284, 5));
      await settleMarks(tester);
      expect(calls.done, 1);
      expect(calls.skipped, 0);
    });

    testWidgets('a tap after Skip does not call onSkip again', (tester) async {
      final calls = await pumpMarks(tester);
      await tester.tap(find.text('Skip'));
      await settleMarks(tester);
      await tester.tap(find.text('Skip'));
      await settleMarks(tester);
      await tester.tap(find.text(tipOne));
      await settleMarks(tester);
      expect(calls.skipped, 1);
      expect(calls.done, 0);
    });
  });

  group('the box fits the screen and its touch targets are at least 48 dp', () {
    for (final tv in [false, true]) {
      final lookName = tv ? 'TV look' : 'menu look';
      for (final entry in screens.entries) {
        testWidgets('at ${entry.key} in the $lookName every step keeps the box inside and Skip 48x48', (tester) async {
          await pumpMarks(
            tester,
            phone: Phone(screen: entry.value, tv: tv),
          );
          await expectEveryStepFits(tester, entry.value, '${entry.key} $lookName');
        });
      }
      testWidgets('at 320x640 with text scale 1.3 in the $lookName every step fits', (tester) async {
        const screen = Size(320, 640);
        await pumpMarks(
          tester,
          phone: Phone(screen: screen, tv: tv, textScale: largeTextScale),
        );
        await expectEveryStepFits(tester, screen, '320x640 at 1.3x $lookName');
      });
      testWidgets('at 568x320 with text scale 1.3 in the $lookName every step fits', (tester) async {
        const screen = Size(568, 320);
        await pumpMarks(
          tester,
          phone: Phone(tv: tv, textScale: largeTextScale),
        );
        await expectEveryStepFits(tester, screen, '568x320 at 1.3x $lookName');
      });
    }
  });
}

/// Walks the three steps and checks, at each, that the box lies inside [screen]
/// and that Skip and the box are at least 48 dp each way.
Future<void> expectEveryStepFits(WidgetTester tester, Size screen, String label) async {
  const touchDp = 48.0;
  final bounds = Offset.zero & screen;
  for (final tip in [tipOne, tipTwo, tipThree]) {
    expect(find.text(tip), findsOneWidget, reason: '$label shows "$tip"');
    expect(tester.takeException(), isNull, reason: '$label overflows at "$tip"');
    final box = tester.getRect(find.byType(party.ToyCard));
    expect(
      bounds.contains(box.topLeft) && bounds.contains(box.bottomRight),
      isTrue,
      reason: '$label: box $box at "$tip"',
    );
    final skip = tester.getSize(find.widgetWithText(TextButton, 'Skip'));
    expect(skip.width, greaterThanOrEqualTo(touchDp), reason: '$label: Skip width at "$tip"');
    expect(skip.height, greaterThanOrEqualTo(touchDp), reason: '$label: Skip height at "$tip"');
    expect(box.height, greaterThanOrEqualTo(touchDp), reason: '$label: box height at "$tip"');
    await tester.tap(find.text(tip));
    await settleMarks(tester);
  }
}
