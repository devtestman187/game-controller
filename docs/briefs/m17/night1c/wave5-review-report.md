## Summary

Verdict: small fixes. Counts: must 1, should 3, could 1.

1. must: the two new "no controller" tests (provider test :136 and :147) pass on the old code, so they guard but do not prove the fix.
2. should: the PlayerBadge dartdoc (player_badge.dart:39-43) does not say the ring is now drawn only inside the host frame.
3. should: the self-check's combination line (f4-report.md:30) says "not tested here" for a window the change has just widened.

## Findings

- **must** packages/party_host/test/night_flow_provider_test.dart:136 The test "a night loaded after its last round gives no controller" (and :147, "a new night after a finished one gets a fresh controller") passes on the old code: the old select also returned null for `isOver`, and a new night rebuilds fresh. → Say in the report that both are regression guards kept on purpose, or confirm the owner accepts them as guards; no code change needed.
- **should** packages/party_host/lib/src/ui/player_badge.dart:39-43 The class dartdoc says nothing about the ring being drawn only inside the host frame, but the joined phone's own badge (controller_app/lib/src/ui/bar_connection.dart:270) now shows players 7 and 8 plain. → Add one sentence to the frame paragraph saying the ring is drawn only inside `HostFrame`, so outside it players 7 and 8 are plain.
- **should** packages/party_host/lib/src/night/night_flow_provider.dart:24 `if (played >= length.rounds) return null;` departs from the brief's literal rule (drop the controller only when the night is null or ended early), so a finished night loaded from a save never runs its ceremony or end. → Owner confirms this (see Decisions); if it must run, a separate job adds a load path for it.
- **should** docs/briefs/m17/night1c/f4-report.md:30 Self-check item 3 reads "unchanged here, not tested here", which is not an answer under review-rules A3: the kept controller now runs the last round's ceremony timer, so pause, host away, a dropped link and leaving during that window are new pairs. → Name those pairs and add a test for each, or state which path each one takes.
- **could** packages/party_host/lib/src/night/party_night.dart:21 `nightBumperRoundReady` is still `const true` and still gates three places (night_start_screen.dart:55 and :132, night_scoreboard_screen.dart:147), so those branches stay dead. → Leave as briefed; record in docs/code-health.md as "when touched".

## Decisions to confirm

- night_flow_provider.dart:24: a night loaded after its last round gets no controller. The brief's literal rule would rebuild a fresh controller that replays the whole night; the worker's guard prevents that but also drops the ceremony and end for that night. Owner to confirm.
- player_badge.dart:59 and bar_connection.dart:270: players 7 and 8 are plain on a joined phone's bar badge (the brief's choice). Owner accepted in the brief; confirm it still holds.
- night_scoreboard_screen.dart:147: the footer gate on `nightBumperRoundReady` is kept, as the brief asked, while the constant is `true`.

## Could not check

- No test or analyzer run: this review is read-only and no run-findings.md exists, so "all 26 OK", "analyze clean" and the fail-on-base claims rest on the worker's report and my reading of the old code.
- controller_app tests host_chip_test, identity_phone_test and lobby_alignment_test (they reference PlayerBadge): not read in full, so I cannot say whether they pin the ring for players 7 and 8 outside the frame.
- Whether every "Play on this phone" and "Show on this device" path goes through controller_app/lib/src/host/host_frame_gate.dart:63 (the framed path): not traced.
- Whether the last round's ceremony timer in night_flow_controller.dart keeps running through the pause menu or a host-away state: not traced into the controller.

## Commit message — a draft: a subject line under 72 characters, a blank line, then at most 8 lines on what changed and why.

review: night1c wave 5 (f4) findings, read-only

Review of the f4 job (controller through the last round's ceremony, host ring only in the host frame,
dead bumper guard removed). Writes only this report; no code changed. Findings: one must (two tests
that pass on the old code, kept as guards), three shoulds (the PlayerBadge dartdoc, the untested
combination window, the loaded finished night with no ceremony) and one could (dead bumper gate).

## Status row — one line for the milestone's STATUS.md: what is now done, and what is open.

night1c wave 5 (f4) review done: verdict small fixes (1 must, 3 should, 1 could). Open: the PlayerBadge dartdoc, the self-check combination window, owner's confirmation of the finished-night-on-load case, controller_app PlayerBadge tests not read.

## Delete

- none
