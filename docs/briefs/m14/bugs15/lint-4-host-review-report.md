# Review of lint-4-host (520fdd91) — report

## Summary

`small fixes` — 0 must, 1 should, 4 could. The code itself is clean: `dart analyze` over the four packages and over the whole workspace prints "No issues found!", and `dart format --output=none --set-exit-if-changed` changes 0 of 515 files. No `// ignore` was added, no public API, text or player-visible behaviour changed, and every file:line of the code diff matches what the report says.

The three that matter most:
1. The report says the repo-wide `analyze` still fails with 82 issues; at this commit it passes, so the Status row would put a false open item in STATUS.md.
2. The one code line the report cites wrong: `unawaited(_pause(by))` is `pause_menu.dart:342`, not 343.
3. The settings decision's justification (report:25) is not true for a `Map<Object?, Object?>` with String keys.

## Findings

- **should** docs/briefs/m14/bugs15/lint-4-host-report.md:32 — the Checks line says `tools/check.sh analyze` FAILs with 82 issues and the Status row repeats that the repo-wide analyze stays red, but the `analyze` step (`dart analyze --fatal-infos` at `.`) over the committed tree prints "No issues found" and `git diff 520fdd91..HEAD` touches docs only → rewrite the Checks line and the Status row as format, analyze and the four suites all passing.
- **could** docs/briefs/m14/bugs15/lint-4-host-report.md:22 — cites `party_host/lib/src/ui/pause_menu.dart:343` for the `unawaited(_pause(by))`, which is at line 342 → change 343 to 342.
- **could** docs/briefs/m14/bugs15/lint-4-host-report.md:25 — the settings decision says a map with non-String keys "reads the same defaults the old code produced", but a `Map<Object?, Object?>` holding String keys did read its values through `m[key]` and now falls through to the defaults at `settings.dart:113` → state that case in the decision, or keep `is Map` and read the entries by name.
- **could** packages/party_host/lib/src/host_service.dart:125 — the brief asks for a one-line comment when a fire-and-forget's reason is not obvious, and this is the `unawaited` whose lost write mints a new host id on the next launch → add the one-line comment saying the constructor cannot await and the write is best-effort.
- **could** packages/party_host/lib/src/testing/fake_stats.dart:101 — the new `Exception('$error')` fallback is run by no test, because the only `FakeStats.failWith` user (`controller_app/test/phone_host_stats_lifecycle_test.dart:64`) sets a `StateError`, which line 99 rethrows unchanged → say so in the report, or add a test that sets a String `failWith`.

## Decisions to confirm

- `settings.dart:113` now tests `json is Map<String, Object?>`; the only callers pass `jsonDecode(...)` or typed map literals, so today nothing changes — confirm the narrower test is wanted rather than `is Map` with named reads.
- `fake_stats.dart:98-102`: `failWith` stays `Object?`, but a String value now throws `Exception('boom')` instead of `'boom'`; no test sets one today — confirm that is acceptable for the apps' tests.
- `pause_menu.dart:342` keeps a 117-column `if` so the file stays at exactly 400 lines (the wrapped form would be 402): the next edit there has to split the file.
- `host_service.dart:125` is the riskiest of the four `unawaited` calls (a lost write means phones re-pair); the brief said not to change it beyond `unawaited` — confirm whether a follow-up job should await the write in an async create or log the failure.
- `night_scoreboard_screen.dart:83`, `stats_screen.dart:39`, `pause_menu.dart:342`: all three discard a future whose failure is silently lost; `stats_screen.dart:39` leaves the screen on its loading state — same question as above, none of them is a behaviour change today.

## Could not check

- The suite counts (look 131, arena 236, puzzle 442, host 514) were not re-run here; `docs/briefs/m14/bugs15/run.log:68` records `host` (and `phone`) passing after the hand-fix, and I ran only `dart analyze` and `dart format` in this review.
- The worker's original 25 issues and its "5 error, 11 warning, 9 info" split: that tree no longer exists, so the counts cannot be verified.
- `docs/briefs/m14/bugs15/run-findings.md` does not exist, so no "passes on the old code" entry applies.
- The old and new behaviour of `PieceShape.fromJson`/`PuzzleSnapshot.fromJson` was judged by reading only; no extra test was run.

## Commit message

Review lint-4-host: the report's analyze-fail claim is stale at the commit

- The Checks line (line 32) and the Status row say the repo-wide analyze
  still fails with 82 issues; `dart analyze --fatal-infos` at the root of
  the committed tree prints "No issues found", and 520fdd91..HEAD is docs.
  Once the three lint commits land together the whole check is green.
- The pause-menu `unawaited` is at pause_menu.dart:342, not 343.
- The settings decision reads a `Map<Object?, Object?>` with String keys
  differently from the old `m[key]`; the new Exception wrapper in
  FakeStats is run by no test (the only user sets a StateError).
- Every other code line, the format result and the no-ignore rule hold.

## Status row

M14 bugs15 lint-4-host: accepted with small fixes — party_host, puzzle_game, test_game and toy_look analyze clean and the whole workspace with them (format, analyze, host, puzzle, arena, look, phone); open: correct the report's analyze-fail claim, the pause_menu line number and the settings decision wording.

## Delete

- none
