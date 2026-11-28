# tune4a h4b2: REPORT-v3.md

## Summary

STATUS: done. Wrote `docs/briefs/m17/city/REPORT-v3.md` (docs only; tests-first: exempt docs only). No rule, FuseParams
or settings file touched.

- Targets: Plaza rate 0.9858-1.0000 in all 28 final-rule rows (bar 0.90), met; night length not measured.
- Four proposals: A no change, B 5-tile 3-Bolt road at 5-8 players, C Roadworks off, D 4 players at 2 Bolts (not
  simulated). Q-A asks the owner for one letter.
- Fable findings: 6 answered or marked unresolved one line each (3-game night and tile-4 gate unresolved; 37% and 61%
  figures not found in v3).
- Firestore stats table and Shape Race team payout context included as proposals only.

## Computed values (my arithmetic, all from the CSV)

- Not-last chance (n-1)/n: 2p 0.500, 3p 0.667, 4p 0.750, 5p 0.800, 6p 0.833, 7p 0.857, 8p 0.875; adult r2 catch-up minus
  that: -0.071, -0.012, -0.119, -0.201, -0.227, -0.226, -0.183.
- Catch-up off minus r2 (adult): +0.0016, +0.0270, +0.0204, +0.0142, +0.0304, +0.0420, +0.0382; (mixed): +0.0568,
  +0.0342, +0.0206, +0.0128, -0.0046, +0.0068, -0.0022.
- Shape Race arithmetic: 4 x 3 + 6 = 18, 4 x 1 + 2 = 6, half-split 12 Bolts; road 6 x 2 = 12, 6 x 3 = 18.

## Decisions

1. CSV row numbers: the CSV is not in the tables' order. Rows 1-14 adult final, 15-28 mixed final, 29-56 adult v1;
   row = file line - 1.
2. "Catch-up" is `mid_last_not_last_rate`, as the brief says; `comeback_rate` is only mentioned to explain why it is weak.
3. Proposal D has no number after the change (no cell); marked as not simulated.

## Self-check

Items 1-3 and 6: docs only, no code or UI. 4: only the two allowed files. 5: nothing to stop on.

## Questions

1. The tile-4 gate: no CSV column or rules.dart text names it. What is it meant to be?
2. Where do the 37% (Roadworks user at 8 players) and 61% (5-tile Plaza) figures come from? Not in v3.

## Suggestions

- Add `games` = 3 cells and a 4-player cost-2 cell to the next run (findings 4 and proposal D).
- The v3 CSV has no mixed v1 rows, so proposal B is adult-only.

## Commit message — a draft: a subject line under 72 characters, a blank line, then at most 8 lines on what changed and why.

tune4a h4b2: City Rush tuning report v3

Adds docs/briefs/m17/city/REPORT-v3.md: v3 simulator results against the targets, the catch-up rate, spread and
Plaza reach for 3-8 players, the open Fable findings, three proposals plus "no change", and a Firestore stats
proposal. Report only; no rule changed.

## Status row — one line for the milestone's STATUS.md: what is now done, and what is open.

tune4a h4b2: REPORT-v3.md written (Plaza target met, proposals A-D); open: owner answer Q-A, night length and repeat rate unmeasured.

## Delete — the files to delete, one `- path` line each (only files you may change), or `- none`.

- none
