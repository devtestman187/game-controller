## Summary

A saved session with no `share` mark on any player is now never uploaded: the queue records its id
in a new `skippedSessions` prefs list and moves on, the file stays on disk for the Stats screen, and
nothing is added to `uploadedSessions`. Sessions with any answer are uploaded as before.

- **metrics `uploadable.dart`:** new exported `bool hasShareMarks(summary)`, true when any player
  entry has a `share` key (a `false` is an answer). The legacy branch of `uploadableSummary` is gone,
  so an unmarked summary uploads no player and no round winner; its rounds keep their totals and the
  session totals stay. Doc comment updated; `uploadable.dart` is 67 lines.
- **party_host `live_stats.dart`:** in `uploadNow`, a pending file without marks is skipped (id into
  `skippedSessions`, saved, `continue`). Pending and the `waiting` count leave out skipped ids, and
  `waiting` also leaves out unmarked files, so a dropped session never counts as waiting. Local
  files are untouched. 380 lines (was 369) — the getter and comment trims keep it under the 380 cap.
- **Tests:** 3 new in `uploadable_unmarked_test.dart`, `uploadable_old_players_test.dart` rewritten
  to the new rule (it asserted the old one), and 1 new in `live_stats_unmarked_test.dart`.
- **Checks seen pass:** `tools/check.sh format analyze metrics host` → format PASS, analyze PASS,
  metrics 172 tests PASS, host 586 tests PASS. `tools/review.sh` → 0 fail, 1 note (the 380-line size).

## Decisions

1. The ids are recorded in `uploadNow`'s loop, as the brief words it, so on the first pass after an
   upgrade a pending list still holds the unmarked file; it is skipped there and, by
   `skippedSessions`, left out of every later pending list and count. `waiting` excludes unmarked
   files directly, so the very first count (from `start`) is already 0.
2. Skipping is permanent: a saved file cannot gain answers, so a later consent change does not
   revisit it. That follows the owner's "Sessions should be dropped."
3. `uploadableSummary` of an unmarked summary now returns an empty `players` and rounds with totals
   only (not a special shape): if a caller ever misses the `hasShareMarks` check, nothing personal
   goes up anyway.
4. No log line for a skipped file: nothing failed, and the prefs list records the decision (a log
   line would also be the only way to see it, if a reviewer wants one).
5. No new `lib/` file, since `allow:` names no other: the additions are paid for by inlining the
   skipped-ids read and one-line comments, so `live_stats.dart` ends at exactly 380 lines.

## Self-check (review-rules.md part A)

1. **Every host setup.** TV/PC, a phone "Show on this device" and a phone "Play on this phone" all
   reach the drop through the same `LiveStats.uploadNow`; the host phone's own player always shares
   (`session_player.dart:105`), so its sessions keep an answer and upload as before. A file written
   by a build one older has no marks and is dropped on the first upload after the upgrade:
   `live_stats_unmarked_test` (unmarked file written by hand, no players asked).
2. **When kept state starts and ends.** `skippedSessions` is written the first time an unmarked
   pending file is met, starts absent (empty set), and never shrinks: no path removes an id, so a
   restart keeps skipping it. With consent off, `uploadNow` returns before any skip is written, and
   `waiting` is already 0 by `hasShareMarks`. Tested: `live_stats_unmarked_test` (second `uploadNow`
   still uploads once, `waiting` 0).
3. **How a new state combines with the others.** The skip list only meets consent, the running
   session file and the retry: consent off short-circuits `uploadNow`; the running file is excluded
   from both pending and `waiting` by `f.path != _sessionPath`; a retry re-reads `skippedSessions`,
   so it cannot resend. `pause()`/`resume()` end and re-open sessions, not saved files, and
   `resume()`'s upload keeps the unmarked one skipped (`live_stats_unmarked_test`; the marked path
   is pinned by `live_stats_share_test`).
