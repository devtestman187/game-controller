# M12 s10b — G4 report: the host's own player joins by itself; a tap picks its side; no pad on the join screen

**STATUS: done**, at G4, the gate the brief names. This replaces the first run's stopped report (that run
stopped because `controller_screen.dart` was outside `allow:`; the brief now allows it for the two unused
imports). Done in this run:

1. The host phone's own player (`ownPlayerIdProvider`, null on the TV) takes a side through
   `sideForNewPlayer` the moment it is here and sideless (a return from away re-joins), each side panel is a
   touch target that moves only the own player there when that side has room, the panel marks it "(you)", and
   the hint is the brief's sentence.
2. s10a's join-screen pad exception (`_atJoinScreen`) is gone: the host phone shows no pad on the join screen
   either, and the screen's own Start button (a `HostButton`, `Key('joinStart')`) begins the round.
3. `controller_screen.dart` lost its now-unused `foundation.dart` and `protocol.dart` imports, as the brief
   allows. Nothing else in that file changed.

## The hint's exact text

On a device with its own player (the phone host):

```
Tap a side to play; press A on a phone to join.
```

The TV and a joined phone keep today's two texts (with and without the keyboard clause):

```
Press A on your phone to join, then left or right to pick a side. Then A or Start begins.
Press A on your phone to join (Space on the keyboard), then left or right to pick a side. Then A or Start begins.
```

## Files changed

- `packages/party_host/lib/src/ui/join_screen.dart` — 305 → 344 lines. New `_ownJoin(players)` called from
  `_tick` right after `_prune`: the own player takes `sideForNewPlayer(_teams)` whenever it is connected (in
  the non-away player list) and has no side, and only a missing side is filled, so a tap's choice and a
  rematch's carried sides are never overridden. New `_pickSide(id, side)`: a tap moves the own player when the
  side has room (`maxPerSide` = 2), nothing else. New `static _hint(...)` picks the brief's sentence when
  there is an own player here. `build` reads `ownPlayerIdProvider` and passes `ownHere` (the own ID only while
  it is in the player list) plus `onPick` to `_Sides`; the class doc gains the rule-5 sentence.
- `packages/party_host/lib/src/ui/join_screen_widgets.dart` — 140 → 164 lines. `_SidePanel` takes
  `ownPlayerId` and a nullable `onTap`, draws its background as `Material(color: surfaceContainer,
  borderRadius: 16, clipBehavior: antiAlias)` + `InkWell` (same look, a touch target), and appends `" (you)"`
  to the own player's row (`'${p.label}${p.simulated ? ' (simulated)' : ''}${p.id == ownPlayerId ? ' (you)' :
  ''}'`). `_Sides` takes `ownPlayerId`/`onPick` (both nullable) and gives a panel a tap only when `onPick` is
  not null: a TV's panels have no `InkWell` callback at all.
- `packages/party_host/test/join_screen_test.dart` — 153 → 281 lines: a top-level `sideText` finder and a new
  group of five tests (below).
- `controller_app/lib/src/ui/controller_parts.dart` — 172 → 162 lines: `_Controls` no longer builds the pad
  for the join screen (`_atJoinScreen` and its doc deleted); the gate is the round's phase alone, so the host
  phone has no pad on any menu, the join screen included (rule 1).
- `controller_app/lib/src/ui/controller_screen.dart` — 237 → 235 lines: two imports deleted
  (`package:flutter/foundation.dart`, `package:protocol/protocol.dart`), the only user of both being the
  deleted `_atJoinScreen`. Nothing else.
- `controller_app/test/host_mode_test.dart` — 398 → 399 lines: the two join-screen steps now tap Start (below).
- `controller_app/test/host_lifecycle_test.dart` — 153 → 153 lines: the same change in the abandoned-round test.
- `controller_app/test/support/host_app.dart` — 234 → 237 lines: new `ownPlayerOn(side)` finder; `soloRound`
  waits for the own player on the left and taps `joinStart`; doc comments updated.
- `docs/briefs/m12/s10b-report.md` — this file.

## Old → new, test by test

