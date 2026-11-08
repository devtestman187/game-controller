import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';

import 'support/host_harness.dart';

/// A screen with one host button on it, for the look's checks.
class _ButtonScreen extends StatelessWidget {
  const _ButtonScreen();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: HostButton(key: const Key('probe'), label: 'Go', onPressed: () {}),
    ),
  );
}

void main() {
  testWidgets('a host button draws the look\'s toy button', (tester) async {
    await pumpHost(tester, screen: const _ButtonScreen());
    final button = tester.widget<ToyButton>(
      find.descendant(of: find.byKey(const Key('probe')), matching: find.byType(ToyButton)),
    );
    expect(button.label, 'Go');
    expect(button.dense, isFalse);
  });

  testWidgets('the focus look reaches the button on a TV', (tester) async {
    await pumpHost(tester, screen: const _ButtonScreen());
    expect(
      tester
          .widget<ToyButton>(find.descendant(of: find.byKey(const Key('probe')), matching: find.byType(ToyButton)))
          .showFocus,
      isTrue,
    );
  });

  testWidgets('a touch-first host hides the focus look on the button', (tester) async {
    await pumpHost(tester, screen: const _ButtonScreen(), overrides: [hostTouchFirstProvider.overrideWithValue(true)]);
    expect(
      tester
          .widget<ToyButton>(find.descendant(of: find.byKey(const Key('probe')), matching: find.byType(ToyButton)))
          .showFocus,
      isFalse,
    );
  });

  testWidgets('a host button style is paper with the ink edge, and takes the focus fill and ring when lit', (
    tester,
  ) async {
    late ButtonStyle style;
    late ToyLook look;
    await pumpHost(
      tester,
      screen: Builder(
        builder: (context) {
          look = ToyLookScope.of(context);
          style = hostButtonLook(context, showFocus: true);
          return const SizedBox.shrink();
        },
      ),
    );
    final colors = look.colors;

    // At rest: paper, ink text, and the look's ink edge on the look's corners.
    expect(style.backgroundColor!.resolve({}), colors.paper);
    expect(style.foregroundColor!.resolve({}), colors.ink);
    final rest = style.shape!.resolve({})! as HostEdgeBorder;
    expect(rest.isLit, isFalse);
    expect(rest.side.color, colors.ink);
    expect(rest.side.width, look.sizes.outlineWidth);
    final rounded = rest.getOuterPath(const Rect.fromLTWH(0, 0, 100, 50));
    expect(rounded.contains(const Offset(1, 1)), isFalse, reason: 'the corners are cut by the card corner');

    // Lit: the focus fill, and the ring [hostRingPx] wide outside the ink edge.
    expect(style.backgroundColor!.resolve({WidgetState.focused}), colors.focus);
    expect(style.backgroundColor!.resolve({WidgetState.pressed}), colors.focus);
    expect((style.shape!.resolve({WidgetState.focused})! as HostEdgeBorder).isLit, isTrue);
    expect(hostRingPx, ToySizes.focusRing);
  });

  testWidgets('with the focus look hidden, a focused button stays at rest', (tester) async {
    late ButtonStyle style;
    late Color paper;
    await pumpHost(
      tester,
      screen: Builder(
        builder: (context) {
          paper = ToyLookScope.of(context).colors.paper;
          style = hostButtonLook(context, showFocus: false);
          return const SizedBox.shrink();
        },
      ),
    );
    expect((style.shape!.resolve({WidgetState.focused})! as HostEdgeBorder).isLit, isFalse);
    expect(style.backgroundColor!.resolve({WidgetState.focused}), paper);
  });
}
