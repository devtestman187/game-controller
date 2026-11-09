# M13 status: Look and sound

Resume here. Branch `m13` in the worktree `E:\AI\game-controller-m13`, cut from `m12` at d06f88a on Nov 8, 2026. Design: docs/design/look-and-sound.md (approved by the owner, Nov 8). Mock-ups: docs/design/look-mockups/. PRD: M13 and L1 to L5.

## Ground rules

- M12's device-test fixes stay on `m12`; merge `m12` into `m13` when they land. A build from `m12` never carries M13 work.
- Every step is a flash-worker job with a brief here and a review gate; Claude designs, reviews and decides.
- Research jobs: `web: yes` briefs (tools/flash.sh --web).
- The look changes only through `toy_look`; rules never import it.
- Tags and builds only on the owner's word; TestFlight internal first.

## Steps (design section 9)

| # | Step | State |
| --- | --- | --- |
| 1 | Spike: toy_look skeleton, toy_shade.frag, toyShape with fallback, a Look test screen in the TV app; checked on Windows and the Android emulator | **Done** (f600fc6, 759f74e): shader works on Windows (Skia and Impeller) and Android (Impeller GLES); Windows TV app now on Skia (Impeller 15x slower drawing shapes); light and shadow fixed on screen. Not yet seen: iPhone, a real Android TV box (owner, through the TV and phone Look test screens once a build has them) |
| 2a | Look package values: tokens (Sunny and Night), the Look setting (Auto by time), fonts, type, ToyLook and ToyLookScope, toyTheme, contrast test, new player colours, review checks for colours and the rule boundary (s2a-tokens-and-theme.md) | **Done**: look 50 tests (13 before); every check green; Claude's review in the report (text follows the screen: onBackground on the background, ink on paper; rules-file check on lib only; toy_look formatted at 120). Open: fonts proven only on a device (step 3) |
| 2b | Look package widgets: ToyButton, ToyCard, ToyBadge, ToyBackground, and a gallery on the Look test screen (s2b-toy-widgets.md) | **Done**: look 74 tests, tv 35; gallery checked by Claude in both palettes with the real fonts; header band full width and a wider glow (Claude's review). Not yet seen on a TV or phone screen |
| 3a | Both apps run in the look: scope, theme, shaders and font licences at start, a toy background behind every page (through the page transition), the Look setting kept and applied at set moments, the Look and sound settings on phone and TV (s3a-look-wiring.md) | **Done**: look 81, host 164, phone 383, tv 36; replaced pages refresh the palette (Claude's review). Not yet seen on a device |
| 3b | The host's screens and cards in party_host restyled (picker, Shape Race list, join, pause, results, away, ready, puzzle settings, stats, consent), HostButton → ToyButton, party_host's colours into toy_look, the string table (s3b-host-screens.md) | **Done**: look 82, host 197, phone 383, tv 36. Screens checked by Claude in both palettes with real fonts. Claude's review: the fit test now really loops its looks; `inkSoft` token (0.7) for text on paper at 4.5:1; winner's time in ink; the away countdown in button type; the TV tests now measure in the look's fonts. Not yet seen on a device |
| 3c | The phone's own screens and cards (connect, settings, diagnostics, waiting, abandoned, rating, tuning dialogs, host start sheet, host chip, top bar), their colours and texts, `ToyPill` (s3c-phone-screens.md) | **Done**: look 88, host 197, phone 403, tv 36. Screens checked by Claude in both palettes with real fonts. Claude's review: p95 dash; no-link dot paper; `PhoneText` split, with `SettingsText` for settings and diagnostics; toy text fields (paper, ink edge, ink text). Not yet seen on a device |
| 3d | The TV app's home and test screens: the theme only, layouts kept (design section 5); the TV tests run the TV look; the title in full, the header at most two rows, two controllers in view at 960 × 540; statuses as `ToyPill`s; `TvText` (s3d-tv-home.md) | **Done**: tv 50 (+1 skipped), look 88, host 197, phone 403. Seen by Claude at 960 × 540 and 1280 × 720 in both palettes. Claude's review: the ping column sized from the type. Step 9: check the remote reaches the manual address, which is below the code at 960 × 540 |
| 4a | Shape Race in the look: board, tray, targets, pieces, dots, HUD (and its text measure), mirror; the snap boing and wrong wobble from the snapshots (s4a-shape-race-look.md) | **Done**: puzzle 144. Seen by Claude in a 2-player race at 960 × 540 in both palettes. Claude's review: the look's sizes use the canvas's whole scale (they were 6× too thick on the split screen); a flat mat and tray; ✓ and ✗ drawn as strokes; the test clocks pinned to midday. Not yet seen on a device |
| 4b | The worker: the player's dot as a character with eyes, arms and effort faces, its pose worked out from the snapshots (s4b-worker.md) | **Done**: puzzle 170. Seen by Claude in six poses. Claude's review: a bigger tummy number. Polish for step 9: the tongue, determined and "o" faces; the 7 mm floor on "Show on this device". Not yet seen on a device |
| 5 | The Arena (marbles with eyes) and its shader | |
| 6 | Shaders everywhere, the effects setting, toy_backdrop.frag | |
| 7 | Sound: lobby, countdown, player joined; looping; volume, music, mute | |
| 8 | The pad restyled at its sizes | |
| 9 | Full review, device tests, a build on the owner's word | |
