# board3a g3s report: stubs behind placing and champion

## Summary

- Added `RoundPlacing` (abstract interface) and `StubRoundPlacing`: `placeRound(playerIds)` gives each id a placing, 1 for the first listed, same shape as the round result's points map.
- Added `CityChampionEntry` (playerId, plazaDistance, bolts), `ChampionDecider` (abstract interface) and `StubChampionDecider`: `decideChampions(entries)` returns the canned set of every entry's id (all share the win, no tie-break).
- No import from `night/` or the host service; pure Dart, no Flutter import in `stubs.dart` (the test uses flutter_test, as board_test does).
- Test file written first: it did not load before `stubs.dart` existed (the first run failed at loading).
- Tests: 4 run, 4 passed (`flutter test packages/party_host/test/city/stubs_test.dart`).
- Computed expectations: `placeRound(['ann','ben','cy'])` = `{ann: 1, ben: 2, cy: 3}`; `placeRound([])` = `{}`; `decideChampions([ann(plazaDistance 4, bolts 1), ben(plazaDistance 2, bolts 0)])` = `{ann, ben}`; `decideChampions([])` = `{}`.
- `dart format` 0 changed; `dart analyze` on both files: No issues found (after making the four test stubs `const`).

## Decisions

- Stub placing uses the order of the list passed in (index + 1). Simplest canned answer that still gives one placing per player.
- Stub champion returns every entry's id. The brief says "a canned set"; a set of everyone is the one answer that needs no tie-break and matches the `shared` step.
- The new entry type is named `CityChampionEntry`, not `ChampionEntry`, because `night/champion.dart` already has a `ChampionEntry` and this job may not import from `night/`.
- The placing input is a list of player ids, not a round result, so the stub has no dependency on the round-result type.
- Both interfaces are `abstract interface class`; both stubs are `const`-constructible.

## Self-check (review-rules part A)

1. Host setups: not applicable; pure data stubs with no host, no phone, no TV. Test: none needed.
2. Kept state: none; the stubs hold no state. Test: `returns an empty map when no player is listed`, `returns no champion when there are no entries` (empty input in, empty out).
3. Combination with pause, away, Get ready, link drop, results, leaving: not applicable; nothing is wired in yet (g3m wires the chain).
4. Folder and allow: only the two allowed `lib` and `test` files plus this report were written.
5. Stop: no stop needed.
6. Looks: not applicable; no widget.

## Tooling gap (not fixed here)

`tools/mine.sh` builds its change list from `git status --porcelain`, which reports a brand-new untracked folder as one `city/` entry and not as its files. The `.dart` filter then skipped both new files: the run printed `0 file(s) formatted, 0 package(s) analyzed, 0 package(s) tested`, which is a false green. I tried to force untracked files to be listed with a `GIT_CONFIG_*` env prefix, and the permission check refused that form. So I ran the allowed prefixed commands directly on the two files instead: `dart format`, `dart analyze`, and `flutter test <file>`. Those are the results listed above. The runner's combined check should still be trusted as the authority.

## Hand-over

- Files changed: `packages/party_host/lib/src/city/stubs.dart` (new), `packages/party_host/test/city/stubs_test.dart` (new), this report (new).
- Open: `mine.sh` misses untracked folders (see above); `tools/mine.sh` should read `git status -uall` or the equivalent.

## Questions

1. Is "every entry shares the win" the canned champion you want, or should the stub return an empty set?
2. Should `RoundPlacing` take the round result itself (as the points map is keyed) rather than a list of ids? I kept the list to stay free of the round-result type.
3. Should `mine.sh` be fixed to see untracked folders? (Not changed here; outside the allow list.)

## Commit message — a draft: a subject line under 72 characters, a blank line, then at most 8 lines on what changed and why.

m17 board3a: stubs behind round placing and champion

Adds RoundPlacing and ChampionDecider as abstract interfaces in
party_host city/, each with a canned stub: placings follow the list
order, and every entry shares the champion win. No tie-break, no
numbers, no import from night/ (ChampionChain is wired in g3m).
Tests written first; 4 pass.

Co-Authored-By: Claude Haiku 5.5 <noreply@anthropic.com>

## Status row — one line for the milestone's STATUS.md: what is now done, and what is open.

- board3a g3s: done: RoundPlacing + StubRoundPlacing and ChampionDecider + StubChampionDecider in party_host city/ (4 tests pass); open: wire ChampionChain in g3m, and mine.sh misses untracked folders.

## Delete

- none
