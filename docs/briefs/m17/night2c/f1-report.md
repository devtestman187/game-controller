# night2c f1 report

## Files changed
- `packages/party_host/lib/src/night/night_vote.dart`: `ServerVoteHandle.dispose` completes `done` with an empty map when the round was not closed (it used to leave `done` pending).
- `packages/party_host/test/night_vote_test.dart`: tests for the timer close (item 2), dispose (item 4) and the default `voteStarterProvider` returning null for local/simulated-only rosters and for a non-server host (item 1). `setup()` takes a duration.
- `packages/party_host/test/night_pick_test.dart`: the vote picker test now uses a starter whose handle closes with a vote for the last offered card and asserts that game (item 3).

## Checks
`tools/mine.sh`: OK, 84 tests in packages/party_host, analyze clean.

## Computed values
- Timer test: round 100 ms (`_shortRound`), one pick of card 'b' before the close; expects outcome `_vote('b')`.
- Pick test: the voted card is `setup.cardsFor('phone-1').last`; 1 vote.

## Questions / suggestions
- I did not run the item-3 test against the old code (it ignored takeResult), so it is not confirmed to fail there. The vote picks the last card and the random fallback could coincide with it. The pick uses Random(1), so it is deterministic.
- The timer test uses the real clock (100 ms), like the rest of the ServerVoteHandle group.

## Commit message
night2c f1: vote engine tests, dispose completes done

ServerVoteHandle.dispose now completes `done` with an empty map when the
round has not closed. New tests: the default voteStarterProvider gives
null for local/simulated-only rosters and a non-server host; a round that
closes by its own timer completes done; the vote picker test asserts the
game its vote chose.

## Status row
f1: vote engine tests and the dispose leak done; nothing open.

## Delete
- none
