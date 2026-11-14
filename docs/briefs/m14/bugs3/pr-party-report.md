# pr-party — proposal for the owner's join-screen change (report only)

Job: M14 bugs3 pr-party. No code was changed; the only file written is this one. Read for it: docs/design/party-night.md (N6, §4, §8), docs/PRD-v2.md "Milestone 14" (G2, T13) and the round flow code named below.

## Summary

- **B-002 (skip the join screen with one player):** today every Shape Race round of a night goes scoreboard → puzzle pick → `JoinScreen` (side pick + Start) → round, even when one person is playing. **Pick:** in a night with exactly one player, a puzzle card starts the round itself, with that player on a solo board; the choice is made at each pick, so a second phone that has joined by then gets today's join screen. Risk: on a TV host a guest is no longer asked to press Start, so the round can begin while they aren't looking; the pairing code was never on the join screen, so nothing about adding friends is lost (the scoreboard/card is unchanged).
- The design says the opposite for every round (party-night §2 N6); B-002 states the one-sentence amendment and the files whose comments echo it.
- Checks: `tools/check.sh format` — PASS (no Dart changed, so it only re-reads the existing packages).

## Decisions (low-usage mode)

- Skip decided at each pick, not once when the night starts — a friend who joins after the night began is picked up by the very next Shape Race pick, and nothing new is stored on the night.
- Count only players who can take a side (not away; the host's own player only when the host shares its view), reusing the join screen's own filter (`join_screen.dart:151-154`, `271`) — a phone host that only shows the game never starts a solo round for its viewer.
- Leave the Bumper Round's waiting card alone — it is not the screen the owner named: it holds the pairing code (`arena_waiting_card.dart:220`), the map choice and Robo's level, and its ready press is the only way to pick them.
- Start the round at once rather than add a one-tap ready card — the owner asked for no screen, Shape Race has no ready beat today, and the Arena's 3-2-1 belongs to the Arena (design §8).
- Keep the puzzle pick — the host still chooses the puzzle each round (N6); only the join/teams step goes.

### B-002 — a one-player night round skips the join screen

**Today (player-visible):** in a night, Shape Race is picked for round 1 on the start card (`night_start_screen.dart:68`) and for later rounds on the scoreboard (`night_scoreboard_screen.dart:127`); both push `ShapeRaceScreen`, and its puzzle card pushes `JoinScreen` (`games_screen.dart:141-142`). The single player presses A to join and A/Start to begin (`join_screen.dart:222-252`, 288) before every round: three screens and two presses per round.
**Change:** when a night is running and exactly one player is playing, pressing a puzzle card opens the round itself — `PuzzleScreen` with `teams = {playerId: PuzzleSide.left}` (a solo board, exactly as today's solo) — with no `JoinScreen` and no join/Start presses. With two or more players nothing changes: the join screen appears so teams can change, as the design asks. Outside a night nothing changes.
**Why:** the join screen's only jobs are joining phones and picking sides; with one player there is nobody to wait for and one place to go, so it adds a screen and two presses every round — five extra screens and ten presses in a five-round night.
- **Late join:** the rule is decided per pick. If a phone has joined by the time the host presses Shape Race, there are two players, so the join screen comes back as today, the newcomer picks a side there, and the scoreboard shows them at 0 (design §4). A phone that joins *during* a solo round waits for the next round — as a mid-round joiner does today, and as the Bumper card already promises ("Joins next round", §8); a running round's teams never change.
- **Adding friends:** pairing is untouched. A new phone pairs with the host's code from the TV's home screen or the phone host's bar chip (`controller_app/lib/src/ui/host_chip.dart`), then appears on the scoreboard, which is what tells the host to pick a round they can join. The join screen never showed the code, so skipping it loses no way in. Optional, not in this fix: the scoreboard card could wear the Arena's code chip (`arena_waiting_widgets.dart:221`) while seats are free — I'd leave it, since frame 4 was approved without it.
**Where:** `ShapeRaceScreen._play` (`games_screen.dart:140-142`, already a `ConsumerWidget` with the night and providers imported) gains a short branch: if `partyNightProvider != null` and the playable roster holds exactly one player, push `PuzzleScreen(choice: choice, teams: {id: PuzzleSide.left})` instead of `JoinScreen`. `MatchFormat.of` then returns `solo`. No new type, no new field on the night, no protocol change.
**Tests** (`packages/party_host/test/night_round_test.dart` unless named):
- "a one-player night round skips the join screen and starts solo": roster `['p1']`, night running, press Shape Race, tap the house puzzle → `find.byType(JoinScreen)` finds nothing, `find.byType(PuzzleScreen)` finds one, teams `{'p1': PuzzleSide.left}`, `MatchFormat.of(teams) == solo`, `PuzzlePlayView.settings().night == true`.
- "two players still get the join screen": roster `['p1','p2']` → after the pick `JoinScreen` finds one and `PuzzleScreen` none; after `startRace` (p1 left, p2 right, p1 Start) the format is `oneVsOne`.
- "a phone joining late gets the next round's join screen": start the solo round, add `p2` to `TestRoster` mid-round → the running round's teams stay `{'p1'}`, and the next Shape Race pick shows `JoinScreen`.
- Update the harness callers: `openNightRound` (`night_round_test.dart:15-26`) and `night_reveal_test.dart:130-134` drop `startRound` (two A presses), which would now be swallowed by the running round.
**Files:** `packages/party_host/lib/src/ui/games_screen.dart` (the branch; ~6 lines); tests `night_round_test.dart`, `night_reveal_test.dart`; design text party-night §2 N6 and §4, plus the comments that repeat it in `night_start_screen.dart:28-30` and `puzzle_screen.dart:227-229`. **Risk:** an immediate start means a TV host's guest isn't asked to press Start and may miss the opening seconds; and if the owner also means the Bumper waiting card, that is a b2 change (the card must keep the code, map and Robo level), not this one.
**Conflict with the design:** party-night §2 N6 says "Shape Race then goes through its puzzle pick and join screen (teams may change there)" and §4 repeats the join screen each round. Amend N6 to "…its puzzle pick; with two or more players joined, its join screen (teams may change there)", and §4's "After each round" the same way. Nothing in the PRD changes: G2 only asks that players may come and go and start at 0.

## Questions

1. B-002: does "join screen" include the Bumper Round's waiting card (pairing code, map, Robo's level, ready press)? I left it as it is; skipping its ready press would be a small change in b2.
2. B-002: applying the skip to round 1 too (the start card) is my pick, so a phone host in "Play on this phone" never sees the join screen at all. Say if round 1 should keep it.
3. B-002: add the pairing-code chip to the scoreboard while seats are free (the Arena card's chip), or keep frame 4 exactly as approved? I picked "keep".

## Self-check (review-rules part A)

No code was changed, so the five checks (host setups, kept state, combining states, this folder only, stop rather than overstep) have nothing to hold against; the only write is this report.

## Commit message

M14 bugs3: proposal to skip a one-player night's join screen

Report only, no code. Answers the owner's request: in a party night with
one player, a Shape Race puzzle card now starts the round straight away
on a solo board, with no join/teams screen between the rounds; with two
or more players the join screen stays, so teams can still change.
A phone joining late gets the join screen from the next pick, and the
pairing code stays where it always was (the TV's home screen and the
phone host's bar chip). Design: party-night N6/§4 amended for a solo
roster. Tests: skip, two-player, and late-join widget tests.

## Status row

B-002 (bugs3 pr-party) is proposed in full: a one-player Shape Race night round skips the join screen (decided per pick, solo board, late joiners get the next pick's join screen); open: the owner's OK on the three questions, then the code job in `games_screen.dart` with party-night N6/§4 amended.

## Delete

- none
