# M13 3c: the phone's own screens and cards in the toy look

Job: `docs/briefs/m13/s3c-phone-screens.md`. Stop after it.

## What changed

### toy_look
- `packages/toy_look/lib/src/toy_pill.dart` (new): `ToyPill({required String label, required Color fill, IconData? icon})`,
  a stadium of `fill` with a `sizes.outlineWidth` ink edge, the label in `type.body`'s size with the button's family and
  weight in ink, padding `space8`/`space4`, no shadow. Its height is `type.body * 1.25 + space8 + outlineWidth`: 29.75
  on the phone, 39.5 on the TV, both measured in the tests.
- `packages/toy_look/lib/toy_look.dart`: exports `toy_pill.dart`.
- `packages/toy_look/test/toy_pill_test.dart` (new): 5 tests — the height on each look, the label's type, the ink edge
  on every fill, and that a fill is drawn without a shadow.

### party_host
- `packages/party_host/lib/src/text/phone_text.dart` (new, 399 lines): `abstract final class PhoneText`, the phone's
  string table. Added this job: `share(num fraction)` (a 0..1 setting as a percent, where `percent` takes an
  already-percent number) and `supportedRow`.
- `packages/party_host/lib/src/text/host_text.dart`: 3b's table, moved from `src/host_text.dart` unchanged.
- `packages/party_host/lib/party_host.dart`: exports both tables; drops `src/host_text.dart`.

### controller_app (in scope)
- `connect_screen.dart`: the title and the bar's words from `PhoneText`, the hosts in a `ToyCard` (paper rows with the
  ink edge, `Key('hostRow-<name>')`, a kind icon in ink, the address in inkSoft), the manual address a paper row with a
  paper `ToyButton`.
- `connect_panels.dart`: every connection state as the look's widgets — icons in `onBackground`, the three ways on as
  `ToyButton`s ("Without a TV" paper, "Host a game" `good`, Settings paper), the code field in `type.title` with
  `space8` letterspacing, Try again/Cancel as `ToyButton`s.
- `settings_screen.dart`: `ToyCard` sections with their name in the header band (Look and sound first), a `Material`
  transparency so a `ListTile` inside a card does not assert, Defaults still leaving the look alone, the layout split
  into `_sections(width)` (two columns on a tablet, one list on the phone) so the file's functions stay under 60.
- `settings_sections.dart`: every section on the look's colours and `PhoneText`, `_HapticsSection.build` split into
  `_tickRow`, `_eventsHeading`, `_eventRow` and `_hardwareLine` (each under 60).
- `diagnostics_screen.dart`: the groups on `ToyCard`s (`_Section` with the bad header for a denied network), rows on
  paper, the log heading in `onBackground` over a `tray` block with the ink edge; the build split into one function per
  group so no function passes 60 lines.
- `diagnostics_screen_widgets.dart` (new part): `_logBlock` and `_Section` (the file was over 400 lines otherwise).
- `diagnostics_view_section.dart`: the game-view summary in a `ToyCard`.
- `waiting_card.dart`: a `ToyCard` with the `caution` header "Waiting"; the host-away lines from `PhoneText`/`HostText`.
- `abandoned_notice.dart`: a `ToyCard` with the `bad` header "Round over" and the sentence in `type.body`.
- `rating_prompt.dart`: a `ToyCard` with the `focus` header ("How did it feel?" / "What got in the way?"), the three
  faces as tinted cards in `good`/`caution`/`bad`, the tags as paper buttons, Skip and Send kept with their keys;
  `build` split into `_faces` and `_tagGrid`.
- `gyro_dialog.dart` and `stick_dialog.dart`: the look's type and colours, `PhoneText`, one `_slider` per dialog so both
  builds are under 60.
- `host_chip.dart`: the code in `type.title` ink, the menu items ink, the join hint in `type.body`/inkSoft, the chip's
  dot a 12 px good dot beside `onBackground` text.
