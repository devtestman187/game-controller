# M12 step 1b, G4 report: review script, controls cycle, home screen split, shared shortcuts

STATUS: done. `tools/check.sh format analyze host tv` passes.

## Files changed

Production:

- `tools/review.sh` (new, 297 lines) — the coding guidelines' mechanical checks over the changed `.dart` files, one
  line per finding, `review: n fail, m note` at the end; exit 0/1/2. Details below.
- `docs/dev-tools.md` — a `tools/review.sh` row in the table, and a "tools/review.sh" section after `check.sh`'s
  (usage, output sample, scope, the ten checks, exit codes, "it doesn't replace the review").
- `packages/party_host/lib/src/controls.dart` (new, 49 lines) — `Controls` (moved unchanged from
  `ui/controller_menus.dart`), `ControlsClaims` (`ClaimHandle claim(Controls)`, `Controls get current`) and
  `ClaimHandle` (`set controls`, `void release()`); no Flutter import, only `package:protocol`.
- `packages/party_host/lib/src/ui/controller_menus.dart` — `Controls`/`ControlsClaims`/`_Claim` left for
  `controls.dart`; `ControlsClaim` now holds a `ClaimHandle` (`claim` in `initState`, `controls =` in
  `didUpdateWidget`, `release()` in `dispose`); `menuLayout` and `ControllerMenus` unchanged.
- `packages/party_host/lib/src/providers.dart` — imports `controls.dart` instead of `ui/controller_menus.dart`; the
  state layer no longer imports UI. Nothing else changed.
- `packages/party_host/lib/src/ui/host_shortcuts.dart` (new, 12 lines) — `const hostActivateShortcuts`
  (select, Enter, gamepad A → `ActivateIntent`) with the doc comment.
- `packages/party_host/lib/party_host.dart` — `export 'src/controls.dart' show Controls, ControlsClaims;` (`ClaimHandle`
  is not exported: nothing outside the package makes a claim by hand) and `export 'src/ui/host_shortcuts.dart';`.
- `packages/party_host/lib/src/ui/game_screen.dart`, `join_screen.dart`, `pause_menu.dart`, `puzzle_screen.dart` —
  one added line each, `import '../controls.dart';` (`Controls` and `ControlsClaim` used to come from the same file).
- `packages/party_host/test/support/host_harness.dart` — the harness's `Shortcuts` uses `hostActivateShortcuts`; its
  copy of the map and the duplicated comment are gone (and the now unused `flutter/services.dart` import).
- `tv_test_app/lib/main.dart` — `TvTestApp` uses `hostActivateShortcuts`; its copy and comment are gone; imports
  `src/ui/home/home_screen.dart`.
- `tv_test_app/lib/src/ui/home/home_screen.dart` (new, 257) — `HomeScreen`, `Header` plus `_WideHome`, `_NarrowHome`
  (the two layouts), `_HeaderTitle` and `_HeaderButtons`; `wideWidth`/`wideHeight`, `rowWidth`/`compactWidth` are
  named, documented constants of the numbers that were bare (720/420, 760/1100).
- `tv_test_app/lib/src/ui/home/panel.dart` (new, 54) — `Panel`.
- `tv_test_app/lib/src/ui/home/pairing_panel.dart` (new, 280) — `PairingPanel`, `SoundLine`, `AdvertiseStatus` and
  the extracted `_PairingCode`, `_AddressList`, `_FirewallNote`, `_SiteUrl`, `_PairingButtons`, `_SimList`;
  `_clientStatusLabel` stays private here. `PairingPanel` is now a `StatelessWidget` (the service read moved into
  `_PairingButtons`, so no `ref` is passed and unused).
- `tv_test_app/lib/src/ui/home/controllers_panel.dart` (new, 192) — `ControllersPanel`, `ControllerTile` and the
  extracted `_ControllerDetails`, `_ControllerLatency`; `_platformIcon` (an `IconData`, not a widget).
- `tv_test_app/lib/src/ui/home/log_panel.dart` (new, 33) — `LogPanel` (`saveLog` still comes from
  `../latency_screen.dart`, as before).
- `tv_test_app/lib/src/ui/home/first_launch_consent.dart` (new, 25) — `FirstLaunchConsent`.

