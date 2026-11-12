# Review of M14 bug b1 (Bumper Round start on a touch host)

## Summary

- **Verdict: `small fixes`** — the change is sound: the Ready button readies only the own player, a TV's
  card and focus are untouched, and every brief item that is code has a test behind it.
- 0 **must**, 3 **should**, 3 **could**.
- Most important: the design doc and two code docs still say the card shows a "✓" (and "Press A"), which the
  change removed — `docs/design/party-night.md:190`, `arena_waiting_card.dart:22`, `arena_waiting_widgets.dart:139`.
- Next: test 1 passes only because no timer tick runs between its two taps (one joined player would start the
  round on the next 16 ms tick); and the row's new `maxLines`/ellipsis is a display change nobody asked for.
- Checked here: `flutter test` in `packages/party_host` — 387 tests pass (380 + the new 7); the new file alone
  passes 7/7; `dart analyze --fatal-infos packages/party_host` clean; `dart format` reports the 4 changed Dart
  files unchanged. No `must` came out of the read of the diff.

## Findings

- **should** docs/design/party-night.md:190 the design's §8 still describes the card as "a ✓ for each ready player" and "Press A when you're ready", both of which the card no longer shows on a touch host → update §8 in a docs job (outside this job's `allow:`) to the word label, the Ready button and the host-dependent line.
- **should** packages/party_host/lib/src/ui/arena_waiting_card.dart:22 the class doc still promises "each joined phone's badge and nickname with a ✓ once they are ready, and 'Press A when you're ready'", which contradicts the widget it documents → reword to the "Ready"/"Not ready yet" word and the two lines.
- **should** packages/party_host/lib/src/ui/arena_waiting_widgets.dart:139 `_RoboRow`'s doc says "Robo is always ready, so it wears a ✓", but the row now wears `_ReadyLabel` → say it wears the word "Ready".
- **could** packages/party_host/test/arena_touch_ready_test.dart:82 test 1 taps Ready with only one player joined, so a single 16 ms `_tick` would start the round and take the card (and `ready-p1`) away; it passes only because `tester.pump()` advances no time before the second tap → add a second phone or change the ready flag without a tap-then-check window.
- **could** packages/party_host/lib/src/ui/arena_waiting_widgets.dart:59 the name's `maxLines: 1` and `TextOverflow.ellipsis` are a display change the brief did not ask for and Decisions does not list → drop it, or add it as a decision.
- **could** packages/party_host/lib/src/text/arena_text.dart:27 `readyButton` and `readyLabel` are both the string `'Ready'`, so the button's word and the row's word can drift apart → one constant, or a doc line saying why they are two.

## Decisions to confirm

1. Decision 1 (placement): the button sits in its own row beside the line, under the mode row — the same place as Shape Race's Start (`join_screen_widgets.dart:273`), not pinned in the header; confirmed visible at 852×393 by test 7, but the owner may still want it in the header row.
2. Decision 3 (wording keyed on the own player, not `hostTouchFirst`): a phone on "Show on this device" reads "Press A when you're ready."; it is true for the joined phones but the owner may hear it as the old bug.
3. The button wears the focus yellow while ready (report Question 2): it then looks like the chosen mode button next to it — a one-line change either way.
4. Decision 6's `HostText.playerLabel` also adds "(simulated)" to a simulated player's row, which the old literal never showed; listed, but it is a second visible change on the card.
5. Tests 4 and 5 assert behaviour that did not change, so they pass on the old card: the "test fails first" gate covers tests 1, 2, 3, 6 and 7 only.

## Could not check

- The `phone` (463) and `tv` (53) suites and `dart analyze` for the two apps: only `packages/party_host` was run here.
- The working tree: `git status` was not permitted, so only the two commits in the given range were read (nothing outside them is judged).
- Anything on a real phone, tablet or TV: widget tests only, so the owner's device test stays open.
- The audit table for the other phone-host screens is a code read: I confirmed no other "Press A" or "Press Start" string exists in `party_host/lib` outside the Arena's line and the join screen's hints (`host_text.dart:56-63`), but I did not run those screens.
- Whether the card still fits a *smaller* landscape phone: only 852×393 is tested (the suite's standard phone size), so the row that now holds button + line is unmeasured on, say, 667×375.

## Commit message

Review of M14 bug b1: small fixes, no must

The Bumper Round's Ready button and the rows' readiness words hold up
against the guidelines and the brief; the checks were rerun (party_host
387 tests pass, analyze and format clean). What is left is documentation
that still says the card shows a ✓ and "Press A": the design's section 8
and two code docs, plus small notes on the test that could start the
round by accident and on two unlisted touches (the name's ellipsis, the
two 'Ready' constants).

## Status row

M14 bug b1 review: read-only pass done (0 must, 3 should, 3 could, verdict small fixes); open: the three doc fixes, the three could notes, and the owner's device test.

## Delete

- none
