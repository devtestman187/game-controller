job: m12 step1b G4 — review script, controls cycle, home screen split, shared activate shortcuts
stop: after G4. Don't start step 2.
read: docs/coding-guidelines.md (§2, §3, review checklist) · docs/dev-tools.md (table + tools/check.sh section, for style) · tools/check.sh (style: bash, set -u, cd to root, one line per result)
small job: straight to G4, no earlier gates.

do:
1 tools/review.sh (new, bash, same style as check.sh). Mechanical guideline checks; prints only findings, one per line: `FAIL <check> <file>:<line> <detail>` or `NOTE <check> <file>:<line> <detail>`, then `review: <n> fail, <m> note`. Exit 0 no FAIL, 1 any FAIL, 2 bad args/missing git.
  usage: `tools/review.sh [--base <ref>] [--all] [--help]`. Default base = `git merge-base HEAD origin/main`.
  scope: .dart files under controller_app tv_test_app packages assets; skip build/, .dart_tool/, *.g.dart, generated_plugin_registrant*. Default = files changed vs base (committed, staged, unstaged and untracked); --all = every file.
  "added lines" = lines added vs base (git diff -U0 base, plus all lines of untracked files); with --all, every line.
  lib = a path containing /lib/; test = /test/.
  whole-file checks (each file in scope):
   a size: lib >400 FAIL, >300 NOTE; test >500 FAIL.
   b func: member length. A member starts at a line indented 0 or 2 spaces that ends in `{` (or `async {`, `async* {`, `sync* {`) and isn't a class/mixin/enum/extension declaration; it ends at the next line that is the same indent + `}` (dart format makes this exact). Lines = end - start + 1. lib only. `build` >60 FAIL; others >60 FAIL, >40 NOTE.
   c platform: `Platform.is` in packages/*/lib FAIL.
   d layers: in packages/: import of package:controller or package:tvtest FAIL; in protocol/connection/metrics: package:flutter FAIL; in puzzle_game/test_game: package:party_host, package:connection/src, or the other game FAIL; anywhere: `package:<x>/src/` imported from outside package <x> FAIL (package of a file = nearest pubspec.yaml `name:`).
  added-line checks:
   e leftover: TODO|FIXME|XXX, `print(`, `debugPrint(` (lib only), `// ignore:` or `// ignore_for_file:` FAIL.
   f catch: empty catch body (`catch (...) {}` on one line, or a catch line followed by a line that is only `}`) FAIL.
   g types: `dynamic` as a word in lib FAIL.
   h timing: `Future.delayed(` or `sleep(` in lib NOTE.
   i clock: `DateTime.now()` or `Random()` (no seed) in packages/puzzle_game/lib or packages/test_game/lib FAIL.
   j number: in lib, a numeric literal other than 0, 1, -1, 2, 0.0, 1.0, 0.5 on a line that isn't a const/final declaration with a name (`const x =`, `static const`, `final x =` at member level), not an import, not inside a string or `//` comment: NOTE.
  Keep the script ≤300 lines; awk is fine (Git Bash, macOS and Linux awk). No network, no writes outside a temp dir it cleans up (trap).
2 docs/dev-tools.md: add a review.sh row to the table and a short "tools/review.sh" section like check.sh's (usage, output, exit codes, "it doesn't replace the review, it finds the mechanical things first").
3 Break the providers.dart → ui/controller_menus.dart import (state must not import UI): new packages/party_host/lib/src/controls.dart holds `Controls` and `ControlsClaims` (no Flutter widget import). ControlsClaims gets a small API instead of the widget reaching its private list: `ClaimHandle claim(Controls controls)`; ClaimHandle has `set controls` and `void release()` (releasing twice is a no-op); `Controls get current` stays (newest unreleased claim, or `Controls.menus()`). Keep the widget's name `ControlsClaim` (rename nothing public that screens use). menuLayout stays in controller_menus.dart. providers.dart imports controls.dart, not ui/. Export from party_host.dart whatever is exported today, nothing new except ClaimHandle if a screen outside the package needs it (it shouldn't: then don't export). New tests in test/controls_test.dart: newest claim wins; release restores the previous; release of a middle claim leaves the newest; updating a claim's controls changes current; no claims → menus.
4 Split tv_test_app/lib/src/ui/home_screen.dart (631 lines) into tv_test_app/lib/src/ui/home/: home_screen.dart (HomeScreen, Header), panel.dart (Panel), pairing_panel.dart (PairingPanel, SoundLine, AdvertiseStatus), controllers_panel.dart (ControllersPanel, ControllerTile), log_panel.dart (LogPanel), first_launch_consent.dart. The private classes become public in src/ui/home/ (not exported anywhere). Every file ≤300; every build ≤60 lines: where one is longer today (Header, ControllerTile at least), extract named widgets, not helper functions. Update imports (main.dart, tests). No behaviour or text change. Old file: leave it in place, unchanged, and list it under DELETE (you can't delete); make sure nothing imports it.
5 Shared activate shortcuts: new packages/party_host/lib/src/ui/host_shortcuts.dart with `const hostActivateShortcuts = <ShortcutActivator, Intent>{select, enter, gameButtonA → ActivateIntent}` and a doc comment (TV remotes send select; Enter and gamepad A too). Export it from party_host.dart. Use it in tv_test_app/lib/main.dart and packages/party_host/test/support/host_harness.dart (remove their copies and the duplicated comments).

after: run `tools/review.sh` (default scope) and `tools/review.sh --all`; in the report give each check's FAIL/NOTE count for both, and every FAIL line from the default run (should be none for your own changes; if one is, fix it or explain). Don't fix --all findings in files outside this job: list counts only.

rules: no behaviour change in the apps · tests: same count + the new controls tests, none dropped or weakened · no pubspec edits · no Platform.isX in party_host.
allow: tools/review.sh · docs/dev-tools.md · packages/party_host · tv_test_app/lib · tv_test_app/test
check: format analyze host tv
report: docs/briefs/m12/s1b-report.md