Tests:

- `packages/party_host/test/controls_test.dart` (new, 71 lines) — 6 tests:
  1. `with no claims the controllers work the menus` — `current.menus` true, `only`/`layout` null;
  2. `the newest claim wins` — the second claim's `Controls` is `current`, and releasing the older one keeps it;
  3. `releasing the newest claim gives the controllers back to the one below` — `same(game)` after `release()`;
  4. `releasing a claim in the middle leaves the newest one on top` — `only == {'p2'}` after releasing the middle
     claim; releasing the newest then leaves the game claim (`menus` false);
  5. `releasing a claim twice does nothing the second time` — the second `release()` still leaves `same(game)`, and
     the last release restores the menus;
  6. `updating a claim changes what the controllers do now` — `claim.controls = menus` makes `current` it.
  No numbers are computed; the values checked are the claim identities (`same(...)`) and the `only` sets
  `{'p1'}` / `{'p2'}`.

## tools/review.sh

- Usage `[--base <ref>] [--all] [--help]`; default base `git merge-base HEAD origin/main`; unknown base, unknown
  option, a `--base` without a ref, no git or no `origin/main` → message on stderr and exit 2.
- Scope: `.dart` under `controller_app`, `tv_test_app`, `packages`, `assets`, skipping `build/`, `.dart_tool/`,
  `*.g.dart`, `generated_plugin_registrant*`. Default = files changed against the base (committed, staged, unstaged
  and untracked), and inside them the lines added (`git diff -U0` hunks; an untracked file's every line); `--all` =
  every file, every line.
- Whole-file checks on every file in scope: `size` (lib > 400 FAIL, > 300 NOTE; test > 500 FAIL), `func` (a member
  starting at indent 0/2 and ending in `{`, not a class/mixin/enum/extension; lib only: > 60 FAIL, > 40 NOTE, and a
  `build` method only FAILs above 60), `platform` (`Platform.is` in `packages/*/lib`), `layers` (a package importing
  an app; `flutter` in protocol/connection/metrics; a game importing a game, `party_host` or `connection/src`;
  `package:x/src/` from outside package `x`, whose name comes from the nearest `pubspec.yaml`).
- Added-line checks: `leftover` (`TODO`/`FIXME`/`XXX` everywhere, `print(`/`debugPrint(` in lib, `// ignore:` /
  `// ignore_for_file:`), `catch` (empty body, one line or `{` then `}`), `types` (`dynamic` in lib), `timing`
  (`Future.delayed(`/`sleep(` in lib, NOTE), `clock` (`DateTime.now()`, unseeded `Random()` in the two games),
  `number` (a lib numeric literal other than 0, 1, -1, 2, 0.0, 1.0, 0.5 that isn't a `const`/`final` declaration
  with a name, an import, a string or a `//` comment — NOTE).
- Writes only into a `mktemp -d` folder, removed by a `trap`. Git's CRLF warnings go to `/dev/null` (they are not
  findings).
- Verified by hand with a throwaway probe file (since moved out of the tree): each of `size` (631 lines), `func`
  (`build` 62), `platform`, `layers` (two kinds), `leftover` (all four), `catch` (both spellings), `types`,
  `timing`, `clock` and `number` fired where expected, and allowed numbers (`1`, `2`, `-1`, `0.5`, named constants,
  numbers inside strings and comments, hex colours) did not.

## Old home screen → new files (no behaviour or text change)

| Old | New |
| --- | --- |
| `HomeScreen` (build 62) | `HomeScreen` (build 16) + `_WideHome` (32) + `_NarrowHome` (14) |
| `_Header` (build 99, plus a `buttonsFor` helper returning widgets) | `Header` (build 24) + `_HeaderTitle` (42) + `_HeaderButtons` (46, one list of named widgets in a Row or a Wrap) |
| `_Panel` | `Panel` (unchanged body) |
| `_PairingPanel` (build 101) | `PairingPanel` (build 25) + `_PairingCode`, `_AddressList`, `_FirewallNote`, `_SiteUrl`, `_PairingButtons`, `_SimList` |
| `_SoundLine`, `_AdvertiseStatus` | `SoundLine`, `AdvertiseStatus` (unchanged bodies) |
| `_ControllersPanel` | `ControllersPanel` (unchanged body, tile renamed) |
| `_ControllerTile` (build 102) | `ControllerTile` (build 30) + `_ControllerDetails` + `_ControllerLatency` |
| `_LogPanel` | `LogPanel` |
| `_FirstLaunchConsent` | `FirstLaunchConsent` |
| `_clientStatusLabel`, `_open` | private in `pairing_panel.dart` / `home_screen.dart` |

