# M12 s10a — G3 report: the round's phase; the host phone's pad only during a round; the bar

Done at G3, the gate the brief names. The plan's job s10a with Claude's answer 2: `RoundPhase` comes from
`Pausable` (a plain `ValueNotifier` in a provider, so a disposing screen may still write it), the host phone's pad
is not built while the phase is `none`, the app lets go of the pad with one neutral input and pauses gyro there, and
the top bar is the full one over the menus on both host routes and the compact one over a round. No file outside
`allow:` was edited; `join_screen*.dart`, `providers/view.dart` and `ui/waiting_card.dart` are untouched.

## Files changed

- `packages/party_host/lib/src/ui/round_phase.dart` — **new**, 82 lines: `RoundPhase {none, ready, playing}`,
  `RoundPhaseSignal extends ValueNotifier<RoundPhase>` with `claim`/`publish`/`release` and a writer token, and
  `roundPhaseProvider` (a `Provider`, disposed with the scope).
- `packages/party_host/lib/src/ui/pause_menu.dart` — 262 → 313 lines: `Pausable` claims the phase in `initState`,
  writes it from one `_publish()` that reads a single `_stopped` getter (`!enabled || _pausedBy != null || hostAway
  || playersAway.isNotEmpty`), and releases it in `dispose`. `_publish()` is called from `initState`,
  `didUpdateWidget`, `_noteHostAway`, `_tick`, `_pause` (both ends) and a `ref.listen(playersAwayProvider, …)` in
  `build`; every write is a post-frame callback, plus `ensureVisualUpdate()` so a tick or an away signal that
  schedules no frame still gets the frame that says it.
- `packages/party_host/lib/party_host.dart` — 39 → 40 lines: `export 'src/ui/round_phase.dart';`.
- `packages/party_host/test/pause_menu_test.dart` — 230 → 304 lines: two tests, below.
- `packages/party_host/test/round_phase_test.dart` — **new**, 32 lines: the writer rules on their own (M10).
- `controller_app/lib/src/ui/controller_parts.dart` — 136 → 172 lines: `_Controls` takes `hosting`, and while it
  hosts it returns a `ValueListenableBuilder<party.RoundPhase>` that builds `_Pad` when the phase is not `none` or
  the own player's buttons are the join screen's; the former pad body moved to a new `_Pad` unchanged in what it
  draws.
- `controller_app/lib/src/ui/controller_top_bar.dart` — 111 → 125 lines: `_TopBar` picks full vs compact from the
  phase while this phone hosts, and from `showsGameProvider` otherwise.
- `controller_app/lib/src/ui/controller_screen.dart` — 203 → 237 lines: `_ControllerScreenState` listens to the
  phase (added in `initState`, removed in `dispose`) and a frame later calls `padProvider.releaseAll()` +
  `gyroProvider.pause()` on `none` and `gyroProvider.resume()` otherwise.
- `controller_app/lib/src/gyro.dart` — 351 → 353 lines: doc comments only (`pause`/`resume` now also name the pad
  going away with the round).
- `controller_app/test/support/host_app.dart` — 188 → 234 lines: `hostPhase`, `soloRound`, `pressStart`, `atFace`.
- `controller_app/test/host_mode_test.dart` — 289 → 398 lines: steps below.
- `controller_app/test/host_lifecycle_test.dart` — 148 → 153 lines: steps below.
- `docs/briefs/m12/s10a-report.md` — this file.

## The phase per screen, as tested

| screen | phase | pad on the host phone | top bar |
| --- | --- | --- | --- |
| the host start sheet's aftermath, the game picker | `none` | not built | full |
| a game's levels (`ShapeRaceScreen`) | `none` | not built | full |
| the join screen | `none` | **built** (the own player joins with A until s10b) | full |
| the round | `playing` | built | compact |
| the pause menu | `none` | not built | full |
| the round after Resume | `playing` | built | compact |
| the away card (a phone away, 1107d B) | `none` | not built | full |
| the host app away | `none` | not built | full |
| the results | `none` | not built | full |
| Play again | `playing` | built | compact |
| "Show on this device" (its picker) | `none` | n/a (no pad, C34) | full |
| a joined phone / no host | untouched (no background, no gate) | today's pad (rule 6) | today's rule |

