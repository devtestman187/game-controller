job: M13 device fixes 2: the Arena's A button says "Dash" on the phone, and the goal's flag is big and in the middle of the pad (owner's iPhone test of m13.1, Nov 9, 2026)
pub: no
stop: after it.
read: docs/design/look-and-sound.md section 5 (Arena) · packages/test_game/lib/src/arena_session.dart (arenaLayout), arena_painter.dart (_goal, _flag and the flag constants, lines 30-47 and 124-170), arena.dart (which buttons the Arena reads) · packages/puzzle_game/lib/src/puzzle_session.dart (how Shape Race labels its buttons) · test_game's tests (arena_paint_test, the session tests) · controller_app/lib/src/ui/face_buttons.dart (how a label is drawn) · docs/review-rules.md · docs/coding-guidelines.md

What the owner saw (iPhone, phone host, the Arena):
1. "The dash button used to be labeled on the controller buttons. We should add this back." Today `arenaLayout` labels only Start ("Pause"). Shape Race's face buttons say "Rotate" and "Pick up", but the Arena's A is a bare letter.
2. "The finish box should still say finish or make the flag bigger and centered. Current design doesn't look good." Today the goal is a green pad with a small 3 × 2 checkered flag at its top-right corner.

Claude's rules:
1. **The Arena's buttons:**
   - `arenaLayout` labels A "Dash", as Shape Race's layout labels its buttons. The label is the same string the TV's HUD uses for the dash ("Dash ready (A)"); share it if that string has a home, else a named constant in arena_session.dart.
   - Buttons the Arena never reads are hidden, as P5 allows. Check arena.dart for B, X and Y (and LB, RB, Select): hide a face button only if the rules read it nowhere. List what you hid. Start stays "Pause".
2. **The goal's flag (Claude's choice of the owner's two options): big and in the middle of the pad**, with no words, so it reads at every size and in every language:
   - The pole stands in the pad's middle. The pole with its cloth is about 60 % of the pad's shorter side tall, and the cloth is about half the pole's height.
   - The cloth is a 4 × 3 checkered banner of ink and paper, flying right from the pole's top, with an ink edge.
   - The pole is ink with a round paper knob on top, and stands on a small ink foot in the pad.
   - The whole flag is centred on the pad's middle, by its pole and cloth together.
   - Sizes are shares of the pad, named and documented, replacing `flagCheckerShare`/`flagMarginShare`'s corner placement. The glow and the pad stay as they are.
   - Keep it a flat plate (design 6: the goal stays flat).
3. Files under 400 lines, functions under 60; no colours outside the look's tokens.

tests (each failing first):
- `arenaLayout` labels A "Dash" and Start "Pause", and hides exactly the buttons the Arena never reads; a test that fails if the rules start reading a hidden button (e.g. by listing the buttons arena.dart reads).
- **The flag:**
  - at the pad's middle there is ink or checks, not the pad's green;
  - the flag's drawn height is 55–65 % of the pad's shorter side;
  - the flag's bounding box is centred on the pad within 5 % of its side;
  - in Sunny and Night;
  - and on a phone-sized and a TV-sized box.
- All existing tests pass (look, puzzle, arena, host, phone, tv, kit). List any you change, and why.

in the report:
- test counts before and after;
- the files changed;
- the buttons hidden;
- the flag's shares.
self-check: docs/review-rules.md part A, items 1–5, one line each with the test that shows it.
rules: no lib file over 400 · no function over 60 lines · tests first, each failing for the missing behaviour · tools/review.sh: no FAIL on your lines · write only inside this job's folder.
allow: docs/briefs/m13/s11-device-arena-report.md · packages/test_game
check: format analyze arena host phone tv
report: docs/briefs/m13/s11-device-arena-report.md
