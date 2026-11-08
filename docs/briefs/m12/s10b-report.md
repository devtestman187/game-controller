# M12 s10b — G4 report: **stopped**; the app side needs a file outside `allow:`

**STATUS: stopped.** The job's step 2 ("remove s10a's join-screen exception, `_atJoinScreen`") cannot be
done inside the allow list: the helper is the only code in the `controller_screen.dart` library that uses
two of that file's imports, and `controller_screen.dart` is not in `allow:`. Removing the helper leaves
two analyzer diagnostics in a file I may not edit, so `analyze` fails and the whole job (step 1 included)
cannot land. No code was changed; this report is the only file I wrote (`git diff --stat` lists no
tracked file).

## The blocker, measured

`_atJoinScreen` (`controller_app/lib/src/ui/controller_parts.dart:32, 41-46`) is the only user of

- `GameLayoutMessage` → `import 'package:protocol/protocol.dart';` (`controller_app/lib/src/ui/controller_screen.dart:8`), and
- `mapEquals` → `import 'package:flutter/foundation.dart';` (`controller_screen.dart:4`).

`controller_parts.dart` is a `part of 'controller_screen.dart'`, and a part file cannot carry imports, so
those two lines can only be removed from `controller_screen.dart` itself. I made the removal as a probe
(the `_Controls` gate kept, `_atJoinScreen` gone), ran the check, and reverted the probe
(`git diff --stat` now shows nothing):

```
$ dart analyze --fatal-infos controller_app      # exit 2
warning - lib\src\ui\controller_screen.dart:8:8 - Unused import: 'package:protocol/protocol.dart'. - unused_import
   info - lib\src\ui\controller_screen.dart:4:8 - The import of 'package:flutter/foundation.dart' is unnecessary
         because all of the used elements are also provided by the import of 'package:flutter/material.dart'. - unnecessary_import
$ tools/check.sh analyze                          # on the untouched tree: PASS (10s)
```

The baseline is clean, so both diagnostics are caused by this job alone. `--fatal-infos` makes the
warning and the info fail `analyze`, which is one of the brief's four checks.

## What the job needs

Either

1. `controller_app/lib/src/ui/controller_screen.dart` added to `allow:` for exactly two deleted import
   lines (4 and 8) and nothing else, or
2. Claude lands those two deletions first (they are inert on their own only if `_atJoinScreen` goes in the
   same commit, so this is really the same as 1), or
3. a different home for the pad gate: the pad's "is it built" decision could move out of
   `controller_parts.dart`... it cannot – the widget lives there.

I did not choose any of these myself: the first two break the file list, and the third does not exist.

## What I had ready for the rest (facts checked today, not done)

- **Step 1, party_host** (its own files, no blocker): the own player (`ownPlayerIdProvider`, null on the
  TV) joins with `sideForNewPlayer` on entry and again whenever it is connected and sideless – the tick
  runs every `ControllerMenus.step` = 16 ms (`controller_menus.dart:82`), so one frame after the screen
  opens. `_tick` would call it beside `_simulatedJoin`, filling only a missing side, so a tap's choice
  and a rematch's carried sides are never overridden. `_SidePanel` becomes an `InkWell`/`Material` with the
  own player's row reading `P1 (you)` (the phone host's own player has no nickname: `host_mode_test`
  finds `P1`), and `_Sides` passes `onTap` only when there is an own player, so the TV's panels are not
  tappable at all.
- **The hint**, exactly: `Tap a side to play; press A on a phone to join.` on a device with its own player;
  today's two texts (with and without the keyboard clause) stay for the TV and a joined phone, where the
  sentence would be a lie.
- **`joinLayout`/`joinedLayout`**: after the exception goes they have no caller outside `party_host`
  (`grep`); the guideline "public surface minimal" would make them private in the same diff. That is a
  public-surface change to `party_host`, so it should be named in the brief.
- **App tests that must change with step 2**: `host_mode_test.dart:84-97` and `:276-289`,
  `host_lifecycle_test.dart:124-128`, and `support/host_app.dart`'s `soloRound` (all in `allow:`): the
  `untilShown(faceButtons)` + `pressA` ×2 becomes "wait until the own player is on a side" (the panel
  reads `P1 (you)`) then `tester.tap(find.byKey(const Key('joinStart')))`. Pressing A twice would now start
  the match on the **first** press, since the own player is already joined.
- **party_host tests** (the plan's §6 list): own player on the left on entry; tapping the right moves it
  only (a second phone stays where it is) and the format follows (`1 vs 1` → `A team of 2 on one board`);
  a full side refuses it; `ownPlayerIdProvider` null (a TV) changes nothing (the existing tests stand
  unchanged, plus one that the panels are not tappable and the hint is today's); a player back from away
  re-joins.

## Checks

- `tools/check.sh format analyze host phone tv` on the tree as I leave it (no code changed):
  **format PASS, analyze PASS, host 106 tests PASS, phone 347 tests PASS, tv PASS**.
- `dart analyze --fatal-infos controller_app` with the probe edit (the job's step 2 without step 1):
  **FAIL**, the two lines above. Probe reverted; no other check was run on the probe.

## Questions

1. Please allow `controller_app/lib/src/ui/controller_screen.dart` (two deleted imports) in the next
   s10b brief, or say which of the three ways above you want.
2. If the next brief keeps `joinLayout`/`joinedLayout` public, say so; otherwise I make them private.

## Commit message

```
docs(m12): s10b stopped; the pad gate needs controller_screen.dart

Deleting _atJoinScreen, the only user of protocol's GameLayoutMessage and
of foundation's mapEquals in the controller_screen library, leaves two
analyzer diagnostics in controller_screen.dart, which the job's file list
excludes. The job is otherwise ready: the own player joins by itself and
a tap picks its side, the hint and the tests are planned, and the app's
tests move from A on the pad to the join screen's Start button.
```

## Status row

| Step 10 host touch s10b | **Stopped, no code**: removing `_atJoinScreen` leaves `controller_screen.dart:4` (foundation, `unnecessary_import`) and `:8` (protocol, `unused_import`) unused, and that file is outside the job's `allow:`; `analyze` fails with `--fatal-infos`. Needs `controller_app/lib/src/ui/controller_screen.dart` allowed for the two import deletions. Open: everything else of s10b |

## Delete

- none
