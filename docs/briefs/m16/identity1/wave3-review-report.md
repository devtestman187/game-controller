# Wave 3 review (f1): the host offers identity

## Summary

- Verdict: **small fixes** — the one code change is right and the two new tests are real; only the doc lines f1
  rewrote are left saying the old thing.
- 0 must · 1 should · 3 could.
- Verified: `host_service.dart:142-144` is the only lib change and the only host capability list (the welcome is
  built from it, `host_server.dart:329`); the new file fails on the old code (run.log:160) and its computed values
  hold (`forPlayer(1)` = slot 1 ears, so crown slot 4 and bow slot 2 are free in both setups); the new
  `protocol.md` sentence matches `host_connection.dart:337` and `host_players_broadcast.dart:32-53`; i1d's
  `host_server.dart:225` is the `PlayersMessage` arm of `capabilityFor` (line 222).
- Most important: i1d-report.md:163 still calls the host's list open after the same commit closes it (1); i1d's
  Q1 now states the players/chars direction backwards (2); f1-report.md:70 counts a hold test in the `host` suite
  that does not exist (3).

## Findings

- **should** docs/briefs/m16/identity1/i1d-report.md:163 — the hand-over still says "Still open: the host app's
  capability list (Question 1) and the `m9_test` expectations (Question 2)", but this commit lists
  `Capability.identity` at `packages/party_host/lib/src/host_service.dart:144` and `m9_test.dart:35` already
  expects it, so the file f1 rewrote contradicts the tree → mark both closed in f1, and fix the suggestion at
  lines 153-155 with them, which still calls the change "dormant" and carries two concessives ("though … although
  …").
- **could** docs/briefs/m16/identity1/i1d-report.md:127 — "`players` and `chars` do reach an app host already" has
  the direction backwards (the host sends them to a phone) → "already reach a phone from an app host".
- **could** docs/briefs/m16/identity1/f1-report.md:70 — self-check 3 says the character hold's tests still pass in
  "the `connection` and `host` suites", but the only held-character test is
  `packages/connection/test/identity_host_test.dart:100`; the `host` suite has none → name the connection suite.
- **could** controller_app/test/host_lists_identity_test.dart:154 — the welcome is checked only with
  `contains(Capability.identity)` (and again at line 165), while f1-report.md:47-48 gives the exact expected list
  `['metrics', 'rating', 'identity']`, so a welcome that lost `metrics` or `rating` from the same constant would
  still pass → assert the whole list in both tests.

## Decisions to confirm

- f1 left the brief's second list alone (`controller_app/lib/src/storage.dart:55`): verified it is
  `loadIdentity`'s *controller hello* list, that a host's welcome comes from the server's own list
  (`host_server.dart:329`), that the library adds `identity` to every hello (`controller_identity.dart:52-65`) and
  that `joined_view_test.dart:38` pins `own.capabilities` → confirm REVIEW must 2 is closed by the host list alone
  and the brief's "both lists" was wrong, so no follow-up job is owed.
- `protocol.md:235`'s re-pair exception documents today's code (`host_connection.dart:337` takes the hello's
  character at once); if the owner instead decides a re-pairing pick during a round should be held like
  `set_character` (i1d report Q4, line 143), that paragraph changes back.
- The new tests pin the welcome with `contains` while f1's own suggestion (f1-report.md:103) asks for `contains`
  in `joined_view_test.dart:38` — the two pull opposite ways on how tightly a capability list is pinned; confirm
  which the codebase wants before the next such test.

## Could not check

- The counts and timings of f1-report.md:23-27 (connection 338 tests, "2 files formatted, 2 packages analyzed,
  2 tested"): the evidence here is run.log's "full check.sh on tip: all suites PASS" (10:32), not a run of my own
  (a review changes nothing).
- f1-report.md:6's "Actual: ['metrics', 'rating']" failure text: run.log:160 records only that the new file failed
  on the old code, not the message.
- Whether the 16 dirty files in the tree now (`docs/design/*.png`, `tv_test_app/windows/flutter/*`) came from f1's
  run or a later one; all are churn-listed (`tools/churn.sh:19-25`) and none is a scratch file.
- f1-report.md:75's "storage.dart was edited for one run, then restored byte for byte": the file has no diff now,
  but no history is readable here to show the edit.

## Commit message

review: wave 3 f1, host identity offer is sound

Findings only, no code changed. LiveHostService lists Capability.identity
(host_service.dart:144), the only host capability list, so the phone's
set_character gate (client_connection.dart:219) opens; the two new tests
fail on the old code and compute the values their report gives. What is
left is the doc text f1 rewrote: i1d's hand-over still calls the host's
list open, its Q1 says players and chars reach a host when they leave it,
and f1's self-check names a host-suite hold test that does not exist.

## Status row

| identity1 wave 3 review | done: f1 checked against docs/coding-guidelines.md, docs/review-rules.md and its brief (0 must, 1 should, 3 could; verdict small fixes) | open: i1d-report.md's hand-over and Q1 wording, f1-report.md's suite claim, the welcome test's `contains`, and the milestone's own open items (the blank-nickname "Player N", the six-parameter painters, i1g2) |

## Delete

- none
