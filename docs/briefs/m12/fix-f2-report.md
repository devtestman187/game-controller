# M12 build 4 fix-f2 — G4 report: a missed host_back; tilt outside a round

Done at G4, the gate the brief names. Two fixes, each tested first:

- **N2** (`docs/code-health.md` N2, review finding 1): a `host_away` whose `host_back` went nowhere while the
  link was down ends when the link comes back — a host that accepts a connection is not away. A host that still
  runs a round re-sends `view_start`, and a `host_away` that arrives after the reconnect starts its own wait.
- **N8** (N8, review finding 4): on a host phone, tilt sends only while the round's phase is not `none`; launch,
  `restoreMode()` and the app's resume follow the phase as the pad does. Joined phones and a TV's phones are
  unchanged.

Only files in `allow:` were edited.

## N2: the wait ends with the link

`HostWaitNotifier._onClientState` cleared `_dropped` on every connected snapshot but kept `_away`, so a host that
hid its app mid-round and came back while this phone was reconnecting left the card (and the 30 s countdown)
standing until the countdown ran out. The client sends a snapshot on every RTT ping while the link is up, so a
reconnect is the step from down to up, and only that step ends `_away`:

```dart
final cameBack = next.isConnected && !(previous?.isConnected ?? false);
if (next.isConnected) {
  _dropped = null;
  if (cameBack) _away = null;
}
```

Every other ending is unchanged: `host_back`, a new view, the end of the view, `idle`. The doc paragraph above
`hostWaitProvider` says so and names the reconnect.

## N8: tilt follows the pad

The pad on a host phone is built only while the round's phase is not `none` (`_Controls`, m12-host-touch rules 1,
2). Gyro was the one input that ignored that: it kept its sensors and its 60 Hz output running over the picker, the
join screen, the pause menu and the results. The rule is now a provider the gyro follows, so launch, `restoreMode()`
and the app's resume all meet the same gate:

- `controller_app/lib/src/providers/pad.dart` — `padOnScreenProvider`: `true` for every phone that is not hosting
  (`gameShownProvider` false, the host route's flag), and while hosting `true` only when `roundPhaseProvider`'s
  phase is not `none`. The phase is a `RoundPhaseSignal` (a `ValueNotifier`) in a provider, so it is followed with
  a listener, not watched.
- `controller_app/lib/src/gyro.dart` — the old `_paused` flag became a set of holds, `_TiltHold {background,
  noRound}`: the app leaving the foreground (m12 §2.10) and the pad being away (rule 2). The sensors and the
  output run only while neither holds; `build` starts held if the pad is already away (launch on a host phone),
  `setMode` turns the mode on and leaves the sensors off, and `_release` re-checks the holds after the first
  reading so a hold that arrives during it cannot start the output.
- `controller_app/lib/src/ui/controller_screen.dart` — `_notePhase` no longer pauses or resumes the gyro; it lets
  go of the pad's buttons on `none` and leaves tilt to `padOnScreenProvider`.

A hold centers the stick a microtask later, not at once: the phase is followed while the widget tree builds
(Riverpod's scheduler runs inside `_UncontrolledProviderScopeState.build`), where a provider cannot be written.
The sensors stop in the same call, so nothing is sent in between.

## Computed test values

- Phone tests: **348 before** this job, **353 after** (+3 for N2 in `waiting_card_test.dart`, +2 for N8 in
  `host_gyro_test.dart` and `host_lifecycle_test.dart`). `waiting_card_test.dart` 16 → 19 tests.
- The three N2 tests fail without the fix, each on the card being up after the reconnect
  (`waitingCard` found at `waiting_card_test.dart:191`, `:206` and `:228`).
- `host_gyro_test.dart` fails without the fix on the picker: **22 inputs sent, 12 expected** (a lean of 30° after
  one of 15° is a new value, so a gyro still running sends it).
- `host_lifecycle_test.dart` fails without the fix after the resume on the pause menu: **25 inputs, 14 expected**.
- The round's "Get ready" beat is 3 s and Start is ignored for 500 ms after it (`Pausable.startGrace`), so both
  gyro tests take a reading through the beat and `settle` once before pressing Start; the first gyro reading has
  1.5 s (`GyroNotifier.gyroTimeout`) to arrive.
- The countdown in the third N2 test is **20 s** with the clock moved 2 s on (the message names the seconds left).
- `controller_app/lib/src/gyro.dart` is 398 lines (limit 400); `host_mode_test.dart` is 456 (test limit 500).

## Old → new, test by test

No existing test's expectations changed. Three files changed around the new tests:

1. `controller_app/test/controls_layer_test.dart` — "in gyro mode on a phone/tablet no control moves at 20%, 60% or
   100% over a game": `inMode`'s app is kept (`final app = await inMode(…)`) and, after the last `shown.set(false)`
   — the pad back — a reading (`app.motion.hold(const Vec3(1, 0, 0), samples: 50)`) and a 100 ms pump are added
   before `takeException`. Gyro's sensors now come back with the pad there and their first-reading timer was left
   pending at the test's end.
2. `controller_app/test/support/host_app.dart` — `pumpHostApp` gained `saved` (passed to `pumpApp`), so a gyro test
   can launch with `{'padMode': 'gyro'}`. No test changed by it.
3. `controller_app/test/host_mode_test.dart` — the new N8 test was written here and then moved, unchanged, to a new
   `host_gyro_test.dart` when the file passed the 500-line test limit (with `dart:math`, `tilt.dart` and the
   `tilted()` helper). The file is 456 lines again; no test of it changed.

New tests:

- `test/waiting_card_test.dart`, group "waiting for the host":
  - "a missed host_back ends with the link: no card and no game when no view comes back" — `host_away` 30 s, the
    link drops, a `connected` snapshot, and no `view_start`: no card, no "The host has left", no arena.
  - "a missed host_back does not outlive the link: a view that still runs comes back alone" — the same drop and
    reconnect with nothing on screen, then `view_start` + a frame: the arena, no card.
  - "a host_away that arrives after the reconnect starts the wait again" — after the reconnect, a new `host_away`
    20 s (clock moved 2 s): the card and "The game goes on if they're back in 20 s"; `host_back` takes it away.
- `test/host_gyro_test.dart` (new): "gyro mode on the host phone sends tilt only in a round" — gyro restored at
  launch sends in controller mode; the picker and the join screen send nothing and the sensors are off; the round
  (pad up) sends; the pause menu and the results send nothing with the sensors off; Resume sends again.
- `test/host_lifecycle_test.dart`: "coming back to the app on the pause menu sends no tilt" — gyro in a round, Start,
  the pause menu, hide + show the app, a 30° lean: no input and no sensors; Resume brings tilt back.

## Self-check (docs/review-rules.md part A)

1. **Every host setup** — TV/PC host and a joined phone: `waiting_card_test.dart`'s three new tests (a phone paired
   to a fake TV host). "Play on this phone": `host_gyro_test.dart` and `host_lifecycle_test.dart`. "Show on this
   device": not affected — the host route sets `gameShownProvider` for both host choices, so the pad is gated by the
   same phase and tilt by the same provider. One build older: a host that sends no `host_back` after a reconnect is
   exactly what `waiting_card_test.dart`'s "a missed host_back ends with the link" covers.
2. **When kept state starts and ends** — `_holds` gains `noRound` when the pad leaves (the phase, or launch already
   away) and `background` when the app hides; each is removed by its own event, the sensors start only when the set
   is empty (`host_gyro_test.dart`'s picker/round/pause/results steps, `host_lifecycle_test.dart`'s resume), and
   nothing runs while both are set. `_away` still ends on `host_back`, a view, an idle client or a reconnect
   (all four in `waiting_card_test.dart`).
3. **How a new state combines with the others** — `noRound` + the pause menu, the results and "Get ready": the
   round's beat keeps the pad up, so tilt sends in `ready` as in `playing` (`host_gyro_test.dart` reads through the
   beat); `background` + `noRound` together: the app's resume starts nothing while the pad is away
   (`host_lifecycle_test.dart`). `Pausable` remains the one owner of the phase.
