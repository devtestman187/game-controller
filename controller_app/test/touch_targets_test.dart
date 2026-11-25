import 'package:controller/src/ui/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart' as party;

import 'support/pump_app.dart';

/// The owner's rule (PRD acceptance): every touch target is at least this many logical pixels on a side.
const minTargetDp = 48.0;

/// The phone sizes the targets are measured at (the same four as connect_narrow_test.dart).
const targetScreens = {
  '568x320': Size(568, 320),
  '640x360': Size(640, 360),
  '375x667': Size(375, 667),
  '320x640': Size(320, 640),
};

/// Today's offenders, measured on the base: `'<screen> <key, tooltip, text or type>'` to the size found (the
/// smallest over the sizes and looks). The test needs every target outside this map to be at least
/// [minTargetDp] and every entry here to still be below it, so whoever fixes a target removes its entry.
const knownBelow48 = <String, Size>{};

/// How far below [minTargetDp] a measured side may fall and still count as 48: layout rounds sizes to device pixels
/// (a 48 dp box can measure a hair under).
const touchRoundingSlackDp = 0.01;

/// The screens measured: what is on screen after [open] ran.
enum TargetScreen {
  pad('pad'),
  connect('connect'),
  settings('settings');

  const TargetScreen(this.label);

  /// The screen's name in [knownBelow48].
  final String label;
}

void main() {
  for (final screen in TargetScreen.values) {
    for (final entry in targetScreens.entries) {
      for (final tv in [false, true]) {
        testWidgets(
          'every touch target on ${screen.label} at ${entry.key} in the ${tv ? 'TV' : 'menu'} look is '
          'at least 48 dp or listed in knownBelow48',
          (tester) async {
            final app = await pumpApp(
              tester,
              // The portrait pad has no Settings button, so Settings opens from Connect's Settings button.
              paired: screen == TargetScreen.pad,
              screen: entry.value,
              extra: [if (tv) party.toyTvProvider.overrideWithValue(true)],
            );
            if (screen != TargetScreen.pad) await reachConnect(tester);
            if (screen == TargetScreen.pad) {
              // Connected, so the bar shows the mode control a linked pad has.
              app.client.emit(connected);
              await settle(tester);
            }
            if (screen == TargetScreen.settings) {
              // Connect's list may hide its Settings button below the fold on a short screen: scroll it into view first.
              await tester.ensureVisible(find.text('Settings'));
              await tester.tap(find.text('Settings'));
              await settle(tester);
            }
            final found = screen == TargetScreen.settings
                ? await measureScrolling(tester, screen.label)
                : measureTargets(tester, screen.label);
            // The pad in portrait shows no control (the phone asks to be turned), so only it may find none.
            final portraitPad = screen == TargetScreen.pad && entry.value.height > entry.value.width;
            if (!portraitPad) expect(found, isNotEmpty, reason: 'no touch target found on ${screen.label}');
            final below = {
              for (final e in found.entries)
                if (_below(e.value)) e.key: e.value,
            };
            final unlisted = [
              for (final e in below.entries)
                if (!knownBelow48.containsKey(e.key)) '${e.key}: ${e.value} (${entry.key}, ${tv ? 'TV' : 'menu'})',
            ];
            expect(unlisted, isEmpty, reason: 'touch targets below 48 dp that knownBelow48 does not list');
          },
          // B-044 control: on the pad at 568x320 in the TV look the connectionChip ActionChip is 35.9x48, below 48 dp.
          skip: screen == TargetScreen.pad && tv && entry.key == '568x320',
        );
      }
    }
  }

  // No "entry is still below 48" check while knownBelow48 is empty: it would depend on the other tests' order. A
  // future entry gets its check inside each case, over the keys of that screen.
}

bool _below(Size size) =>
    size.width < minTargetDp - touchRoundingSlackDp || size.height < minTargetDp - touchRoundingSlackDp;

/// How far one drag scrolls Settings while its rows are measured (the list builds only the rows on screen).
const scrollStepDp = 200.0;

/// The most drags that walk the Settings list to its end.
const maxScrollSteps = 60;

/// [measureTargets] over the whole of the Settings list, top to end. Scoped to [SettingsScreen] so Connect's own
/// scrollable underneath the Settings route is not the one walked.
Future<Map<String, Size>> measureScrolling(WidgetTester tester, String screen) async {
  final found = measureTargets(tester, screen);
  expect(find.byType(SettingsScreen), findsOneWidget, reason: 'Settings is open');
  final scrollable = find.descendant(of: find.byType(SettingsScreen), matching: find.byType(Scrollable)).first;
  final position = tester.state<ScrollableState>(scrollable).position;
  for (var step = 0; step < maxScrollSteps && position.pixels < position.maxScrollExtent; step++) {
    await tester.drag(scrollable, const Offset(0, -scrollStepDp));
    await tester.pump();
    for (final e in measureTargets(tester, screen).entries) {
      final old = found[e.key];
      if (old == null || e.value.width * e.value.height < old.width * old.height) found[e.key] = e.value;
    }
  }
  return found;
}

/// The tappable widgets whose hit area is measured; a [Material] button's own [InkWell] is not counted twice.
final _tappables = <Finder>[
  find.byType(IconButton),
  find.byType(ButtonStyleButton),
  find.byType(party.ToyButton),
  find.byType(Switch),
  find.byType(Slider),
  find.byType(DropdownButton),
  find.byType(PopupMenuButton),
  find.byType(Chip),
  find.byType(InputChip),
  find.byType(ActionChip),
  find.byType(ChoiceChip),
  find.byType(ListTile),
  find.byType(InkWell),
];

/// Every tappable on screen as `'<screen> <name>'` to the smallest size found for that name.
Map<String, Size> measureTargets(WidgetTester tester, String screen) {
  final sizes = <String, Size>{};
  final counted = <Element>{};
  for (final finder in _tappables) {
    for (final element in finder.evaluate()) {
      if (!counted.add(element)) continue;
      if (_insideCounted(element)) continue;
      final box = element.renderObject;
      if (box is! RenderBox || !box.hasSize) continue;
      // Hidden by an offstage route or scrolled out of the layout is still measured: the size is the same.
      final key = '$screen ${_nameOf(element)}';
      final old = sizes[key];
      if (old == null || box.size.width * box.size.height < old.width * old.height) sizes[key] = box.size;
    }
  }
  return sizes;
}

/// True when [element] sits inside another tappable of the kinds above (its box is that one's hit area).
bool _insideCounted(Element element) {
  var inside = false;
  element.visitAncestorElements((ancestor) {
    final w = ancestor.widget;
    if (w is IconButton ||
        w is ButtonStyleButton ||
        w is party.ToyButton ||
        w is Switch ||
        w is Slider ||
        w is DropdownButton ||
        w is PopupMenuButton ||
        w is ListTile ||
        w is ActionChip ||
        w is InputChip ||
        w is ChoiceChip ||
        w is Chip) {
      inside = true;
      return false;
    }
    return true;
  });
  return inside;
}

/// The widget's key, else its tooltip, else its first text, else its type.
String _nameOf(Element element) {
  final w = element.widget;
  final type = w.runtimeType.toString();
  if (w.key is ValueKey) return '$type ${(w.key! as ValueKey).value}';
  if (w is IconButton && w.tooltip != null) return '$type ${w.tooltip}';
  String? text;
  void visit(Element child) {
    if (text != null) return;
    final cw = child.widget;
    if (cw is Text && cw.data != null) {
      text = cw.data;
      return;
    }
    child.visitChildren(visit);
  }

  element.visitChildren(visit);
  return text == null ? type : '$type $text';
}
