# M14 stats1 b4: why no puzzle round carries a `level_` tag

## Summary

**No code change. No bug found: the exported rounds were played on builds that
predate the level tag.** The tag survives every filter between `_endTags` and
the summary's round JSON; the 36 exported rounds come from builds made before
commit 5e43313 (2026-11-14 17:12 -0600), the first commit with the tag.

- Code path: `_endTags` (puzzle_session.dart:185-192, level tag first) →
  `PuzzleReport.write` `'tags'` (puzzle_report.dart:80) → `SessionRecorder`
  `round_end` (session_recorder.dart:83,96) → `SessionCollector.roundEnded`'s
  `_roundTags` filter (session.dart:322-325, 241). Nothing drops it.
- Values: `Level {easy, medium, hard}`, so `level_easy` (10 chars) /
  `level_medium` (12) / `level_hard` (10) all match `^[a-z0-9_.-]{1,32}$`; a
  round has at most 4 tags against `maxRoundTags = 8`, and `take(8)` runs
  before filtering with level the first tag.
- Dates: `chaos_` shipped first in m14.2 (Nov 12 07:17); `level_` first in
  m14.4 (Nov 14 23:37, build 571). The 14 Nov TV rounds (chaos_, no level) are
  m14.2/m14.3 (Nov 12); the Windows rounds (no tags) are m14.1 (Nov 10 21:47)
  or earlier.
- Tests seen passing on this tree: puzzle 441, metrics 111 (format, analyze
  PASS too), including the pinned lists at `puzzle_session_test.dart:204,218`
  and `round_stats_test.dart:83-106`. No new test was added: there is nothing
  to fail on old code.
