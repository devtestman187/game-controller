job: M13 step 3b — the host's screens and cards in party_host in the toy look: HostButton becomes a ToyButton, menus and cards are ToyCards with badges, the game picker shows each game as a big drawn card, the 3-2-1 pops, every colour in party_host comes from the look, and the host's texts move into one string table
stop: after it.
read: docs/design/look-and-sound.md sections 2 (D5, D8, D10, D12), 3, 4 and 5 (Menus, Cards over the game) · docs/design/look-mockups.html (the frames `game-picker`, `join-screen`, `results`, `phone-paused` and `settings`: their SVG code is the layout to follow) · docs/briefs/m13/s3a-look-wiring-report.md (and Claude's review at its end) · packages/toy_look/lib · packages/party_host/lib/src/ui (all of it) · packages/party_host/test/support/host_harness.dart · docs/code-health.md (the "Look-and-sound" row) · docs/review-rules.md · docs/coding-guidelines.md

3a put both apps in the look's theme and fonts. This job restyles what the host shows, on the TV, the PC and the phone host alike: everything in packages/party_host/lib/src/ui. The game boards themselves (Shape Race's painter, the Arena's) are steps 4 and 5; the phone's own screens and the TV's home are 3c.

Claude's rules:
1. **Buttons.**
   - `HostButton` keeps its API and its callers, and draws a `ToyButton` (fill as given, else `good`), passing `showFocus: ref.watch(hostFocusLookProvider)` (M12 bug 1107f: no focus look on a touch-first host).
   - Its `compact` form (a panel's title row) needs a smaller button: add `dense` to ToyButton in toy_look (height 0.75 of `sizes.buttonHeight`, the label in `type.body`'s size with the button's family and weight), with a test there.
   - `hostButtonLook` (rows, steps and cards that are buttons) becomes the toy version of the same rule. At rest: paper, a `sizes.outlineWidth` ink side, `sizes.cardCorner` corners, ink text. Lit (pressed, or focused while the focus look shows): the `focus` fill with a `sizes.focusRing` ring in `focus` outside the ink edge.
2. **Screens** (design section 5, "Menus"): a title in `type.title` and `onBackground`, then `ToyButton`s and `ToyCard`s on the page's toy background (from 3a's page transition; don't add another).
   - The **game picker**: each game is a big `ToyCard` with a drawn picture above its title and line, drawn by a small CustomPainter with `toyShape` (fallback, or the look's `shade` when it has one).
     - Shape Race: a triangle in `player(4)`, a square in `player(2)` and a circle in `player(1)`, overlapping a little, like pieces on a mat.
     - The Arena: a `player(1)` marble (a circle) beside a `good` goal pad (a rounded square) with a small ink flag pole.
     - The pictures are 0.4 of the card's height.
   - The **Shape Race list** (levels and puzzles), **puzzle settings**, **stats** and the **stats consent** dialog: their groups in ToyCards, their rows on paper.
3. **The join screen** (mock-up `join-screen`): each side a ToyCard whose header band is the side's colour with its name, each joined player a row with a `ToyBadge` and their name, an empty seat a dashed line. Start and Back are ToyButtons, Start in `good`. Keep the format line, every key and the focus order.
4. **Cards over the game** (design section 5, "Cards over the game"): a `ToyCard` with a coloured header for each. Keep each card's text, keys, buttons, focus and timing exactly; only the look changes.

   | Card | Header band | Other changes |
   | --- | --- | --- |
   | Results (mock-up `results`) | The winning side's colour, or `focus` for a draw | Each side's time and pieces with their ✓ |
   | Pause (mock-up `phone-paused`) | `focus` | The badge of who paused |
   | Away | `caution` | Its countdown in `type.clock` |
   | Ready, 3-2-1 | none | Each number in `type.clock`'s family at 3 times its size, popping 1.3 → 1.0 over 250 ms with `Curves.easeOutBack` as it changes when `look.effects` is on, and still when it's off |
   | Arena's "No controller connected" and the debug overlay | | Paper cards |

   The play hint ("Start on a phone: pause · Back: leave") is `onBackground` text on a `ToyBadge`-like pill of the background colour, unchanged in words.
5. **Colours**: every `Colors.` and `Color(0x` in packages/party_host/lib goes; each use takes the look's token for its meaning (greenAccent → `good`, amberAccent → `caution`, a red → `bad`, white on the background → `onBackground`, white or black on paper → `ink`, the old player colours → `player(n)`). After the job `grep -rE "Colors\.|Color\(0x" packages/party_host/lib` finds nothing; put that grep in the report.
6. **The string table** (code-health.md's "Look-and-sound" row):
   - `packages/party_host/lib/src/host_text.dart` holds every player-facing text in packages/party_host/lib/src/ui, as `abstract final class HostText` with `static const` strings and small static functions for texts with a value. Example: `static String playerAway(int number) => 'Player $number is away'`.
   - "P2 is away" and "Player 2 is away" become that one function's text, wherever party_host says either. Any other pair that says one thing two ways becomes one too; list them in the report.
   - Export it (3c moves the phone's texts to it).
   - Tests keep their literal texts: they're the specification, so a changed word fails a test.
   - The texts 3a added (Look and sound) move in too.
7. **Sizes**:
   - On the TV (`toyTvProvider` true) a screen uses the TV's type and sizes, on a phone the phone's (3a's ToyLook does this; take sizes from `look.sizes`, not literals).
   - A new test per restyled screen and card pumps it at 960 × 540 with the TV look and at 852 × 393 with the phone look, in Sunny and in Night, with the look's real fonts loaded (as `controller_app/test/support/test_font.dart` does), and expects no overflow and no exception. Where the TV's bigger type doesn't fit, shrink spacing first, then the layout, never the type.
8. Keep files under 400 lines: pause_menu.dart (385) and join_screen.dart (363) will grow, so move their widgets into `*_widgets.dart` files as the others do.
9. Change nothing else: no behaviour, timing, focus order, key or text (bar the merged pairs in rule 6). No game painter. No file outside party_host and toy_look's lib, bar tests.

tests (each failing first, unless it only guards a fit):
- toy_look: ToyButton dense (height 36 on a phone, 48 on a TV; the label's size).
- party_host:
  - HostButton draws a ToyButton with the focus look on a TV host and none on a touch-first one.
  - hostButtonLook at rest (paper, ink side) and lit (the focus fill).
  - The picker's two cards each have their picture.
  - The join screen's sides have ToyCard headers in their side colours and a ToyBadge per player.
  - The results header is the winner's colour, and `focus` on a draw.
  - The away card's header is `caution`.
  - The ready card's number pops with effects on (1.3 at its start, 1.0 after 250 ms) and doesn't with them off.
  - The HostText functions; the merged away text on the away card.
  - Rule 7's fit tests.
- The existing tests all still pass (host, phone, tv); fix any that pinned an old colour and list them in the report.

in the report: test counts before and after (look, host, phone, tv); the files changed; the colour grep; the merged texts; any test whose pinned colour or text changed.
self-check: docs/review-rules.md part A, items 1–5, one line each in the report with the test that shows it.
rules: no lib file over 400 · no function over 60 lines · tests first, each failing for the missing behaviour · tools/review.sh: no FAIL on your lines · write only inside this job's folder.
allow: docs/briefs/m13/s3b-host-screens-report.md · packages/toy_look · packages/party_host · controller_app/test · tv_test_app/test
check: format analyze look kit host phone tv
report: docs/briefs/m13/s3b-host-screens-report.md
