job: read-only scan: what the party features (docs/party-ideas.md sections 1 to 3) would touch in the code and the docs, to plan them as M14
stop: after the report.
read: docs/party-ideas.md · docs/PRD-v2.md (the roadmap, M13, M14, Puzzle game design, Analytics, Test strategy, Risks) · docs/protocol.md · docs/design/look-and-sound.md (sections 5a, 8) · docs/code-health.md · packages/puzzle_game/lib · packages/game_kit/lib · packages/party_host/lib · packages/protocol/lib · controller_app/lib/src (host, haptics, sounds, settings) · docs/briefs/m13/STATUS.md

Owner, Nov 8, 2026: "Yes let's plan for this content in M14." The content is the party ideas: the cat and other chaos events, power-ups, points, party nights, end-of-night awards and on-device leaderboards. The PRD's current M14 ("Fun, content and the first outside playtest") already lists some of the same things (nicknames C20, the best-times board T15, celebration, results on joined phones).

Answer each, with file:line references:
1. **Rules.** Where a chaos event or a power-up would live in Shape Race's rules: the game loop and its tick, how pieces move, how events (`PuzzleEvent`) are made, the random source and seeding, what a round's start and end look like. What must not change (tolerances, the locked-piece rule).
2. **The snapshot and the protocol.** What a joined phone sees today (`PuzzleSnapshot`, `MatchSnapshot`). What a cat, a power-up star, points pop-ups and a scoreboard would need added. Which fields are versioned or optional, and how an older phone copes with an unknown field (docs/protocol.md's rules on compatibility).
3. **The phone.** How the phone learns its labels and shows a status today (labels from the game, `StatusMessage`, haptic events). Where "what you got" for a power-up and its buzz would come from.
4. **Points and awards.** What is recorded per player in a round today (game.dart counters such as wrongDrops, `puzzle_report.dart`, the stats summary). Which award (Cat Catcher, Best Helper, Sharpshooter, Speedy Snapper) could be worked out from what is already counted, and which need new counters.
5. **A party night.** How rounds follow each other today (Rematch, Next puzzle, Change teams, the results card, the join screen). Where a set of 3 or 5 rounds, a scoreboard between rounds and a final awards show would sit in the host's flow.
6. **Storage on the host.** What is stored on the TV or host phone today (shared preferences, stats files, best times if any) and where an all-time hall of fame would go. Who a player is across sessions today (controller ID, nickname plans C20).
7. **Settings.** Puzzle settings today, and where a Chaos setting (Off / A little / Party) would go, on the TV and on the phone host.
8. **Sound.** What the sound player can do today and what M13 step 7 adds (design section 8), for the meow, points, fanfare.
9. **Overlap with the PRD's current M14**: for each of its scope bullets, say whether it is party content, setup for it (nicknames, best times), or unrelated (the 9 puzzles, the playtest, licences, the v3 recommendation).
10. **Risks**: anything in the code that makes these features hard: performance with 4 players, the rule that a joined phone is drawn only from snapshots, the m12 away/pause rules, review-rules.md part A.

In the report: one section per question, short bullets with file:line; then "Suggested M14 cut": the smallest first step that gives a party night feel (as party-ideas.md's last line suggests) and what could wait. Keep it under 250 lines.
allow: docs/briefs/m14/scan-party-touchpoints-report.md
report: docs/briefs/m14/scan-party-touchpoints-report.md
