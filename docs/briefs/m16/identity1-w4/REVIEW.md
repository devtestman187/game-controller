# Run review: M16 identity1 w4 (w4a, w4b, w4c)

## Summary

- **Verdict: one fix batch.** Counts: must 1 · should 4 · could 5.
- **Five that matter most:**
  1. `paintToyBadge` now has seven parameters (§3 allows five); this run added the seventh.
  2. The Nov 23 owner decision (no number on the join badge) is in a test comment only; `docs/decisions.md` lacks it and design D10 still says numbers are always drawn.
  3. The named `tools/check.sh format analyze arena host` suite was never run (w4b).
  4. `join_badge_test.dart` checks the `numbered` flag, not what is painted.
  5. Three `tv_test_app/windows` generated files are still modified in the working tree.
- **Carry-over:** no per-job review reports, `STATUS.md` or `run-findings.md` exist in this folder, so nothing to carry over.
- **Hand-fixes:** `run.log` has no `HAND-FIX` lines. Tests-first lines are in `run.log` 14–15 for `join_badge_test` and `toy_badge_unnumbered_test`; w4a is exempt (report); w4b states nothing. Reports exist for w4a, w4b, w4c.
- **Across jobs:** every `ArenaPainter`, `ArenaMarblePainter` and `paintToyBadge` caller in the repo is updated (grep, none stale). `host_connection.dart` went 380 → 300.
- **Fix sizing (one wave):** batch A (toy_look): findings 1, 6, 7. Batch B (`phone`): findings 3, 9. Batch C (docs): finding 2. Claude or operator: 4, 5, 8, 10.
- **Owner-only questions:** open questions 1–5 below.

## Findings

- **must** packages/toy_look/lib/src/toy_badge.dart:38 `paintToyBadge` takes seven parameters (canvas, centre, diameter, number, look, character, numbered); §3 allows five and this run added `numbered` → fold `character` and `numbered` into one value object (from: w4c, its Question 2)
- **should** docs/decisions.md:101 (newest row is 2026-11-17) and docs/design/look-and-sound.md:42 (D10: "players keep their numbers on badges") omit the Nov 23 decision that the join badge and Settings preview draw no number; the decision lives only in controller_app/test/join_badge_test.dart:14–16 → add a dated decisions row and amend D10 (from: across jobs, §10)
- **should** controller_app/test/join_badge_test.dart:27 and :44 assert the widget's `numbered` flag, not the paint; a painter that ignores the flag passes this suite, and no phone-level pixel check exists → add a pixel check of the join badge, or a `numbered` check on the painted output [phone] (from: w4c, its Question 3)
- **should** tv_test_app/windows/flutter/generated_plugin_registrant.cc, generated_plugin_registrant.h and generated_plugins.cmake are modified and uncommitted (git status at start); `run.log` says the harness dropped them from w4b and w4c → revert them before the next commit or push (from: across jobs)
- **should** docs/briefs/m16/identity1-w4/w4b-report.md (Checks): the named `tools/check.sh format analyze arena host` was not run, only `tools/mine.sh` → run the named suite once (from: w4b)
- **could** packages/toy_look/test/toy_badge_unnumbered_test.dart:16 says the disc edge is 34 from the centre; the ink stroke is centred on the r=40 rim, 5.71 px wide (toy_badge.dart:57), so its inner edge is about 37.1 px. The ±20 square (corner 28.3 px) is inside either way → correct the comment (from: w4c, its 34.3 figure)
- **could** packages/toy_look/lib/src/toy_badge.dart:102–103 says `numbered` is false "(the join screen)", but controller_app/lib/src/ui/settings_profile_section.dart:295 passes false too → name both callers (from: w4c)
- **could** docs/briefs/m16/identity1-w4/w4b-report.md (no tests-first line): a pure refactor must say "tests-first: exempt <reason>" (G9); w4a says it, w4b does not → add the line to the report (from: w4b)
- **could** controller_app/lib/src/ui/connect_panels.dart:373 (372 before this run; over the 300 target, under the 380 cap) and settings_profile_section.dart:303 → split the badge widgets out when next touched [phone] (from: across jobs)
- **could** packages/connection/lib/src/host_connection_pairing.dart:5 "The members moved here unchanged to keep that file under its size cap" records history, not the reason the extension exists → keep only the reason (from: w4a)

## Open questions