4. **Stay in the job's folder.** Only `allow:` files changed: `uploadable.dart`, `live_stats.dart`,
   three test files and this report.
5. **Stop rather than overstep.** Nothing was needed outside `allow:`. One thing I did not fix: the
   `live_stats_share_test` player-order flake seen once (see Hand-over).

## Tests and computed values

New tests, red on the code before the change, for the reason each names:

- `packages/metrics/test/uploadable_unmarked_test.dart` — summary `old` with players `a`(1) and
  `b`(2), both without `share`; rounds: 1 `winner` 1, 2 `winner` 1 with `winners` `[1, 2]`; frames
  `{drawn: 300, dropped: 3}`. Expected and seen: `hasShareMarks` false; with `b` given
  `share: false`, `hasShareMarks` true (a no is an answer); `uploadableSummary` → `players` empty,
  rounds `{game: arena, players: 2, timeS: 5.0}` and `{game: arena, players: 3, timeS: 9.0}`,
  frames `{drawn: 300, dropped: 3}`, the input's 2 players untouched. Old code: both compile-fail
  (`Method not found: 'hasShareMarks'`), and after only adding that name the summary keeps both
  players and both winners.
- `packages/metrics/test/uploadable_old_players_test.dart` (rewritten, not loosened) — the same
  file: `hasShareMarks` false, `players` empty, both rounds with totals only, frames unchanged, the
  saved file still holding 2 players. Old code kept `['a', 'b']` and `winners` `[1, 2]`.
- `packages/party_host/test/live_stats_unmarked_test.dart` — two files written into the sessions
  folder before `start`: `old-unmarked` (player `old-a`, no `share`) and `new-marked` (`new-a`,
  `share: true`), consent true, `FakeUploader`. Expected and seen: `uploader.uploaded` ids
  `['new-marked']`, its player `['new-a']`, `uploadedSessions` `['new-marked']`, `skippedSessions`
  `['old-unmarked']`, `state.saved` 2, `state.waiting` 0, `stats.sessions()` both ids, two files on
  disk; a second `uploadNow()` leaves 1 upload and `waiting` 0. Old code: `skippedSessions` never
  written (`TimeoutException` in the wait), and both files uploaded.

Commands run: `tools/check.sh format analyze metrics host` → all four PASS (metrics 172 tests, host
586 tests) on the final tree; `tools/review.sh` → 0 fail, 1 note (`live_stats.dart:1` 380 lines).

## Hand-over

- **Flake seen once:** in the first full host run, `live_stats_share_test` failed its saved-file
  player order (`['phone-no', 'phone-yes']` for `['phone-yes', 'phone-no']`); the test connects both
  phones without waiting, so the server may record them in either order. It passed alone and in the
  rerun, and this diff does not touch join order. Suggestion only: use `unorderedEquals` there.
- `skippedSessions` grows by one id per dropped session and is never pruned; there is no session
  deletion path yet, so pruning belongs with one.
- The Stats screen still cannot say why a session will never be uploaded; telling the adult is UI
  work outside this brief.
- `live_stats.dart` is at exactly 380 lines: the next change here needs the split the code-health
  list already asks for (the 369-line entry named it before this job).

## Commit message

Drop saved sessions that have no stats answer from the upload

Sessions saved before this build have no `share` key on any player: uploadableSummary no longer
uploads them as before, and a new hasShareMarks tells the queue to drop them. live_stats records
such files in a new skippedSessions prefs list and skips them, so they are neither uploaded nor
counted as waiting; they stay on disk for the Stats screen, and sessions with any answer upload
exactly as before. The old-players test now asserts the drop, with new tests for hasShareMarks and
for the queue.

## Status row

- **M14 sentry2 unmarked-drop:** done — sessions with no share mark are skipped and listed in `skippedSessions`, never uploaded or counted as waiting; open: pruning that list, a Stats-screen note, the `live_stats.dart` split (380 lines).

## Delete

- none