`ready` is written by nobody yet: s10c fills it.

## Old → new, test by test

`controller_app/test/host_mode_test.dart`:

1. "a phone hosting plays its own game…", the picker: deleted the pad steps; the card and the levels are
   `tester.tap(find.byKey(const Key('pickShapeRace')))` and `tester.tap(find.byKey(const Key('random-easy')))`,
   each followed by `untilShown` (the host's menus read the tap and the puzzle library loads, s9c). Added over the picker: no
   `ControlsLayer`, no `faceButtons`, `hostPhase == none`, `BarModes`, `Settings`, `Diagnostics` present and no
   `modeMenu`/`connectionDot` (was: the compact-bar expectations, `host_mode_test:50-54`).
2. The join screen: added `untilShown(ControlsLayer)` before the two `pressA`s (the pad only returns once the join
   screen has sent its layout), `ControlsLayer` rect `(0, 52, 852, 341)`, `BarModes` and `hostPhase == none` —
   the pad stays (the brief's option), and the reason is written beside it.
3. The round: added `hostPhase == playing`; the compact-bar checks now stand only here: no `BarModes`, a
   `modeMenu`, `Settings`, `Diagnostics`, the dot, and the `hostChip` right of the dot and at least as tall as
   Settings (kept from C14). The `'A Pick up'` label wait is unchanged.
4. "Show on this device" (`host_mode_test:128-149`): the bar is now the full one over its picker too — added
   `playerBadge`, `Diagnostics`, the `hostChip` with `'Hosting · '` and the code, and "no `modeMenu`, no
   `connectionDot`" (was: no modes, no Settings, nothing said about the chip).
5. The compact-bar-over-the-round test is replaced by "the host route gets the full bar over its menus
   (m12-host-touch rule 1)": `playerBadge`, `BarModes`, `Settings`, `Diagnostics`, `hostChip` with `'Hosting · '`,
   and no `modeMenu`/`connectionDot` (was: `modeMenu`, `connectionDot`, compact chip).
6. "Stop hosting in the chip…": the comment now says the chip over the picker opens the same menu as the compact
   one over a round; the steps are unchanged.
7. "the system back on the results goes to the picker…": the picker and the levels are taps (`pickShapeRace`,
   `random-easy`), the join keeps `untilShown(faceButtons)` + `pressA` ×2, and the results test now waits for
   `hostPhase == none`, then `settle`, then expects no `faceButtons` and `BarModes` (was: no phase, a compact
   bar).
8. **New** "Start on the pad pauses the round: the menu is touch, Resume brings the pad back": `soloRound`, Start,
   phase `none`, no `faceButtons`, `BarModes`, no `modeMenu`; Resume → phase `playing`, `pauseMenu` gone,
   `faceButtons` back, no `BarModes`.
9. **New** "a pad hidden under a held finger lets go of it with one neutral input": `ownClientProvider` is pointed
   at the test app's fake client, a finger down on A sends `'A 0,0'`; Start through the real client pauses the
   round; the fake then sees exactly `'A 0,0'`, `'0,0'` (one neutral input), `padProvider.isNeutral` and no
   `faceButtons`; after Resume the finger's release sends nothing more.

`controller_app/test/host_lifecycle_test.dart`:

1. "hiding the app pauses the round…" (`:63-65`): after Resume the bar is the full one — `BarModes` and the
   `hostChip` (was: `modeMenu` and the compact chip); `hostChip` was already expected.
2. "a round hidden longer than the grace is abandoned…": the picker and the levels are taps, the join keeps
   `untilShown(faceButtons)` + `pressA` ×2 (was: pad steps through all three screens).

`packages/party_host/test/pause_menu_test.dart` (added, the plan's host-side list):

1. "the round's phase is none on the menus and playing in a round, and after Resume": `none` on the home, the
   picker and the join screen; `playing` in the round; `none` with the pause menu up; `playing` after Resume;
   `none` on the results; `playing` after Play again (the new round's screen claimed the phase before the results
   were disposed, M10).
2. "a round that waits for a phone away or for the host is none": the away card → `none`, the phone back →
   `playing`, `hostAwayProvider` true → `none`, false → `playing` (1107d B's pauses reach the phase).

`packages/party_host/test/round_phase_test.dart` (new): only the round that claimed the phase last speaks for it —
the old screen's `publish` and `release` say nothing once a new round claimed, and `release` clears a frame later.

## Decisions worth naming

- **A deferred write.** Every phase change goes out in a post-frame callback: the results end a round during a
  build, and a `ValueListenableBuilder` rebuilt right there would `markNeedsBuild` a locked tree. `ensureVisualUpdate()`
  follows each one, because a tick or an away signal need not schedule a frame on its own. The app's own reaction
  (`releaseAll` + gyro) is deferred the same way.
- **The writer token** (`claim`/`publish`/`release`): Play again puts the new screen up before the old one is
  disposed (M10), and the old one keeps ticking until then. `claim` takes the phase, `publish` from anyone else is
  dropped, and `release` only clears it if nothing claimed since—and only if the signal is still alive.
- **The join screen keeps its pad**, through a bridge in `_Controls` and not in `join_screen*.dart` (s10b's file):
  while hosting, the pad is also built when `gameLayoutProvider`'s labels equal `party.joinLayout.labels` or
  `party.joinedLayout.labels`. Without it the own player could not join at all (A is its only way on). s10b
  replaces this with taps; the comparison should go then.

## Checks

`tools/check.sh format analyze host phone` → PASS, all four: format, analyze, host **106 tests**, phone **341
tests**. Before this job: host **103**, phone **339** (+2 phase tests and +1 writer-rule test in `party_host`, +2
app tests). `tools/review.sh` → **0 fail, 2 note** (two size notes on files at 313 and 353 lines, both under the
400 limit).

Tests failed first, as the brief asks: the new phase expectations failed before `round_phase.dart` existed, the pad
and bar expectations failed before the gate and the bar switch, and the neutral-input test failed until the app
released the pad on the phase change.

## Not sure

1. The join-screen bridge above is a stopgap that s10b must remove; the comment in `_Controls` says so.
2. `tools/review.sh` also reports nothing on my lines, but `git status` shows modified generated files I did not
   edit — `tv_test_app/windows/flutter/generated_plugin_registrant.cc`, its `.h` and `generated_plugins.cmake`
   (Flutter's Windows build rewrites them). Left alone, not committed by me.
3. The phase is `none` while the awaiting card or the away card stands over a *waiting* phone: only the host
   phone's screens read it, so nothing else changed (rule 6).
4. Gyro is paused for the whole `none` phase, including the join screen (where the pad is kept), because the pad
   there has no stick to send from; it resumes with the round.

## Commit message

```
feat(m12): the round's phase, and a host phone's pad only in a round

Pausable claims a RoundPhaseSignal in a Provider and writes it after
each frame: none on the menus, on the pause menu, on the away card and
on the results, playing in a round, and a screen being replaced says
nothing (M10). The host phone builds its pad only then; the app lets go
of every button with one neutral input and pauses gyro, and the top bar
is the full one over its menus, on both host routes, and compact over
the round. The join screen keeps its pad until s10b.
```

## Status row

| Step 10 host touch s10a | Done ([s10a-report.md](s10a-report.md)): `RoundPhase {none, ready, playing}` from `Pausable` (written a frame later, a writer token for Play again), the host phone's pad built only in a round with one neutral input and gyro paused, the full bar over its menus on both host routes and the compact one over the round; the join screen keeps its pad until s10b. Checks: format, analyze, host 106, phone 341, review 0 fail | Open: none |

## Delete

- none