`packages/party_host/test/join_screen_test.dart`, five new tests (`ownPlayerIdProvider` overridden with
`'p1'`, the fake host's connected iPhone):

1. **"the own player is on the left on entry, marked, and Start begins the match"**: on entry the panel
   shows `P1 iPhone 3F1C (you)` on the left and not on the right, no `notJoined` row, `joinFormat`
   `1 player`, hint `Tap a side to play; press A on a phone to join.`; tapping `joinStart` shows
   `PuzzleScreen`. Computed: `sideForNewPlayer({})` = left (a tie goes left); one player on one side is
   `MatchFormat.solo` → `formatName` `1 player`.
2. **"a tap on a side moves only the own player there, and the format follows"**: p3 (number 2) joins with A
   → right (left = 1, right = 0 → the fewer side), format `1 vs 1` (`oneVsOne`). Tap `side-right`: the own
   player is right, `P2 Phone 2` stays right, left is empty, format `A team of 2 on one board`
   (`MatchFormat.team`, 2 players on one side).
3. **"a full side refuses the own player's tap"**: p3 joins → right; p4 (number 3) joins → left (1–1 tie);
   p5 (number 4) joins → right (left is full). Sides: left `P1 (you)` + `P3 Phone 3`, right `P2 Phone 2` +
   `P4 Phone 4`, format `2 vs 2` (`twoVsTwo`). Tap `side-right` (2 taken, `maxPerSide` 2): the own player
   stays left and the format stays `2 vs 2`.
4. **"without an own player the sides are not tappable and the hint is unchanged"** (the TV): no override, so
   `ownPlayerIdProvider` is null; A joins p1 to the left, `P1 iPhone 3F1C` with no "(you)", the hint is
   today's second text, and a tap on `side-right` changes nothing (`1 player`).
5. **"the own player back from away joins a side again"**: on the left on entry; `setAway('p1', true)` drops
   its side (1107d's rule, `Nobody has joined yet.`); `setAway('p1', false)` puts it back on the left.

`controller_app/test/host_mode_test.dart`:

1. **"a phone hosting plays its own game…"**, step 6 — old: `untilShown(faceButtons)` on the join screen,
   `ControlsLayer` rect `(0, 52, 852, 341)`, `pressA` ×2. New: `settle`, `JoinScreen` rect
   `(0, 0, 852, 393)`, **no** `ControlsLayer` and **no** `faceButtons`, the hint text above,
   `ownPlayerOn('left')`, then `tester.tap(Key('joinStart'))`. The `puzzle.teams` expectations are unchanged
   (own player id → `left`).
2. **"the system back on the results…"** — old: `untilShown(faceButtons)` + `pressA` ×2. New:
   `ownPlayerOn('left')` + tap `joinStart`.

`controller_app/test/host_lifecycle_test.dart`:

1. **"a round hidden longer than the grace is abandoned…"** — old: `untilShown(faceButtons)` + `pressA` ×2.
   New: `ownPlayerOn('left')` + tap `joinStart`; the comment now names rules 1 and 5.

`controller_app/test/support/host_app.dart`:

1. **new** `ownPlayerOn(String side)`: the "(you)" text inside a side's panel.
2. **`soloRound`** — old: `untilShown(faceButtons)` + `pressA` ×2. New: `ownPlayerOn('left')` + tap
   `joinStart` (three host-mode tests use it).

Tests failed first, as the brief asks: the four own-player party_host tests failed on the run before
`_ownJoin`/`_pickSide`/`(you)` existed (0 widgets with the "(you)" text, no tap handler), and the app's pad
assertions fail against the old code, where `host_mode_test` itself expected a `ControlsLayer` on the join
screen (it had one). The first new fail of the full-side test was my own expectation, not the code: I had the
players on the wrong sides (right = `P2`, left = `P3`/`P4`); the computed values above are the corrected ones.

## Checks (all on the tree I leave)

```
$ tools/check.sh format analyze host phone tv
PASS  format      (2s)
PASS  analyze     (8s)
PASS  host        (111 tests, 13s)
PASS  phone       (347 tests, 21s)
PASS  tv          (11s)
All checks passed (56s)
$ tools/review.sh
review: 0 fail, 8 note     # two size notes and six layout-literal notes, all pre-existing lines
```

- **Test counts:** host **106 → 111** (+5 new tests in `join_screen_test.dart`); phone **347 → 347** (no
  test added or removed, only steps rewritten); tv **28 passed, 1 skipped** (unchanged).
- `tv_test_app` alone: `+28 ~1: All tests passed!`.
- `join_screen.dart` 344 lines (limit 400); `join_screen_widgets.dart` 164; no file over the limit.

## Not sure / questions

1. **`joinLayout`/`joinedLayout`** are public in `join_screen.dart` and now have no caller outside
   `party_host` (their only outside use was the deleted `_atJoinScreen`). The first run asked whether to make
   them private; this brief did not answer, and its note allows `controller_screen.dart` "for the two unused
   imports only", so I left them public. Say the word and a one-line later job makes them private.
2. **The mark's wording** is `" (you)"` on the row (`P1 iPhone 3F1C (you)`); the brief only says "the panel
   marks the own player". The app's own player does have a nickname (its device name, e.g.
   `Controller 983A`), so the host phone's panel reads `P1 Controller 983A (you)` — the first run's report
   said it had none, which was wrong.
3. **The panel's look** is unchanged apart from `Material` + `InkWell` (same `surfaceContainer`, radius 16,
   anti-aliased clip). A full side still shows its ripple when tapped and does nothing; I chose to keep the
   panel a touch target whenever the own player is here, and to refuse inside `_pickSide`, so there is one
   place that decides room. If you would rather a full side not react at all, that is a one-line change.
4. `git status` also lists `tv_test_app/windows/flutter/generated_plugin_registrant.{cc,h}` and
   `generated_plugins.cmake` as modified: Flutter's Windows build rewrites them; I did not edit them (s10a's
   report notes the same).

## Commit message

```
feat(m12): the host phone's own player joins by itself; a tap picks its side

The own player takes a side on entry with sideForNewPlayer and again
whenever it is here and sideless, so a phone back from away re-joins. A
tap on a side panel moves only the own player there when the side has
room, the panel marks it "(you)", and the hint says "Tap a side to play;
press A on a phone to join". s10a's join-screen pad exception goes: the
host phone shows no pad on the join screen either, and its tests begin
the round with the screen's Start. The TV and joined phones are unchanged.
```

## Status row

| Step 10 host touch s10b | Done ([s10b-report.md](s10b-report.md)): the host phone's own player joins by itself on entry and whenever it is back and sideless, a tap on a side moves only it when there is room, the panel marks it "(you)" and the hint is "Tap a side to play; press A on a phone to join"; s10a's join-screen pad exception is gone (no pad on the join screen) and the app's tests start the round with the screen's Start. Checks: format, analyze, host 106→111, phone 347, tv 28+1 skipped, review 0 fail | Open: none (s10c is next) |

## Delete

- none
