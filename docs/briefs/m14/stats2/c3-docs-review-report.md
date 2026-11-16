# M14 stats2 c3-docs: review

Reviewed `6e106fc..8d9a55b`: `docs/dev-tools.md` (+2/-1 lines), `docs/design/m12-report.md` (+1/-1),
`docs/briefs/m14/STATUS.md` (+2) and `docs/briefs/m14/stats2/c3-docs-report.md` (new). Checked against
`packages/metrics/lib/src/report.dart:118-172`, `report_rounds.dart:150-215`,
`session_clean.dart:36-54`, `packages/game_kit/lib/src/game_session.dart:148-225`,
`packages/puzzle_game/lib/src/puzzle_report.dart:70-90` and `play_view.dart:110-140`.

## Summary

Verdict: **small fixes**. Findings: 0 must, 0 should, 2 could.
Both CSV claims hold: `report.dart:118-122` is 37 fields ending `host_app,app,host_build,build`, and
`report_rounds.dart:161-162` is 18 ending `start_s,host_build` — counted field by field, both docs now
say 37 and 18. `buildCell`/`splitAppBuild` blank a build exactly as the docs' line says, and
`game_session.dart:211-214` moves `_frames` once per `advance()` only `if (_players.isNotEmpty)` and
after the pause check, which is the docs' "with players present"; a `PuzzleSession` is created per
round (`play_view.dart:123`), so the count is round-scoped. The self-check lines are all true (three
files in `allow:` plus the report, no code), as is the report's `tools/check.sh format` claim (I
re-ran it: PASS, 3s). The two coulds are a duplicated phrase in the STATUS line and stale size
figures in the paragraph next to the edited one in `docs/design/m12-report.md`.

## Findings

- **could** docs/briefs/m14/STATUS.md:14 "nothing built" appears twice in the new line — in the bold label `M14 stats2 (Nov 15, docs only, nothing built):` and again at the end — while the brief's row and every neighbouring line say it once → drop the trailing `; nothing built` (or the label's), leaving one.
- **could** docs/design/m12-report.md:25 the §2 budgets beside the edited paragraph are stale: it says `session.dart` is "(379)" and `host_service.dart` "(345) may not pass 360", but `session.dart` is now 361 lines (split into `session_clean.dart`, 78) and `host_service.dart` is 369, past its own cap — this predates the diff → refresh the two figures when that paragraph is next touched, and decide whether the 369 is tech debt.

## Decisions to confirm

- Decision 1 (correcting 35/17 to 37/18 in the paragraph m12 §1 owns): safe — `grep` over `docs/`
  outside `briefs/` found no other place quoting the old counts.
- Decision 2 (two new bullets in dev-tools rather than one line): the frames/fps bullet is long and
  duplicates the m12-report sentence word for word; fine if the tool docs are meant to be
  self-contained, which they read as.

## Could not check

- The 120 Hz display-rate reading itself: no device here, so the "about 120 on a ProMotion iPhone
  host" expectation rests on the brief and c1's three rounds, as the docs say.
- Whether `0.14.0+654` is still the build the apps will send: `pubspec.yaml` in both apps says
  `0.14.0+14`; the example is c1's, so it illustrates the shape, not today's build.

## Commit message

review: c3-docs docs pass, two coulds

Check the c3-docs commit against the guidelines, review rules A and B and
its brief: the CSV column counts (37, 18), the build columns and the
frames_drawn/fps wording match report.dart, report_rounds.dart,
session_clean.dart and game_session.dart, and format passes (re-run).
Two coulds: STATUS.md:14 says "nothing built" twice, and the m12 §2 size
budgets in the touched file predate the session.dart split.

## Status row

- M14 stats2: c3-docs reviewed, two coulds (STATUS wording, stale m12 §2 sizes); the fps display-rate finding still needs the device check.

## Delete

- none
