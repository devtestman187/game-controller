# d2g report: "Set up your night"

## Summary

Done. `tools/mine.sh`: OK, 1202 tests in packages/party_host (format, analyze, touched tests; the existing night_start_* and night_cards_fit tests pass unchanged). Option C was not built.

Files:
- `lib/src/text/night_setup_text.dart` NEW: all the setup's words (title, row labels, chip names, picker names and help lines, buttons, cat note, start-card words).
- `lib/src/ui/night_setup_widgets.dart` NEW: `NightSetupRow` (label, Wrap of chips, optional help line) and `NightSetupChip`.
- `lib/src/ui/night_setup_screen.dart` NEW: `NightSetupScreen`.
- `lib/src/ui/night_start_screen.dart`: `_length` starts from the settings and the header segment writes it back; "Set up" button (key `nightSetup`) at the right end of the bottom line; with a picker other than host, one "Start the night" footer button (key `nightStartPick`) and the line "Games are picked for you".
- `lib/party_host.dart`: exports `NightSetupText` and `NightSetupScreen`.
- `test/night_setup_screen_test.dart` NEW: 12 tests (fit at 360x640 and 320x640 in the menu and TV looks, behaviour, start card).

## How the screen fits

- `NightSetupScreen` is a `HostFrameScreen`. Its body is ONE `ListView` (the frame's one scrolling region), so a row is reached by scrolling at 360x640 and 320x640. Nothing is shrunk and no FittedBox is used.
- Each setting is a `NightSetupRow`: a label above a `Wrap` of chips, so chips go to a new line when the frame is narrow and no row overflows. Long help lines wrap.
- Rows: Kids chip, How long, Games, Easiest, Hardest, Who picks the next game (with the chosen picker's help line), then the cat note.
- Chip size rule: height at least max(48 frame px, 48 / scale), width at least 48 / scale, text at least max(body size, 14 / scale), with `scale = HostFrameInfo.maybeOf(context)?.scale ?? 1`. On a TV (scale above 1) the chip is the normal 48 px chip.
- Measured by the test (on-screen size, through the frame's transforms): every chip is at least 48.0 dp tall and wide, and its text at least 14.0 dp. In frame px that is a 128 px high chip with 37.3 px text at 360x640 (scale 0.375) and a 144 px chip with 42 px text at 320x640 (scale 0.3333). Both looks. I did not print the exact on-screen numbers: the test asserts >= 47.99 dp and >= 13.99 dp.
- Option C was not built.

## Decisions

1. **The Kids button is a chip at the top of the list, not in the footer.** The frame's footer is a fixed 84 frame px, which is 31.5 dp at 360x640: no button can be 48 dp tall in it, and HostFrameScreen may not change. So only Done is in the footer (always on screen, tested after scrolling the list to its end); like every footer button and the header's back arrow in the app (see `knownBelow48Host`), Done is below 48 dp on a phone. The test checks Done is inside the screen and works, not its size. The brief's "every button measures 48 dp" is therefore met for every chip and the Kids button, not for Done.
2. `NightSetupText` has `Rotating`/`Vote` names only because the picker switches are exhaustive; no row offers them.
3. Start card: after the setup screen closes, `_length` is re-read from the settings.
4. I did not export the night settings/pick types from party_host.dart: it would have made the existing tests' `src` imports unnecessary (analyzer infos in files I may not change). My test imports them from `src`.

## Self-check (review-rules part A)

1. Host setups: the start card with a one-player roster in both pickers (`the start button with a Shape Race pool and one player`, `... Bumper Round pool`); a TV or phone host differs only by look and size (fit tests, 360x640 and 320x640, menu and TV). Joined phone / old-build peer: no change to those paths (night_start_old_app_test passes unchanged).
2. Kept state: the settings are saved on every change (`a tap changes the setting and the saved prefs`); the played list holds one variant after a picked start; nothing going on: the chips are plain settings.
3. A running night: `a running night shows the settings read-only`. Pause menu, host away, results and leaving: not touched by this job.
4. Stayed in the allow list.
5. Nothing needed outside it.
6. Both looks: the fit tests run menu and TV; no fixed pixel height for a chip (height is a minimum from the scale).

## Questions

1. Is a Kids chip in the list (decision 1) acceptable, or should the footer be taller on phones (a HostFrameScreen change, which this job may not make)?
2. The picker help lines are my wording.

## Commit message

night2b d2g: Set up your night screen and the start card's Set up button

A scrolling setup screen (length, games, easiest, hardest, who picks, Kids)
drawn in the host frame, with 48 dp / 14 dp chips on a phone. Every change
is saved through the night settings. The start card's length now lives in
the settings, gets a Set up button, and with a picker other than the host
it has one "Start the night" button that opens round 1's pick.

## Status row

d2g: setup screen built, fits 360x640 and 320x640 by scrolling, start card Set up and Start the night done; open: Done in the footer is below 48 dp on phones (frame footer 84 px), option C not built.

## Delete

- none