- `controller_top_bar.dart`: the two icon buttons take `onBackground` and their tooltips from `PhoneText`.
- `bar_connection.dart`: the chip's label in `type.body`/`onBackground`, `LinkDot` in `good`/`caution`/`focus`/`inkSoft`
  with an ink edge, `PlayerBadge` in `player(n)` with ink text.
- `bar_modes.dart`: every label and tooltip from `PhoneText` (`modeName`, `gyroSettings`, `stickSettings`).
- `status_panel.dart`: paper fill with the ink edge, `bad` fill while warning, ink text, the progress in `good` (ink on
  a `bad` fill); `build` split into `_label`.
- `labels.dart`: the status words and the problem sentences are `PhoneText.status` and `PhoneText.problemText`.

### controller_app (host start sheet)
- `host/host_start_sheet.dart`: a `ToyCard` sheet with the two choices as `ToyButton`s and their "why" line under each;
  the keys (`hostOnPhone`, `hostOnDevice`, `hostCancel`) are kept.

### tests
- `controller_app/test/phone_look_test.dart` (new, 11 tests): the Connect buttons' fills (Host a game `good`, Settings
  paper, read from the painter, since an unset colour means `good`), a host row's paper fill and ink edge, Settings'
  cards' headers with Look and sound first and Haptics below it, Defaults keeping `look.choice` and resetting
  `gyroSensitivity`, the waiting/abandoned/rating headers' colours, `linkDotColor` for each status, the bar's chip and
  gear in `onBackground`, and the `PhoneText` functions.
- `controller_app/test/phone_fit_test.dart` (new, 8 tests): the Connect, Settings and Diagnostics screens, the bar with
  its status panel, the waiting card, the abandoned card, the rating card on both steps, and the host start sheet, each
  at 667 × 375, 852 × 393 and 1180 × 820 in Sunny and in Night, with `loadHostFonts`; no exception and no overflow.
  Each look starts from an empty tree so the last look's route does not sit over this one's.
- `controller_app/test/game_controls_test.dart`: the status panel's pin now reads the look (ink text, `bad` fill) instead
  of the scheme.
- `controller_app/test/connect_screen_test.dart`: the host start sheet's two choices are counted as `ToyButton`s.

## Test counts

| target | before | after |
| --- | --- | --- |
| look | 82 | 87 (+5: `ToyPill`) |
| host | 197 | 197 |
| phone | 383 | 402 (+19: 11 look rules, 8 fit tests) |
| tv | 36 (+1 skipped) | 36 (+1 skipped) |
| kit | 48 | 48 |

## The colour grep

```
grep -nE "Colors\.|Color\(0x|colorScheme|scheme\.|textTheme" <each in-scope file>
```
on `connect_screen, connect_panels, settings_screen, settings_sections, diagnostics_screen,
diagnostics_screen_widgets, diagnostics_view_section, waiting_card, abandoned_notice, rating_prompt, gyro_dialog,
stick_dialog, host_chip, controller_top_bar, bar_connection, bar_modes, status_panel, labels` (all under
`controller_app/lib/src/ui`) and `host/host_start_sheet.dart`, `host/host_screen.dart`: no output.

## Colours kept

`Colors.transparent`: **none**. Both dialogs that had it (the rating prompt and the host start sheet) now take the
theme's dialog paper, which is the same paper, corner and ink edge as a `ToyCard` (`paperShape`), so the card sits on
it exactly; that also clears `tools/review.sh`'s colour rule, which fails on any `Colors.` outside toy_look. 3b's
`pause_menu_widgets.dart` does the same.

## Texts merged

- The seven status words (`labels.dart`) and the nine problem sentences are one copy, in `PhoneText.status` and
  `PhoneText.problemText`; `idle` and `failed` both said "Not connected" and still do.
- The settings' floating-stick subtitle and the stick dialog's ("…in its half of the screen") are one:
  `PhoneText.floatingLine`; the dialog's switch and the settings' row now read the same words.
- The waiting card's three host lines ("The host has left", "Waiting for the host to come back", "Reconnecting to the
  game…") and its "You can keep waiting, or leave." live in `PhoneText` only; the card and the host's own away text
  share them.
