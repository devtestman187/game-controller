# sentry1 f2 review

## Summary

Verdict: **small fixes**. Counts: 0 must, 2 should, 2 could.

1. `uploadable.dart:44` still documents the old winners rule ("left out unless every listed player shares").
2. The self-check's line 1 says a phone on "Show on this device" is covered by `live_stats_answer_kept_test`; that test is a windows TV host and no test covers a phone host.
3. The two host tests the report calls new are not in the f2 commit (they are in 52389e7c, f1's), so the diff a reviewer reads shows the pause fix without its test.

Checked and true: metrics 169 tests pass, party_host 580 pass at HEAD, `dart format` clean on all 8 changed Dart files, `dart analyze`/`flutter analyze` clean on metrics and party_host. The pause test failed on the old code (run.log 16:07:28), so the missing test in the diff is a reporting gap, not a missing proof. The code behaves as the brief asks: kept answers, in-process sharing, the old-file fallback and the two-member team rule all match their tests.

## Findings

- **should** packages/metrics/lib/src/uploadable.dart:44 the doc comment still says "a winner or a team is left out unless every listed player shares", while `_roundTotals` now keeps a team of two among three when two of them share (uploadable.dart:54) → reword it to say a team keeps its sharing members only while two or more of them share.
- **should** docs/briefs/m14/sentry1/f2-report.md:51 self-check line 1 says a phone on "Show on this device" is covered by `live_stats_answer_kept_test`, but that test runs a windows TV host (live_stats_answer_kept_test.dart:61) and no test covers a kept answer on a phone host → say which setups are tested (TV/PC, joined phone) and that the phone host's own player is covered only by uploadable_in_process_test.
- **could** packages/party_host/lib/src/session_recorder.dart:64 the comment cites "(B-019)" for reading the answer before the session lookup, but B-019 is the dispose/order leftover list (docs/code-health.md:112) and does not cover keeping an answer between sessions → drop the reference or cite sentry1 f2.
- **could** docs/briefs/m14/sentry1/f2-report.md:85 the report calls the two host tests new for this job, but 61cc4274 changes nothing under packages/party_host/test: the file is in 52389e7c (f1's commit), so the f2 diff shows the pause fix with no test in it → name the commit that carries the test so a diff-based check can find it.

## Decisions to confirm

- Old files upload every player with `install`, device and their data, and every winner, for players
  who were never asked (f2-report.md:38-40, uploadable.dart:22-28) — the brief asked for it, but it
  is the one choice a privacy reader should see: confirm it is what the privacy page promises.
- An in-process player shares even if that player's own `shares` is false (session_player.dart:105) —
  confirm an explicit no from the host phone's own pad can never opt it out.
- The kept answer is keyed by install ID and applied to any later join in the same app run, including
  a player who left the party and came back (session_recorder.dart:145-148) — confirm that scope.

## Could not check

- The device path ("Play on this phone" really uploading its own player): needs a running host app.
- The report's party_host count of 570: HEAD has 580 (f3's tests landed after f2), so only the two
  stats test files could be re-run, and both pass.
- A real session file saved by a pre-`share` build: no sample found, so the old-file branch is judged
  from the new test's handmade map only.

## Commit message

Review sentry1 f2: no must, two should, mostly docs

Read the f2 diff against the coding guidelines, review rules parts A and B, and
the brief. The behaviour matches the brief and its tests: kept stats answers,
in-process sharing, old-file fallback, two-member team rule.
Re-ran metrics (169) and party_host (580) tests, format and analyze on the
changed files: all pass.
Two should findings, both in text: a stale winners rule in uploadable.dart's
comment, and a self-check line that claims a phone-host test that does not
exist. Two could: a borrowed B-019 reference and the host tests living in f1's
commit instead of f2's.

## Status row

sentry1 f2 reviewed: behaviour matches the brief and its tests pass; open: fix the stale `_roundTotals` comment (uploadable.dart:44) and the self-check's phone-host claim, plus the owner's call on uploading old files.

## Delete

- none
