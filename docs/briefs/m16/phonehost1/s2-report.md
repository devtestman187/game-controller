# M16 phonehost1 S2 — HostFrameScreen scaffold, ScoreRow, RoundSegment

## Summary

- Added `packages/party_host/lib/src/ui/host_frame_screen.dart`: `HostFrameScreen` (title left + optional
  `trailing` chip in a 64 px header, the body as the only `Expanded`, an 84 px footer holding the screen's
  buttons at the right end, the 24 px gutter applied to all three) with `hostFrameHeaderHeightPx`,
  `hostFrameFooterHeightPx` and `hostFrameGutterPx`. It is a `Scaffold`, like the existing `HostScreen`.
- Added `score_row.dart`: `ScoreRow` + its value object `ScoreRowData` (rank, number, character, name, points,
  delta): rank column 32 px, `PlayerBadge` at 38 px, a 190 px name column with ellipsis, a bar that takes the
  slack and fills by `points / maxPoints`, the star with the score, and `+delta` (hidden at 0). Named consts:
  `scoreRowHeightPx` 52, `scoreRowBadgePx` 38, `scoreRowNameWidthPx` 190, `scoreRowRankWidthPx` 32,
  `scoreRowBarHeightPx` 16, `scoreRowStarPx` 24.
- Added `round_segment.dart`: `RoundSegment` + `RoundOption` (value + label), two chips at 48 px
  (`roundChipHeightPx`) in the header; the chosen chip is filled with `colors.focus`, the others with
  `colors.paper`; each chip is a tap/keyboard button (FocusableActionDetector with the host's
  `hostActivateShortcuts`, `HostFocusRing` for the host's focus look) drawn with the look's `ToyPillPainter`.
- Tests first: `packages/party_host/test/host_frame_screen_test.dart` (23 tests), written before the widgets and
  failing on the old code ("Method not found: 'HostFrameScreen'"), now passing.
- Checks: `tools/check.sh format analyze host` → PASS format, PASS analyze, PASS host (whole package).
  `tools/review.sh` → 0 fail, 0 note; `tools/review.sh --strings` → 7 added, all keys and number formats
  (`'hostFrameHeader'`, `'${row.rank}'`, `'+$delta'`, …), no new player-facing prose.
- `host_frame.dart` (S1) and `host_screen.dart` are untouched; no screen is moved to the new scaffold yet.

## Decisions

1. **`HostFrameScreen(title, trailing, body, footer)`**, where `footer` is a list of widgets. The scaffold never
   picks a button kind: S3–S6 pass `ToyButton`s (or whatever the screen needs), so the layout does not depend on
   the look's button sizes — which matter until the design's "pick `ToyType.frame` inside `HostFrame`" wiring
   exists (see Open questions 5).
2. **The gutter lives in the scaffold** (`hostFrameGutterPx` 24 each side of header, body and footer). DESIGN
   rule 4 says a card fills the stage minus a 24 px gutter; putting it in one place means S3–S6 need no padding
   of their own and every screen's body starts at the same 24 px.
3. **It is a `Scaffold`**, as `HostScreen` is: S3–S6 replace `HostScreen(...)` with `HostFrameScreen(...)` and
   drop the `ListView` + `hostMenuPadding` shells, without adding another scaffold layer.
4. **`ScoreRow(row: ScoreRowData, maxPoints: int)`**: the guideline's "at most 5 parameters, beyond that a value
   object" applies to the row's eight facts, so they are one small value with a doc comment each. `ScoreRowData`
   is public because a screen builds its rows from a night's scores (S4) or an Arena round's coins (S6).
5. **The bar's fraction is `points / maxPoints`** (0 when the card's top score is 0, clamped to 1), so the leader
   fills the slack and the rows behind show their share of it (DESIGN rule 4: "width = points"). The bar is a
   `tray` track with the player's colour inside it, its fill inset by the ink edge so the edge stays whole.
6. **`delta == 0` hides the `+n`**, so a final-scores card (nothing added) has no zeroes to read. The star and the
   score always show.
7. **The chip is not a `ToyButton`**: `ToyButton` takes its label size from `look.type` (18 px on a phone look),
   below the frame's 20 px floor, and the brief says the frame's type. The chip is 48 px
   (`roundChipHeightPx`) with `ToyType.frame.button` at `ToyType.frame.body`'s size (22) in ink, which is how
   `ToyPill` sets its own label.
8. **`RoundSegment(value, onChanged, options)`**: the labels are parameters (`RoundOption.label`), so the widget
   holds no strings; the night's `NightText.threeRounds`/`fiveRounds` stay the screen's to pass. `onChanged` null
   draws chips that can't be picked (a night already under way).
9. **Keys for tests and tools**: `hostFrameHeader`, `hostFrameBody`, `hostFrameFooter`, `scoreRowBar`.
10. **The test file copies `host_frame_test.dart`'s five-device table** (`_Case`, `_pumpFrame`) rather than moving
    it to `test/support/`, which is outside this job's `allow:`. A later slice that needs it twice should move it.

## The rendered frame px (what the tests assert)

- Header 64, footer 84 at every size; the body takes the rest: **392** at 960x540 (640x360, 1920x1080),
  **392** at 1170.687x540 (852x393), **572** at 960x720 (1024x768), **452** at 960x600 (1280x800).
- The header/footer span the frame's full width; their content is inset 24 either side, so the body's content
  is 912 px wide at 960 and 1122.687 at 1170.687.
- The footer's frame rect ends exactly at the frame's bottom edge (drawn: 304…360 device px at 640x360, s = 2/3;
  1080 - 84 x 2 = 912…1080 at 1920x1080) and stays there while the body's 1200 px list scrolls.
