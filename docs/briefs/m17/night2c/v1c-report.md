# v1c report: the Vote on the TV

## Files
- `packages/party_host/lib/src/text/variant_text.dart`: VoteText gets voteNow, firstGame, secondsLeft(n), wins(name), byChance(name).
- `packages/party_host/lib/src/ui/night_vote_strip.dart` (new): NightVoteStrip over nightVoteProvider; open: call, seconds, offered labels; settled: winner line; nothing when null. No fixed height; wrapping Text in the look's body type.
- `packages/party_host/lib/src/ui/night_vote_screen.dart` (new): NightVoteScreen; cancel + run(1) post-frame; the settled result waits `nightVoteShowResultS` (2) s, then pops true; Back and any other pop cancel the vote and pop false.
- `packages/party_host/lib/src/ui/night_scoreboard_screen.dart`: post-frame `_startVote` (picker vote, night not over -> run(round + 1)); the strip sits under the scoreboard in a Column.
- `packages/party_host/lib/src/ui/night_start_screen.dart`: `_startNight` (which `_startPicked` goes through) opens NightVoteScreen first when the picker is vote; starts the night only on true.
- `packages/party_host/test/night_vote_screen_test.dart` (new): 9 tests, each in menu and TV look.

## Test values
- vote duration 5 s (`Duration(seconds: 5)`), round 1 on the start card, round 2 on the round-1-of-3 scoreboard.
- Result shows 2 s (`nightVoteShowResultS`); tests pump 3 s. Votes: 2 for offered[1] vs 1 for offered[0] -> offered[1]; 1 vote offered[2] on the scoreboard -> pick offered[2].
- Strip sizes: 360x640 and 960x540, both looks, open and settled; no exception.

## Self-check
1. TV/menu looks: all tests via forEachLook. Phone on "Play on this phone"/joined/old peer: not separately covered; the vote itself is v1a's (fake starter here).
2. Vote state starts on the vote screen or the scoreboard, ends when the next pick takes it or the night ends (v1a). Nothing happens with another picker or after the last round (tests).
3. Pause/host away/dropped link: not changed or tested; the vote is a 5 s timer in the notifier.
6. Strip has no fixed height.

## Questions
1. Back/system back on the vote screen is handled by PopScope; no separate test for system back.
2. The vote also runs when a night "left before round 1" is re-entered (a new vote each time).
3. `_startNight` holds the vote step, so it covers every start path; with picker vote only `_startPicked` is on screen.

## Commit message
night2c v1c: the vote on the TV, round 1 and later rounds

New NightVoteStrip and NightVoteScreen. With the vote as picker the start
card opens the vote screen first (Back starts no night), and a scoreboard
between rounds starts the vote for the next round and shows the strip.
New VoteText strings. Tests with a fake VoteStarter.

## Status row
v1c: vote screen on the start card and vote strip on the scoreboard done; open: phone-side wiring and pause/away cases untested.

## Delete
- none
