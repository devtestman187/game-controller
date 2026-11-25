# n9d2 review: "Round N of M" in the HUD and the clock red in the last 15 s

## Summary

- Verdict: **small fixes** (one must, Claude can fix it by hand).
- Counts: must 1 · should 3 · could 1.
- 1. **must**: the Best-time text shares the clock's `tabular` style, so "Best" also turns red in the last 15 s (`arena_hud_widgets.dart:217`).
- 2. **should**: the race test builds a Bumper Round frame (`arena_hud_round_test.dart:25`), so no race frame is tested.
- 3. **should**: `ArenaHud` now takes 7 parameters and `ArenaBoard` 8 (limit 5; `arena_hud_widgets.dart:38`).
- Checks: the report's pinned-test claims are true (`arena_night_test.dart:85` and `:159`, `arena_view_test.dart:106`).
- Checks I ran: none (read-only review). The test counts and the `mine.sh` result in the job report are not verified.

## Findings

- **must** packages/test_game/lib/src/arena_hud_widgets.dart:217 The Best-time text uses `tabular`, which now carries the `bad` colour in the last 15 s, though the brief asks only for the clock → give the clock its own style (`tabular` with the colour) and keep `Best` on `ink`; add a test that `Best` stays ink at 15000 ms.
- **should** packages/test_game/test/arena_hud_round_test.dart:88 The race test calls `bumperFrame`, which sets `mode: ArenaMode.bumper` (line 25), so the "race has no clock" case is a Bumper frame with a null clock, which the game never sends → add a `mode` parameter to the helper and pass `ArenaMode.race` in this test.
- **should** packages/test_game/lib/src/arena_hud_widgets.dart:38 `ArenaHud` has 7 constructor parameters (the guideline's limit is 5; it had 5 before), and `ArenaBoard` (`arena_view_widgets.dart:22`) has 8 → group `round` and `rounds` into one value object (e.g. a round-count type) and pass it as one parameter.
- **should** packages/test_game/lib/src/arena_hud_widgets.dart:191 `_hurrying` is a boolean that does not read as a question (guidelines §4 names `isPaused`, `hasView`) → rename it `isHurrying`.
- **could** packages/test_game/test/arena_hud_round_test.dart:60 On the old code the whole file fails to compile (the new parameters), so no test fails for its own rule; the failure is not the clock or the label rule → say so in the job report (it does) or give the old-code run a line of its own in run-findings.

## Decisions to confirm

- `arena_hud_widgets.dart:184-185`: the label uses the `round` parameter, but the fallback uses `snapshot.round`; two sources for one number. Using `snapshot.round` always and keeping only `rounds` would remove the split, but the brief asked for `round`.
- `arena_view.dart` (diff): "Round N of M" now shows in every ArenaView that receives `rounds`, not only the night; the owner may want it limited to a night.
- `arena_hud_widgets.dart:82-86`: 0 ms left shows ink, not the warning colour (chosen; the test pins it).
- No entry in `docs/decisions.md` records the Nov 24 owner decision (item 9) with its reason (guidelines §10); the reason lives only in the code comment at `arena_hud_widgets.dart` (`_hurryLeftMs`).

## Could not check

- The report's counts "18 tests in two files" and "8 tests" were not verified: a grep finds 25 `testWidgets` in the three files, so the figures depend on tests written another way; I did not run tests.
- `tools/mine.sh` result (RESULT ok) and the format/analyze claims: not run, read-only job.
- Whether the `bad` colour reads well on the TV look: a look judgement, not checkable from code.

## Commit message — a draft: a subject line under 72 characters, a blank line, then at most 8 lines on what changed and why.

none — read-only review; this job makes no commit.

## Status row — one line for the milestone's STATUS.md: what is now done, and what is open.

n9d2 reviewed (wave 2): verdict small fixes. Open: the Best-time text turns red in the last 15 s (must, arena_hud_widgets.dart:217); race test uses a Bumper frame; ArenaHud/ArenaBoard parameter count; `_hurrying` name.

## Delete

- none
