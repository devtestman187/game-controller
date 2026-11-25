# Verdicts (driver), wave 1 review
- t1 must: snapshot held churn paths only - must - fixed by hand (churn.sh records every dirty path; case 4b now dirties a non-churn file after the briefs commit; fails on the old churn.sh, passes now). HAND-FIX-EVENT f-t1: 12 lines.
- t1 should: two parked jobs sharing a path - should - fixed by hand (run-wave.sh skips parked siblings).
- t1 should: 2 s sleep in case 4b - should - fixed (stub-wait-for polls, bounded).
- t1 should: t1-report failure wording - trivial - fixed (report reworded).
- c1 should: constructor dartdoc - trivial - fixed.
- could: driver-kit sentence - trivial - fixed. could: folder entries in allow: match exactly - minor - code-health.
- decision (shared path stays and is committed with the sibling): accepted, documented in driver-kit.
- c1 showHud name and ArenaHud ignoring it: accepted; the name is the existing field's.
