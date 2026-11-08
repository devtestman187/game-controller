job: M13 step 3c: the phone's own screens and cards in the toy look (connect, settings, diagnostics, the cards over the pad, the tuning dialogs, the host start sheet, the host chip, the top bar), their colours from the look, their texts in the string table, and a status pill in toy_look
stop: after it.
read: docs/design/look-and-sound.md sections 2 (D5, D8, D10, D11, D12), 3, 4 and 5 (Menus, Cards over the game) · docs/design/look-mockups.html (the frames 'Phone: connect screen', 'TV: Look and sound settings' and `phone-paused`: their SVG code is the layout to follow) · docs/briefs/m13/s3b-host-screens-report.md (and Claude's review at its end) · docs/briefs/m13/s3a-look-wiring-report.md (Claude's review) · packages/toy_look/lib · packages/party_host/lib/src/host_text.dart · packages/party_host/lib/src/ui/host_button.dart · controller_app/lib/src/ui · controller_app/lib/src/host · controller_app/test/support · docs/review-rules.md · docs/coding-guidelines.md

3b restyled the host's screens in party_host. This job restyles the phone app's own screens in controller_app. The pad itself (A/B/X/Y, D-pad, sticks, tilt) is step 8 and the TV app is 3d; leave both alone.

In scope: connect_screen, connect_panels, settings_screen, settings_sections, diagnostics_screen, diagnostics_view_section, waiting_card, abandoned_notice, rating_prompt, gyro_dialog, stick_dialog, host_chip, controller_top_bar, bar_connection, bar_modes, status_panel, labels (controller_app/lib/src/ui), and host_start_sheet, host_screen (controller_app/lib/src/host).
Out of scope (step 8, don't touch): face_buttons, pad_widgets, controls_layer, stick_widgets, tilt_view, pad_mode_view, controller_parts, joined_view.

Claude's rules:
1. **Screens** (design section 5, "Menus"): the title in `type.title` and `onBackground`, then `ToyButton`s and `ToyCard`s on 3a's toy page background (don't add another). Groups in `ToyCard`s, rows on paper.
   - **Connect** (mock-up 'Phone: connect screen'): each TV or phone host found is a paper row; "Host a game" is a ToyButton in `good`; Settings is a paper ToyButton.
   - **Settings** (mock-up 'TV: Look and sound settings'): each section is a ToyCard with its name in the header band. The Look and sound card moves to the top, before Controls and Haptics. Split `_HapticsSection.build` (70 lines; review.sh's one standing FAIL) into parts under 60. The Defaults button keeps leaving the look alone: it resets the controls, not the look (keep, and test it).
   - **Diagnostics**: its groups in ToyCards, rows on paper.
   - **Host start sheet**: a ToyCard sheet, its two choices as ToyButtons.
2. **Cards over the pad** (waiting, abandoned, rating): a `ToyCard` with a coloured header each. Waiting: `caution`. Abandoned: `bad`. Rating: `focus`. Keep each card's text, keys, buttons, focus and timing exactly; only the look changes. The rating's stars are drawn in `focus` with an ink edge, not as text.
3. **The top bar and the host chip** sit over the pad's background. Their text and icons are `onBackground`. The link quality (good, slow, bad) is a `ToyBadge`-sized dot in `good`/`caution`/`bad` with an ink edge beside the text, never the text's colour. The status panel's warning is a `bad` fill with ink text. The bar's sizes don't change (D11: the bar's 48-high row is a touch target).
4. **Status colours**: text is never `good`, `caution` or `bad`, on paper or on the background (good on paper is 2:1; 3b's review). A status is either a dot beside ink or onBackground text, or the new **`ToyPill`** in toy_look:
   - `ToyPill({required String label, required Color fill, IconData? icon})`: a stadium of `fill` with a `sizes.outlineWidth` ink edge, the label in `type.body`'s size with the button's family and weight in ink, padding `space8`/`space4`, no shadow. 3d uses it on the TV's controllers panel.
   - Tests in toy_look: its height on the phone and the TV look; ink text on every status fill at 4.5:1 (add the pairs to the contrast test if any is missing).
5. **Colours**: every `Colors.`, `Color(0x`, `colorScheme`, `scheme.` and `Theme.of(context).textTheme` read in the in-scope files goes. Each takes the look's token for its meaning:
   - on paper: `ink`, or `inkSoft` for a label beside its value;
   - on the background: `onBackground`;
   - status: as rule 4;
   - player: `player(n)`.

   After the job, `grep -nE "Colors\.|Color\(0x|colorScheme|scheme\.|textTheme" <each in-scope file>` finds nothing; put the command and its output in the report. `Colors.transparent` may stay where a widget needs "no colour"; list each one kept.
6. **Texts**: every player-facing text in the in-scope files moves to the string table.
   - If `host_text.dart` would pass 400 lines, split it now: `packages/party_host/lib/src/text/` with one file per area (`host_text.dart` for the host's screens, `phone_text.dart` for these) and `HostText` and `PhoneText` as `abstract final class`es, both exported from party_host.dart. 3b's tests that use `HostText` keep working.
   - A text with a value is a small static function.
   - Any pair that says one thing two ways becomes one; list them in the report.
   - Tests keep their literal texts.
7. **Sizes**: from `look.sizes` and `look.type`, never literals. The phone uses the phone's look (`toyTvProvider` false), and a tablet too.
   - A new fit test per restyled screen and card pumps it at 667 × 375, 852 × 393 and 1180 × 820, in Sunny and in Night, with `controller_app/test/support/test_font.dart`'s fonts loaded, and expects no overflow and no exception.
   - Where the type doesn't fit, shrink spacing first, then the layout, never the type.
8. **Contrast**: every text you colour is ink or inkSoft on paper, onBackground on the background, or ink on a fill. Nothing is faded below `inkSoft`.
9. Keep files under 400 lines and functions under 60; move widgets into `*_widgets.dart` files as the others do.
10. Change nothing else: no behaviour, timing, focus order, key or text (bar the merged pairs), no pad file, no file outside the allow list.

tests (each failing first, unless it only guards a fit):
- toy_look: `ToyPill` (height on each look, ink label, ink edge; contrast pairs).
- controller_app:
  - Connect: Host a game is a ToyButton in `good`; each host found is a paper row.
  - Settings: the sections are ToyCards with their names in the header, Look and sound first; Defaults leaves the Look setting as it was.
  - The waiting, abandoned and rating cards' headers are `caution`, `bad` and `focus`.
  - The link dot's colour for good, slow and bad, and the bar's text is onBackground.
  - The status panel's warning is a `bad` fill with ink text.
  - The PhoneText (or HostText) functions.
  - Rule 7's fit tests.
- The existing tests all still pass (look, host, phone, tv); fix any that pinned an old colour and list them in the report.

in the report: test counts before and after (look, host, phone, tv); the files changed; the colour grep; the `Colors.transparent` kept; the merged texts; any test whose pinned colour or text changed.
self-check: docs/review-rules.md part A, items 1–5, one line each in the report with the test that shows it.
rules: no lib file over 400 · no function over 60 lines · tests first, each failing for the missing behaviour · tools/review.sh: no FAIL on your lines · write only inside this job's folder.
allow: docs/briefs/m13/s3c-phone-screens-report.md · packages/toy_look · packages/party_host/lib · packages/party_host/test · controller_app/lib/src/ui · controller_app/lib/src/host · controller_app/test
check: format analyze look kit host phone tv
report: docs/briefs/m13/s3c-phone-screens-report.md