- Not done: no device round on m14.4, so the tag is **unmeasured on the build
  that has it — needs a device check** (one puzzle round on build 571, then
  look for `level_` in that session's `rounds[].tags`).

## Trace

One tag, end to end, reading only code:

1. `packages/puzzle_game/lib/src/puzzle_session.dart:185-192` — `_endTags`
   returns `['level_${match.puzzle.level.name}', 'chaos_${…chaos.name}',
   'finished'?, ...roundTags]`, level first.
2. `puzzle_session.dart:145` — on the step the match ends, `_report.write(…,
   tags: _endTags(result))`.
3. `packages/puzzle_game/lib/src/puzzle_report.dart:68-82` — the `round_end`
   record gets `if (tags.isNotEmpty) 'tags': tags` (line 80). Nothing filters
   the list here.
4. `packages/party_host/lib/src/session_recorder.dart:76-97` — the `round_end`
   case reads `r.data['tags']` as a `List`, keeps `whereType<String>()` (line
   83) and passes it to `roundEnded(tags: tags)` (line 96). No encoding
   boundary in between: `ServerGameHost.record` (`server_game_host.dart:301`)
   hands the same `GameRecord` object to the recorder.
5. `packages/metrics/lib/src/session.dart:232-241` — `_roundTags(tags)`, then
   `if (roundTags.isNotEmpty) 'tags': roundTags` in the round JSON (line 241).

## Filters checked

Every filter, against the real values:

- `_roundTags` (`session.dart:322-325`) takes `tags.take(8)` **before**
  filtering, and level is the first tag, so it can never be cut. A round has at
  most 4 tags (`level_`, `chaos_`, `finished`, one host `night_nofm`), under
  `maxRoundTags = 8` (`session.dart:316`).
- The pattern `^[a-z0-9_.-]{1,32}$` (`session.dart:351`): `Level` is
  `enum Level { easy, medium, hard }` (`puzzle.dart:82-85`), so the values are
  `level_easy` (10 chars), `level_medium` (12) and `level_hard` (10) — all
  lower case, all match. `Chaos` is `enum Chaos { off, little, party }`
  (`settings.dart:4`), so `chaos_off/little/party` match too, as does
  `finished`. No capital letter anywhere in these names.
- `puzzle_session_test.dart:204,218` already pin the exact lists
  `['level_easy', 'chaos_party', 'finished', 'night_2of3']` and
  `['level_easy', 'chaos_little']`, and `packages/party_host/test/
  round_stats_test.dart:83-106` pins that a record's tags reach the summary
  round. Both pass on the current code; there is no gap a fix could close.

## Dates

(git log -S over `puzzle_session.dart`, `git for-each-ref refs/tags`,
`git merge-base --is-ancestor` on each tag):

| what | commit | date (-0600) | first tag with it |
| --- | --- | --- | --- |
| `chaos_` tag added | b86430f | 2026-11-10 22:30 | m14.2 (Nov 12 07:17) — not m14.1 (Nov 10 21:47) |
| `level_` tag added | 5e43313 | 2026-11-14 17:12 | m14.4 (Nov 14 23:37, build 571, version 0.14.0) |

So the exported rounds match the builds they came from exactly: Windows rounds
have no tags at all → a build before `chaos_`, i.e. m14.1 or earlier; the
14 Nov TV rounds have `chaos_` and no `level_` → m14.2 or m14.3 (Nov 12), about
two days older than 5e43313. No build with the level tag (m14.4, build 571) had
been played when the export was taken, so the tag is absent for the right
reason. **Not a defect. Unmeasured on m14.4: needs one puzzle round on build
571 (or later) to see `level_` in the export.**

## Decisions

Low-usage mode, one line of why each:

- No test file `level_tag_survives_test.dart`: the brief says add no code when
  nothing drops the tag, and a test that passes on the old code fails the
  runner's tests-first gate.
- Did not run the tag through the real metrics filter in a test:
  `puzzle_game` does not depend on `metrics` (or on `party_host`), so the only
  legal end-to-end test would need a pubspec change outside allow.
- Trusted the existing pinned lists (`puzzle_session_test.dart:204,218`,
  `round_stats_test.dart:83-106`) instead of writing a duplicate of them.

## Checks and self-check

`tools/check.sh format analyze puzzle metrics` on this tree: format PASS,
analyze PASS, metrics PASS (111 tests), puzzle PASS (441 tests), all checks
passed (145 s).

Review-rules part A: no new host setup (no code changed); no kept state added;
no new state to combine with the others; changes stay in my folder (this report
only); the job was clear, so nothing was overstepped.

## Questions and suggestions

1. Worth knowing for the stats batch: the "By game and feature" table can never
   show a level row for a round older than m14.4, and the code cannot tell an
   old round from an untagged one — the summary schema stays as designed.
2. If a device round on m14.4 is wanted as the measurement, it needs the owner
   (a TV or phone host and a controller); no code follows from it either way.
3. No test can cover the full path inside `packages/puzzle_game`, because
   `metrics` and `party_host` are not its dependencies. If a cross-package
   end-to-end tag test is wanted, it belongs in `packages/party_host/test`
   beside `round_stats_test.dart` (outside this job's allow).

## Hand-over

- The `level_` tag is correct in code (puzzle_session.dart:185-192) and reaches
  the summary round (`session.dart:241`). Nothing to fix here.
- What is needed is a measurement, not a fix: one puzzle round on m14.4 (build
  571) or later, then re-export and look for `level_easy/medium/hard` in that
  session's `rounds[].tags`.
- Older sessions will keep showing no level row; do not read that as a defect.
- Files changed: this report only.

## Commit message

M14 stats1 b4: no level_ tag is a build date, not a bug

Trace the puzzle's level tag from _endTags to the summary round: the tag
survives every filter (take(8) keeps it first, Level's names are lower case
and match the tag pattern, the recorder passes record tags through). The 36
exported rounds predate it: the level tag came with 5e43313 on Nov 14 17:12
and first shipped in m14.4 (build 571, Nov 14 23:37); the 14 Nov TV rounds are
m14.2/m14.3 (Nov 12, chaos_ only) and the Windows rounds are m14.1 or earlier
(no tags at all). No code change; needs one puzzle round on build 571 to see
the tag in an export.

## Status row

M14 stats1 b4 done: the missing `level_` tag is a build-date artefact (first shipped in m14.4, build 571, Nov 14 23:37), code path verified filter by filter, no fix needed; open: one puzzle round on build 571 or later to confirm `level_` in an export.

## Delete

- none
