# Review: M14 bugs11 b021-end-night-1 (B-021 phase 1, End night on the Arena's results)

## Summary

Verdict: **small fixes** — 0 must, 5 should, 5 could. The feature works as the brief says (endNow records + awards, reveal then final scores, Last round keeps Next alone, Right reaches End night), but three claims and one size rule need a second pass.
- Self-check item 4 is not true: the runner's log lists five `site/shots/*.png` changed outside `allow:` (it dropped them and the job ended with result 4).
- `_ResultsBody.build` grew from 41 to 67 lines, past the guidelines' ~60-line build limit.
- `roundsLeft` changed behaviour (0 once ended early) with no reader in `lib/` and no test behind it.

## Findings

- **should** `docs/briefs/m14/bugs11/b021-end-night-1-report.md:47` says only `allow:` files were changed, but `docs/briefs/m14/bugs11/run.log:49` records five `site/shots/*.png` changed outside the list (dropped by the runner; the job's result was 4) → say in self-check 4 what those five files were and that they were generated rather than written.
- **should** `packages/party_host/lib/src/ui/arena_results.dart:179` `_ResultsBody.build` is now 67 lines (41 before), past the guidelines' "under about 60" for a `build`, because both button groups are written inline in the if/else → extract the night's Next/End night row and the plain three-button wrap into two named widgets.
- **should** `packages/party_host/lib/src/night/night_state.dart:193` `roundsLeft` now answers 0 for a night ended early — a behaviour change the brief did not ask for, read by no file in `lib/` and covered by no test → revert it to `rounds - round`, or add the test if 0 is the wanted answer.
- **should** `packages/party_host/test/end_night_arena_test.dart:66` asserts `totals['p1'] == 5 + points` where `points` is read off the played round and was 0 in the report's own runs (Robo took the coins), so the assertion holds with none of that round's points kept → end the night on a card whose round has known non-zero points, so this line can fail.
- **should** `docs/briefs/m14/bugs11/b021-end-night-1-report.md:80` offers "Questions and suggestions" where the brief asks for a `Decisions` list with one line of why each, so the `Row`-instead-of-`Wrap` choice, the `roundsLeft` change and the new required `lastRound` parameter are not listed as decisions → add a `## Decisions` section with those three and their reasons.
- **could** `packages/party_host/lib/src/ui/game_debug_overlay.dart:12` makes `debugKeys` a public top-level set in a file `party_host.dart` exports, so an internal debug key set joins the package's public surface (guideline §3) → hang it on the overlay (a static on `GameDebugOverlay`) instead of a loose global.
- **could** `packages/party_host/test/end_night_arena_test.dart:90` runs the phone-host case at the harness's default 960×540, where `shareView` changes no layout, so it repeats the first case's assertion → run it at a phone surface (852×393), the size where a two-button Row is the risk.
- **could** `packages/party_host/test/menu_press_test.dart:91` moves the focus onto Next itself, so it pins the Right walk but not brief item 4's first half (Next keeps the first focus) → assert `focused(tester, 'next')` once the round's results appear, e.g. in `end_night_arena_test`.
- **could** `packages/party_host/lib/src/night/night_state.dart:164` still says the awards are decided "when its last round is recorded", which ending early is not → say "when the night ends, on its last round or early (B-021)".
- **could** `docs/design/party-night.md:108` still ends the Arena's results card with "Play again / Change mode / Back, or "Next" in a night" → add "Next and End night" there, as section 4's new bullet says.

## Decisions to confirm

- The night's two buttons are a local `Row` rather than a shared widget; the report's `IntrinsicWidth` explanation means phase 2 (Shape Race) will copy this row, so decide the shared widget before then.
- `roundsLeft` returning 0 for an ended-early night: keep or revert (nothing reads it today).
- `ArenaResults.lastRound` is required even outside a night; phase 2 adds the same flag to the puzzle card, so confirm the name and that the flag stays per-card.
- Design §4's new bullet says "the card also has End night" for every game, while Shape Race's card has only Next until phase 2.

## Could not check

- That `end_night_arena_test`'s three cases fail on 55bad98 (would need a checkout; read-only review).
- The layout figures ("card 284 px", "394 px inside") — no screen-fit test covers `ArenaResults`, and measuring would need a scratch test.
- The `phone` check (475 tests) and the format result; I reran only `analyze` and `host` at HEAD.

## Commit message

review b021-end-night-1: small fixes, no must

The Arena card's End night works as the brief says: endNow records and
awards, the reveal and final scores follow, the last round keeps Next
alone and Right reaches End night. Findings: self-check 4 misses five
site/shots files the runner logged as outside `allow:`; the results
body's build is 67 lines, past the ~60 limit; `roundsLeft`'s new 0 is
untested and unread; the points assertion is vacuous when P1 scores 0;
the report has no `Decisions` list. Five `could`s, including a public
`debugKeys` and a phone case that runs at TV size.

## Status row

B-021 phase 1 reviewed: End night on the Arena's results works, with 5 `should`s open (self-check 4, 67-line build, untested `roundsLeft`, weak points assertion, no Decisions list); B-021 phase 2 (Shape Race) still open.

## Delete

- none
