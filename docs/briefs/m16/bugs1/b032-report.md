# B-032 — round chips dead after backing out of a started night

## Summary

**Fixed, unverified: needs device check.** The cause was not measured on a device; it was
reproduced in a widget test and fixed there.

What was wrong: the start card starts the night on its first game button, and the night stayed
set when the host came back from Shape Race's pick without a round recorded. The chips' rule
("a night under way keeps its length, M14 r5 12") then handed them `onChanged: null` for a
night nobody had played.

The fix (smallest of the brief's two options): the night start card now waits for its round's
route to come back and asks `PartyNight.dropIfUnplayed()`: a night with `round == 0` is
cleared, so the card is a fresh pick and its chips pick again. A night with a recorded round is
never dropped (same rule the scoreboard's "End the party night?" No and the picker already
rely on). The night restarts itself only because the host pressed a footer button again, which
draws a fresh awards set — the second option in the brief (restarting the unplayed night with
a new length) was rejected because `PartyNight.start` deliberately no-ops when a night is set,
so it would have needed a second start path.

Tests: new `test/night_start_back_out_test.dart`, 2 tests. The back-out test failed on the old
code at line 27 (`container.read(partyNightProvider)` was a `NightState`, not null — the same
symptom the owner saw), and passes now. The recorded-round test passed before and after (it
pins the rule the fix must not break). Related suites: `party_night_test`,
`night_start_frame_test`, `night_start_noscroll_test`, `night_screens_test` = 81 tests, all
pass. Extra flows run: `night_round_test`, `end_night_puzzle_test`, `end_night_arena_test`,
`abandon_test` = 27 tests, all pass.

Checks: `tools/check.sh format analyze host` — format PASS, analyze PASS, host FAIL on the first
run (1 of 1011: `live_stats_share_test.dart` "a phone that said no is left out of the upload"
saw the ids in the other order — unrelated code, and it passes alone); `tools/check.sh host`
rerun: PASS (128 s).

Line counts: `night_start_screen.dart` 218, `party_night.dart` 148 (limit 380).

Self-check (review-rules.md part A):

1. **Every host setup** — the change is in shared `party_host` code with no platform branch;
   TV, PC, "Play on this phone" and "Show on this device" run the same card and the same
   notifier. Shown by `night_start_back_out_test.dart` (pumpHost at the harness's 960x540) and
   the unchanged frame tests at all five sizes. A joined phone never sees the start card.
2. **When kept state starts and ends** — the night starts on the footer button; it now also
   ends when its round 1 route comes back with `round == 0` (`dropIfUnplayed`), and still ends
   via `end()`/`endNow`. With nothing going on no night is held. Both ends are in
   `night_start_back_out_test.dart`.
3. **How a new state combines with the others** — the drop only reads `NightState.round`; it
   touches no pause/away/results state and only fires after the night's first route returns.
   A round 1 abandoned with Quit is also dropped (round never recorded): `abandon_test.dart`
   passes.
4. **Stay in the job's folder** — four files, all inside `allow:` (report, two `lib` files, one
   new test).
5. **Stop rather than overstep** — no stop; note under Questions that
   `packages/party_host/lib/src/ui/shape_race_screen.dart` from the brief does not exist
   (`ShapeRaceScreen` lives in `games_screen.dart`) and needed no change.

## Decisions

- Drop the unplayed night rather than restart it with the new length (see Summary).
- The drop lives in `PartyNight.dropIfUnplayed()` so the rule sits with the night's own state,
  not in a widget; the card only decides *when* the night's first route came back.
- `_start` and `_startBumperRound` share `_startNight`; both now return `Future<void>` (no
  caller awaits them, the buttons take `VoidCallback`-compatible closures — an `async` method
  returning `Future<void>` is fine as `onPressed`).
- "Before any round is recorded" is read as `NightState.round == 0`, the night's own counter
  of recorded rounds.

## Questions

1. The brief names `packages/party_host/lib/src/ui/shape_race_screen.dart`, which does not
   exist; `ShapeRaceScreen` is in `games_screen.dart`. No change was needed there, so this was
   not a blocker — should the next brief name the real file?
2. Quitting round 1 from the pause menu (round never recorded) now drops the night as well,
   because the same route returns with `round == 0`. That matches "left before any round is
   recorded", but it is a second way to lose a set-up night — confirm it is wanted.
3. Needs a device check on the owner's phone: start a night, back out of Shape Race's pick,
   and the 3/5 chips should pick again.

## Hand-over

Open: device check (the cause was not measured on a device). Nothing else pending; no files to
delete. The repo's `live_stats_share_test.dart` failure seen once in the full host run is a
pre-existing order-dependent flake (passes alone and on the rerun) and was not touched.

## Commit message

B-032: drop an unplayed night when the host backs out of round 1

The start card started the night on its first game button and kept it
when the host came back without a recorded round, so the 3/5 chips got
onChanged null and stopped picking. The card now awaits its round's
route and calls PartyNight.dropIfUnplayed(): a night with round 0 is
cleared and the card is a fresh pick again, while a night with a
recorded round keeps its length as before. New test covers the back-out
and the recorded-round case. Fixed, unverified: needs device check.

## Status row

B-032 done: backing out of round 1 before a round is recorded drops the unplayed night, so the 3/5 round chips pick again; open: device check (cause not measured on a device).

## Delete

- none
