job: M13 full review R2: the host. party_host (screens, cards, look providers, sound, lobby music, countdown, settings) and assets. Read-only
stop: after the review. Change no file but the report, and fix nothing. Write only inside this job's folder.
read: docs/review-rules.md (parts A to D: the rules for this review) · docs/coding-guidelines.md · docs/design/look-and-sound.md (all, with the "Decided at step N" blocks) · docs/PRD-v2.md L1–L6 and T15 · docs/briefs/m13/STATUS.md and the step briefs and reports it lists · docs/design/m12-host-touch.md (rules 1–6) · docs/design/m12-joined-view.md §0
diff: `git diff d06f88a HEAD -- packages/party_host assets` (M13 was cut from m12 at d06f88a). Read the tests as well as lib: a test that would still pass if its rule broke is a finding.

do:
1. **Part A:** for each M13 job in your area, is its self-check true?
2. **Part B** over the diff, B1–B8, focused on:
   - the palette changing only between screens and never mid-round (ToyLookRouteObserver, refresh);
   - the sky held still in rounds;
   - the lobby music's holds and the moments they start and end (picker, join, round, Play again, Change teams, hidden or shown, Music off, scope disposed);
   - the countdown against the beat (held, restarted, results, dispose);
   - the player-joined cue (rejoin, away, local, simulated);
   - the volume reaching the player on every host and on a joined phone;
   - settings saved and read back;
   - the string table: no user text outside HostText;
   - the focus highlight on every host screen, for the remote (L3).
3. **The combination table (A3)** for every state your area touches (lobby music × round × Music setting × app shown; countdown × beat held × results; palette × route change × round). For each pair: "tested by <test name>", or "not tested" and what the code does.
4. **Part C:** only for your area, and only what would cost much more to fix later than now. Weigh it against M14: G1–G8, the party night's rounds and scoreboard, and nicknames (C20). In particular, can a round be followed by a scoreboard and another round without the lobby music or the countdown misbehaving?
5. **PRD coverage:** for L3 and L5, say whether each sentence is done, with the file or test that shows it, or what's missing. L5 names "a mute switch": say whether volume 0 plus the Music switch meets it, or what would.
6. Run `tools/review.sh` on the range and copy every FAIL.
format: docs/review-rules.md part D, at most 140 lines.
check:
report: docs/briefs/m13/m13-review-r2-report.md
allow: docs/briefs/m13/m13-review-r2-report.md
