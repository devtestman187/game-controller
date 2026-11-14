# pr-party review — the B-002 proposal, checked against the code

## Summary

**small fixes.** The B-002 pick stands and every code citation checks out: the join screen's away
filter and own-player gate (`join_screen.dart:151-154`, `:271`), the pushes (`games_screen.dart:141-142`),
the round buttons (`night_start_screen.dart:68`, `night_scoreboard_screen.dart:127`), the harnesses
(`night_round_test.dart:16-26`, `night_reveal_test.dart:130-134`) and `MatchFormat.of` returning `solo`
for one team (`match.dart:37-40`). The fixes are to three claims about the documents and one test gap.
- must 0 · should 3 · could 3
- The conflict paragraph asks for a §4 amendment to text that does not exist: party-night §4 never names
  the join screen (`party-night.md:61-62` says only that Change teams is replaced by Next).
- The PRD line the report calls unchanged is quoted short: G2 also says "Teams may change between
  rounds" (`PRD-v2.md:168`), the clause nearest this change.
- The one decision with host-specific behaviour — the host's own player counts only when the host shares
  its view (`pr-party-report.md:14`) — has no test among the four proposed (`:27-31`).

## Findings

- **should** docs/briefs/m14/bugs3/pr-party-report.md:33 says party-night §4 "repeats the join screen each round" and asks for §4's "After each round" to be amended, but that bullet and the Scoreboard one (`party-night.md:61`, `:62`) never name the join screen — they only replace Change teams with Next → cite line 61 for what §4 does say and either drop the §4 amendment or aim it at that sentence.
- **should** docs/briefs/m14/bugs3/pr-party-report.md:33 says "Nothing in the PRD changes: G2 only asks that players may come and go and start at 0", but G2 also says "Teams may change between rounds" (`PRD-v2.md:168`) → quote that clause and say team change still happens whenever two players are present, with only the one-player pick skipping the screen.
- **should** docs/briefs/m14/bugs3/pr-party-report.md:27 lists four tests but none covers the rule at `:14` (the host's own player counts only when the host shares its view), so a phone host on "Show on this device" starting a solo round for its viewer would go unguarded → add "a phone host showing the game still gets the join screen": one roster player, `shareView` false, `JoinScreen` found.
- **could** docs/briefs/m14/bugs3/pr-party-report.md:26 calls the branch "reusing the join screen's own filter (`join_screen.dart:151-154`, `271`)", but that filter is an inline list inside `_tick` and a private getter, so the branch would copy the rule → name one small shared helper (players who can take a side: not away, the own player only when sharing) that both screens use.
- **could** docs/briefs/m14/bugs3/pr-party-report.md:26 puts the branch in `_play` at "~6 lines", but `_play` takes no `ref` (`games_screen.dart:141-142`) and the file does not import `puzzle_screen.dart` → say the job also changes `_play`'s signature and adds one import.
- **could** docs/briefs/m14/bugs3/pr-party-report.md:43 answers part A's five checks in one line, where review-rules A asks one line each with its test → five one-line answers ("not affected, report only" is fine for A4 and A5).

## Decisions to confirm

- Per-pick skipping (`pr-party-report.md:13`): safe as written, but it means a second phone joining mid-night changes the next round's screens — the owner should know round N+1 can open differently from round N.
- Round 1 too (`:22`, Question 2): on a phone host in "Play on this phone" the player never sees the join screen in a solo night, which is more than the owner's "between rounds".
- Leaving the Bumper waiting card alone (`:15`, Question 1) matches the owner's words; if they meant every between-round screen, this is the b2 change the report names.
- Starting with no ready beat (`:16`): a TV host's only player gets no "press Start" and can miss the opening seconds — stated as the risk, so the owner should accept it knowingly.

## Could not check

- Behaviour on a real TV host, phone host and joined phone: the branch is code yet to be written, so only the report's plan was read.
- Whether a phone joining mid-round in a Shape Race night today really waits for the next round: `PuzzleScreen` fixes `widget.teams` when it is built (`puzzle_screen.dart:50`, `:59`), which supports the claim, but I ran no device test.
- `tools/check.sh format`: the range `af81..a5ea` changes only this markdown report, so the PASS claim holds without running it; I ran no Dart.

## Commit message

Review pr-party: B-002 pick stands, three claims need fixes

Report only, so the review checks the proposal's claims against the code.
The pick is sound: the join screen is the only route from the puzzle card
(`games_screen.dart:141-142`), one team makes `MatchFormat.solo`, and the
harnesses the report names are the ones a skip breaks. Corrections: party-
night §4 does not repeat the join screen (`party-night.md:61`), PRD G2 also
says "Teams may change between rounds" (`PRD-v2.md:168`), the "Show on this
device" rule has no test, and the filter it "reuses" would be a copy.

## Status row

B-002 (bugs3 pr-party) reviewed: the proposal's pick and code citations hold (0 must, 3 should, 3 could); open: the §4/PRD wording, the "Show on this device" test, and the owner's OK on the four decisions, then the code job in `games_screen.dart`.

## Delete

- none
