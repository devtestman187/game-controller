# M12 bug 1108a — G4 report: "Show on this device" has no player of its own

Done at G4, the gate the brief names. The cause was the one in the brief: `PhoneHost.start()` always paired this
phone's own player on the in-process link, and the sheet's choice was applied after it, so in "Show on this device"
that player took P1, could never take a side (no pad), and blocked the phone from playing. Now the choice is made
before the host is built and handed to it: a phone that shows the game on itself builds no link, no client and
pairs nobody, and its own-client seam stays null (rule A). "Play on this phone" is untouched (rule C). No file
outside `allow:` was edited; `packages/party_host` needed no change at all, because its join screen and puzzle screen
already key off `shareView` and a null `ownPlayerIdProvider`.

## Files changed

- `controller_app/lib/src/host/phone_host.dart` (160 lines) — `final bool playsHere`; `listener` and `client` are now
  nullable and are built only when the phone plays here; `PhoneHost.live(inputs, {required playsHere, nowMs})` takes
  the choice, and `PhoneHostBuilder` (the tests' seam) with it. `start()` pairs a player only when there is a client;
  `dispose()` releases the client and the listener only when they exist. New `bool get started`: true once `start()`
  has finished (server listening, addresses read, advertised) — a host that pairs nobody has no player to wait for,
  and waiting on `state.host.running` returns before the service has created its address timer (Question 3).
- `controller_app/lib/src/host/hosting.dart` (99 lines) — `start({required bool playsHere})` (rule D): the builder
  gets the choice, `host.service.shareView = playsHere` is set before `host.start()` rather than after, and
  `ownClientProvider` is set only when the host has a client, so in Show mode it stays null (rule A).
- `controller_app/lib/src/host/host_overrides.dart` (76 lines) — `party.ownPlayerIdProvider` is null while the host
  shows the game on this device (rule A); unchanged for the TV, for a fresh app and for "Play on this phone".
- `controller_app/lib/src/ui/connect_panels.dart` (300 lines) — the sheet's choice goes into the start call
  (`hosting.start(playsHere: choice == HostChoice.onPhone)`); the separate `shareView` line is gone.
- `controller_app/test/support/host_app.dart` (281 lines) — `ownClientOf(host)` (fails the test with a clear message
  when a host has no own player), `hostReady` reads the own client through it, `enterHostMode` waits for
  `host.started` in Show mode and for the own player in Play mode, and new `stopHosting(tester, host)` stops a host
  from its chip as a player does.
- `controller_app/test/host_own_player_test.dart` (**new**, 133 lines) — the four tests below.
- `controller_app/test/hosting_test.dart` (185 lines) — the new unit test below; `hosting.start()` →
  `hosting.start(playsHere: true)` (three places) and `host.client.…` → `ownClientOf(host).…`.
- `controller_app/test/host_mode_test.dart` (458 lines) — `host.client.…` → `ownClientOf(host).…` (six places); the
  existing Show-mode test now also asserts the bar has no player badge and no "P1" text (rule B).
- `controller_app/test/host_lifecycle_test.dart` (239 lines) — same substitution (four places), and the builder
  override the presence test installs takes the new `{required playsHere}` parameter.
- `controller_app/test/host_gyro_test.dart` (127 lines) — same substitution (two places).
- `docs/briefs/m12/bug-1108a-fix-report.md` — this report.

## Rule A: what "Show on this device" pairs now

- Nothing is on the in-process link: `PhoneHost.live` builds no `InProcessListener` and no `ControllerClient`, so
  `host.listener` and `host.client` are null and the server is started with `inProcess: null`.
- `ownClientProvider` stays null, so `clientProvider` is the TV client (idle, silent) and `ownPlayerIdProvider` is
  null: the join screen's own-player line and its tap-a-side are off, and the puzzle screen highlights no own side.
- The first phone to join takes P1: `ServerGameHost.addLocalPlayer` and a pairing phone use the same "lowest free
  number" table, and nothing of this phone's own is in it. Test 1 joins one with A, sees it on the left, and starts
  the match with it.
- The host still has its presence and its away state: hiding the phone pauses a round and abandons it after the
  grace, exactly as when it plays here (unchanged).

## Rule B: the bar, before and after

| Where | Before | After |
| --- | --- | --- |
| Full bar (menus, picker, join screen) | "P1" badge + `Hosting · 3609` chip + Diagnostics (the brief's picture) | the chip with the code and its menu (address, Stop hosting) + Diagnostics; no badge |
| Compact bar (the round) | dot, chip, Diagnostics (the chip is compact there, so no badge either way) | the same; the dot now shows the TV client's idle grey instead of the own player's connected green (Question 1) |
| Join screen | "Not joined: P1 iPhone 6D8B" and "Tap a side to play; press A on a phone to join." | no "Not joined" line, no "(you)", sides empty, and "Press A on your phone to join, then left or right to pick a side. Then A or Start begins." |

The badge is drawn from `clientStateProvider.player`, which follows `clientProvider`: with no own client there is no
player number, so nothing else had to change to take it away.

## Rule D: the choice before the start

`HostChoice` stays out of `hosting.dart`: `HostingNotifier.start({required bool playsHere})` takes the meaning, the
caller (`connect_panels.dart`) decides it from the sheet, and the builder, the host's fields and `shareView` all come
from it before `host.start()` runs. No player is paired and then dropped; nothing reads `shareView` half-set.

## Rule E: every reader of the own client and `ownPlayerIdProvider`

`clientProvider` = `ownClientProvider ?? tvClientProvider`, so with the seam null every reader gets the TV client,
which the app has not connected while it hosts (discovery is stopped): it is `idle` and silent.

| Reader | What it does in Show mode |
| --- | --- |
| `hosting.dart` `start` | sets no own client (only a host that plays here has one) |
| `providers/connection.dart` `clientProvider` | falls back to the TV client |
| `ClientStateNotifier` | follows the TV client: `idle`, no player, so no badge anywhere |
| `ConnectionActions` | not reached: its Connect screen is behind the host route |
| `ui/bar_connection.dart` `BarConnection`, `CompactConnection` | no badge; the dot shows the TV's idle grey |
| `ui/host_chip.dart` | no badge; the chip and its menu are unchanged |
| `providers/device.dart` `sessionMonitorProvider` | samples this phone's battery/heat; the input rate it reports is the TV client's (0) |
| `providers/metrics.dart` `phoneMetricsProvider` | records nothing: the client is not connected, and no pad is drawn |
| `providers/pad.dart` | never sends: "Show on this device" draws no pad (`hostPadProvider` passes no rects) |
| `providers/view.dart` (view active, host wait, abandoned notice) | all follow the silent TV client: no view is requested, no notice shows |
| `providers/game_feedback.dart` (`sendRating`, the prompt notifiers) | no prompt: nothing asks the host for a rating for a player it has not got |
| `ui/controller_screen.dart` (`resume()` on resume, the waiting card's clock) | resumes an idle client (no-op) and reads its clock, which no host screen shows |
| `ui/diagnostics_screen.dart` | shows the TV client's counters (no states sent) beside the host's own numbers |
| `ui/joined_view.dart` | no view (`shareView` false), so not built |
| `party.ownPlayerIdProvider` (the app's override) | null |
| `packages/party_host` `ui/join_screen.dart` `_ownPlayer` | null: no "(you)", no own-player not-joined line, no tap-a-side hint |
| `packages/party_host` `ui/puzzle_screen.dart` `playerId` | null: no own side; a tablet still draws the whole match (`wholeMatchProvider`) |

## Tests, each failing first

The four widget tests and the unit test were run against the code before the fix (tests only, old lib) and failed on
the bug's own symptom — `expect(host.client, isNull)` gave `Expected: null Actual: <Instance of 'ControllerClient'>`,
the own player that show mode must not have. The Play-mode test passed before and after, as rule C wants.

| Test | Shows |
| --- | --- |
| `host_own_player_test.dart` '"Show on this device" pairs no player of its own, and the first phone to join is P1' | rule A: null client and listener, no controllers and no players, no badge, chip and Diagnostics there; the join screen has no "Not joined", no "(you)", no tap-a-side; a joining phone is listed as "Not joined: P1 Ada", takes left with A, and Start begins the match with it |
| `host_own_player_test.dart` '"Play on this phone" pairs its own player, and it joins P1 by itself' | rule C: the own client is connected, one local controller, player 1, the badge is there, and it is on the left by itself |
| `host_own_player_test.dart` 'stopping a "Show on this device" host and playing here pairs a player again' | Show → Play: the own client connects, player 1, badge back |
| `host_own_player_test.dart` 'stopping a host that played here and showing on this device pairs no player' | Play → Show: no client, no listener, no connected controller (the old pairing is only remembered, as any dropped phone is), no players, no badge, and the first phone to join is still P1 |
| `hosting_test.dart` '"Show on this device" pairs no own player, so the first phone to join is P1' | the same without a widget: the seam null, `clientProvider` the TV client, `ownPlayerIdProvider` null, `shareView` false, no controllers or players, `addLocalPlayer` gives 1; then Play mode pairs it again |
| `host_mode_test.dart` '"Show on this device" shows the game alone: no pad, no modes, no Settings' (existing) | a guard from this job on: the bar has no `playerBadge` and no "P1" text |

Old → new in existing tests: `hosting.start()` → `hosting.start(playsHere: true)`; `host.client.…` →
`ownClientOf(host).…` in four files (the seam is nullable now); the lifecycle test's builder override takes
`{required playsHere}`. No expectation was weakened.

## Test counts, before and after

Measured with `tools/check.sh` on this machine:

| Check | Before | After |
| --- | --- | --- |
| host (`party_host`) | 132 | 132 (no change needed there) |
| phone (`controller_app`) | 370 | **375** (four own-player tests, one hosting test) |
| tv | (the check prints no count) | unchanged |
| format, analyze | PASS | PASS |

## Checks run

- `tools/check.sh format analyze host phone tv` — PASS, all five (format 2 s, analyze 10 s, host 132 in 17 s, phone
  375 in 30 s, tv 9 s).
- `tools/review.sh` — `review: 0 fail, 0 note` on this job's lines. `connect_panels.dart` was 301 lines after the
  change (the aim is 300), so a comment was tightened and it is 300 now.
- One thing to know: `git status` lists `tv_test_app/windows/flutter/generated_plugin_registrant.cc`, `.h` and
  `generated_plugins.cmake` as modified, but `git diff --numstat` reports no changed lines — a line-ending / mtime
  change made by a Flutter tool run, not by this job. They are outside `allow:` and were not edited here.

## Questions

1. The compact bar's dot in Show mode. It follows the screens' client, which is now the TV client, so over a round it
   shows idle grey where it showed the own player's connected green. Nothing in rules A–B says what that dot means on
   a phone that is the screen. Hide it while hosting, leave it as the TV's state, or give it the host's own link?
   Not decided here.
2. The screen may sleep while waiting for the first phone. `keepAwakeProvider` follows the host's connected
   controllers; in Show mode nobody is connected until a phone joins, where before this fix the own player always
   was. A phone left on the join screen could dim. Same for the TV, so it may be the wanted behaviour — your call.
3. `PhoneHost.started` was added for the tests' Show-mode wait. Waiting on `state.host.running` returns too early
   (`HostServer.start()` sets it before `LiveHostService.start()` reads the addresses and creates its 10 s timer), and
   disposing then leaks that timer ("A Timer is still pending even after the widget tree was disposed"). Should
   `dispose()` instead wait for an in-flight `start()`? That would also fix the same race in Play mode — a player who
   stops within a few ms of hosting — and would remove the new getter. Not done: it is a change to the host's
   lifecycle, beyond this bug.
4. After a "Play on this phone" host stops, the next "Show on this device" host lists this phone's old pairing in
   Diagnostics as a remembered, disconnected controller (a pairing the host keeps, as it keeps any phone's). It is
   not a player, holds no number (the first joiner is P1, asserted), and shows no badge. Should Show mode start from
   an empty pairing book, or is being a host that remembers phones the right thing? Not changed.
5. Suggestion for `docs/project-notes.md` (not in `allow:`): a widget test that disposes a host must not stop it
   before `PhoneHost.start()` has finished — wait for `host.started`, not `state.host.running`.

## Self-check (review rules, part A)

1. **Every host setup.** TV/PC: untouched (no `party_host` change, 132 tests pass); phone "Play on this phone": the
   own player pairs and auto-joins — `host_own_player_test` '"Play on this phone" pairs its own player, and it joins
   P1 by itself' and `hosting_test`'s first test; "Show on this device": no own player, the first joiner is P1 —
   `host_own_player_test`'s first and fourth tests and `hosting_test`'s new one; a joined phone: a pairing player is
   P1 and takes a side — `host_own_player_test`'s first test (addLocalPlayer is the same numbering and side path a
   pairing phone uses);
   a build one older: no protocol message or field changed, so nothing to test.
2. **When kept state starts and ends.** `playsHere` and the null seams are set once per host and end when `stop()`
   disposes it; `_started` turns true once `start()` finishes and dies with the host; the presence/away state still
   starts with `start()` and ends with `dispose()` — `host_own_player_test`'s two stop-and-host-again tests walk both
   host lifetimes, and `host_lifecycle_test` still walks hide/return and the grace on a Play-mode host.
3. **How a new state combines with the others.** Show mode adds no new pause, wait or input state: a round still
   belongs to `Pausable`/`RoundPhase`, the host's away state is unchanged, and the pad is absent exactly as before
   (C34). What could combine — a round, a pause and a phone joining — is `host_own_player_test`'s first test
   (a joining phone, a side, Start, the round up) and `host_mode_test`'s '"Show on this device" shows the game
   alone: no pad, no modes, no Settings' (no pad, no Settings, the bar's modes gone).
4. **Stay in the job's folder.** Every file above is under `controller_app/lib`, `controller_app/test` or is this
   report; `packages/party_host` was read but not edited.
5. **Stop rather than overstep.** Done at G4 only. The four decisions above (the dot, keep-awake, `started` versus a
   disposing `dispose()`, the remembered pairing) are reported rather than taken, since each changes behaviour the
   brief did not name.

## Commit message

Pair no own player when the phone only shows the game

- "Show on this device" now makes the phone the screen: it builds no in-process link and no client, so no player of
  its own is paired, listed or left unable to join (m12 bug 1108a, rule A).
- The sheet's choice is passed into `HostingNotifier.start` and into the host before it starts, so no player is
  paired and then dropped (rule D); `shareView` is set before the server runs.
- The bar has no player badge in that mode, only the chip with the code and Diagnostics (rule B); "Play on this
  phone" is unchanged (rule C).
- `ownPlayerIdProvider` is null while the host shows the game, so the join screen has no "(you)" and no tap-a-side.
- `PhoneHost.client` and `listener` are nullable, with `ownClientOf` in the tests; a new `started` flag lets a
  Show-mode test wait for the host instead of a player.

## Status row

Bug 1108a fixed at G4: "Show on this device" pairs no own player (no link, no client, no badge, first joiner is P1)
and "Play on this phone" is unchanged, with five new tests and the whole suite green. Open: what the compact bar's
dot and keep-awake should do on a phone that is only the screen, and whether `dispose()` should wait for a start in
flight (Questions 1–3).

## Delete

- none
