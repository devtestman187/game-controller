# pr-arena — proposals for the owner's three change requests (report only)

Job: M14 bugs3 pr-arena. No code was changed; the only file written is this one.
Read for it: docs/design/party-night.md §5, §7, §7b, §8; docs/PRD-v2.md M14 (G3, G9, the
Bumper Round bullet); the code each item names.

## Summary

- **B-005 (the dropper's coin):** the lockout is real and permanent — `_takeCoins` in
  `arena_bumper.dart` skips every coin whose `dropper` is the marble, for its whole life. The PRD
  does not ask for it (G9: "one coin beside it for anyone to grab"); only party-night §7 and a test
  do. **Pick:** the dropper may take its own coin back 2 s after it lands (1 s dizzy + 1 s safe),
  while anyone else may take it at once, as today. Risk: a hazard then costs almost no coin, so the
  drop loses most of its bite; the 2 s and the steal window are what is left of it.
- **B-006 (the cat):** there is only one cat — Shape Race's `CatChaos`. The Bumper Round has none,
  so "even in Party mode" is the Chaos setting's Party level. Today Party gives 2 visits a round
  (one about every 42 s in a 120 s round) and one knock. **Pick:** Party gets 3 visits and up to
  2 knocks, and the numbers move into a named preset (`CatPreset`: Calm / Lively / Wild) saved
  with the other Puzzle settings; all of the PRD's safety limits stay. Risk: two placed pieces can
  go back to the tray in one round for the side ahead, which is the side that has done well.
- **B-015 (race maps):** the kit and picker already take a map with both modes, so reusing a Bumper
  map needs only a `race` section — no code. **Pick:** add a race to **Block Castle** (finish on the
  keep's floor) and **Toy Factory** (finish bay in the top corner); leave Pinball and Spinning Tops
  as Bumper-only. Risk: an open arena makes a thin race — the shortest way is a sprint past hazards
  — so the owner should see the two renders before this lands.
- Conflicts with the design are stated in each proposal (B-005: party-night §7; B-006: PRD G3 and
  party-night §5; B-015: party-night §7b's "the race stays on the Playroom").
- Checks: `tools/check.sh format`. No computed expectation exists yet because no code changed; the
  values this report uses (2 s; 85.2 s / 42.6 s / 28.4 s; 1.53 / 2.23 marbles) are shown in place.

## Decisions (low-usage mode)

- B-005: a 2 s lock rather than none — it keeps the hazard's cost and gives the others the 2 s
  steal window that makes the scatter fair, and it reuses timers the game already has.
- B-006: a preset setting with one table, rather than a hidden developer screen — the Puzzle
  settings already save a Chaos level the same way, a test can pick a preset, and no shipped
  branch depends on the build mode.
- B-015: two of the four maps, with no geometry edits — a race section alone passes the map rules
  and leaves the Bumper play of those maps exactly as the owner has played it.
- No design decision needed beyond the three below; nothing was blocked.

### B-005 — a marble may take back the coin it dropped (Bumper Round)

**Today:** `_BumperGame._takeCoins` (`arena_bumper.dart` 102-121) skips a coin for its whole life while `coin.dropper == p.id`, with no timer. No PRD row asks for it — G9 says a drop leaves "one coin beside it for anyone to grab"; party-night §7 ("takable at once by anyone but the dropper") and `arena_coin_rules_test.dart`'s "the dropper can't take it back" do.
**Change:** a dropped coin may be taken by its dropper **2 s after it lands**; for those 2 s it is anyone's but the dropper's, as today, so the scatter stays fair. 2 s is `ArenaFieldRules.dizzyS` (1 s, no dash) + `safeS` (1 s, drops nothing), so the owner picks it up as its safety ends. The drop still costs a coin, a dash and 2 s, and a coin taken back can be dropped again.
**How:** in `_takeCoins`, `if (coin.dropper == p.id && coin.ageS < dropLockS) continue;`, with `static const double dropLockS = ArenaFieldRules.dizzyS + ArenaFieldRules.safeS;` beside `dropGapShare`. No protocol change: the frame already carries `ageMs` and the dropper's seat, so the snapshot version stays 2.
**Tests:** rewrite the test above as "the dropper takes its dropped coin back after 2 s, and not before": b drops, stands on it for 114 steps of 1/60 s (1.9 s) — `b.coins` stays 1; at step 120 (2.0 s) it is 2 and no `dropper == 'b'` coin is left. Add "another marble takes a dropped coin at once" (b at 0.1 s) and "a coin taken back by its dropper can be dropped again".
**Files:** `arena_bumper.dart`, `arena_coin_rules_test.dart`; party-night §7's coin sentence with the code. **Risk:** see the Summary; `dropLockS = 0` is the owner's "no penalty" answer and needs nothing else.

### B-006 — the cat comes more often on Party, and its numbers get a name

**Which cat:** the only one is `CatChaos` in `puzzle_game` (Shape Race; PRD G3, party-night §5). The Bumper Round has none ("The cat stays in Shape Race"), so "even in Party mode" is the Chaos setting's Party level (`PuzzleSettings.chaos`, Puzzle settings on the host, default A little in a night).
**Today:** `_plan()` (`cat_chaos.dart` 175-189) plans 1 visit on A little and 2 on Party, each visit 4.8 s (`CatRules.visitS` = 2 + 1.2 + 0.4 + 1.2), spread over the round less its first 20 s and last 10 s, with at most one knock a round. In the 120 s default round that is a window of 85.2 s, two shares of 42.6 s, so **a visit about every 42 s** (9.6 s of 120 on screen). It is planned once, in the constructor, from `settings.timeLimitS`.
**Change:** on Party, **3 visits and up to 2 knocks**.
- visits: a share of 28.4 s (85.2 / 3), so a visit about every 28 s (14.4 s of 120). A little stays at 1, which the PRD fixes.
- knocks: `_mayKnock` takes `_knocks < tuning.partyKnocks` in place of `!_knocked`. Every other limit stays as the PRD has it: only the side ahead by at least one piece (so a second knock on one side needs it still ahead), never the picture's last piece, never one placed in the last 3 s, the side keeps its points, never the same side twice in a row. The 2 s warning and the shoo are unchanged.
**Tuning:** `cat_tuning.dart` holds one table, as `CpuPilot` does for Robo: `CatPreset { calm, lively, wild }` × (A little visits 1 / 1 / 1, Party visits 2 / 3 / 4, Party knocks 1 / 2 / 3). A `catPreset` field on `PuzzleSettings` is saved by name (unknown names fall back, as `chaos` does) and shown as a "Cat" row beside Chaos: **Calm / Lively (new default) / Wild**. A test picks it through the settings `CatChaos` already takes; for a device test a debug-only `--dart-define=CAT_PRESET=wild`, read in the host's provider as `SHARE_VIEW` is (`party_host/lib/src/providers.dart:74`), overrides it. No hidden screen, no build-mode branch in `puzzle_game`.
**Files:** `cat_tuning.dart` (new), `cat_chaos.dart`, `settings.dart`, `puzzle_settings_screen.dart`, `host_text.dart`, tests. **Tests:** `cat_test.dart`'s Party count in a 40 s round and its prose; new "on Party the cat knocks two placed pieces loose in a round" and "Calm brings 2 visits, Wild 4". The cat's snapshot fields do not move.
**Conflict:** PRD G3 says Party comes "at most twice a round" and knocks "once a round"; party-night §5 repeats it, and the acceptance bullet "On Party a placed piece it knocks loose goes back to the tray" should say twice. All change with the code; nothing else in G3 moves. **Risk:** two placed pieces can go back in one round for the side ahead — but only that side, and it keeps its points.

### B-015 — more Race maps: two of the four Bumper maps can carry a race

**What a race needs:** a `race` section (start, goal, swapSides), a clear start column for four slots (`startSpacing` 0.14 → 0.42 of the height), a way from every start to the goal both ways at least 1.6 marbles wide, no hazard sweeping a start or the goal's mouth, and no spring, post, belt or mover's sweep on a start (the map rules' race and piece checks).
- **No code:** `mapForRound` and `arena_map_choice.dart` already offer only maps with a `race` for the race, so a map with both sections plays both modes and "Surprise me" uses it at once. A night plays Bumper rounds only (party-night §8), so these races serve the Arena outside a night.
- **Block Castle — yes.** `"race": {"start": [0.075, 0.5], "goal": [0.4625, 0.444, 0.5375, 0.556], "swapSides": true}`: a finish on the keep's floor — in through a castle gate, across the courtyard past the left cannonball, into the keep through a gate. Nothing moves, and the symmetric goal lets the mirrored round race back into the same keep. By eye: gates 0.1428 of the height between wall faces (2.23 marbles, over 1.6, under the 2.5 aim); the hazards (x 0.2813 sweeping y 0.2444-0.7778, y 0.2778, y 0.8) reach no start nor the goal's inner part (x 0.4805-0.5195, y 0.476-0.524); the keep-gate movers' sweeps stay off the goal; starts 0.139 from the corner posts against a 0.072 reach.
- **Toy Factory — yes.** `"race": {"start": [0.1, 0.5], "goal": [0.88, 0.14, 0.97, 0.24], "swapSides": true}`: over the belt loop (belts carry at half speed), round the two walls, up the east side into a finish bay with the crate hazard on its rim. The goal sits above the press's sweep (x 0.75-0.93, y 0.37-0.63) and east of the x 0.84 wall; the hazard's sweep (x 0.622-0.838, y 0.122-0.198) stops short of the goal's inner part (x 0.898-0.952); starts x 0.1 are 0.107 from the belt's line against a 0.077 reach.
- **Pinball — not now.** A race passes above the posts (their faces leave 1.53 marbles, under the 1.6 rule, and the rule grid does not see posts so `check` would pass a squeeze) or between the flippers over the drain, whose still hazard sends a marble back to its start. Fixing it means respacing the posts and changing the Bumper play; a new race map is cheaper.
- **Spinning Tops — no.** The carousel sweeps the middle (0.3556 round the centre), so a start at y 0.5 on the west edge sits in its sweep (the bumper starts dodge it at 0.456; a four-slot column cannot), and a race outside its circle is a lap with no hazards.
**Besides the section:** `notes` loses "No race section."; docs/levels.md's Arena part and party-night §7b's "the race stays on the Playroom" change with it; `tools/level.sh check` then `render` (the `docs/design/maps/` pictures are generated and change). The schema and parser already take `race`, so the format stays 1. **Tests:** the rule book over the library (`map_check_test`), a race-play test on each map (slot 0 to the goal, and slot 0 mirrored), the render and picture tests, `four_maps_test`'s "Bumper-only" lines. **Risk:** an open arena makes a thin race — the design's worry in reverse ("a corridor makes a dull bumper arena") — and all four starts share one x, so the start is a shove at the gate; the routes need the owner's look at the renders.

## Questions

1. B-006: should the new numbers be Party's default (my pick, with PRD G3 and party-night §5 edited),
   or a fourth Chaos level that leaves Party as it is so a family can step back down?
2. B-005: is 2 s what the owner means by "allowed", or does the coin come back at once? It is one
   constant (`dropLockS`), so either answer is a small job.
3. B-015: is the keep's floor the right finish for Block Castle (a gold coin zone sits just beside
   the pad), and does the owner want Pinball's posts respaced for a race later?

## Self-check (review-rules part A)

No code was changed, so the five checks (host setups, kept state, combining states, this folder
only, stop rather than overstep) have nothing to hold against; the only write is this report.

## Commit message

M14 bugs3: proposals for coin pickup, the cat and race maps

Report only, no code. Answers the owner's three changes: a Bumper marble may take back the coin it
dropped after 2 s (dizzy + safe), while anyone else may still take it at once; the Shape Race cat
comes 3 times and knocks twice on Party, with the numbers in a named preset (Calm / Lively / Wild)
saved beside Chaos; and two of the four Bumper maps, Block Castle and Toy Factory, can carry a race
with a race section and no geometry change, so the Arena's Race mode gains two maps.
Pinball and Spinning Tops stay Bumper-only; the reasons, the values and the design and PRD lines
that move are in docs/briefs/m14/bugs3/pr-arena-report.md.

## Status row

B-005, B-006 and B-015 (bugs3 pr-arena) are proposed in full: a 2 s take-back for a dropped coin, the cat at 3 visits and 2 knocks on Party with a Calm/Lively/Wild preset, and race sections on Block Castle and Toy Factory. Open: the owner's OK (and the three questions), then the code jobs, with PRD G3/G9 and party-night §5/§7/§7b updated alongside.

## Delete

- none
