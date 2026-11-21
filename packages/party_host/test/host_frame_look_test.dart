import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';

/// The phone's own look, the one the host app's scope holds (DESIGN section
/// 5): a phone-shaped look, which the frame turns into the frame's type.
final _phoneLook = ToyLook.build(palette: ToyPalette.sunny, tv: false);

/// A screen inside the frame that reports what the frame gives it: the look
/// below it and the text scale it is drawn at.
final class _Probe extends StatelessWidget {
  const _Probe(this.seen);

  /// Takes what the probe saw, once per build.
  final void Function(ToyLook look, TextScaler textScaler) seen;

  @override
  Widget build(BuildContext context) {
    seen(ToyLookScope.of(context), MediaQuery.textScalerOf(context));
    return const SizedBox.expand();
  }
}

/// Mounts [home] the way a host app does (DESIGN section 5): the phone's look
/// over a `MaterialApp` whose builder puts the frame above the navigator, at
/// [device]'s size with a device pixel ratio of 1, so logical and physical
/// pixels are the same.
///
/// [outside] reads the look the scope holds above the frame, which is the
/// look a widget outside it still sees.
Future<void> pumpPhoneHost(
  WidgetTester tester,
  Size device, {
  required Widget home,
  ToyLook? look,
  void Function(ToyLook look)? outside,
}) async {
  tester.view.physicalSize = device;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ToyLookScope(
      look: look ?? _phoneLook,
      child: Builder(
        builder: (context) {
          outside?.call(ToyLookScope.of(context));
          return MaterialApp(builder: hostFrameBuilder, home: home);
        },
      ),
    ),
  );
}

void main() {
  testWidgets('the frame drops the device\'s text scale: 2.0 outside reads as no scaling inside', (tester) async {
    // A phone host with the system text made twice as large.
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    // The device really is scaling its text: the same platform value read
    // outside the frame is 2.0.
    TextScaler? outside;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            outside = MediaQuery.textScalerOf(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(outside!.scale(10), 20);

    TextScaler? inside;
    await pumpPhoneHost(tester, const Size(640, 360), home: _Probe((_, textScaler) => inside = textScaler));
    // The frame's layout is fixed at 960x540, so the device's scale would only
    // overflow it: inside the frame the text is drawn at its frame size.
    expect(inside, TextScaler.noScaling);
  });

  testWidgets('a phone look draws as the frame\'s type inside the frame and stays the phone\'s outside', (
    tester,
  ) async {
    ToyLook? outside;
    ToyLook? inside;
    await pumpPhoneHost(
      tester,
      const Size(640, 360),
      outside: (look) => outside = look,
      home: _Probe((look, _) => inside = look),
    );

    // The frame keeps the palette and the sizes; only the type changes.
    expect(outside, _phoneLook);
    expect(inside!.palette, outside!.palette);
    expect(inside!.sizes, outside!.sizes);
    expect(inside!.colors, outside!.colors);
    expect(inside!.type, same(ToyType.frame));
    expect(inside!.type.title.fontSize, 40);
    expect(inside!.type.button.fontSize, 28);
    expect(inside!.type.body.fontSize, 22);
  });

  testWidgets('a button in the frame draws its label at 28 frame px, 18.7 dp at 640x360', (tester) async {
    await pumpPhoneHost(
      tester,
      const Size(640, 360),
      home: Scaffold(
        body: Center(
          child: ToyButton(label: 'Play', onPressed: () {}),
        ),
      ),
    );

    final paragraph = tester.renderObject<RenderParagraph>(find.text('Play'));
    final fontSize = (paragraph.text as TextSpan).style!.fontSize!;
    // The phone's own button size would be 18 frame px, 12 dp at this scale.
    expect(fontSize, 28);
    expect(fontSize, ToyType.frame.button.fontSize);

    // 640x360 is a scale of 2/3, so 28 frame px are 18.67 device px.
    final scale = HostFrameInfo.of(tester.element(find.byType(ToyButton))).scale;
    expect(scale, moreOrLessEquals(2 / 3, epsilon: 1e-9));
    expect(fontSize * scale, moreOrLessEquals(18.7, epsilon: 0.05));
  });

  testWidgets('a TV look inside the frame reads the frame\'s type too, at one set for every host', (tester) async {
    ToyLook? inside;
    await pumpPhoneHost(
      tester,
      const Size(1920, 1080),
      look: ToyLook.build(palette: ToyPalette.sunny, tv: true),
      home: _Probe((look, _) => inside = look),
    );

    // One size set for the TV and the phone hosts (DESIGN section 5): at
    // 1920x1080 the title is the frame's 40 px, drawn at 80 device px.
    expect(inside!.type, same(ToyType.frame));
    expect(inside!.type.title.fontSize, 40);
  });

  testWidgets('a zero-size device builds an empty frame instead of a NaN one', (tester) async {
    // A minimised desktop window, or the first layout before the size arrives:
    // the frame's scale would be zero and its size infinite, which a SizedBox
    // asserts on.
    tester.view.physicalSize = Size.zero;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ToyLookScope(
        look: _phoneLook,
        child: const MaterialApp(builder: hostFrameBuilder, home: Text('home')),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(HostFrame)), Size.zero);
  });
}