- "Look and sound" is `HostText.lookAndSound` for both the TV's settings and the phone's new top card.
- The mode names (`D-pad`, `Gyro`, `Sticks`) and the two dialogs' tooltips are `PhoneText.modeName`,
  `PhoneText.gyroSettings`, `PhoneText.stickSettings`, replacing three private copies in `bar_modes.dart`.

## Tests whose pinned colour or text changed

- `game_controls_test.dart` ("the status panel shows the game's message"): pinned the scheme's `onSecondaryContainer`
  for the text and `secondaryContainer` for the fill; now pins `look.colors.ink` and `look.colors.bad` (the warning).
- `connect_screen_test.dart` ("host a game"): counted two `OutlinedButton`s in the sheet; now two `ToyButton`s.

## Fit tests (rule 7)

`phone_fit_test.dart`, described above. Values computed for the tests: `PhoneText.percent(70)` is `70%`,
`PhoneText.share(0.4)` is `40%`, `PhoneText.pingStats(5, 22, 130)` is `30 s: min 5 · avg 22 · max 130 ms`,
`PhoneText.linkWithPing('Android TV', null)` is `Android TV · – ms`, `PhoneText.hostLine('Phone', '192.168.1.51:45780')`
is `Phone · 192.168.1.51:45780`, `PhoneText.playerOnTv(2)` is `P2 on the TV`, `PhoneText.eventStrength('hit', 70)` is
`hit 70%`, `PhoneText.modeName('dpad')` is `D-pad`.

## Self-check, review rules part A

1. **Every host setup.** The screens are the phone's own; nothing in them reads the host's state. The waiting card and
   the abandoned card show for the same events as before (tested by `phone_fit_test.dart`'s two card tests, which play
   the Arena as a joined phone); the bar and its panel are the same widgets for a TV host and for a hosting phone
   (`connection_test`/`game_controls_test` still pass); nothing changed in what a host one build older sees.
2. **When kept state starts and ends.** Only the rating prompt's timer is involved and it is untouched: it restarts on
   each pick (`_restartTimer` in `_pick` and in each tag), and it sends and closes as before (`phone_metrics_test`
   green).
3. **How a new state combines with the others.** These are skins: no state, no focus order, no key changed. Waiting,
   abandoned and rating each still take the same one owner as before, and the fit tests pump the waiting and abandoned
   cards over a running round and the rating card over a paused-looking screen.
4. **Stay in the job's folder.** Every file written is inside this job's folder and in `allow:`; `git status` shows no
   other file written by this job (the `packages/party_host/lib/src/ui/*` and `tv_test_app/windows/*` entries it lists
   came with 3a/3b).
5. **Stop rather than overstep.** Nothing needed a file outside `allow:`. Two brief items had no code to change (the
   rating's stars, the `ToyBadge`-sized dot); they are questions below, not changes.

## Questions and suggestions

1. **The rating's stars** (rule 2). The prompt has no stars: it is three faces (`good`/`caution`/`bad`) and four tags,
   and nothing in the app draws a star (no `Icons.star`, no ★). The card's header is `focus` and a picked face takes a
   double ink edge, so the intent reads; if stars are wanted they are new UI, not a restyle.
2. **`ToyBadge`-sized dot** (rule 3). `ToyBadge`'s default is 40 px; the bar's row is 48 px with `statusPanelHeightShare`
   0.75 (= 36 px) for the panel, and rule 3 also says the bar's sizes don't change. The link dot stays `LinkDot.dotSize`
   (12) and takes the look's colour with an ink edge, so it is "badge-shaped, bar-sized". Say if it should grow to 40 on
   a taller bar instead.
3. **`Colors.transparent`** was allowed to stay but is gone (see above): the dialog theme already is the card's paper
   and edge, and the review's colour rule fails on it. If a widget ever needs a hole, the token belongs in toy_look.
4. **A p95 that isn't there** now reads `p95 0 ms` in the ping row (it was `p95 null ms`, which came from `int?` in
   `PhoneText.summaryWithP95`); the report text and the screen agree on this. Worth a `–` if you'd rather.
