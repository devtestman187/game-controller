# Review of b020-solo-both (4440477)

## Summary

`small fixes` — 0 must, 3 should, 6 could.
Three that matter most:
- the card counts "solo" its own way (`_joined.length >= 2`) instead of the `skipsLobby` rule the brief named, and
  already disagrees with that rule's caller (`games_screen.dart:157`) on the host's own player.
- a second phone joining the solo card is untested, though it silently swaps a picked Race back to Bumper and hides
  the race button.
- the case named "the night goes on after it" never leaves the race, so the way out and the night's survival have
  no test.

## Findings

- **should** packages/party_host/lib/src/ui/arena_waiting_card.dart:196 `_bumperOnly` counts `_joined` as `>= 2`
  itself while `games_screen.dart:157-162` counts a night's players with the host's own player left out before it
  asks `skipsLobby` (`solo_skip.dart:13`), so a phone host playing here with one phone joined shows Bumper alone
  on the card and still gets a solo night's Shape Race → derive `_bumperOnly` from `skipsLobby` (or one shared
  helper) so both screens agree on what a solo night is.
- **should** packages/party_host/test/solo_arena_both_test.dart:66 nothing covers a second phone joining the card
  that is open, though that is the new count rule in action: the race button goes and a Race the host picked is
  replaced by Bumper without a word (`arena_waiting_card.dart:196-203`) → add a case that picks Race, joins a
  second phone, and asserts the race button is gone and Start plays Bumper.
- **should** packages/party_host/test/solo_arena_both_test.dart:69 the case's name says "the night goes on after
  it", but it stops at the race's first frames and never leaves the race, so the way out (Escape/Back, the report's
  self-check 3) and the night's next card are untested → leave the race and assert the night's start card is up
  again with Bumper, `round == 0` and `maps` still empty.
- **could** packages/party_host/lib/src/ui/game_screen.dart:203 a night's Race now gets `const []` for
  `_roundTags`, so metrics records it as a plain arena round and a night whose first round is a race starts later
  in the party-night report (metrics `night_xofy` tags) — a decision the report's Decisions list does not give →
  state it there, or tag the round as a night race and say so in N7.
- **could** packages/party_host/test/solo_arena_both_test.dart:90 this case passes on the old code (the report
  itself saw 2 of 3 fail), so it proves nothing new; it is the brief's guard, so keep it, but make it carry an
  assertion the change needs (the join swap above) or fold it into the `arena_night_test` pin.
- **could** packages/party_host/lib/src/ui/arena_waiting_card.dart:66 `night` is a `bool` that does not read as a
  question (guidelines §4) → `isNight`.
- **could** docs/design/party-night.md:192 the card's section does not say that a solo night's race is played alone
  (Robo is Bumper-only, `arena_waiting_card.dart:217`) nor what the card does when a second player joins after a
  Race pick → add one clause for each to section 8.
- **could** docs/briefs/m14/bugs11/b020-solo-both-report.md:51 the computed log for case 1 is "Playroom"; the run
  prints `Round started: arena, bumper, Toy Factory` → correct the value.
- **could** docs/briefs/m14/bugs11/b020-solo-both-report.md:62 self-check 1 says a phone playing here gets both
  buttons, but the only phone-host night test it cites (`arena_touch_ready_test.dart:110`) has two players and so
  never shows a phone host's solo card → add a solo case to that file, or say in the self-check that the phone
  host's solo card is untested.

## Decisions to confirm

- The card's count of a solo night (decision 1) and the night's Shape Race count (decision 1 vs `solo_skip.dart`) differ for a phone host playing here; which one is "solo" should be settled before both are relied on.
- Decision 4 (a solo night's race is unscored) also drops the metrics night tag (finding 4): confirm the metrics party-night report reading is what the owner wants.
- Not listed as a decision: a second phone joining an open night card returns the card to Bumper and hides a Race pick; confirm that is the intended behaviour of "a night of two or more plays Bumper alone".
- Open question from the report (does a solo race count as a night round; the lone player races alone): an owner answer is needed before section 8 and N7 can be called final.

## Could not check

- The new file's failure on the old code (needs a checkout); I ran it on HEAD: 3 pass.
- A real phone host's solo night card and its Ready line (no device, no such test).
- The "six named suites 55" figure; I ran `tools/check.sh host` instead (468 pass).

## Commit message

docs: review of b020-solo-both (three should, six could)

The review of 4440477 finds no must: the card, the screen and the docs agree
on a solo night's two modes. Three shoulds: the card counts a solo night its
own way instead of skipsLobby's, a mid-card join swaps a Race pick back to
Bumper with no test, and the "night goes on" case never leaves the race. Six
coulds cover the metrics night tag a race drops, the guard test that passes
on the old code, the `night` flag's name, two missing doc clauses and two
report values (case 1's map, the phone-host claim).

## Status row

M14 bugs11 b020-solo-both: reviewed at 4440477 (`small fixes`, 0 must, 3 should, 6 could). Open: the three shoulds, the metrics night tag, and the owner's call on whether a solo race counts as a night round.

## Delete

- none
