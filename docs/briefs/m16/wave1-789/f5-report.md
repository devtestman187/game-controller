## Summary

Changed: `packages/party_host/test/volume_semantics_test.dart` only. Lib is unchanged.

- Removed the `// ignore: deprecated_member_use` line and the whole-tree `_spokenValues` helper.
- Removed the `contains(...)` check. Each slider now gets its own `expect(value, shown)` with `equals`.
- Added `expect(shown, isNotEmpty)` before the equality, so an empty percentage cannot pass.
- The case now runs through `forEachLook` (menu look, then TV look) for both the Sunny and Night palettes.
- The slider value is read from the slider's own semantics node: a walk down the element tree from the
  `soundVolume` / `musicVolume` key to the first node with the `isSlider` flag, then its `value`.

Why not `tester.getSemantics(find.byKey(...))`: in a diagnostic run it returned an empty value for both
sliders (`get=[]`), so it was not the slider's own node. The brief's merged-node explanation fits.
`simulatedAccessibilityTraversal` plus a value search would have been a `contains` in disguise, so I did not use it.

Computed values (the test passed, so the other values are equal to their shown text):
- Sunny, menu look, soundVolume: shown `80%`, semantics value `80%` (diagnostic run, since removed).
- Night, menu look, soundVolume: shown `80%`; the diagnostic run showed `get=[]` for it, and the final run passed,
  so the walk's value equals `80%`.
- The musicVolume values and the TV-look values were not printed; the final run passed for all of them.

Self-check (docs/review-rules.md part A):
1. Hosts: the menu and TV looks both run under `forEachLook`; the test passes (`OK 2 tests packages/party_host`).
2. Kept state: none; each look's semantics handle is taken and disposed in its body.
3. Combinations with the pause menu, away states, results and leaving: not in this screen's test; no change.
4. Stayed inside the allow list: yes. The diagnostic file is outside it, see Hand-over.
5. Stop: none.
6. Looks: both the menu look and the TV look are tested; no fixed pixel height.

Tests-first: exempt, as the brief says (the test pins the existing callback and the default semantics value).

Checks: `tools/mine.sh` → `OK 2 tests packages/party_host`, `RESULT: ok: 1 file(s) formatted, 1 package(s) analyzed, 1 package(s) tested`.
Ran `tools/mine.sh` several times while diagnosing; only the last run is the result.

## Hand-over

- Leftover: the diagnostic run wrote `packages/party_host/.dart_tool/f5diag.txt`. It is in the git-ignored
  `.dart_tool` folder, outside my allow list, and I cannot delete it. It is safe to remove by hand.
- The test file was reformatted by `dart format` once during the run; the final content is the formatted version.
- `tools/check.sh` was not run; the script does that after the job.

## Commit message

Test: volume sliders read their own semantics value, both looks

Drop the analyzer ignore and the whole-tree contains() check from the
volume semantics test. Each Sounds and Music slider now compares its
own semantics value with equals to the percentage shown above it, and
asserts that percentage is not empty. The case runs in the menu look and
the TV look, for the Sunny and Night palettes. The slider value is read
from the slider's own node, because the merged parent node is empty.

## Status row

M16 wave1-789 f5: done — party_host volume slider test uses per-slider equals, no ignore, both looks; open: none.

## Delete

- none
