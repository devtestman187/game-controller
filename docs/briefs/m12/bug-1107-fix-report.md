# Bug 1107 fix report — the dot reaches the tray on phones; the advertising tag (G4)

**Done.** Bug 1's fix (one value in `_computePhones`, its doc, three failing tests) and the advertising tag
(`[tv] Advertising …` → `[host]`). Bugs 2 and 3 needed no code, as the triage said.
`tools/check.sh format analyze puzzle host phone tv` passes.

## 1. Files changed

| File | Change |
| --- | --- |
| `packages/puzzle_game/lib/src/split_layout.dart` | `_computePhones`: `top: margin` (was `margin + tray.height`), and the comment above it now says why (the dots may stand in the tray, where the pieces start). The world, tray and board are untouched. |
| `packages/puzzle_game/lib/src/puzzle.dart` | `PuzzleField.top`'s doc now says what it is on all three layouts: the one-board clock strip, nothing on the split screen, the world's top margin on phones. |
| `packages/puzzle_game/test/phone_tray_reach_test.dart` | New: 3 tests (below), plus two helpers (`phonesGame`, `spotOn`). |
| `packages/party_host/lib/src/providers.dart` | `advertiserProvider` logs through `sink('host')` (was `sink('tv')`), so a phone host's log says `[host] Advertising "…"`, as `BonsoirAdvertiser`'s own doc already promised and `LiveHostService` has since s9b. |
| `docs/briefs/m12/bug-1107-fix-report.md` | New: this report. |

No other file changed. The screen layout's numbers, the phone world's sizes, the mm values and every existing
test are as they were. (`docs/briefs/m12/STATUS.md` and the three `tv_test_app/windows/generated_*` files
were already modified in the working tree when this job started; they aren't mine.)

## 2. The numbers (seed 1, `LayoutTarget.phones`, world units)

`_computePhones` puts the tray at `(margin, margin)` and the board below it, so `top` used to equal
`tray.bottom` on every phone world. `PuzzleGame.dotRadius` is 2.6 and `_inField` clamps the dot's centre to
`top + dotRadius`, so the dot's edge stopped exactly on the tray's bottom.

| puzzle | world | tray (l, t, r, b) | tray.bottom | **old** dot stop (`tray.bottom` + 2.6) | test limit (`tray.bottom` − 2.6) | **new** dot stop (`margin` + 2.6) | dot start |
| --- | --- | --- | --- | --- | --- | --- | --- |
| house | 90.88 × 88.50 | 2, 2, 48.9, 22.5 | 22.5 | **25.1** | 19.9 | **4.6** | (21.4, 55.5) |
| rocket | 89.19 × 79.50 | 2, 2, 47.2, 16.5 | 16.5 | **19.1** | 13.9 | **4.6** | (30.6, 48.0) |
| tree | 91.06 × 102.00 | 2, 2, 49.1, 27.0 | 27.0 | **29.6** | 24.4 | **4.6** | (16.5, 64.5) |
| boat | 111.59 × 80.52 | 2, 2, 69.6, 15.5 | 15.5 | **18.1** | 12.9 | **4.6** | (24.8, 48.0) |

The tree's 29.6 is the triage's number, and the failing run before the fix printed the house's 25.1 and
"house walls: no point of the piece is where the dot may stand (the tray is Rect.fromLTRB(2.0, 2.0, 48.9,
22.5), the dot stops at 25.1)". After the fix the dot's centre reaches 4.6 on all four, i.e. its top edge
sits on y = 2 (the tray's top, the world's margin line): it can stand anywhere in the tray row and over the
HUD area, but not into the 2-unit margin itself. The dot starts are unchanged: `_startFor`'s clamp floor
(`field.top + 6`) went from 28.5/22.5/33/21.5 to 8, and every start is the board's centre, well above it.

## 3. The advertising log

`advertiserProvider` (`providers.dart:61`) built the single `BonsoirAdvertiser` of both apps with the tag
`tv`; every line it logs (`Advertising "…"`, "Name already taken…", "Advertising stopped", "Advertising
failed: …") came out as `[tv] …` on a phone host. It is now `host`, the tag `LiveHostService` uses
(`host_service.dart:112`).

Nothing else matches the old text: `grep -rn "Advertising"` finds only `advertiser.dart` and docs, and
`grep -rn "\[tv\]" tools` finds nothing. `tools/smoke.sh` reads `Listening on port` and greps `[host]`
(`:186`, `:197-200`), `tools/tv-dev.sh` reads `Listening on port` only — so both keep working.

## 4. The new tests (`phone_tray_reach_test.dart`)

All three failed for the bug's reason before item 1 (run before the change, `+0 -3`) and pass after it.

1. **"held up, the dot reaches the tray's bottom less its radius"** — per puzzle: the dot starts below the
   tray, 150 frames of the left stick fully up (`InputMode.sticks`, `leftY: -1`, 2.4 s at 48 units/s), then
   `dy <= tray.bottom − 2.6` (table above) and `dy == field.top + 2.6 = 4.6` exactly. Before the fix the
   house stopped at 25.1 against a 19.9 limit.
2. **"in a phones solo game, A takes the tray piece the dot stands on, for every piece"** — `SplitLayout.of`
   with `phones` at seed 1, the game on `layout.left` and `layout.angles`, one player. For each tray piece,
   a fresh game: the dot goes to the piece's drawn centre (or to the nearest point of its drawn shape that no
   later piece covers), A is pressed, and the held piece must be that one. 19 pickups, one per piece.
3. **"in a phones split match, A takes the tray piece the dot stands on, on both sides"** — a `PuzzleMatch`
   (`target: phones`, `Random(1)` as the helpers do, so one fixed match seed) per piece and side; both
   `p1` (left) and `p2` (right) must take the piece under their dot. 38 pickups (19 × 2 sides).

