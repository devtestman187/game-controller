job: M13 step 3d: the TV app's home and test screens in the toy look (theme only, layouts kept), measured as the TV draws them: the TV look, the look's fonts, 960 × 540
stop: after it.
read: docs/design/look-and-sound.md sections 2 (D5, D10, D12), 3, 4 and 5 (the last bullet: "TV home and test tools … the theme only; their layouts stay as they are") · docs/briefs/m13/s3b-host-screens-report.md and docs/briefs/m13/s3c-phone-screens-report.md (Claude's reviews at their ends) · packages/toy_look/lib · packages/party_host/lib/src/text · packages/party_host/lib/src/ui/host_button.dart · tv_test_app/lib · tv_test_app/test · docs/review-rules.md · docs/coding-guidelines.md

The TV app runs the TV look (`toyTvProvider` is true in tv_test_app/lib/main.dart), but its tests pump the phone look: nothing has been measured at the TV's type. 3b and 3c restyled the host's and the phone's screens. This job does the TV app's own screens: the home (`lib/src/ui/home/*`), the haptic panel, the latency screen, the input visualizer, the Look test screen (`shader_spike_*`) and `debug_start.dart`. The gallery (`toy_gallery.dart`) is the look's own and stays.

Claude's rules:
1. **The tests run the TV look.** `test/support/pump_app.dart` overrides `toyTvProvider` with true, as main.dart does; `flutter_test_config.dart` already loads the look's fonts. Fix what that breaks by rule 3, never by changing a test's sizes.
2. **Theme only** (design section 5): the panels, rows and buttons keep their places and keys. The changes:
   - **`Panel`**: paper with a `sizes.outlineWidth` ink edge and `ToySizes.cardCorner` corners, like a `ToyCard` with no header. Its title is `type.button` in ink, its padding from `ToySizes`.
   - **Text** on paper is ink, or `inkSoft` for a label beside its value. Text on the background is `onBackground`.
   - **A status is never coloured text** ("Connected" green on paper is 2:1). Use a `ToyPill` (3c) or a dot with an ink edge beside ink text:
     - in the controllers panel: Connected `good`, Waiting for code `focus`, reconnecting `caution`, gone `bad`;
     - in the pairing panel: the network and sound checks, and "No network connection".
   - **The pairing code** is `type.clock`'s family in ink. Each player's colour is `player(n)`, via `ToyBadge`.
   - **The log**: ink on paper, in a monospace family the platform has (keep what it uses now).
   - **The input visualizer**: the pressed buttons in the face tokens (`faceA`/`faceB`/`faceX`/`faceY`), the rest paper with an ink edge.
   - **The haptic panel and the latency screen**: rows on paper, their status colours as above.
3. **The home at 960 × 540 in the TV look** (the TV's size). This is what has to be true; how you get there is your choice, in this order: spacing first, then the header's arrangement, never the type.
   - The title "Thumb Party TV" is shown in full; today it is cut to "Thumb…". The version and protocol may move under it, or into the pairing panel.
   - The header is at most two button rows high.
   - The controllers panel shows two controllers' tiles in full: the sample state's iPhone and Pixel.
   - Every header button is still reached by the remote, in the same order (`home_screen_test` "the remote reaches and presses every button").
   - The narrow layout (below `HomeScreen.wideWidth`/`wideHeight`) still scrolls, and fits at 700 × 500.
4. **Colours**: every `Colors.`, `Color(0x`, `colorScheme`, `scheme.` and `textTheme` read in tv_test_app/lib goes. The exceptions are `toy_gallery.dart` and the shader spike's deliberate test colours, if any; list each one kept and why. Put the grep and its output in the report.
5. **Texts**: the TV app's own player-facing texts move to a new `TvText` (`abstract final class`, in `tv_test_app/lib/src/tv_text.dart`, under 400 lines). Texts the host already says come from `HostText`. Tests keep their literal texts.
6. Keep files under 400 lines and functions under 60. Change no behaviour, key, focus order or text, bar any merged pairs (list them).

tests (each failing first, unless it only guards a fit):
- `Panel` is paper with the ink edge and an ink title.
- The controllers panel's status for each state is a `ToyPill` or a dot in the state's token, with ink text.
- The input visualizer's pressed A/B/X/Y take the face tokens.
- The pairing code is ink in the clock family.
- Rule 3's fits:
  - at 960 × 540, the TV look, Sunny and Night: the home's title text is not cut (its `TextPainter` doesn't exceed its width), both controllers' names are visible inside the controllers panel, and there is no overflow;
  - the narrow home at 700 × 500;
  - the haptic panel, the latency screen and the Look test screen at 960 × 540, no overflow.
- All existing tests pass (look, host, phone, tv); list any whose pinned colour or text changed.

in the report: tv test counts before and after (and look, host, phone); the files changed; the colour grep and what was kept; the header's new arrangement in a sentence; the merged texts; tests whose pins changed.
self-check: docs/review-rules.md part A, items 1–5, one line each with the test that shows it.
rules: no lib file over 400 · no function over 60 lines · tests first, each failing for the missing behaviour · tools/review.sh: no FAIL on your lines · write only inside this job's folder.
allow: docs/briefs/m13/s3d-tv-home-report.md · tv_test_app/lib · tv_test_app/test
check: format analyze look host phone tv
report: docs/briefs/m13/s3d-tv-home-report.md