4. **Stay in the job's folder** — `git status` lists only the files in `allow:` (plus the generated
   `tv_test_app/windows/flutter/generated_*` that Flutter rewrites, never edited or committed by me).
5. **Stop rather than overstep** — nothing outside `allow:` was needed; no stop.

## Not sure

1. **A "hosting" flag read by a pad rule.** `padOnScreenProvider` uses `gameShownProvider`, which the host route sets
   for both host choices. `controls_layer_test.dart` fakes it to mean "a game behind the controls", so tilt now stops
   there while it is true — that is why the test needed the reading above. A name that says "this phone hosts" would
   read better, but renaming a provider used by the controls is outside this job.
2. **Tests must feed the sensors.** A host phone's sensors need a reading within 1.5 s of the pad coming back, so a
   test that waits out the "Get ready" beat has to hold the phone still through it (both gyro tests do). A future
   host-gyro test that pumps the beat without readings sees gyro mode go "unavailable" instead.
3. **`_release`'s re-check** after the first reading is new and not covered by a test of its own: it closes a race
   the old `pause()`/`resume()` pair already had (a hold arriving during `_startSensors` could still start the
   output). I left it in because the race sends tilt outside a round, which is the bug N8 fixes; say if you would
   rather have it as its own test or out.
4. **`tools/review.sh` could not run here.** The sandbox refused to run `tools/review.sh` and `tools/check.sh`
   ("requires approval"), so I ran their steps by hand: `dart format --output=none --set-exit-if-changed . ../tv_test_app ../packages`
   (0 changed), `dart analyze --fatal-infos` ("No issues found!"), `flutter test` in `controller_app` (353 tests).
   On my lines review.sh would print no FAIL: the largest lib file is 398 lines, no added lib line has a numeric
   literal but `0`, and there is no TODO, `print(`, empty `catch`, `dynamic` or cross-layer import. It would print
   the two size NOTEs the files already had.

## Suggestions (not acted on)

- `docs/code-health.md` N2 and N8 can be closed; the pad's phase gate and tilt now share `padOnScreenProvider`.
- The brief's N8 wording says "the round's phase", and `RoundPhase.ready` (the "Get ready" beat) is a round that
  holds its step: the pad is up there, so tilt sends. Say if you meant `playing` only.

## Commit message

```
fix(m12): end a missed host_back with the link; tilt only in a round

A host that accepts a connection is not away, so a host_away whose
host_back went nowhere while the link was down ends with the reconnect;
a host that still runs a round re-sends its view, and a later host_away
starts a new wait.

On a host phone, tilt follows the pad: padOnScreenProvider is on for
every phone that does not host and in a round while it does, and gyro
holds its sensors and output for the background and for a pad away.
```

## Status row

| Build 4 fix-f2 (the phone) | Done ([fix-f2-report.md](fix-f2-report.md)): a missed `host_back` ends with the reconnect (a host that answers is not away; a round it still runs re-sends `view_start`; a later `host_away` starts a new wait), and the host phone's tilt sends only while the round's phase is not `none` (`padOnScreenProvider`, holds for the app's background and the pad's absence; joined phones unchanged). Checks: format, analyze, phone 353 (348 before) | Open: none |

## Delete

- none
