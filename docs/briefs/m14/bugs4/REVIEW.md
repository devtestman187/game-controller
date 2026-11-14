# M14 bugs4 — the run's review

Job: read-only review of the whole bugs4 run (`5793f36..1aa3f9e`: job f3-review-fixes and the review of it),
against `docs/coding-guidelines.md`, `docs/review-rules.md` and the briefs. The run was one code job, so the
per-job review's findings were re-checked against the final code and are carried below where they still hold.
Checked with `git diff`/`git status`/`wc -l` and the files read; no suite was run.

## Summary

`one fix batch`. 1 must, 3 should, 8 could.

- **must:** item 4's six corrected bugs3 reports exist only in the working tree — `git status` lists all six
  as modified and the run's diff carries no `docs/briefs/m14/bugs3` change, so the report's "4 done" is lost
  on a fresh checkout.
- **should:** `GameField`'s constructor takes nine parameters (guidelines §3 allows five).
- **should:** `_stageBody(Object? night)` types the night `Object?` where `PartyNight?` is in scope.
- **should:** pr-shape's report still says "nothing in `packages/metrics` reads `gameStats` keys today",
  which `session_player.dart:111-113` contradicts — item 4's metrics fix is half done.
- **could:** `_game!` has no guard; the local-pad filter is written twice (card and menus); three new public
  callbacks have no dartdoc; a report line count is wrong; a bare `8` in a new test; a vacuous second-press
  expectation; `focusRow` returns silently; four untracked `run-*.patch` artifacts.

Only the owner can answer: the three `generated_plugin` files still show as modified (line endings only, so a
`git add -A` carries them); whether two owners may read the host's own pad; whether `BoardCache.onRecord` is
wanted as shipped API.

## Findings

