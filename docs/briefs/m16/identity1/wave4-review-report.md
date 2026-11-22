# Wave 4 review (i1g1, commit d321bcdf)

## Summary

Verdict: **small fixes**. Counts: must 0, should 2, could 4. The three that matter most:
- The report's self-check answers only item 6 and waives the rest (should, report:23).
- The report says `toyTvProvider` does not exist; it does, so the TV-look decision's reason is false (should, report:29).
- The accessory test proves only that two renders differ, not that the crown is drawn (could, test:125).

The code is right: `ViewContext.characters` is documented as asked, filled at the one build site (`frame_view.dart:304`), and passed to
`ArenaBoard` (`arena_module.dart:54`). At HEAD I ran the two new files: game_kit 2/2 and test_game 4/4 pass; `run.log:164-165` records the
runner's tests-first proof that both fail on the old code.

## Findings

- **should** docs/briefs/m16/identity1/i1g1-report.md:23 the self-check answers only item 6 and says it did not open review-rules.md, where part A requires one line per item ("Not affected" is an answer, silence is not) → add lines for 1-5: an old-build phone lists no `Capability.identity`, so the host withholds `chars` (`host_players_broadcast.dart:119`) and the phone draws the number's default; nothing is kept, paused or hidden, so 2 and 3 are "not affected"; 4 and 5 held.
- **should** docs/briefs/m16/identity1/i1g1-report.md:29 the TV-look decision says `toyTvProvider` "does not exist in this repo", but it does (`packages/party_host/lib/src/look_providers.dart:56`) → give the real reason (a game package cannot import `party_host`, guidelines §1) and note that `ToyLook.build(tv: true)` is what the app's provider itself builds (`look_providers.dart:94`), so the look under test is the app's.
- **could** docs/briefs/m16/identity1/i1g1-report.md:32 the decision cites `connection/lib/src/server_game_frames.dart`, which does not exist at this commit; the per-viewer `chars` filter is `host_players_broadcast.dart:113-120` → cite that file (the same stale path sits in `docs/code-health.md:261`).
- **could** docs/briefs/m16/identity1/i1g1-report.md:13 the report gives no computed pixel counts for the `countOf` expectations (200 and 20), which guidelines §9 asks for → add the measured counts per look per case so the margins can be judged.
- **could** packages/test_game/test/arena_phone_identity_test.dart:125 `expect(crown, isNot(equals(variant)))` passes for any accessory the viewer draws, so a swapped or wrong accessory would still pass, and the brief asked for the crown → compare the crown's band with a reference render as `arena_identity_test.dart:255-267` does with mask/share.
- **could** packages/test_game/test/arena_phone_identity_test.dart:141 the fourth test rebuilds `capture`'s harness inline (physical size, `withLook`, `pumpWidget`, `addTearDown`) instead of reusing it → give `capture` the roster and ids (5 parameters is still within the limit) and read the dots from the same tree.
- **could** packages/game_kit/lib/src/game_module.dart:58 the `ViewContext` dartdoc enumerates roster, player, whole match, pads and px-per-mm but not the new field → add a clause naming `characters` and its empty-means-number-default rule to that paragraph.

## Decisions to confirm

- The owner called `ViewContext.characters` "OPTIONAL" (NEXT-i1g.md decision 3); it is implemented as a required record field that is always an empty map when the host sent none. That is optional in effect, but every future `ViewContext` literal must now name it — confirm that is wanted.
- The TV look is built directly (`ToyLook.build(tv: true)`) rather than through `toyTvProvider`, because `test_game` cannot import `party_host`; the sibling `arena_identity_test.dart` does the same. Confirm this satisfies review rule A6 for game-package tests.
- The phone test's crown is checked by render difference, not geometry; i1f's board test owns the crown's shape. Confirm the split is enough.

## Could not check

- The report's `tools/mine.sh` and `tools/review.sh` results: I ran only the two new test files (both pass), not mine.sh or the full suite.
- Whether the whole suite is green at d321bcdf: the report says the full suite was not run; `DRIVER-NOTES.md:13` claims kit 77 / arena 252 / puzzle 445 pass.
- Whether the new tests fail on the old code by my own run: reverting code is not allowed here, so I rely on `run.log:164-165`.
- `run-findings.md` does not exist in the brief folder, so it contributed no entries.

## Commit message

m16 identity1: wave 4 review of i1g1

Reviews d321bcdf against its brief, the coding guidelines and review rules A-B.
No must findings: the ViewContext.characters contract, its fill in frame_view
and the Arena phone path match the brief, and both new test files pass (2 and 4
tests). Two should findings correct i1g1-report.md (self-check items 1-5
unanswered; a false claim that toyTvProvider does not exist). Four could findings
on report accuracy and test strength. No code or doc changed but this report.

## Status row

wave 4 reviewed (i1g1: small fixes, 0 must); open: i1g1-report.md self-check and decision reasons, the could items, then i1g2 (painters).

## Delete

- none
