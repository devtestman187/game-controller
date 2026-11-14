# M14 bugs3 — the run's review

## Summary

**needs Claude's design.** The code the run committed holds up: the still-parts and path caches, the bar rule, the
flag order, the TV scale and the phone OK all work, and the tests pass (puzzle_game 400, the two touched party_host
files 20, 16 changed Dart files format-clean). What is not settled is two calls only the owner can make, plus one
batch of report corrections that would otherwise become wrong briefs.
- must 2 · should 17 · could 28
- The Arena waiting card still reads only A and B, so a phone cannot work it at all — B-013, a Blocker, is probably
  still open, and i1's job saw it and left it out (`arena_waiting_card.dart:110`, `game_screen.dart:310`).
- B-004's fix protects the music's voice on a cause nobody measured ("Pinball fills the 16 voices"), so it changes
  how every loop is stolen in every mode, and a busy Pinball round now loses effects instead (`sound_loop.dart:66`).
- a1's five B-004 music tests landed in i1's commit, so no commit in the run matches its report
  (`a1-pinball-flags-report.md:20`).
- The still-parts key leaves out the canvas scale on the match path, where the painter gets a box in field units:
  a resized window or a rotated phone keeps the old ink widths until the next lock (`board_cache.dart:129`).
- Each phone A press lifts the OK before the press only, so every phone press leaves the button held and the next
  TV-remote OK on it is swallowed (`controller_menus.dart:263`).
- Owner: is the waiting card part of B-013, and is losing a busy Pinball round's bumper sounds the right price for
  keeping its music?

## Findings

