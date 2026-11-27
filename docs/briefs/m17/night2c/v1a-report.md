# night2c v1a report: the Vote engine

## Files changed
- `packages/party_host/lib/src/night/night_vote.dart` (new): VoteHandle, VoteStarter, ServerVoteHandle, voteStarterProvider, nightVoteDurationProvider, NightVoteState, NightVoteNotifier (run, takeResult, cancel), nightVoteProvider.
- `packages/party_host/lib/src/night/night_pick_provider.dart`: public `voteOffer()`, `NightPicker.vote => _votePick(round)`; host and rotating still null.
- `packages/party_host/test/night_vote_test.dart` (new): 10 tests (fake starter and a real HostServer with one capable phone).
- `packages/party_host/test/night_pick_test.dart`: `_loaded` takes optional overrides; 3 vote-picker tests.

## Checks
tools/mine.sh: OK, 72 tests in party_host, format and analyze clean.

## Computed test values
- Default pool has 7 variants (the brief said 6); the vote offers 4 (maxVoteCards), duration 5 s, secondsLeft 5 at start.
- Countdown: 4 after 1 s, 2 after 3 s (testWidgets fake clock).
- Votes 2/1 gives votes 2, byChance false; no votes gives votes 0, byChance true; 1-1 tie gives votes 1, byChance true.
- ServerVoteHandle: host pick 'a' gives ChoiceOutcome(a, 1, byDefault false); no pick gives ChoiceOutcome(null, 0, byDefault true).

## Questions
1. The brief says a 6-variant pool; the default pool is 7, so the test uses it (still capped at 4).
2. nightVoteProvider and nightPickProvider read each other lazily (no cycle at build time).
3. A vote that is cancelled while open never completes `run`'s await if the handle's done never completes; the guard ignores a late result.

## Suggestions
- v1b could call `run(round)` from the scoreboard and start card, and read `nightVoteProvider` for the countdown.

## Commit message
night2c v1a: Vote engine and the vote pick

NightVoteNotifier runs a 5 s vote on the phones through ChoiceRound and
OldPhoneChoices (ServerVoteHandle), settles it with settleVote, and keeps
the result for the round. NightPickNotifier.voteOffer and the vote picker
use it; with no vote run the pick is random. No UI or wire change.

## Status row
Vote engine and vote pick built and tested (night2c v1a); open: the vote UI, setup option and wiring into the scoreboard/start card (v1b).

## Delete
- none