1. Should the Settings preview keep its number once the phone is paired? Suggest: no, as built; the number it drew was `colourSlot`, not a player number (settings_profile_section.dart:252–257).
2. Record the no-number decision in `docs/decisions.md` and amend D10? Suggest: yes (finding 2).
3. Is the join test's compile failure on the old code its tests-first proof? `run.log` says it "fails on the old code"; the w4c report says it was never reverted. Suggest: accept if the harness reverted it; otherwise re-prove.
4. Value object for `paintToyBadge` (w4c Q2)? Suggest: yes, in batch A.
5. Join test: keep the flag check or add a pixel check (w4c Q3)? Suggest: add the pixel check (finding 3).
6. w4a Q1, unqualified `_onHello(message)` instead of `this._onHello`? Suggest: keep unqualified; the analyzer rejects `this.`.
7. w4a Q2, `host_connection.dart` at 300 rather than about 290? Suggest: accept 300.
8. w4c Q1, rename the hello test's group or move it? Suggest: keep the rename; owner's Q10 asked for it.
9. Why did w4b and w4c finish with `result 4` in `run.log` when their reports say checks passed? Suggest: find out before the next wave.

## Numbers against targets

- `paintToyBadge` parameters: 7 against ≤5 → **miss** (finding 1).
- `ArenaPainter` 5 (was 6); `ArenaMarblePainter` 5 (was 6) → meets.
- `host_connection.dart` 300 against the brief's "near 290" → 10 over; the 380 cap is met.
- `connect_panels.dart` 373 (was 372), `settings_profile_section.dart` 303, `arena_painter.dart` 309 (was 323) → over the 300 target, under the 380 cap.
- `toy_badge_unnumbered_test`: middle square 41 × 41 = 1681 px; disc sample (100, 70) is 30 px from the centre, inside the disc either way.
- Tests reported: connection 346 (w4a); test_game 14 and party_host 2 (w4b, via `mine.sh`); look 144 and the phone suite (w4c, not per file). No target is stated for these; the arena/host suite was not run.

## Could not check

- Nothing was run: this review is read-only and no check was named. Pass claims come from the reports and `run.log` only.
- Job briefs `w4a.md` to `w4c.md` were not in the read list, so brief conformance is not judged.
- The unnumbered badge's look on a phone and on the TV is covered by widget and pixel tests only; no device check.
- `run.log` (tests-first ok) and the w4c report (never reverted) disagree; not reconciled here.
- At the start the working tree also had uncommitted changes to `run.log` and an untracked `docs/briefs/m16/tools7/` folder from another job; not reviewed.
- `mine-w4b.log`, named under w4b's Delete, is absent, so there is nothing to delete.

## Commit message — a draft

M16 identity1 w4: run review, findings for Claude

Reads the w4a, w4b and w4c commits as one change against the coding
and review rules. Ten findings (one must, four should, five could) and
a fix batch of three jobs are in REVIEW.md. No code or other document
was changed.

Co-Authored-By: Claude Haiku 5.5 <noreply@anthropic.com>

## Status row

M16 identity1 w4 run reviewed (REVIEW.md, 10 findings, 1 must): w4a, w4b, w4c committed and read as one change. Open: fix batch (paintToyBadge value object, join pixel check, no-number decision in decisions.md), revert tv_test_app generated files, run `tools/check.sh format analyze arena host`, nine open questions.

## Delete

- none

## Driver verdicts, wave A (Nov 23)
Held for the single end-of-run fix round (f1), not fixed now: must 1 (paintToyBadge 7 params: fold character+numbered into one object; real), should 2 (decisions.md row + D10), should 3 (pixel check on the join badge), should 5 (run the named arena host suite: done at the final check), coulds 6, 7, 8, 10 (comments, report line). should 4 (tv_test_app generated files) is churn, never staged. could 9 (connect_panels 373 lines) to code-health. Open questions 6-8 accepted as suggested; 1, 2, 4, 5 go in f1 as suggested (owner may veto); 3 accepted (harness proved tests-first).

## Driver verdicts, wave B (Nov 23)
No worker review of wave B exists: the run skipped the wave review (single-wave run) and no run review started after 02:54 (run-review.md is still the 01:49 wave A one; run-findings.md holds only the tests-first line, resolved by `tests-first: exempt` in the w4e brief). Real findings queued for f1 from wave B: none. Wave B's commits (w4d deb0e982, w4e 76d5f1c6, w4h 95d1cbad) get read with wave C in the review after it.

## Driver verdicts, wave C (Nov 23)
- w4f (owner Q2: a dropped player's colour/accessory stay reserved for the reserve minute): Haiku stopped before any edit; commit f2a2689c is empty ("none: no change made"). Cause: no testable clock seam; HostServer reads a private Stopwatch (host_server.dart:96, _now :248, nowMs :89-90), other identity tests do not fake time. REAL, needs an owner/main-session call (add a clock seam to HostServer, or accept a test that ends the away slot by hand and skips the minute). Not queued into f1; Q2 is NOT implemented.
- w4g (f2a... f3b59242): committed; checks passed with the tools suite skipped. No wave review ran (single-wave run); read with the final check.
