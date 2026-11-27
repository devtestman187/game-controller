# night2b d2f report

## Summary

Vote rules for the host and a phone test for the generic choices screen. Vote is not wired into a night.
- `variant_text.dart`: `variantLabel`, `variantDetail`, `VoteText.title`, `maxVariantLabelLength` (12), `mapNames`.
- `vote_round.dart`: `voteDuration` (5 s), `maxVoteCards` (4), `offerFor`, `voteSetup`, `VoteResult`, `settleVote`.
- Tests: variant_text_test (5), vote_round_test (12), choices_vote_test (12: 3 sizes x 2 looks, plus details, tap/clear, timer 0 per look).
- mine.sh: 12 tests controller_app, 17 tests party_host, all OK; format and analyze clean.
- choices_screen.dart needed NO change: 4 cards with details held 48 dp at 320x640, 360x640 and 667x375 in both looks.

Computed values: "Shapes Easy" 11, "Shapes Med" 10, "Shapes Hard" 11; "Spinning Tops" is 13, so "Spinning Top"; "Race Playroom" is 13, cut to "Race Playroo"; "Race Block Castle" cut to "Race Block C"; 2-2 tie over 30 seeds reaches both tied games; no votes over 40 seeds reaches all 3 offered.

## Decisions
- `arenaMapNames` is not exported by test_game and a lib import of its src is an analyzer info (implementation_imports); test_game is not in allow. So variant_text.dart keeps a copy (`mapNames`) and a test compares it with `arenaMapNames` (src import in the test), so it cannot drift.
- An unknown map id falls back to the id as its name.
- `offerFor`: pool duplicates are removed; a pool of only the last played game still offers it.
- `settleVote`: offered ids that repeat count as one entry; a card id not offered is not a vote.

## Self-check
1. Host setups: not applicable, no host wiring; phone widths and both looks in choices_vote_test.
2. State: none kept; settleVote is pure.
3. Pause/away/results: not wired; the existing choices_screen_test covers pause; "timer reaches 0" test shows no pick.
4. Stayed in allow:.
5. No stop needed.
6. Menu and TV look: choices_vote_test groups, 3 sizes each.

## Questions
1. Should test_game export `arenaMapNames` so the copy can go?

## Hand-over
Wire `offerFor`/`voteSetup`/`settleVote` into the night flow once the owner decides when the vote runs.

## Commit message
Vote round rules and vote card texts for the host

Adds offerFor, voteSetup and settleVote (5 s, at most 4 games, ties
and no votes settled at random) and short vote card labels of at most 12
characters. A phone test shows four vote cards with details hold 48 dp
at 320x640, 360x640 and 667x375 in both looks. Not wired into a night.

## Status row
d2f: vote rules, card texts and phone vote test done; open: wiring the vote into a night (owner decision), export of arenaMapNames.

## Delete
- none