The two layout branches are named widgets (`_WideHome`, `_NarrowHome`) instead of inline trees, so `HomeScreen`'s
build is 16 lines. Nothing outside `src/ui/home/` is exported or imported; the class names are public only because
the brief asks for it.

## Computed values

- Test counts: `party_host` 38 → 44 (the 6 new controls tests, nothing dropped); `tv_test_app` 21 → 21.
- `tools/review.sh`: 297 lines (limit 300).
- New/changed file sizes: `controls.dart` 49, `host_shortcuts.dart` 12, `controller_menus.dart` 233,
  `home_screen.dart` 257, `panel.dart` 54, `pairing_panel.dart` 280, `controllers_panel.dart` 192, `log_panel.dart`
  33, `first_launch_consent.dart` 25, `controls_test.dart` 71, `controller_menus.dart` 243 — all under 300.
- Build lengths in the new home files: `_HeaderButtons` 46, `_HeaderTitle` 42, `_WideHome` 32, `ControllerTile` 30,
  `PairingPanel` 25, `Header` 24, `HomeScreen` 16, `_NarrowHome` 14; the review script reports no other member over
  40, so every build is under the 60-line limit.

## Checks

`tools/check.sh format analyze host tv`:

```
PASS  format      (1s)
PASS  analyze     (4s)
PASS  host        (44 tests, 10s)
PASS  tv          (21 tests, 8s)
All checks passed (24s).
```

`tools/review.sh` (default scope): **17 fail, 170 note**.

| Check | FAIL | NOTE |
| --- | --- | --- |
| size | 1 | 3 |
| func | 15 | 7 |
| leftover | 1 | 0 |
| number | 0 | 160 |
| (platform, layers, catch, types, timing, clock) | 0 | 0 |

`tools/review.sh --all`: **75 fail, 776 note**.

| Check | FAIL | NOTE |
| --- | --- | --- |
| size | 18 | 11 |
| func | 48 | 36 |
| leftover | 4 | 0 |
| catch | 2 | 0 |
| clock | 3 | 0 |
| number | 0 | 729 |
| (platform, layers, types, timing) | 0 | 0 |

Every FAIL line from the default run, with why it is not from this job:

```
FAIL leftover packages/party_host/lib/src/providers.dart:47 debugPrint(          ← M12 step 1 code, not touched here
FAIL func  packages/party_host/lib/src/simulated_controllers.dart:17 62 ...     ← step 1b code
FAIL func  packages/party_host/lib/src/ui/controller_menus.dart:129 61 _tick()   ← existed at HEAD; I only removed code above it
FAIL func  packages/party_host/lib/src/ui/game_screen.dart:165 64 build          ← existed at HEAD (one import added)
FAIL func  packages/party_host/lib/src/ui/join_screen.dart:113 74 _tick()        ← existed at HEAD (one import added)
FAIL func  packages/party_host/lib/src/ui/join_screen.dart:211 98 build          ← existed at HEAD
FAIL func  packages/party_host/lib/src/ui/puzzle_screen.dart:122 66 build        ← existed at HEAD (one import added)
FAIL func  packages/party_host/lib/src/ui/puzzle_screen.dart:191 106 _Results    ← existed at HEAD
FAIL func  packages/party_host/lib/src/ui/stats_screen.dart:55 98 build          ← step 1 code
FAIL func  packages/party_host/lib/src/ui/stats_screen.dart:224 78 build         ← step 1 code
FAIL func  tv_test_app/lib/src/ui/haptic_panel_screen.dart:52 111 build          ← step 1 code
FAIL size  tv_test_app/lib/src/ui/home_screen.dart:1 631 lines                   ← the old file, kept unchanged (DELETE)
FAIL func  tv_test_app/lib/src/ui/home_screen.dart:21/91/249/471 ...             ← the same old file, kept unchanged
FAIL func  tv_test_app/lib/src/ui/latency_screen.dart:88 75 build                ← step 1 code
```

