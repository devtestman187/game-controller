# M16 identity1 i1e2 report: the five failing tests of the hand-applied i1e

## Summary

- Three test files changed, no lib file: the i1e code needed no fix (its five failures were
  the tests' own setup, as the brief said).
- `host_chip_test.dart` (2 failures): the two badge tests overrode `clientStateProvider` with a
  `connected` snapshot before pumping. The Connect screen's `hostGame` button lives in its
  `_NotConnected` panel, which only shows while the status is idle, so `enterHostMode` found no
  button. Fix: no client override. The phone now saves the teal crown
  (`saved: {'profileCharacter': jsonEncode(tealCrown.toJson())}`), joins the real host as
  "Play on this phone", the host answers the hello with that character, and the test asserts the
  chip's badge shows the host's number and that character, in the menu look and the TV look.
  The `_FixedClientState` fake and its two imports are gone.
- `phone_metrics_test.dart` (1 failure): the hello's capability list now ends with
  `Capability.identity` (the client library adds it in `ControllerIdentity.toHello`); expected list
  updated with a comment saying where it comes from.
- `m9_test.dart` (2 failures: webSocket and inProcess): the host learns
  `[..._both, Capability.identity]` for a client whose app listed metrics and rating.
- Grep for other exact capability lists (`capabilities` + expect/==/literal `'metrics'` in
  `controller_app/test`, `packages/connection/test`): only `joined_view_test.dart:38`, which pins
  `ControllerIdentity.capabilities` (not the hello), so it is still right; and
  `identity_client_test.dart:102`, which already expects identity. Nothing else to change.
- Tests seen in this job: host_chip 4 passed, phone_metrics 18 passed, m9 22 passed,
  identity_phone 9 passed, identity_client 10 passed. `tools/check.sh format analyze phone
  connection`: PASS (format 5 s, analyze 14 s, connection 326 tests 15 s, phone 70 s, 104 s).
  `tools/mine.sh`: OK (22 controller_app, 22 connection, 16 test_game; 3 generated files reverted).

## Decisions

- **A real host instead of a fake client state.** The brief asked to fix the setup "so they pass and
  still prove the chip's badge wears the host's character". Overriding `clientStateProvider` before
  the pump fights the Connect screen's own status; going through the host costs one saved setting
  and proves the whole path (hello → `PlayerMessage` → client snapshot → chip). pattern copied from
  the other host tests, which never override the client state.
- **A character no number's default gives.** The saved ask is the teal crown (slot 4 + crown); the
  own player is player 1, whose default is blue ears (slot 1 + ears), so the badge's teal crown can
  only have come from the host's answer, not from `ToyCharacter.forPlayer`.
- **The number is read, not pinned.** The test takes the own player's number from the host's answer
  (`ownClientOf(host).snapshot.player`) rather than hard-coding 1, so it survives the host handing
  out numbers differently; it asserts the answer was a real one (not null) and that the character
  arrived as asked.
- **The prefs key is a named constant in the test.** `profileCharacter` is `profile.dart`'s private
  key; the test names it once as `_characterKey` with a doc comment (tests elsewhere hard-code
  `statsConsent`, `lastHost` the same way).

## Computed test values

- Saved/asked character: `{"c":4,"a":"crown"}` (the teal crown). Player 1's default is slot 1,
  ears (blue ears), so `badge.character == tealCrown` fails if the chip falls back to the default.
- The host's answer in both looks: player 1, teal crown (the only paired controller, so the ask is
  free and `nearestFreeIn([])` returns it).
- Hello capabilities after the change: `['metrics','rating','layout','status','view','identity']`
  (6, app's 5 then the library's 1).
- A client whose app lists `['metrics','rating']`: the host records
  `['metrics','rating','identity']` (3) — the two m9 transports.
- Test counts: host_chip 4 (2 old + 2 looks), phone_metrics 18, m9 22 (11 per transport),
  identity_phone 9, identity_client 10; connection suite 326.

## Self-check (docs/review-rules.md part A)

1. **Every host setup**: no lib change, so TV, PC, "Play on this phone", "Show on this device",
   a joined phone and an older peer behave as before. The chip test now runs the "Play on this
   phone" setup itself with its own player and the real host — host_chip_test "the chip's badge
   wears the character the host gave the own player, in the menu look"/"…the TV look".
2. **Kept state**: none added; only the phone's saved character (an existing setting) is set
   before launch. Nothing happens when nothing is going on — the connection suite's untouched
   capability tests.
3. **With the pause menu, host away, player away, "Get ready", a dropped link, the results and
   leaving**: no change; the capability list only rides the hello (m9 "each side learns what the
   other supports", both transports).
4. **Job folder and `allow:`**: only `host_chip_test.dart`, `phone_metrics_test.dart` and
   `m9_test.dart` changed, plus this report. The tree also holds i1f's uncommitted `test_game`
   edits and two untracked i1f files; I did not touch them (`git status --short`).
5. **Stop rather than overstep**: no lib change was needed, so nothing was stopped. `host_chip.dart`
   already reads the own player's `character` off the client snapshot; changing it would have been
   the overstep the brief warns against.
6. **Every look**: the chip tests run the menu look (852×393, `tablet: false`) and the TV look
   (1180×820, `tablet: true`, `toyTvProvider` true); no fixed pixel height is involved. The
   capability tests are not UI.

## Questions

1. The chip test cannot tell "the host's answer" from "the saved profile" today: the host grants a
   free ask, so the two are equal. Once the host handles `set_character` (i1d) and can answer with a
   different character (colour or accessory taken), a step that changes the profile after pairing
   would pin the chip to the answer. Left out now because it depends on i1d's host behaviour.
2. `phone_metrics_test`'s name still says "the hello lists metrics and rating" while it now pins six
   capabilities; rename it, or leave the name as the rule it started as? Left as it was.
3. `profile.dart`'s `_characterKey` is private, so this test repeats `'profileCharacter'`. Exposing
   it (or a `ControllerProfile.save` the test can call before the override is built) would avoid
   the copy.

## Suggestions (not acted on)

- Let the host's answer differ from the ask in the chip test by occupying the asked character with a
  joined phone first; that needs a second real client per look and is slow.
- `joined_view_test.dart:38` could say why the identity itself lists no `identity` capability (the
  library adds it to the hello); it currently reads as if the list were the hello's.

## Hand-over

- The i1e work is green in the tests this job touched; the five failures are fixed and no lib code
  changed.
- Open for the milestone: i1d's host-side `set_character` answer, and the questions above.

## Commit message

phone tests: reach host mode for the chip's badge, list identity

Stop overriding clientStateProvider before pumping in host_chip_test: a
connected snapshot hides the Connect screen's hostGame button, so
enterHostMode found nothing. The phone now saves the teal crown, joins the
real host, and the badge test asserts the host's number and character in the
menu and TV looks.
Add Capability.identity to the hello expectations in phone_metrics_test and
m9_test (both transports): the client library adds it to every hello.
No lib change: the i1e code was right.

## Status row

| identity1 i1e2 | done: the five i1e test failures fixed (host_chip badge tests through a real host in both looks, hello capability lists in phone_metrics and m9); format, analyze, connection 326 tests and phone green | open: i1d's host `set_character` answer, and Q1's chip-vs-profile distinction until then |

## Delete

- none
