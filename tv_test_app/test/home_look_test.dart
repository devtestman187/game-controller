import 'package:connection/connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_assets/asset_manifest.dart';
import 'package:party_host/party_host.dart';
import 'package:tvtest/src/ui/home/controllers_panel.dart';
import 'package:tvtest/src/ui/home/log_panel.dart';
import 'package:tvtest/src/ui/home/panel.dart';
import 'package:tvtest/src/ui/home/pairing_panel.dart';
import 'package:tvtest/src/ui/status_line.dart';

import 'support/pump_app.dart';

/// The TV look every screen is drawn in (M13 3d): the TV's type and sizes, the
/// Sunny palette the tests' clock picks.
final tvLook = ToyLook.build(palette: ToyPalette.sunny, tv: true);

/// The first [ShapeDecoration] a panel draws, which is its paper.
ShapeDecoration? panelPaper(WidgetTester tester, Finder panel) {
  for (final element in find.descendant(of: panel, matching: find.byType(DecoratedBox)).evaluate()) {
    final decoration = (element.widget as DecoratedBox).decoration;
    if (decoration is ShapeDecoration) return decoration;
  }
  return null;
}

/// The status line whose text is [label].
StatusLine statusLine(WidgetTester tester, String label) =>
    tester.widget<StatusLine>(find.ancestor(of: find.text(label), matching: find.byType(StatusLine)));

/// A host state with one controller in each state: connected, waiting for the
/// code, and gone.
HostViewState threeControllers() {
  ControllerInfo info(String id, String name, ControllerState state, {int? player}) => ControllerInfo(
    controllerId: id,
    name: name,
    platform: 'android',
    appVersion: '0.1.0',
    remoteAddress: '192.168.1.2$id',
    state: state,
    since: DateTime(2026),
    player: player,
  );
  return HostViewState(
    hostName: 'Android TV',
    host: HostSnapshot(
      running: true,
      port: 45780,
      pairingCode: '0427',
      controllers: [
        info('c1', 'Connected phone', ControllerState.connected, player: 1),
        info('c2', 'Waiting phone', ControllerState.pairing),
        info('c3', 'Gone phone', ControllerState.disconnected),
      ],
    ),
  );
}

void main() {
  testWidgets('a panel is paper with the ink edge, a card corner and an ink title', (tester) async {
    await pumpApp(tester);
    final panel = find.byType(Panel).first;
    final paper = panelPaper(tester, panel);
    expect(paper, isNotNull, reason: 'the panel draws its paper as a shape with an ink edge');
    expect(paper!.color, tvLook.colors.paper);
    final shape = paper.shape as RoundedRectangleBorder;
    expect(shape.side.color, tvLook.colors.ink);
    expect(shape.side.width, tvLook.sizes.outlineWidth);
    expect(shape.borderRadius, BorderRadius.circular(ToySizes.cardCorner));

    final title = tester.widget<Text>(find.descendant(of: panel, matching: find.text('Pairing code')));
    expect(title.style?.color, tvLook.colors.ink);
    expect(title.style?.fontFamily, tvLook.type.button.fontFamily);
    expect(title.style?.fontSize, tvLook.type.button.fontSize);
  });

  testWidgets('each controller state is a dot in its token, beside ink text', (tester) async {
    final fake = await pumpApp(tester);
    fake.state = threeControllers();
    fake.emit();
    await tester.pumpAndSettle();

    expect(statusLine(tester, 'Connected').color, tvLook.colors.good);
    expect(statusLine(tester, 'Waiting for code').color, tvLook.colors.focus);
    expect(statusLine(tester, 'Disconnected').color, tvLook.colors.bad);
    for (final label in ['Connected', 'Waiting for code', 'Disconnected']) {
      expect(tester.widget<Text>(find.text(label)).style?.color, tvLook.colors.ink, reason: '$label is ink on paper');
    }
  });

  testWidgets('the network and sound checks are statuses, and a missing network is bad', (tester) async {
    await pumpApp(tester);
    // The sample state advertises and all the sounds loaded.
    expect(statusLine(tester, 'Phones on this Wi-Fi can find this TV').color, tvLook.colors.good);
    expect(
      statusLine(tester, '${SoundKey.values.length} of ${SoundKey.values.length} event sounds loaded (fake)').color,
      tvLook.colors.good,
    );

    final fake = await pumpApp(tester);
    final s = fake.state;
    fake.state = HostViewState(hostName: s.hostName, host: s.host, addresses: const []);
    fake.emit();
    await tester.pumpAndSettle();
    expect(statusLine(tester, 'No network connection').color, tvLook.colors.bad);
    expect(tester.widget<Text>(find.text('No network connection')).style?.color, tvLook.colors.ink);
  });

  testWidgets('the pairing code is ink in the clock family', (tester) async {
    await pumpApp(tester);
    final style = tester.widget<Text>(find.byKey(const Key('pairingCode'))).style;
    expect(style?.color, tvLook.colors.ink);
    expect(style?.fontFamily, tvLook.type.clock.fontFamily);
    expect(style?.fontSize, tvLook.type.clock.fontSize);
  });

  testWidgets('the log is ink paper in the platform\'s monospace family', (tester) async {
    await pumpApp(tester);
    final panel = find.descendant(of: find.byType(LogPanel), matching: find.byType(Panel));
    // The TV host logs no lines of its own in a test, so the style is what is
    // checked: the panel's paper, and ink lines in a monospace family.
    final style = LogPanel.lineStyle(tvLook);
    expect(style.color, tvLook.colors.ink);
    expect(style.fontFamily, 'monospace');
    expect(style.fontSize, tvLook.type.body.fontSize);
    expect(panelPaper(tester, panel)?.color, tvLook.colors.paper);
  });

  testWidgets('the controllers panel shows a tile per controller on paper', (tester) async {
    await pumpApp(tester);
    expect(find.byType(ControllerTile), findsNWidgets(2));
    expect(panelPaper(tester, find.byType(ControllersPanel)), isNotNull);
    expect(panelPaper(tester, find.byType(PairingPanel)), isNotNull);
    // The header's own texts sit on the background, so they are onBackground.
    expect(tester.widget<Text>(find.text('Thumb Party TV')).style?.color, tvLook.colors.onBackground);
  });
}