None of the FAILs is on a line this job added. Re-running with `--base HEAD` (only this job's changes) gives
6 fail, 51 note, and the 6 FAILs are the pre-existing `controller_menus._tick` and the `game_screen`,
`join_screen` (two) and `puzzle_screen` (two) members above; every `NOTE` is the `number` check on the layout
values moved out of the old home screen (the old file had no numeric notes because its lines were not new).

## Deviations and decisions inside the brief

1. **The `func` end also accepts `};`.** The rule is "the next line that is the same indent + `}`"; a member whose
   body ends in a set/map literal (e.g. `static Set<_Key> _keysOf(...) => { ..., };`) closes with `};` and would
   otherwise swallow the next member and produce a false FAIL. Literal `}` is still the common case.
2. **`print(`/`debugPrint(` are checked in lib only**, as the brief's parenthetical reads; `TODO`/`FIXME`/`XXX` and
   the `// ignore` comments are checked in tests too.
3. **`--all` also takes untracked files** ("every file"): `git ls-files` plus `--others --exclude-standard`.
4. **Named layout constants.** The four window-width/height numbers that were bare in the old header/home build are
   now documented `static const`s, so the `number` check doesn't fire on them; values are unchanged (720, 420, 760,
   1100). Everything else that moved (paddings, flex, sizes) is unchanged and does produce `number` notes.
5. `PairingPanel` went from `ConsumerWidget` to `StatelessWidget` because the only `ref` use moved into
   `_PairingButtons`; its factory name and text are unchanged.
6. `tools/flash.sh` and the three `tv_test_app/windows/flutter/generated_*` files were already modified before this
   job started; I did not touch them.
7. A throwaway probe (`packages/party_host/lib/zz_probe.dart`) and the two review outputs were used while testing
   the script; all three were moved into `build/` (ignored), so the tree has no scratch files.

## DELETE: files Claude must delete

- `tv_test_app/lib/src/ui/home_screen.dart` — the old 631-line screen, left in place unchanged as the brief says;
  nothing imports it (checked with grep over `controller_app`, `tv_test_app`, `packages`, `assets`). Until it is
  deleted the default `review.sh` run keeps reporting its size and its four long builds.

## Questions

1. The default base (`origin/main`) makes the default run show every M12 change, so its 17 FAILs are all older work.
   Is that the intent, or should the default be `HEAD` (a job's own diff) with `--base` for the whole branch?
2. Check `e`: I read "(lib only)" as covering `print`/`debugPrint` only. Should `TODO`/`FIXME`/`XXX` also be lib only,
   or tests too (as now)?
3. `ClaimHandle` is not exported. If the phone app's host mode ever claims controllers from its own code (not through
   `ControlsClaim`), it will need to be exported then — confirm that is the intended later step.
4. The `number` check is loud on UI code: 160 notes in the default run, nearly all `EdgeInsets`/`SizedBox`/flex
   values. Exempting lines that call `EdgeInsets`, `SizedBox`, `Expanded` and `Padding`, or a shared dimensions file,
   would need a rule from you; I left the check exactly as briefed.
5. On screens, `_tick` in `controller_menus.dart` (61 lines), `join_screen`'s `build` (98) and `_Results` (106),
   `haptic_panel_screen`'s `build` (111) and `stats_screen`'s two builds are over 60 lines. They are outside this
   job; a later brief could split them.

## Suggestions

- `packages/puzzle_game/lib/src/{game,library,match}.dart` use `Random()` as a fallback when no seeded `Random` is
  passed (`--all` reports all three under `clock`). That is the rules' determinism rule (guideline §5); it predates
  this job and I did not change it.
- `controller_app/lib/src/providers.dart:75` (`debugPrint`) and `:141` (empty catch), `packages/metrics/bin/report.dart:124`
  (empty catch) and two `// ignore` lines in `tv_test_app/integration_test/sound_test.dart` are the `--all` leftovers;
  listed as counts only, as the brief says.
