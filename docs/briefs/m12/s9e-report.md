# s9e report — CI's analyze failed on 5 infos; the local check is as strict now (G4)

**Done.** Three files changed: `controller_app/test/puzzle_size_test.dart`, `tools/check.sh`,
`docs/dev-tools.md`. `tools/check.sh format analyze phone` passes.

## 1. `puzzle_size_test.dart`: the five `print`s are `debugPrint`

- New import `package:flutter/foundation.dart` with `show debugPrint`, above `flutter_test` (the
  same line `packages/puzzle_game/test/split_layout_test.dart` uses; `frame_size_test.dart` imports
  the whole library).
- Lines 122, 128, 132, 139 and 143 (the brief's numbers) are `debugPrint(...)` now; the strings
  passed are byte for byte the same, so the table and the `lowest`/`Hard` lines print unchanged.
  `avoid_print` is the lint that flagged them (info level): a `print` in test code counts as
  production code to the lint, and `debugPrint` isn't flagged.

No other line of the file moved; the test adds no expectation and drops none.

## 2. `tools/check.sh` and `docs/dev-tools.md`: infos fail here too

- `check.sh` analyze row: `dart analyze` → `dart analyze --fatal-infos`, and its "what it covers"
  text is now `static analysis of the whole workspace (infos fail, as on CI)`. `--fatal-infos`
  makes an info exit non-zero, so a `print` in a test fails `tools/check.sh analyze` the way it
  fails `flutter analyze` on CI. Nothing else in the script changed; the failed-run filter already
  shows lines matching `info -`, so a failure prints the finding.
- `docs/dev-tools.md`: the check table's `analyze` row shows `dart analyze --fatal-infos`, and a new
  **Analysis** bullet under the output list says why (CI's `flutter analyze` fails on infos) and
  that a `print` in a test is such an info, so use `debugPrint`.

## 3. What the analyze check found with `--fatal-infos`

`tools/check.sh analyze` — `PASS  analyze (8–11 s)` in three runs after the fix, with **no infos,
warnings or errors anywhere in the workspace**: nothing else to list, so nothing else touched.

That the flag really is what catches this was checked by hand, with one `print` put back for a
single run and then reverted (the file's final state is the five `debugPrint`s):

- `dart analyze --fatal-infos controller_app/test/puzzle_size_test.dart` — exit **1**:
  `info - puzzle_size_test.dart:140:7 - Don't invoke 'print' in production code. Try using a logging
  framework. - avoid_print`.
- `dart analyze controller_app/test/puzzle_size_test.dart` (no flag, the old command) — the same
  one info printed, exit **0**: this is why the check passed here while CI failed.

The flag itself is a `dart analyze` option (`--fatal-infos  Treat info level issues as fatal.`,
from `dart analyze --help` on this machine), so no other tool is involved.

## What I ran

- `tools/check.sh analyze` (alone, first) — `PASS  analyze (11s)`, `All checks passed (11s)`.
- `tools/check.sh format analyze phone` — `PASS format (1s)`, `PASS analyze (10s)`,
  `PASS phone (329 tests, 72s)`, `All checks passed (83s)`.
- The same three after the flag experiment and its revert — `PASS format (2s)`,
  `PASS analyze (8s)`, `PASS phone (329 tests, 18s)`, `All checks passed (28s)`.

## Questions and suggestions

1. **Suggestion — match CI's command, not only its strictness.** CI runs
   `flutter analyze controller_app tv_test_app packages assets` (`ci.yml` line 50) and Codemagic
   `flutter analyze controller_app packages/protocol packages/connection`. `dart analyze
   --fatal-infos` at the root covers the same folders (it walks `packages/` and both apps; a
   workspace-wide run found the same file) and fails on infos now, so this closes the gap that bit
   m12.2. Switching the check to `flutter analyze` would also catch anything `flutter analyze` sees
   that `dart analyze` doesn't; that would cost more seconds per run, so it isn't done here — Claude's
   call.
2. **Note — output timing.** `debugPrint` throttles in chunks of about 1 KB per second, so on a slow
   run the table's lines can arrive a little later than `print`'s did; the strings are identical.
   `split_layout_test` and `frame_size_test` already print their tables this way, so the check's own
   output is unaffected.
3. **Note — no hard-coded values.** This job computed nothing: no expectation changed, and the
   size table's numbers are the ones the tests already produced.
4. **Note — files already changed in this worktree.** `docs/briefs/m12/STATUS.md` and
   `tv_test_app/windows/flutter/generated_plugin_registrant.{cc,h}` /
   `generated_plugins.cmake` were modified before this job started; I didn't touch them.

## Files changed

- `controller_app/test/puzzle_size_test.dart` — `debugPrint` import; the five `print` calls are
  `debugPrint`.
- `tools/check.sh` — the analyze check runs `dart analyze --fatal-infos`; description says so.
- `docs/dev-tools.md` — the analyze row and a new Analysis bullet on infos failing as on CI.

## Commit message

test: debugPrint the puzzle size table, fail analyze on infos (s9e)

CI's flutter analyze fails on infos, and the five prints in
puzzle_size_test were infos (avoid_print), so the m12.2 check failed
while the local one passed. They are debugPrint now, and the table
reads the same.
tools/check.sh's analyze runs dart analyze --fatal-infos, so an info
fails here as on CI; its description and docs/dev-tools.md say so.

## Status row

| 9 Docs and device tests | … **s9e done** (`s9e.md`): the five `print`s in `controller_app/test/puzzle_size_test.dart` are `debugPrint` (the size table prints the same), and `tools/check.sh analyze` runs `dart analyze --fatal-infos` (docs/dev-tools.md says so), so an info fails here as CI's `flutter analyze` does; a whole-workspace run finds no other infos. Open: the m12.2 CI rerun, Codemagic's two failed iOS builds, s8c, the PRD M12 acceptance tests in the checklist |

## Delete

- none
