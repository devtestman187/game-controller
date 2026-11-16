# Stats screen review fixes: one read at a time, a private crash button, the crash "no"

## Summary

Findings 12, 13, 14 and the `fake_crash.dart:52` could, fixed, each pinned by new tests.

- `stats_screen.dart`: `_reading` is set at the start of `_load()` and cleared in `whenComplete`, so
  a second load (a quick second Retry) returns at once and no failure leaves the screen unable to
  retry. Retry stays unfocused and spinner-free (finding 13: yes, guard first).
- `stats_screen_widgets.dart`: `CrashSharingButton` → `_CrashSharingButton`; nothing outside the
  two lib files named it, so no test needed fixing (the brief expected one).
- `fake_crash.dart`: `capture` drops a report while `enabled` is false, like the real reporter.
- New: `stats_retry_once_test.dart` (2 tests), `fake_crash_off_test.dart` (3),
  `crash_dialog_no_test.dart` was written, then moved by hand into `consent_prompts_test.dart` (3 tests: the no saves false and disables once; Esc and back answer nothing).
- Red first, on the old code: the Retry test read 3 times (`Expected: <2> Actual: <3>`) and 2 of
  the 3 fake tests kept a report while off. The dialog-no file passed on the old code: the behaviour
  it pins was already right and the finding was that no test pinned it.
- `tools/check.sh format analyze host phone`: all PASS (host 576 tests, phone 521). `tools/review.sh`
  on the diff: 0 fail, 0 note.
- Nothing here is device-only, so no item is marked "needs device check".

## Decisions

1. A second call is swallowed rather than the Retry being disabled while reading: the button is the
   error state's whole action and the design keeps it unfocused and spinner-free.
2. `_reading` clears in `whenComplete`, not in `_readSessions`: the guard's future also covers the
   reported-and-swallowed path, so no failure can lock the Retry out.
3. The fake refuses reports while off, leaving `CrashReports.capture`'s own `enabled` check as the
   one a test covers; every capture in the repo goes through `CrashReports`, whose tests are untouched.
4. `_CrashSharingButton` takes no key, like its neighbour `_SharingButton`: no caller needs one.
5. A back on the crash prompt closes the dialog without an answer (ordinary dialog behaviour); a
   `PopScope` to hold it open lives in `consent_prompts.dart`, outside this job's `allow:`.

## Self-check (review-rules part A, items 1-5)

1. **Every host setup** — the change is in `StatsScreen`, which both a TV/PC host and a phone on
   "Play on this phone" build (the phone suite's `host_stats_test.dart` finds `party.StatsScreen`),
   and no joined phone ever shows that screen; no protocol or saved-format change, so an older
   build differs in nothing. Shown by `stats_retry_once_test` at 960×540 and the phone suite's 521
   passing tests.
2. **When kept state starts and ends** — `_reading` starts in `_load`, ends in `whenComplete` for
   success, failure and reported-then-swallowed alike, and runs nothing when idle; leaving the
   screen mid-read keeps the flag moot because the state object dies with the route. Shown by the
   two `stats_retry_once_test` cases.
3. **How the new state combines** — the guard only pairs with the Retry press; the Stats screen has
   no pause, away or round state, and a consent dialog opening over it neither starts nor ends a
   read. Shown by "two quick Retry presses read the sessions once" (the held read still fills the
   table once released).
4. **Stay in the job's folder** — every changed file is in `allow:`; no lib file touched ends over
   380 lines (229, 236, 55); `tools/review.sh` reports 0 fail.
5. **Stop rather than overstep** — nothing needed a file outside `allow:` (the "fix a test that
   uses the type" part had no test to fix) and no rule had to be bent, so nothing was stopped.

## Hand-over

- `_load()`'s guard is per screen instance: two Stats screens opened over the same store still read
  twice, which is right (each has its own table).
- The back-closes-the-prompt note above is the one open question: if the adult must answer the
  crash question before the app goes on, `_ask` needs a `PopScope`, in `consent_prompts.dart`.
- `FakeCrashReporter` no longer shows whether the app called the reporter while off; that check now
  belongs to `CrashReports` (already covered by `crash_reports_test`'s "sends nothing while reports
  are off").

## Commit message

Guard the Stats read, privatise the crash button, pin the crash no

_load() sets a _reading flag and does nothing while a read is going, so
two quick Retry presses read the sessions once, a slow failure cannot land
over a newer table, and the flag clears however the read ends.
CrashSharingButton is now _CrashSharingButton, off party_host's public
surface. FakeCrashReporter drops a report handed over while off, like the
real reporter.
New tests: stats_retry_once_test (2), fake_crash_off_test (3),
crash_dialog_no_test (3: the no saves false and disables once; Esc and
back answer nothing).

## Status row

- **sentry1 f3 (Nov 16, 2026):** the Stats screen's Retry reads once at a time (`_reading`),
  `CrashSharingButton` is private, `FakeCrashReporter` drops reports while off, and the crash
  dialog's no/Esc/back are pinned by new tests (host 576, phone 521, format and analyze pass; the
  read-guard and fake tests were red on the old code). Open: whether back should be blocked on the
  crash prompt (`consent_prompts.dart`, outside this job).

## Delete

- none
