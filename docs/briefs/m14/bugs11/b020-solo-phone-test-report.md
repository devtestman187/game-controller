# M14 bugs11 b020-solo-phone-test report

## Summary

Run review finding 1: the phone host's night card was tested only with a second phone added, so a lone night
player on a phone that plays here (the host's own player, where the round now waits for its Ready tap) had no
test. Added one test in a new file; no `lib/` change.

- `packages/party_host/test/arena_touch_solo_night_test.dart` (new, 1 test): a phone host with the
  `ownPhoneOverrides` copied from `arena_touch_ready_test.dart`, one player, opens the night's Bumper card
  (`arenaWaitingCard`), `notReady-p1` is shown, a second of frames starts nothing, and one tap on `arenaReady`
  starts the round (`arena` key; the waiting card is gone).
- Mode-agnostic: no mode button and no snapshot mode are asserted. The log's "Round started: arena, bumper,
  Pinball" is the card's default, not a tested expectation.
- Test values are below; the test was run in this job and passes.

## Files changed

- `packages/party_host/test/arena_touch_solo_night_test.dart` — new: a copied `ownPhoneOverrides` helper and one
  test for the lone night player's Ready tap (53 lines).
- `docs/briefs/m14/bugs11/b020-solo-phone-test-report.md` — this report.

## Computed test values

- Setup: `pumpHost` at 852×393 (phone landscape, the touch tests' size), overrides
  `ownPlayerIdProvider = 'p1'` and `hostTouchFirstProvider = true`; `neutral(tester, fake, ['p1'])`;
  `openNight`, then `nightBumper`, then 500 ms of frames.
- After the card opens: `arenaWaitingCard` 1, `notReady-p1` 1, `arena` 0.
- After `pump(1 s)`: `arena` 0 (no round on its own).
- After the Ready tap + `pump()` + `pump(200 ms)`: `arenaWaitingCard` 0, `arena` 1. Log line:
  `Round started: arena, bumper, Pinball` (Bumper is the night card's opening mode; not asserted).
- The 200 ms pump: the card's "everyone ready" check runs in its `Timer.periodic(ControllerMenus.step)`, step =
  16 ms (`arena_waiting_card.dart` line 77, `controller_menus.dart` line 84). The `pump()` after the tap only
  draws the toggle; the 200 ms frame lets the timer fire, as `arena_touch_ready_test.dart` does after its Ready
  tap (line 117).
- Host suite: 469 tests (was 468; +1 new).

## Decisions

1. **Copied `ownPhoneOverrides`, did not edit `arena_touch_ready_test.dart`** — the brief says copy, and the
   other file is not in `allow:`.
2. **No mode assertion** — the brief asks for mode-agnostic; the test only checks that *a* round starts.
3. **The 1 s "no round before the tap" pump sits before the tap, after the card** — same shape as
   `solo_arena_card_test.dart`'s "round starts on a press, never on its own", so the same rule is checked here.
4. **Test ends when the round has started, after the 200 ms frame** — the arena's round is left running, as the
   other arena tests do; nothing in this fake-host path starts an upload or writes a temp folder, so there is no
   `settleUploads`/`deleteTempFolder` to await (see Hand-over).
5. **One file, one test, no shared harness helper** — a single user keeps the copy small; a shared helper would
   touch files outside `allow:`.

## Async side effects before teardown (brief step 2)

This test runs on `FakeHostService`/`FakeStats`: no session folder, no `LiveStats`, no uploader, and
`game_screen._start` makes no stats call. The asynchronous work it does trigger is the card's 16 ms periodic
timer (cancelled with the card's State when the card leaves the tree, which the tap causes) and the started
round's frames, both advanced by awaited `pump`s. The `FakeStats` futures it never calls are no-ops anyway.
So there is nothing like `settleUploads`/`deleteTempFolder` to wait for here; the pumps are all awaited.

## Self-check (review-rules part A)

1. **Every host setup.** Only the phone host that plays here changes in this test; its two setups (own player and
   touch-first) are the ones the card branches on. TV, "Show on this device" and joined phones are covered by
   the existing `arena_touch_ready_test.dart` tests and are untouched — no `lib/` change, and no protocol change,
   so an older build is unaffected.
2. **When kept state starts and ends.** The card's `_ready` set starts empty when the card's State is made and
   ends with it (the round replaces it); the test shows it empty (notReady-p1) before the tap, starts the round
   on the single tap, and the card is gone afterwards.
3. **How a new state combines with the others.** Nothing new: the tap goes through the card's existing all-ready
   path into `Pausable`'s playing stage; the pause, away, results and leaving paths are unchanged and covered by
   the existing night/arena tests.
4. **Stay in the job's folder.** Only the new test file and this report were written, both in `allow:`.
5. **Stop rather than overstep.** Nothing needed a file outside `allow:` and no rule contradicted the code, so
   no stop.

## Checks run

- `dart format packages/party_host/test/arena_touch_solo_night_test.dart` — formatted, 0 changed on the last run.
- `flutter test packages/party_host/test/arena_touch_solo_night_test.dart` — 1 test, pass. (First run failed at
  the "waiting card is gone" expectation: the tap only drew the toggle and the card's 16 ms timer had not
  fired; adding the 200 ms frame fixed it. The test did not pass before that fix.)
- `tools/check.sh format analyze host` — PASS format, PASS analyze, PASS host (469 tests, 130 s).

## Questions and suggestions (not acted on)

1. Question: is the 200 ms frame after the tap the intended shape, or should the test pump a single 16 ms step
   (`ControllerMenus.step`) so the timer interval is named rather than implied? I used 200 ms to match
   `arena_touch_ready_test.dart`.
2. Suggestion: `ownPhoneOverrides` is now copied in two test files; if a third needs it, a helper in
   `test/support/host_harness.dart` would keep the two rules (own player + touch) in one place.
3. Suggestion: a test that a lone night player's Ready tap starts a *Bumper* round (asserting the snapshot mode)
   could sit beside this one if the owner wants the solo default pinned while the mode buttons are still fresh.

## Hand-over

The setup the run review flagged is now pinned: a lone night player on a phone that plays here readies with the
card's Ready button, and no round starts before that tap. The test is mode-agnostic by design, so it survives a
change of the solo night's default mode; the existing `solo_arena_card_test.dart` and `solo_arena_both_test.dart`
still carry the mode content. Nothing in `lib/` changed, so no behaviour needs re-checking beyond the host suite.

## Commit message

A lone night player on a phone host starts on Ready

The phone host's night card was only tested with a second phone added. Add
one test for the setup whose behaviour changed (run review finding 1): a
phone that plays here, a night of one player, the waiting card asking for
that player's Ready. The card opens, a second of frames starts nothing, and
one tap on the card's Ready button starts the round. The test is
mode-agnostic, so it does not pin which mode button a solo night opens on;
only the ready path is checked. No lib change; host suite 469 tests.

## Status row

M14 bugs11 b020-solo-phone-test: a lone night player on a phone host that plays here has a test (card opens, no round before the tap, one Ready tap starts it); open: nothing (test-only job, no lib change).

## Delete

- none
