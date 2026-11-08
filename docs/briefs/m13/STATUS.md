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
| 2 | Look package: tokens (Sunny and Night), the Look setting (Auto by time), toyTheme, ToyButton, ToyCard, ToyBadge, ToyBackground, fonts (Fredoka, Nunito), contrast test, rule-boundary test, literal check, string table | Waits for the font download (owner's OK) |
| 3 | Menus and cards on both apps | |
| 4 | Shape Race in the new look, and the worker | |
| 5 | The Arena (marbles with eyes) and its shader | |
| 6 | Shaders everywhere, the effects setting, toy_backdrop.frag | |
| 7 | Sound: lobby, countdown, player joined; looping; volume, music, mute | |
| 8 | The pad restyled at its sizes | |
| 9 | Full review, device tests, a build on the owner's word | |