- Six score rows: 6 x 52 = **312** ≤ 392, each row the body's full 912 (960) / 1122.687 (1170.687) wide.
- The bar takes every spare frame px: 210.687 wider at 852x393's frame than at 960 (the frame's `extraW`).
- Chip 48 px inside the 64 px header (8 above and below), asserted at the five sizes by
  `host_frame_screen_safe_area_test.dart` (added in f2; S2 only drew it); title 40 px; every row text ≥ 20 px (body 22,
  delta 20).
- `Nightshade` (10 characters) at the frame's body size measures inside the 190 px column (`didExceedMaxLines`
  false); a 21-character name exceeds it and is ellipsised rather than clipped.

## Naming

Confirmed as fixed by Claude: the scaffold is `HostFrameScreen` in `host_frame_screen.dart` (the existing title-bar
`HostScreen` in `host_screen.dart` is untouched), `ScoreRow` in `score_row.dart`, `RoundSegment` in
`round_segment.dart`; all three are exported from `lib/party_host.dart`.

## Self-check (review-rules part A)

1. **Every host setup** — the three widgets read only the look and the frame and no provider beyond the host's
   focus look (`HostFocusRing`), so the TV/PC host, a phone on "Play on this phone", "Show on this device" and a
   joined phone get the same widget; the five-device tests include 1920x1080 and 640x360 with taps through the
   transform ("the footer stays put and its buttons work while the body scrolls", each size). No app uses them yet.
2. **When kept state starts and ends** — nothing is held, timed or counted: all three are stateless and
   `RoundSegment` only reports the value its caller holds ("picking the other chip reports its own value").
3. **How a new state combines** — no pause/away/wait state is added; the only stateful thing is the focus
   (`HostFocusRing` around each chip), which combines with nothing and stays pickable while the body scrolls or
   the footer is used ("a chip takes the focus and the centre key picks it").
4. **Stay in the job's folder** — `git status` shows only the six allowed paths (five Dart files plus this
   report); `run.log` and the `tv_test_app/windows/flutter/generated_plugin*` files were touched by the tooling,
   not by me.
5. **Stop rather than overstep** — nothing outside `allow:` was needed; `host_frame.dart` and `host_screen.dart`
   were read only. The open points below are questions, not changes.

## Open questions

1. **Safe-area insets inside the frame.** `HostFrameScreen` does not wrap its column in a `SafeArea`, so the
   64/84 are exact; on a phone with a notch in landscape the frame's insets (`HostFrameInfo` divides them by the
   scale) would be unclaimed. Should the scaffold take them (and give up some of the 64/84) or do S4/S6's screens?
   **Answered in f2:** the scaffold claims them once (`SafeArea` around its column); the 64/84 stay the content's
   heights and the insets add room outside them. See `f2-report.md`.
2. **The footer has no band.** The design says "footer bar" and puts Thumby's corner "at the left end of the
   footer bar"; the footer here is the sky with the buttons at its right end. Is a paper strip wanted (S3)?
3. **The final scores' taller winner row** (58 px badge, 32 px type) needs a size variant of `ScoreRow`; the row's
   height is a const today. Add a flag in S4 or an `heightPx` parameter?
4. **What the row sits on.** The row draws ink (`colors.ink`) on the assumption it is inside a `ToyCard`; on the
   sky it would want `colors.onBackground`. Which one is the scoreboard's (S4)?
5. **The look's type inside the frame.** The three widgets use `ToyType.frame` directly. Until the wiring of
   DESIGN section 5 exists (the look picking `frame` inside `HostFrame`), a `ToyButton` in the footer still draws
   its label at the look's own size (18 px on a phone look), below the 20 px floor — the footer's buttons are only
   in the floor once that wiring is in.

## Suggestions

- The chip's focus ring is the look's rounded-rect `ToyFocusRing` drawn over a stadium-shaped pill; they differ by
  the corner radius (16 vs 24) at the chip's ends. Either give the pill a 16 px radius or let `ToyFocusRing`
  take a shape.
- The five-device table is now in two test files; the next slice that needs it can move it to `test/support/`.

## Hand-over

- S2 is complete and unused: no screen is moved to `HostFrameScreen` yet (S3–S6 do that). `HostFrame` is still not
  wired into either app.
- S3 can build the night start card as `HostFrameScreen(title: …, trailing: RoundSegment(…), body: <one row of
  three AwardTiles + names>, footer: [Shape Race, Bumper Round])`; the five-device test file here is the pattern
  for its own tests.

## Commit message

Add the host frame screen scaffold, score row and round segment (M16 S2)

- HostFrameScreen: 64 px header with title and trailing chip, the body as
  the only flexing region, an 84 px footer with the screen's buttons at the
  right end, and the design's 24 px gutter; a Scaffold, like HostScreen.
- ScoreRow (+ ScoreRowData): rank, 38 px PlayerBadge, 190 px name column
  with ellipsis, a bar filling by points/maxPoints that takes the slack,
  star + score, +delta; 52 px rows, six of them in a 392 px body.
- RoundSegment (+ RoundOption): two 48 px chips in the header, the chosen
  one in the focus yellow, each pickable by tap, remote, Enter or gamepad A.
- Tests at the five devices: header/footer sizes and positions, the footer
  staying put while the body scrolls, six rows fitting, the bar's share and
  slack, the name column, the 20 px floor, chip selection and focus.
- Exported from party_host.dart; no existing screen changed.

## Status row

S2 done: HostFrameScreen, ScoreRow + ScoreRowData, RoundSegment + RoundOption (23 tests, five devices), exported; no screen uses them yet. Open: S3 (night start), S4 (scoreboard/final), S5 (reveal), S6 (Arena/puzzle results), the frame's safe-area and footer-band questions.

## Delete

- none
