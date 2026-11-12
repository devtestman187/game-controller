## Summary

- Bumper bar per player: dot, name, the game's coin + count, then "Dash ready"; no Wins/Hits/Dashes; clock = time left.
- Race and other modes: bar unchanged (Wins/Hits/Dashes, time run, no coin).
- Each marble wears its coin count above its head (paper pill, game coin, ink number), popping on a change.
- A joined phone: same bar over the game, so its own row's count shows; new app test at 852 × 393.
- Counts are the frame's existing per-marble coins (gold = 2, hazard −1); no snapshot or protocol change.
- Files: 6 in test_game/lib (hud, new coin icon, moments, marble painter, coin painter, export) + 4 tests (2 new).
- Decisions: coin via ArenaCoinPainter; pop view-side in ArenaMoments (no new field); pill outside the fade layer;
  name capped at 24 % with an ellipsis.
- Not done: no "you" mark on a joined phone's row; "Best" still shows in a Bumper Round (Questions 2–3).
- Try on a device: Bumper with two phones — counts up/down, +2 on gold, pop on a change, clock down; a race keeps its bar.

## Self-check (docs/review-rules.md part A)

1. **Every host setup** — TV/PC host, a phone on "Play on this phone" and a host phone on "Show on this device" all
   draw `ArenaHud`, tested at 960 × 540 and 667 × 375 (`arena_hud_coins_test`); a joined phone draws the same bar
   over frames (`controller_app/test/arena_coins_test.dart`); no snapshot or protocol change, so a build one older
   draws the old bar and still plays (protocol suite passes, snapshot version untouched).
2. **When kept state starts and ends** — `ArenaMoments` starts counting each player's coins at the first snapshot,
   records the round's clock on a change, and clears counts and pop times when the round number changes; the pop
   decays within `coinPopS` (0.4 s) and is 0 when nothing changed (`arena_moments_test`, two tests).
3. **How a new state combines** — the pop pauses/hides/blocks nothing: it is view-side, read from the round's clock,
   so the pause menu, host away, a player away, "Get ready" and the results leave it frozen or at its last value;
   nothing is timed by a widget (`arena_moments_test`, `arena_count_paint_test`).
4. **Stay in the job's folder** — only the files listed in Summary changed; no file outside `allow:` was touched.
5. **Stop rather than overstep** — no outside file was needed and no rule blocked the job; two brief points are
   answered as decisions below and a wording mismatch is under Questions.

## Decisions

1. **The bar's coin is the game's own coin, in a new `ArenaCoinIcon` that reuses `ArenaCoinPainter`** — one coin
   everywhere (bar, field, pill), never an emoji, and no second drawing of it.
2. **The count on the marble is drawn from the frame, the pop from the view's moments** — the snapshot has no
   "changed at" field and adding one would change the protocol (and `docs/protocol.md`, outside this job), while
   `ArenaMoments` already holds view-side state for the eyes.
3. **The count sits in a paper pill above the head**, drawn outside the recovering marble's fading layer: that layer's
   box is too small for a badge over the head, and paper-under-ink reads in both looks.
4. **The bar shows a player's coins whenever `mode` is bumper, not when `timeLeftMs` is set** — the mode is the design's
   own switch (party-night §7), and the clock text follows `timeLeftMs` so the race keeps its time run.
5. **A Bumper Round caps a name at 24 % of the bar's width with an ellipsis** — four names, counts and dashes must
   fit a phone's bar, and the count must never be the thing that gives way (Claude's design).
6. **A joined phone needs no new code for its own count**: its arena view is the same bar drawn from frames, which
   party-night §7 asks to show "each player's coins ... on the host and joined phones", so its own count is its own
   row; a test proves it on the phone.

## Computed test values

- The bar's clock: `timeLeftMs` 16600 → `16.6 s`; 6000 → `6.0 s`; the race's `roundTimeS` 12.4 → `12.4 s`.
- Counts from the round: a coin taken → 1; a gold coin taken with 1 held → 1 + `ArenaCoin.goldValue` (2) = 3; a hazard
  from 3 → 2; four marbles with 1, 2, 3, 4 in the frame round-trip and stay under `arenaSnapshotBudgetBytes` (2048).
- The name cap: 0.24 × 667 = 160.08 px on the shortest phone, 0.24 × 960 = 230.4 px on a TV; "P4 Alexanderthegreat"
  is cut with an ellipsis and every `coins-*` count stays within the 667 px screen.
- The pill at the shortest phone (shortest side 375 px): the marble's radius 0.032 × 375 = 12 px; the coin's radius
  12 × 0.42 = 5.04 px; the pad 12 × 0.18 = 2.16 px; the inner gap 12 × 0.15 = 1.8 px; the count's font 12 × 0.95 =
  11.4 px; the measured pill 27.6 × 15.32 px, its bottom at 187.5 − 12 − 1.8 = 173.7 px and its centre at 166.04 px,
  inside the 152–176 px band the paint test scans.
- The pop: 1 at the change, 0.5 after `coinPopS` / 2 = 0.2 s, 0 at 0.4 s (within 1e-9), and 0 for the first snapshot
  of a round or a new round.
- The race: "Wins 2", "Hits 5", "Dashes 1" twice each and no `coin-*` or `coins-*` keys.

## Questions

1. **The brief points at `packages/party_host/lib/src/text/arena_text.dart` for the bar's words, but the bar is
   `packages/test_game/lib/src/arena_hud_widgets.dart`** and a game may not import `party_host`: its words ("Wins",
   "Hits", "Dashes", "Dash ready (A)") are already literals there, and the new strings are only numbers and " s".
   Should the bar's words move to a text file the game can read (a `text_game` library), or stay as they are?
2. **A joined phone shows every player's count, not only its own**, as party-night §7 asks; it has no "you" mark.
   Want one (the app already passes `ViewContext.playerId`, which `ArenaViewer` could hand to the bar)?
3. **"Best –" still shows in a Bumper Round.** It is always null there; should it leave the bar as Wins / Hits /
   Dashes do?
4. **The pill shows 0 coins too**, so a drop to nothing is visible and the badge never comes and goes; if four
   marbles' pills feel busy on a phone, the alternative is to hide the pill at 0.

## Commit message

```
Arena: show every player's coins in a Bumper Round

The Bumper Round's bar now reads dot, name, the game's coin and the count,
then Dash ready: Wins, Hits and Dashes leave the bar (they stay in results
and stats) and the clock shows the time left. Each marble wears its count
above its head, popping when it changes; the pop is view-side, from the
round's clock, so no snapshot or protocol field changed. Race rounds and a
joined phone (the same bar over frames) keep their behaviour; names cap at
24 % of the bar so four counts always fit a phone.
```

## Status row

`b2 bumper coins: done — the Bumper Round's bar shows each player's coin picture and count (and the time left), each marble wears its count above its head, popping on a change, and a joined phone's bar carries its own count; open: a "you" mark on a joined phone's row and whether "Best" stays in a Bumper Round.`

## Delete

- none