- **must** packages/party_host/lib/src/ui/arena_waiting_card.dart:110 the card reads only A and B from the pads (`_keysOf`) and `game_screen.dart:310` keeps the menus off during that stage, so no phone can move the focus or press the mode, map or Start rows — B-013's "cannot control TV menu at all" is still open for the one Arena menu a phone cannot work → give the card the pad's directions (or hand its buttons back to `ControllerMenus`) and test a phone picking a mode and pressing Start. (from: i1-ok-presses review)
- **must** docs/briefs/m14/bugs3/a1-pinball-flags-report.md:20 lists `round_music_test.dart` as this job's file, but its 16 lines landed in `c4e4e00` (i1's commit), whose report does not mention them, so no commit in the run matches its report → say in a1's report that the tests are outside its commit and add them to i1's, or move them in a follow-up commit whose report claims them. (from: a1-pinball-flags review; across jobs)
- **should** packages/party_host/lib/src/sound_loop.dart:66 protects the loop's voice on the assumption that a busy map fills SoLoud's 16 voices, which nothing in the repo or the report measures, and it changes how every loop is stolen in every mode → measure `getActiveVoiceCount` or voice steals on a device Pinball round before calling B-004 fixed, and say in the report what is lost instead. (from: a1-pinball-flags review)
- **should** packages/party_host/lib/src/ui/controller_menus.dart:263 the OK is lifted before `Actions.maybeInvoke` and never after it, so every phone press leaves the focused button's `_isKeyHeld` set and the next OK from the TV remote on that button does nothing until its own release → lift again after the invoke (or in a `finally`) so no press path leaves a button held. (from: i1-ok-presses review)
- **should** packages/puzzle_game/lib/src/board_cache.dart:129 `stillKey` keys the board, box, field, look and piece flags but not the canvas's px, while the still parts bake in `_styles(px)` and the match paths pass a box in field units (`match_painter.dart:134`, `:196`) that does not change when the window does → add the canvas's px (or `_pxPerUnit`'s value) to `StaticBoardKey`. (from: p2-coop-fps review)
- **should** packages/puzzle_game/test/board_cache_test.dart:58 only the `filled` part of the key is ever derived from a snapshot (the fourth test, line 158); `hints`, `ready`, `lockedMoving` and `glowAgeMs` appear only as hand-built keys in test 1, which tests `==` rather than `stillKey` → paint a cached `PuzzlePainter` over two snapshots and assert a second record when a hint, a ready target or the finish glow appears. (from: p2-coop-fps review)
- **should** docs/briefs/m14/bugs3/run-findings.md:1 the review of s1-progress-bar was never written, so B-001 (five files in `puzzle_game`) shipped on its worker's self-check alone → write it or record s1 as self-checked in STATUS.md; reading it here, its only code note is the duplicated done rule below. (from: run-findings; across jobs)
- **should** docs/briefs/m14/bugs3/a2-arena-size-report.md:13 names `packages/test_game/lib/src/arena_player_scale.dart` as the new file, but the commit adds `arena_player_scale_painter.dart` → correct the path. (from: a2-arena-size review)
- **should** docs/briefs/m14/bugs3/a2-arena-size-report.md:76 says "No other file changed", but three `tv_test_app/windows/flutter/generated_plugin_*` files are still modified in the tree (s1's report, lines 46 and 74, says the suites rewrite them) → revert them before the next commit and say so; a `git add -A` carries them now. (from: a2-arena-size review; across jobs)
- **should** docs/briefs/m14/bugs3/a1-pinball-flags-report.md:33 gives only "the arena + phone suites pass" for the brief's `format analyze arena host phone tv`, `pr-arena-report.md:28` names `tools/check.sh format` without a result, `pr-shape-report.md:158` has no check line, and `s1-progress-bar-report.md` has none for `format analyze puzzle host` → one line per `check:` entry with pass or fail in each report. (from: a1, pr-arena, pr-shape reviews; across jobs)
- **should** docs/briefs/m14/bugs3/pr-arena-report.md:58 says `cat_test.dart`'s Party count in a 40 s round rises to 3, but a 40 s round leaves 10 s between `CatRules.graceS` and `tailS` and three 4.8 s visits need 14.4 s, so `_due` drops the third → keep 2 visits in the 40 s test and pin the new count with a 120 s-round test. (from: pr-arena review)
- **should** docs/briefs/m14/bugs3/pr-arena-report.md:68 rejects Spinning Tops because a start at y 0.5 sits in the carousel's sweep, but a spin mover's bar reaches x 0.3-0.7 at most and the map has no walls, so `checkMap` would pass it → give the real reason (the only sane finish is the post, inside the sweep, which no rule checks). (from: pr-arena review)
- **should** docs/briefs/m14/bugs3/pr-arena-report.md:58 lists `host_text.dart` for B-006 but not the line that becomes false: `chaosLine` says "on Party it also knocks one placed piece back to the tray" (`host_text.dart:210`) while Lively gives up to 2 → name that line in Files and in the Change. (from: pr-arena review)
- **should** docs/briefs/m14/bugs3/pr-party-report.md:33 says party-night §4 "repeats the join screen each round" and asks for its "After each round" bullet to be amended, but that bullet and the Scoreboard one (`party-night.md:61`, `:62`) never name the join screen → cite line 61 for what §4 does say and drop or re-aim the amendment. (from: pr-party review)
- **should** docs/briefs/m14/bugs3/pr-party-report.md:33 says "Nothing in the PRD changes: G2 only asks that players may come and go", but G2 also says "Teams may change between rounds" (`PRD-v2.md:168`) → quote that clause and say team change still happens whenever two players are present. (from: pr-party review)
- **should** docs/briefs/m14/bugs3/pr-party-report.md:27 lists four tests but none covers the rule at `:14` (the host's own player counts only when the host shares its view) → add "a phone host on 'Show on this device' with one roster player still gets the join screen". (from: pr-party review)
- **should** docs/briefs/m14/bugs3/pr-shape-report.md:53 gives a repeat by the third round of 20% and by the fourth of 36%, but `avoidPuzzleId` is passed only by `_rematch` (`puzzle_screen.dart:277`) while the round after "Change teams" is built with none (`join_screen.dart:293`), where a repeat is 1/6 → say the guard covers rematches only, give the join-path odds, and fix the Decision at :40 that leans on it. (from: pr-shape review)
- **should** docs/briefs/m14/bugs3/pr-shape-report.md:18 says both timings "reach the report through `gameStats` with no report change", but :90-92 adds moving and placing columns and a derived share to the per-player table, and nothing in `packages/metrics` reads `gameStats` keys → say the summary JSON gets them for free and name the table work, or drop the table claim. (from: pr-shape review)
- **should** docs/briefs/m14/bugs3/pr-shape-report.md:119 heads its list "What does not change: Easy's and Medium's limits" while item 3 at :115-117 raises Medium's clock from 120 s to 150 s → reword to "Medium's pieces, turn rules and files stay; only its default clock changes". (from: pr-shape review)
- **could** packages/puzzle_game/test/board_cache_test.dart:125 the byte-for-byte test draws both frames with the cache and without, so it cannot tell a hit from a miss (test 1 covers reuse) → say in its doc comment that it checks recording, not reuse, or count records here too. (from: p2-coop-fps review)
- **could** packages/puzzle_game/lib/src/board_cache.dart:129 the key holds no puzzle identity, so a view State given another puzzle keeps drawing the first one's mat, slots and locked pieces → put the puzzle in the key, or clear the cache in `didUpdateWidget` when `widget.puzzle` changes. (from: p2-coop-fps review)
- **could** packages/puzzle_game/lib/src/board_cache.dart:105 eviction takes the oldest entry, so while one board re-records every frame (the finish celebration's `glowAgeMs`) the other board is evicted and recorded again each frame → move a layer to the end when it is used, or keep three. (from: p2-coop-fps review)
- **could** packages/puzzle_game/lib/src/board_cache.dart:57 the key compares `field` with `==` but `PuzzleField` (`puzzle.dart:35`) has no `operator ==`, so the cache hits only because `SplitLayout.of` memoises its layouts → give `PuzzleField` value equality or state the identity requirement in the key's doc. (from: p2-coop-fps review)
- **could** packages/puzzle_game/lib/src/view.dart:74 neither view State has a `dispose` and `BoardCache` disposes no picture, though p2's self-check says the cache ends with the State → give `BoardCache` a `dispose` and call it from both States, or say the GC is relied on. (from: p2-coop-fps review)
- **could** packages/puzzle_game/lib/src/puzzle_status.dart:15 re-derives "done" instead of using the new `PuzzleSnapshot.isComplete` (`snapshot.dart:115`), so the rule now lives in five places with two meanings (`board_hud.dart:59`, `match_painter.dart:146` either side, `phone_hud.dart:124` any board, this one that side's) → name one rule and pass the answer in. (from: across jobs)
- **could** packages/puzzle_game/lib/src/puzzle_painter.dart:155 the file went 326 → 350 lines in this run (p2's still parts, s1's bar before it), with `view.dart` at 373 → split the still-parts recording out along `board_cache.dart`'s seam the next time the file is touched. (from: across jobs)
- **could** packages/test_game/lib/src/arena_player_scale_painter.dart:16 is named `_painter` but holds no painter, only the factor and its function, so it also sorts before `arena_painter.dart` in `test_game.dart:21` → rename it `arena_player_scale.dart`. (from: a2-arena-size review)
- **could** packages/test_game/test/arena_paint_test.dart:357 asserts `tvWidth > phoneWidth + 20` after lines 355-356 pin both widths to disjoint ranges, so it can never fail on its own → drop it, or keep it and drop the two ranges. (from: a2-arena-size review)
- **could** packages/test_game/test/arena_player_scale_test.dart:7 declares `tvLook` and `phoneLook` that repeat `test/support/look.dart:9` and the `tvLook` at `arena_paint_test.dart:43` → put one in `test/support/look.dart` and use it in both tests. (from: a2-arena-size review)
- **could** docs/briefs/m14/bugs3/a2-arena-size-report.md:54 computes the TV body width as 2 × 40.5 × √0.84 = 74.2 px, but the test measures at 0.4 × the phone radius, where the chord is 2 × 40.5 × √(1 − (10.8/40.5)²) = 78.1 px → state the width at the row the test measures and keep 68-75 only as the width after the edge and shading. (from: a2-arena-size review)
- **could** docs/briefs/m14/bugs3/a2-arena-size-report.md:66 says the scale is tested "for the three kinds of look", but `arena_player_scale_test.dart` tests two kinds (TV and phone) plus palette and effects variants → say two kinds and name the variants. (from: a2-arena-size review)
- **could** docs/briefs/m14/bugs3/a2-arena-size-report.md:17 says the accessory, the dash glow, the cooldown ring, the aim cursor and the coin-count pill "grow with it", but the new paint test measures only the body (`arena_paint_test.dart:346`) → add a pixel check for the pill, or say in the report that those follow the radius and are untested. (from: a2-arena-size review)
- **could** packages/test_game/maps/map.schema.json:80 says decor "never hides a marble, a wall or a hazard", but flags now draw over walls (`arena_painter.dart:121`) → reword the line to allow a flag standing in front of a wall. (from: a1-pinball-flags review)
- **could** packages/test_game/test/map_flags_test.dart:18 defines `mapBox` as `Size(320, 180)`, the same value as `cell` in `test/support/map_sheet.dart:8`, which the test already imports → use `cell`. (from: a1-pinball-flags review)
- **could** docs/briefs/m14/bugs3/a1-pinball-flags-report.md:7 lists the changed files but omits `docs/design/maps/block-castle.png`, which the commit changes (the map render suite rewrites it) → list it as a regenerated design picture. (from: a1-pinball-flags review)
- **could** packages/party_host/lib/src/ui/controller_menus.dart:92 `okKey` is public though nothing outside the file uses it, and the file does not import `host_shortcuts.dart`, so the doc link `[hostActivateShortcuts]` resolves to nothing → make it private (or use it for the physical key too) and import the file or drop the brackets. (from: i1-ok-presses review)
- **could** docs/briefs/m14/bugs3/p2-coop-fps-report.md:51 self-check 1 says the TV and "Play on this phone" draw `PuzzleView`, but both draw `MatchView` (`play_view.dart:174`, `puzzle_module.dart:133`), whose State owns the cache → name `MatchView`. (from: p2-coop-fps review)
- **could** docs/briefs/m14/bugs3/pr-arena-report.md:47 expects the take-back "at step 120 (2.0 s)", but a dropped coin is aged in the step it lands, so its `ageS` reaches 2.0 after 119 standing steps → expect 119 or say "by step 120". (from: pr-arena review)
- **could** docs/briefs/m14/bugs3/pr-arena-report.md:52 calls A little "default ... in a night", but it is the default in and out of a night while `PuzzleSettings.defaults` is `Chaos.off` → say "the host's default, in and out of a night". (from: pr-arena review)
- **could** docs/briefs/m14/bugs3/pr-arena-report.md:66 puts the press's sweep at x 0.75-0.93 and the crates' at x 0.622-0.838; a slide bar is ±16.2 px round its place (0.649-0.851) and the hazard radius is a shorter-side 0.038 (0.6386-0.8214) → correct the two ranges; the goal stays clear either way. (from: pr-arena review)
- **could** docs/briefs/m14/bugs3/pr-arena-report.md:57 cites `party_host/lib/src/providers.dart:74` for how a define is read, but that line is a doc comment and `SHARE_VIEW` is read in `tv_test_app/lib/src/debug_start.dart:21`, and it puts a "Cat" row beside a card already titled 'The cat' (`host_text.dart:206`) → cite `hosting_settings.dart:25` with the `kReleaseMode` guard and call the row "Cat visits". (from: pr-arena review)
- **could** docs/briefs/m14/bugs3/pr-arena-report.md:82 answers the five part-A checks in one sentence, as does `pr-party-report.md:43`, where review-rules A asks one line each with its test → five one-line answers each ("not affected, report only" is fine). (from: pr-arena, pr-party reviews; across jobs)
- **could** docs/briefs/m14/bugs3/pr-party-report.md:26 calls the branch "reusing the join screen's own filter" in "~6 lines", but that filter is an inline list inside `_tick` and a private getter, and `_play` takes no `ref` and the file imports no `puzzle_screen.dart` → say the branch needs a shared helper, `_play`'s signature and one import. (from: pr-party review)
- **could** docs/briefs/m14/bugs3/pr-shape-report.md:96 names "the carry step (`puzzle_carry.dart:103`)", but line 103 is `p.rotatingS += dt` inside `_turn`; the per-step walk and carry that would add `moveS`/`placeS` are `puzzle_tick.dart:26-35` → cite that and add the file to Files. (from: pr-shape review)
- **could** docs/briefs/m14/bugs3/pr-shape-report.md:88 claims "the two sum to the round's clock for that player", which fails for a player dropped mid-round (the dot's steps stop while the side's clock runs) → state that an away or dropped player's pair stops at the drop. (from: pr-shape review)
- **could** docs/briefs/m14/bugs3/pr-shape-report.md:10 lets each Summary item run four or five lines where the brief asks one line per item → one line each, keeping the conflicts and computed-values lines after them. (from: pr-shape review)
- **could** docs/briefs/m14/bugs3/pr-shape-report.md:161 answers part A1 for a TV host, a phone host on both settings and a joined phone, but not the "phone or host one build older" that `review-rules.md:16` names → add "not affected: no new field on the wire". (from: pr-shape review)

## Open questions

- B-004's cause is a hypothesis: measure voice steals on a device Pinball run; if the engine never fills, revert `sound_loop.dart:66`. (safest: keep it until measured, and say so in the bug's status.)
- Protecting the loop means the engine steals effects instead: a busy Pinball round may lose bumper sounds — safest: accept it; the music is the one sound a round cannot lose silently.
- Is the Arena waiting card part of B-013? Safest: yes — it is the one Arena menu a phone cannot work at all; it becomes its own small job.
- The `KeyUpEvent` workaround lives in `party_host` because `toy_look` was outside `allow:` — safest: keep it, and replace it when `toy_look` gains a release API.
- `ControllerMenus.okKey` is public with no outside caller — safest: make it private.
- a2's classifier is the look's `sizes`, so a Windows PC host draws at 1.5 and a phone host feeding a TV stays at 1.0 — safest: accept; a settings value can come later.
- `tvPlayerScale` is a compile-time constant, not a `ToySizes` field or a settings value — safest: accept for now, move it when it is tuned on a device.
- The aim cursor, dash glow and cooldown ring grow with the picture, which the brief did not ask for — safest: accept; they must stay in proportion to the body.
- On a TV the picture is 0.048 of the field against a 0.032 collision radius, so marbles overlap before touching — safest: accept (picture only), owner to confirm on a device.
- p2 declined `RepaintBoundary` and remote interpolation — safest: the owner's on-device re-test decides whether B-016 is closed; the layer split is the next lever.
- `cache:` is a new public parameter and `BoardCache`/`StaticBoardKey` are exported though only tests construct one — safest: keep them behind the views, or accept the surface as documented.
- `keptLayers = 2` with oldest-out eviction re-records the other board every frame during a celebration — safest: accept and measure; keep three only if a device shows it.
- a1's five map tests live in i1's commit — safest: leave the tests where they are and correct both reports.
- s1's bar stays a bar of the clock and goes full only at the finish — safest: keep; a pieces-placed bar is a design change (design section 5).
- B-006's "Lively (new default)" changes Party for every family that never touches the setting, and Question 1 still offers a fourth Chaos level — safest: let the owner pick before code.
- B-015 reopens the owner's Nov 9 answer on the Playroom; the two races also need a render check — safest: the owner's word before the map files change.
- B-005's 2 s lockout is the report's pick, not the owner's — safest: keep 2 s, since `dropLockS` is the only place that differs.
- A debug-only `--dart-define=CAT_PRESET` in the shipped settings path — safest: a preset in tests instead.
- B-002's per-pick skipping changes the next round's screens when a phone joins mid-night, and round 1 too on a solo phone night — safest: accept, and say it in the report the owner reads.
- pr-party leaves the Bumper waiting card alone and starts with no ready beat — safest: matches the owner's words; the missing beat is a stated risk they should accept knowingly.
- Hard's blanket rule sits against PRD M15's "tuned starting angles", and Medium's 150 s makes "Medium should be easy" a content question — safest: confirm the rule, not tuning, before the Hard jobs.
- The `level_*` round tag and its report row go beyond the brief's "what to measure" — safest: keep it in the metrics job.

## Numbers against targets

- a2: the report's 74.2 px TV chord is computed at 0.4 × the TV radius; the test measures at 0.4 × the phone radius (10.8 px below the middle), where the chord is 78.1 px. Its measured 72 px and the asserted 68-75 hold only because the ink edge and rim shading take ~6 px; the report's own arithmetic does not tie to its asserted range.
- a2: the test asserts 44 px in 41-47 and 72 px in 68-75, then `72 > 44 + 20` by 8 px — the third assertion cannot fail alone (`arena_paint_test.dart:357`).
- s1: full end 933 px, old rule 410 px (3/8 of the solo track) and 471 (race gap) against 509; thresholds are "more than 50 px short" (solo, co-op) and "more than 10 px" (race, phone), "within 2 px" when done — all met, and all five frames are in ranges the old code misses.
- p2: a fresh co-op board 930 → 514 µs a frame, all locked 282 → 233 µs; the 60 fps budget is 16,700 µs (guidelines §5), so the board is ~3% of a frame — inside, but the table came from a benchmark that is now deleted.
- p2's brief caps every touched `lib/` file at 380 lines: `puzzle_painter.dart` 350, `phone_hud.dart` 227, `match_painter.dart` 227, `board_cache.dart` 176 — met; `view.dart` 373 (362 before) and `puzzle_painter.dart` exceed the guidelines' ~300.
- There is no `docs/briefs/m14/bugs3/STATUS.md`, so these are measured against the briefs' own targets only.

## Could not check

- That SoLoud really runs out of voices on Pinball, and the device sound the owner hears: device only.
- a1's old-code sample for the bottom-left flag (48, 130) = 0x2c285a, 20 off the ink, limit 8: it needs the old painter, which a review may not restore; the geometry is believable.
- p2's µs table: its benchmark is deleted and I did not rebuild one; the GPU-side cost of the replayed picture is device only.
- The pr-arena, pr-party and pr-shape proposals: they are code yet to be written, so only the reports' claims against today's code were checked.
- `tv_test_app`'s suite and the Windows-only painters: not run here.
- Whether a round can start another puzzle while the previous `MatchView` State is still alive (the cache's missing puzzle id): I read `frame_view.dart:176-201`, not the host's round chaining.
- Side effect of my own run: `flutter test` in `puzzle_game` rewrote five `docs/design/*.png` (the picture tests the s1 report warns about); I put them back from `HEAD` byte for byte, so the tree is as I found it. The three `tv_test_app/windows/flutter/generated_plugin_*` files were already modified before this review and still are.

## Commit message

Review M14 bugs3 run: the waiting card, B-004 and the still key

Seven jobs read as one change: the still-parts and path caches, the bar
rule, the flag order, the TV scale and the phone OK all work (puzzle 400,
the two party_host files 20, 16 files format-clean). To decide: the Arena
waiting card a phone still cannot work (B-013), and B-004's voice
protection on an unmeasured cause. To fix: the still key's missing canvas
scale, the OK lifted only before a phone press, a1's tests sitting in
i1's commit, and the reports' missing check lines and wrong claims.

## Status row

M14 bugs3 run reviewed: 7 jobs, code sound (must 2, should 17, could 28) — open: the waiting card and B-004 for
Claude's call, one fix batch for the reports and the still key, and the owner's device re-tests for B-004, B-013 and
B-016.

## Delete

- none