5. **The cards over the pad keep `FilledButton`/`TextButton`** for Leave game, Skip and Send: several tests pin those
   types and rule 2 says keep the buttons, so only the card around them is the look's. If the next step wants them as
   `ToyButton`, that is a test change too.
6. **`phone_text.dart` is 399 lines** — one line under the lib limit. The next phone string should push `PhoneText`
   into a part (`phone_text_widgets` isn't right for text) or a second class; worth a decision before 3d adds any.

## Commit message

M13 3c: the phone's screens and cards in the toy look

Connect, Settings, Diagnostics, the dialogs and the host start sheet are ToyCards and ToyButtons on 3a's page; the
hosts are paper rows. The waiting, abandoned and rating cards take caution, bad and focus headers. The bar and the
host chip read onBackground, the link is a dot in good/caution/bad with an ink edge, and a warning's panel is bad with
ink text. Every colour comes from the look and every text from the new PhoneText table (HostText moved beside it).
ToyPill joins toy_look with its tests, and a fit test covers each restyled screen and card at three sizes in both
palettes.

## Status row

M13 3c: the phone's own screens, dialogs and cards are in the toy look (colours from the look, texts in PhoneText, ToyPill in toy_look, fit tests at 667 × 375, 852 × 393 and 1180 × 820 in both palettes); open: the pad itself (A/B/X/Y, sticks, tilt) and the TV app are 3d/8, and the rating prompt has no stars to draw.

## Delete

- packages/party_host/lib/src/host_text.dart

## Claude's review (Nov 8, 2026)

Accepted, with these changes (each test-first):

1. **A p95 not yet known** read "p95 0 ms". `PhoneText.summaryWithP95` takes an `int?` and shows a dash for null (pinned in phone_look_test).
2. **The no-link dot** (idle, failed) was `inkSoft`, which is lost on the Night sky. It is now a `paper` dot with its ink edge.
3. **The string table's split**: `phone_text.dart` went to 401 lines with the fix above, so it is split now, as the worker suggested.
   - `PhoneText` keeps Connect, the bar, the modes, the cards, the rating and the host sheet (179 lines).
   - The new `SettingsText` (`src/text/settings_text.dart`, 231 lines) takes Settings, the tuning dialogs and Diagnostics. It is exported from party_host.
   - The two tables each had their own "–"; there is one now, `HostText.dash`.
4. **The text fields**: Connect's address field and the pairing-code field drew a stock Material border; the code field typed in `onBackground`, which would be white on paper at night.
   - toyTheme gains an `inputDecorationTheme`: paper fill, ink edge, card corners, a thicker edge on focus, the label kept inside, hint and label in `inkSoft`. It also sets an ink cursor.
   - Both fields drop their own border and type in ink.
   - Tests: toy_theme_test pins the field theme in both palettes; phone_look_test checks the address field at night.
5. **`toyTheme` passed 60 lines** with the field theme, so the switch's theme moved to `_switchTheme`.

Answers to the questions:
1. **No stars**: the brief was wrong, as the prompt has faces. The faces as tinted cards are right.
2. **The dot** stays bar-sized (12 px): D11 keeps the bar's sizes.
3. **`Colors.transparent`**: gone is better.
4. **p95**: a dash, as above.
5. **FilledButton and TextButton on the cards** stay. The theme draws them as toy pills, and the tests pin their types.
6. **The table's size**: split now, as above.

Seen by Claude at 852 × 393 in both palettes, with the real fonts: Connect, Settings, Diagnostics, the bar with its panel, waiting, abandoned, rating and the host start sheet. The pad behind the cards is still the old look (step 8). The bar's ping line wraps to two lines at the look's body size; it did before too, with `maxLines: 2`. Counts after the review: look 88, host 197, phone 403, tv 36 (+1 skipped).