The spot is "the drawn centre" for 14 of the 19 pieces. Five have no usable centre, and the test takes the
nearest point of the shape instead (`spotOn` allows what the brief allows: a point of the shape that is on
the top layer there):

| piece | drawn centre | why the centre isn't usable | point used |
| --- | --- | --- | --- |
| rocket right fin | (38.74, 4.45) | above the dot's stop at 4.6 (the row's top is y 4) | (38.7, 4.8) |
| tree mountain | (25.61, 12.39) | inside the sun (layer 2, circle r 6 at (30.96, 10.0)) | (25.5, 12.5) |
| boat sail | (16.59, 7.80) | the shape's origin lies on its own x = 0 edge, so `contains` is false | (16.5, 8.0) |
| boat flag | (35.93, 6.02) | its own edge again, and inside wave 1 (35–44.6 × 4–7) | (36.0, 7.0) |
| boat wave 2 | (45.09, 5.50) | the mast lays flat over it (22.5 × 2.25 at 45.1–67.6 × 4–6.3) | (44.8, 5.5) |

`spotOn` also keeps the point inside the dot's clamp box (x 2.6…width − 2.6, y `top` + 2.6…height − 2.6) and
within the pickup reach, so a piece it can't answer for is a `null` and the test fails with the reason.

## 5. Existing tests

None changed — no old → new. `flutter test` in `puzzle_game`: 98 pass before, **101** after (98 + the 3 new
ones), the same file names otherwise. Whole-repo counts: `puzzle` 101, `host` 76 (76 before),
`phone` 329, `tv` 28 (+1 skipped) — the last two were only run after the change.

## 6. What I ran

- `tools/check.sh format analyze puzzle host phone tv` — **PASS** on all six (format, analyze, puzzle 101,
  host 76, phone 329, tv). Run after the fix and again after the last edit to the test and report files.
- `flutter test test/phone_tray_reach_test.dart` before item 1 — **3 failures**, quoted in §2 and §4.
- `tools/review.sh` — **1 FAIL**, `packages/puzzle_game/lib/src/split_layout.dart:141 120 lines (>60):
  static SplitLayout _computeScreen(...)`. That function is **not mine**: `git show HEAD:` has it at lines
  141–260, the same 120 lines, and my edit is at 293–296. It only shows up because the file entered the diff.
  Splitting it is a design change this brief doesn't ask for. Three size NOTEs (providers 315, puzzle 325,
  split_layout 385).
- `tools/review.sh --strings`: 1 removed (`'tv'`), 1 added (`'host'`), 44 unchanged or moved.

## 7. Accepted for now (your Q3) — tech debt

- **The dot stands over the HUD area and the tray**: it can be anywhere on the row, in front of the clock and
  counts. Cosmetic; nothing draws under it that it hides for long.
- **A carried full-size piece is clipped at the world's top**: a piece taken from the tray is drawn at full
  size from its first pickup, so carrying the crown (28 units across) with the dot deep in the tray puts its
  top at about y −9.4, outside the world the viewer fits to the box. Worth a look in the look-and-sound
  milestone (a carried piece drawn at `trayScale` until it leaves the tray, or the world given a top band),
  not now.
- **Pickups are easier on phones than before**: the dot can now stand on a piece and takes the top one under
  it, which is what the owner asked for; on the split screen nothing changed.

## 8. Questions and suggestions (not acted on)

1. The advertising tag has **no test**: `BonsoirAdvertiser` talks to the `bonsoir` plugin, so a unit test
   would need a fake method channel. Worth one, or is the grep + smoke enough?
2. `providers.dart:270` logs the screen-awake line under `tv` too ("Keeping the screen on while controllers
   are connected", seen as `13:28:23.745 [tv] …` in the TV test run). On a phone host that line still says
   `tv`. Out of this brief's scope (it names the advertising sink only) — should it follow?
3. `_computeScreen` (120 lines) is a `review.sh` FAIL whenever `split_layout.dart` is in a diff. It was
   already there; a cleanup job like c1–c3 could split it (candidates: the tray-width search, the panel
   placement, the fit).
4. A piece whose drawn centre is above y = 4.6 can't be picked up from its exact centre (the rocket's right
   fin, 4.45). The test takes it 0.35 lower. If "every piece from its centre" is ever wanted, the world's
   top margin or the tray's first `trayGap` would have to grow; per your Q1/Q3 I left both alone.
5. The triage's suggestion of a row-wide reach test for every seed is still open (this job pins seed 1, as
   the brief says). The new `spotOn` helper would make that cheap if you want it later.

## Commit message

```
fix(m12): the dot reaches a phone's tray; advertising logs host

The phones world's top was margin + tray height, the very line the tray's
bottom sits on, so _inField kept the dot's edge on it: A could only take
tray pieces by centre distance, or nothing at all. top = margin lets the
dot stand on the row, and A takes the top piece under it again. Three
tests: the dot reaches the tray on all four puzzles, and A takes every
tray piece at seed 1, solo and in a split match on both sides. The
advertiser's log sink says host, not tv, as LiveHostService does.
```

## Status row

| Bug 1107 fix | G4 done ([bug-1107-fix-report.md](bug-1107-fix-report.md)): the phones `PuzzleField.top` is `margin`, so the dot stands in the tray and A takes the piece under it — 3 new tests fail before the fix and pass after (puzzle 98 → 101); the advertising sink logs under `host`; the screen layout, the world sizes and every existing test are unchanged. Open: the owner's confirmation on the next build, the clipped full-size carried piece (tech debt), and whether the screen-awake log line's `tv` tag follows |

## Delete

- none
