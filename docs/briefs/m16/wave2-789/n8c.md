job: wave2-789 n8c — coach marks overlay as a pure widget
model: sonnet
stop: Pure widget: no saved flag, no Home, no routing, no consent. Takes its steps and callbacks as arguments.
read: docs/briefs/templates/COMMON.md · controller_app/lib/src/home/home_text.dart and home_contract.dart (from n8a: HomeText, HomeAnchors; read them first) · controller_app/lib/src/ui/connect_screen.dart:150-260 (how widgets use ToyLookScope, ToyCard, ToySizes) · controller_app/test/connect_narrow_test.dart (sizes, looks, text scale helpers) · docs/briefs/m16/ux-review/APP-START.md:36-52 · owner decision: the screen is dimmed, a hint box with an arrow points at one anchor at a time, a tap advances, Skip dismisses; nothing else.
changes: CoachStep · CoachMarks
turns: 50
expected-min: 35
do:
1 New file controller_app/lib/src/home/coach_marks.dart: `class CoachStep { final GlobalKey anchor; final String text; }` and `CoachMarks({required List<CoachStep> steps, required VoidCallback onDone, required VoidCallback onSkip})`: a full-screen Stack above its parent: a dim scrim with a rounded hole around the current anchor's rect (read from the anchor's RenderBox after layout, re-read on layout change), a hint box (ToyCard-style, look colours, ink text on paper) placed below the anchor or above it when below has no room, with an arrow toward the anchor, the step text, and a Skip button. A tap on the scrim or the box advances; the last step's tap calls onDone; Skip calls onSkip at any step. A step whose anchor has no render box yet is skipped over, never a crash.
2 Skip and the advance area are at least 48 dp (set minimum sizes; do not scale text down). The box wraps its text and stays inside the screen at 568x320, 320x640 and 1.3x text.
3 Tests FIRST, new file controller_app/test/coach_marks_test.dart: a host screen with three anchors; step 1 text shows, tap shows step 2, tap shows step 3, tap calls onDone once; Skip at step 2 calls onSkip and not onDone; the box rect is inside the screen and the Skip button is at least 48x48 at 568x320, 640x360, 320x640, 375x667 and with 1.3x text scale, in the menu look and the TV look (`party.toyTvProvider.overrideWithValue(true)`); touch-target test: the 48 dp assertion above.
4 Before finishing run `dart analyze` on the files you changed and fix every info.
allow: controller_app/lib/src/home/coach_marks.dart · controller_app/test/coach_marks_test.dart
check: format analyze
report: docs/briefs/m16/wave2-789/n8c-report.md
