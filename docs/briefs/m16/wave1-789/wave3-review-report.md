# Review of wave3 (n9d3) — the Arena HUD names the map

## Summary

Verdict: small fixes. Counts: must 0, should 2, could 1.
- The report's decision says no view or session holds the loaded `ArenaMap`; the code says `ArenaFieldRules` holds it (`arena_field.dart:64`). The table decision stands, but its stated reason is wrong, and the commit draft repeats the claim.
- The report says the three `tv_test_app` generated files are no longer modified after the run; `git status` in this worktree still lists all three as ` M`. Nothing from this job touches them, but the claim is unverified.
- The code matches the brief: name shown first in the round bar, unknown id draws nothing, `arena_map.dart` untouched, no wire change, all changed lines within 120 columns, `arena_hud_widgets.dart` 367 lines, test file 94 lines.

## Findings

- **should** `packages/test_game/lib/src/arena_map_names.dart:1` The report's decision and commit draft say "no view or session holds the loaded ArenaMap", but `ArenaFieldRules` holds `final ArenaMap map` (`packages/test_game/lib/src/arena_field.dart:64`) and `ArenaGame` passes it on (`packages/test_game/lib/src/arena.dart:67,76-77`) → Reword the decision to: the map lives on the host's game object, the HUD only gets the snapshot, which carries the id, and a name on the wire is out of scope; then fix the commit draft's "no view or session holds" sentence to match.
- **should** `docs/briefs/m16/wave1-789/n9d3-report.md:34` The report says that after the run `git status` no longer lists the three generated `tv_test_app/windows/flutter` files; in this worktree `git status --short` still shows them as ` M` → Claude to check whether those uncommitted changes survived before anything else is done; do not revert them from this job.
- **could** `docs/briefs/m16/wave1-789/n9d3-report.md:7` The report says `OK 4 tests` for `packages/test_game` but the new file has 3 tests and the worker did not name the fourth → Name the fourth test (or the suite) in the report, or drop the count.

## Decisions to confirm

- The bundled names are hard-coded in `packages/test_game/lib/src/arena_map_names.dart:4-10`. The guidelines forbid hard-coded names in lib; the drift test in `arena_hud_map_test.dart:91-93` is the only guard. Why: the owner should accept the table, or ask for the name to come from the loaded map on a later job that changes the wire.
- `lib/test_game.dart` does not export `arena_map_names.dart`; the test imports `package:test_game/src/arena_map_names.dart` directly. Why: the file is outside the brief's `allow:`; a later job can add the export if other callers need it.
- The name is placed first in the Wrap, before the round label (`arena_hud_widgets.dart:36`), so it reads "Pinball  Round 1 of 3", not "Round 1 of 3  Pinball". Why: the brief says "beside"; the order is a choice the owner may want to see.

## Could not check

- The `tools/mine.sh` output and the `OK 4 tests` run were not re-run (read-only job); only the code and the diff were read.
- Whether the uncommitted changes to the three generated files were lost (see the should finding above): `git status` shows them still modified here, so the question is open.
- The full `docs/coding-guidelines.md` and `docs/review-rules.md` were not opened; the worker extract was the rule source, and no question went beyond it.
- `run-findings.md` has one entry (`volume_semantics_test`, another job); it names no n9d3 test.

## Commit message — a draft: a subject line under 72 characters, a blank line, then at most 8 lines on what changed and why.

docs: review of wave3 n9d3 (the Arena HUD names the map)

Read-only review of commit 22aa639c. Adds this report only. Findings: the
report's "no view or session holds ArenaMap" is wrong (ArenaFieldRules
holds it); the three tv_test_app generated files are still modified here,
which the report says they are not. Owner decision open: hard-coded names
table in arena_map_names.dart.

## Status row — one line for the milestone's STATUS.md: what is now done, and what is open.

wave3 n9d3 review: done — read-only; verdict small fixes (0 must, 2 should, 1 could). Open: the report's ArenaMap claim to correct, the three tv_test_app generated files still modified (Claude to check), and the owner's call on the hard-coded name table.

## Delete

- none
