# Verdicts (driver), wave 1 review
- t1 must: snapshot held churn paths only - must - fixed by hand (churn.sh records every dirty path; case 4b now dirties a non-churn file after the briefs commit; fails on the old churn.sh, passes now). HAND-FIX-EVENT f-t1: 12 lines.
- t1 should: two parked jobs sharing a path - should - fixed by hand (run-wave.sh skips parked siblings).
- t1 should: 2 s sleep in case 4b - should - fixed (stub-wait-for polls, bounded).
- t1 should: t1-report failure wording - trivial - fixed (report reworded).
- c1 should: constructor dartdoc - trivial - fixed.
- could: driver-kit sentence - trivial - fixed. could: folder entries in allow: match exactly - minor - code-health.
- decision (shared path stays and is committed with the sibling): accepted, documented in driver-kit.
- c1 showHud name and ArenaHud ignoring it: accepted; the name is the existing field's.

# Wave 2 (c2 review, pause after wave 2)
- c2 should: report lacks checks/self-check - should - fixed (report extended by the driver).
- c2 should: stray report path - should - fixed (A4 line in the report).
- c2 could: ShellBack constructor dartdoc - trivial - fixed.
- c4: no change; owner question (options A/B/C in c4-report.md): pad top bar at 568x320 TV look needs a design choice.

# Wave 2 review (c3, c5, c4)
- c3 should: volume test name - should - fixed (renamed).
- c5 should: self-check A1 names no test - should - fixed (mapped to tests).
- c4 could x2: barPadding expression, Summary block - trivial - fixed.
- Decision: launchConsentDue name kept (brief's name; side effect noted in dartdoc is a could). c3 covers palettes only: accepted.