- **must** docs/briefs/m14/bugs4/f3-review-fixes-report.md:21 says item 4 is "done", but the six bugs3 report edits are uncommitted (`git status` shows `a1-pinball-flags`, `a2-arena-size`, `pr-arena`, `pr-party`, `pr-shape`, `s1-progress-bar` reports modified; the run's diff has no `docs/briefs/m14/bugs3` change) → commit the six reports by name (not `git add -A`) or state in the report that they are uncommitted (from: f3-review)
- **should** packages/party_host/lib/src/ui/game_field.dart:18 `GameField`'s constructor takes nine required parameters (game, playing, debug, hosting, keyboard, roundTags, onEvent, onClock, onFinished) where guidelines §3 allows five → pass the settings, tags and three callbacks as one value object (from: f3-review)
- **should** packages/party_host/lib/src/ui/game_screen.dart:328 `_stageBody` takes `Object? night` although `PartyNight?` is in scope (`partyNightProvider` at :296) — a type dodge, not listed under Decisions → type it `PartyNight?` (from: f3-review)
- **should** docs/briefs/m14/bugs3/pr-shape-report.md:21 still says "nothing in `packages/metrics` reads `gameStats` keys today", while `packages/metrics/lib/src/session_player.dart:111-113` copies every `gameStats` key into the uploaded summary; item 4 asked for this claim to be fixed → say that no report column reads the keys (from: f3-review)
- **could** packages/party_host/lib/src/ui/game_screen.dart:337 `_game!` relies on the stage proving the game is set, which the line does not show (the old `_field()` returned `SizedBox.shrink()` when null) and guidelines §2 allows `!` only when the line before proves it → keep a null guard (from: f3-review)
- **could** packages/party_host/lib/src/ui/arena_waiting_card.dart:142 `if (!p.local) continue` repeats the local-player split `ControllerMenus` makes at controller_menus.dart:155, so two owners decide who reads a pad and a change to either filter makes a joined phone's A press its row twice → put the split in one predicate both read (from: f3-review)
- **could** packages/party_host/lib/src/ui/game_field.dart:51 `onEvent`, `onClock` and `onFinished` are public members with no dartdoc, unlike the six fields above them (guideline §10) → one line each (from: f3-review)
- **could** docs/briefs/m14/bugs4/f3-review-fixes-report.md:51 says the screen is "now 369 lines"; `wc -l` gives 365 for `game_screen.dart` → 365 (from: f3-review)
- **could** packages/party_host/test/arena_phone_card_test.dart:32 the walk cap `8` is a bare number (guideline §2 allows only 0, 1, -1, 2 and indices) → name it, e.g. `maxWalkSteps` (from: f3-review)
- **could** packages/party_host/test/arena_phone_card_test.dart:46-47 the second A on the chosen mode row asserts the same `ArenaMode.race` as the first, so a swallowed second press passes the "next press works too" claim → press a row that changes something (the ready row does this at :57-62, or the other mode) (from: across jobs)
- **could** packages/party_host/test/support/host_harness.dart:216 `focusRow` returns without a word when the row is missing, so `readyUp` and a test can press A with the focus somewhere else and still pass → let the missing row fail the test (`expect(row, findsOneWidget)`) (from: across jobs)
- **could** docs/briefs/m14/bugs3/run-a1-pinball-flags.patch (also `run-i1-ok-presses`, `run-p2-coop-fps`, `run-s1-progress-bar`, 3.7 MB together, dated at the run's start) are untracked review artifacts in the repo, so a `git add -A` commits them → leave them to whatever made them, and stage report files by name (from: across jobs)

## Open questions

- Item 6: the three `tv_test_app/windows/flutter/generated_plugin*` files are back at `HEAD`'s bytes but `git status` still flags them (line endings); safest: accept it and stop touching generated files.
- Item 1: two owners read the host's own pad (the menus read joined phones, the card reads local players); safest: accept for now, take the shared predicate when either filter next changes.
- Item 1: a joined phone's first focus is the chosen mode, so an A pressed on arrival re-presses the mode; safest: keep it — the first A of the join press is already held and let go (`_before == null`).
- Item 3: `BoardCache({this.onRecord})` is shipped API whose only caller is a test; safest: keep it (guidelines §2 allow an injected observer) and note it in the cache's doc.
- Item 4, pr-party: the review named a "Show on this device" one-roster-player test that cannot exist (that host pairs no player, `hosting.dart:23-27`); the report pins the rule with two cases instead — safest: accept the substitute.
- Item 1: the field moved to `game_field.dart` only for the 380-line rule; safest: leave it there.
- The card reads only A and B from local pads (arena_waiting_card.dart:117-120) and the menus skip local players (controller_menus.dart:155), so a local player's directions move no focus while the card is up; safest: say so in the card's dartdoc, since that player is always on the host's own touch screen.

## Numbers against targets

- f3's brief, "no lib file you touch may end over 380 lines": game_screen 365, view.dart 379 (one line spare),
  puzzle_painter 350, arena_waiting_widgets 343, arena_waiting_card 336, controller_menus 301, game_field 90 —
  all pass; five of them are past guidelines §3's "about 300" line and two (§3's 400 hard limit) are not.
- f3's brief, "no function over 60 lines": the touched ones are `build` (game_screen.dart:295-326, 32 lines),
  `_stageBody` (:328-359, 32), `stillParts` (board_cache.dart:113-127, 15) — pass.
- guidelines §3, "at most 5 parameters": `GameField` 9 — fails (the should above).
- f3's report, "the screen is now 369 lines and the field 90": 365 and 90.
- The suite counts the reports give (host 399, phone 464, puzzle 403, arena 219) and pr-arena's 40 s / 120 s
  cat arithmetic: not re-run, not re-computed.

## Could not check

- The suite counts: I ran no suite, since a run rewrites the design and site pictures.
- The truth of the six uncommitted bugs3 report edits beyond a1's (its "landed in i1's commit `c4e4e00`" is true:
  `git show c4e4e00` carries the 16 `round_music_test.dart` lines).
- pr-shape's 1/6 and 42% repeat arithmetic on the join path, and pr-arena's cat numbers: proposal text, no code.
- Whether the suites' rewritten pictures were restored: `git status` lists none modified, which is consistent.
- Whether the four untracked `run-*.patch` files were made by the runner or a worker: only their timestamps (the
  run's start minute) say anything.

## Commit message

M14 bugs4 review: commit item 4's six reports, give GameField a value object

Commit the six corrected bugs3 reports: the run's diff has none of them,
so the report's "4 done" is lost on a fresh checkout.
Type `_stageBody`'s night `PartyNight?`, pass GameField's settings, tags
and three callbacks as one value object, guard `_game!`, and finish
pr-shape's metrics line (no report column reads the `gameStats` keys).
Also: name the walk cap, make `focusRow` fail on a missing row, assert
a second mode press on a row that changes, and fix the 369-to-365 line
count.

## Status row

B-013 fixed (a phone works the Arena waiting card through the menus, tested press after press), the menus' OK
lifted after the press (remote after phone tested) and the board cache keyed by canvas scale with the used
layer last and a puzzle swap cleared (all tested); open: item 4's six bugs3 report edits are uncommitted, the
pr-shape metrics line is still false, GameField takes nine parameters and `_stageBody` types the night
`Object?`.

## Delete

- none
