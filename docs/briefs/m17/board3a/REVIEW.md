# board3a run review

## Summary

Verdict: one fix batch. Counts: 1 must, 2 should, 4 could.
Read: the four files of the change, both job reports, run.log, the two rule docs. No STATUS.md, run-findings.md, REVIEW-VERDICTS.md or per-job review report exists, so carry-over is empty.
Hand-fixes: none (no HAND-FIX lines in run.log).
Top five:
1. tools/mine.sh:161 lists untracked folders as one entry, so the city files were never checked; both jobs saw "0 file(s)" and a green result.
2. stubs.dart:29 `CityChampionEntry` duplicates the night's `ChampionEntry` (night/champion.dart:31).
3. board.dart:1 eight public types in one file; the one-type rule allows it only for small types that belong together.
4. board.dart:7 the "unique id" claim is unchecked.
5. stubs.dart:23 duplicate player ids silently drop a placing.
Owner questions: keep the board types in one file; the Gate contract (brief's `shared` field); the name for the champion entry; the held jobs g3b and g3f (DRIVER-NOTES.md: tile cost, draft effect, drive cost).

## Findings

- **must** tools/mine.sh:161 `git status --porcelain -z` lists the new untracked `city/` folders as one entry, so their `.dart` files are skipped and the run reports a green "0 file(s)" → add `-uall` to that call and re-run the check on both city folders (from: g3a, g3s).
- **should** packages/party_host/lib/src/city/stubs.dart:29 `CityChampionEntry` is a second name for the night's `ChampionEntry` (packages/party_host/lib/src/night/champion.dart:31), against "don't invent a second name" → reuse one name or give both one shared type, a design call (from: g3s).
- **should** packages/party_host/lib/src/city/board.dart:1 eight public types in one file, which the rule allows only for small types that belong together → keep the file and state that reason in the library doc, or split it along the type seams (from: g3a).
- **could** packages/party_host/lib/src/city/board.dart:7 "[id] is unique on the board" is stated, but no code or test checks it → soften the doc, or enforce it where the ids are known (from: g3a).
- **could** packages/party_host/lib/src/city/stubs.dart:23 duplicate ids in `placeRound` collapse in the map, so `['a','a','b']` gives `{a: 2, b: 3}` and no test covers it → document that ids must be unique, or add a test (from: g3s).
- **could** packages/party_host/lib/src/city/board.dart:83 the `GateKind` values `brokenBridge`, `potholeField` and `riverFerry` have no dartdoc, though §10 asks for every public member → one line per value (from: g3a).
- **could** packages/party_host/test/city/board_test.dart:1 and packages/party_host/test/city/stubs_test.dart:1 the tests-first proof only shows a missing-file or compile failure (run.log 22:17:42, 22:17:57), not a behaviour failing → accept, and say so in the next report (from: g3a, g3s).

## Open questions

1. Keep all board types in `board.dart`? Suggest yes, with the reason in the library doc (g3a Q1).
2. Should `Gate` take a `shared` field, or is the single `opened` flag enough? Suggest the single flag; confirm the brief's `Gate(kind, opened, shared)` (g3a Q2).
3. Should `Token.tilePosition` be checked against its road length? Suggest leave it to the rules job (g3a Q3).
4. The analyzer finding expected at board_test.dart:82 did not occur. Suggest close it: run 2 of run.log passed the check (g3a Q4).
5. Should the stub champion return every entry? Suggest yes, as briefed (g3s Q1).
6. Should `RoundPlacing` take the round result rather than a list of ids? Suggest keep the list (g3s Q2).
7. Should `mine.sh` see untracked folders? Suggest yes; see the first finding (g3s Q3).
8. Owner, not a job report: g3b and g3f are held on tile cost, draft effect and drive cost (DRIVER-NOTES.md). Suggest leave them held until answered.

## Numbers against targets

- Tests: board_test.dart has 11 tests (District 4, Tile 1, Token 1, Bolts 1, RoadworksBlock 1, Gate 3), all passing per g3a. stubs_test.dart has 4 tests, all passing per g3s. No target is stated in the briefs read, so nothing misses.
- Sizes: board.dart 103 lines, stubs.dart 61, board_test.dart 82, stubs_test.dart 38. All under the 300-line guideline, and no file grew over several jobs.

## Could not check

- Whether the run's combined check (run.log 22:18:23) saw the new city files: tools/check.sh was not read. If it lists changes the way mine.sh does, the same gap applies.
- The names Bolts, RoadworksBlock and Plaza against the PRD: a grep of docs/ found only briefs, and its output was cut at 8 files, so the PRD was not confirmed.
- No hand-fix proof or per-job review exists to check, so the "tests-first and review report" check for hand-fixes is empty.

## Commit message — a draft

board3a run review: findings for Claude's fix brief

Review report only; no code changed. One must (the mine.sh untracked-folder
gap, so the city files were never checked), two shoulds, and four coulds.
The findings are for Claude to verify and turn into one fix brief.

## Status row

board3a run review: done. Open: one must (tools/mine.sh misses untracked folders), two shoulds (CityChampionEntry name, board.dart type split), four coulds, and the owner questions in REVIEW.md.

## Delete

- none

## Verdicts (driver, Nov 26; judge texts verbatim in DRIVER-NOTES)
- F1 tools/mine.sh:161 untracked city/ folders skipped, green "0 files" - must. Shared file: NOT touched on the board line. Owner/main to fix (add -uall, fail on 0 files). Until then city/ is checked by explicit path (f3a used dart format/analyze/flutter test by path).
- F2 stubs.dart:29 CityChampionEntry duplicates night ChampionEntry - closed by f3a (dartdoc on the shape difference, no import from night/).
- F3 board.dart:1 eight small related public types in one file - accepted with note (small related types; splitting is a style choice, not a defect).
- F4 board.dart:7 unique ids - closed by f3a (asserted, tested).
- F5 stubs.dart:23 duplicate ids - closed by f3a (ArgumentError, tested).
- F6 board.dart:83 GateKind dartdoc - closed by f3a.
- F7 tests-first shows compile failures only - note only (type and stub wave).

## Superseded (Nov 26 late, owner road model)
The nine findings of the g3b run-1 review (commit 50b963e3, shared road model) are superseded by the rework brief; not verdicted.
