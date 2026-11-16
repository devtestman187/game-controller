# M14 stats2 c3-docs: the build columns, and what frames_drawn and fps mean

## Summary

Docs only, no code and no behaviour change. Read first: `c1-build-metrics-report.md` (Summary),
`docs/dev-tools.md` (the stats report section), `docs/design/m12-report.md` (the CSV paragraph),
`game_session.dart` (`frameCount`, `advance`), `puzzle_game/lib/src/puzzle_report.dart` (the
`frames` record) and `report_rounds.dart` (`_fps`, `roundsCsvHeader`); the headers in
`report.dart` and `report_rounds.dart` are the source of the column lists.

- **`docs/dev-tools.md`**: the `--csv` / `--csv-rounds` bullet now says 37 columns ending
  `host_app,app,host_build,build` and 18 round columns ending `start_s,host_build` (the counts and
  lists in the old text, 35 and 17, were stale since the build columns landed). Two new bullets
  follow it: the build columns (digits of `version+build`, blank for old data and "dev" builds) and
  `frames_drawn` / `fps` (host display vsyncs, so the display rate, not the game rate `hz`; about
  120 on a ProMotion iPhone host at 60 is expected; needs a device check, and the refresh rate
  itself is not exported — a possible later column).
- **`docs/design/m12-report.md`**: the same facts in its one CSV paragraph, which m12 §1 owns, so
  the design and the tool docs don't say different things.
- **`docs/briefs/m14/STATUS.md`**: one line for stats2, above the stats1 line.

## Decisions

1. **Counts updated, not just names appended.** The brief says to read the headers in the code, and
   the docs had 35/17 where the code has 37/18 since the build columns; leaving the old numbers
   beside the new names would be wrong. Corrected in both places, including the "only a model is
   quoted (in the 37-column CSV)" remark.
2. **Two extra bullets in dev-tools, prose in m12-report.** dev-tools already lists the CSVs as
   bullets, so the build and frames notes are bullets of their own; m12-report is one paragraph per
   item, so the same text goes into that paragraph, in the same order.
3. **Build note after the list, frames note last.** That keeps the order of mention matching the
   header (`...,host_app,app,host_build,build`) and the brief's items 1 then 2.
4. **Example build `0.14.0+654`.** It is c1's own example and the m14.5 build number, so the doc
   shows the shape the apps actually send.
5. **"with players present" kept in the frames wording.** It is the code's rule
   (`game_session.dart`, `advance`: `_frames` moves only `if (_players.isNotEmpty)`), and it is
   the reason an idle lobby doesn't water the rate down; a reader comparing rounds needs it.
6. **No code or test changes.** The brief stops after this job; the docs now describe the code as it
   is, and the only open item is the device check, written down in both docs.

## Computed values (checked against the code, not the old docs)

- Stats CSV header, `report.dart` `ModeRow.csvHeader`: 37 fields, ending
  `host_app,app,host_build,build` (was documented as 35 ending `host_app,app`).
- Rounds CSV header, `report_rounds.dart` `roundsCsvHeader`: 18 fields,
  `session,host,game,hz,time_s,battery_start,battery_end,thermal,tags,host_app,winner,draw,players,frames_drawn,frames_late,fps,start_s,host_build`.
- `_fps(drawn, timeS)` = `(drawn / timeS).toStringAsFixed(1)`, blank when `drawn` is not a num or
  `timeS <= 0`. Example from the finding: 60 s round, 7200 vsyncs -> `7200 / 60 = 120.0`, which is
  the host display's 120 Hz, not the 60 Hz game step.
- `frameCount` is `_frames`, incremented once per `advance()` while players are present
  (`game_session.dart`); `puzzle_report.dart` writes it as `frames.drawn`.

## Self-check (review-rules.md part A)

- Every host setup: none — no code, so no host, provider or screen touched.
- When kept state starts and ends: no state; the docs only describe existing behaviour.
- How a new state combines with the others: nothing new is stored anywhere.
- My folder only: three allowed files changed (`docs/dev-tools.md`, `docs/design/m12-report.md`,
  `docs/briefs/m14/STATUS.md`) plus this report.
- Stop rather than overstep: stopped after the docs; no table, column or test was added.

## Checks

- `tools/check.sh format` -> PASS format (5s), "All checks passed". No other check applies: no Dart
  file changed.

## Questions / suggestions

1. Suggestion only: if the display rate is wanted per round later, a host query at `round_start`
   could record it beside `hz` (the brief's "possible later column"); not done here.
2. Suggestion only: `docs/design/m12-report.md` still names the round CSV's `hz` as "the game rate"
   nowhere explicitly; the new sentence now makes the `hz` (game) vs `fps` (display) difference
   visible, and the same one-line distinction could go in the protocol or stats design later.

## Hand-over

- Nothing built, nothing tagged, no commit made by me; the diff is three docs plus this report.
- The fps finding is written down as expected behaviour (display rate), with the device check named
  in both docs and in STATUS.md, so it is not lost.
- Open: the device check itself (one iPhone-hosted round compared with the display rate).
- The design paragraph and the tool docs now give the same column counts (37 / 18) and the same
  meaning for `frames_drawn` and `fps`; a later column change must update both.

## Commit message

M14 stats2: CSV build columns, and what frames_drawn and fps mean

Document host_build and build in both CSV column lists (37 and 18 columns),
and say a build is the digits of an app's "version+build", blank for old
data and local "dev" builds. Define frames_drawn as the host display's
vsyncs while a round ran with players present, so fps is the display rate,
not the game rate hz: about 120 on a ProMotion iPhone host at 60 Hz is
expected. Add the device check; the refresh rate itself is not exported.
Docs only, no behaviour change.

## Status row

- M14 stats2: build number columns, fps finding (display rate, needs device check); nothing built.

## Delete

- none
