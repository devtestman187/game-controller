# M17 status

**Resume here (night2a) B7 done (Nov 27, see docs/briefs/m17/night2a/REPORT.md):** d2a map tier field (arena_map.dart split to arena_map_parse.dart), d2b first ratings by hand (playroom easy, pinball easy, toy-factory medium, spinning-tops medium, block-castle hard; owner confirms), d2c Variant model + pool filter, d2d NightDirector (pure, DirectorInput), d2e pickers, k1 Kids nights capped at A little (Kids length is already NightLength.three), f1 f2 fixes. Director NOT wired (nightNextVariantProvider still null): B8 notes in docs/code-health.md "night2a notes". iOS HOLD stays. Next: B8 night2b. tip 71cb648a tip 71cb648a
## Resume here (Nov 26, 2026)
- **Owner, Nov 26: "A, A, A" (Fable-reviewed), FINAL:** (1) skip and reroll swap the game and never use up a round; a night still plays 5 games; the skipped game must give nobody points (built with the host skip buttons, code-health night1c). (2) Cat: nights keep following the host's saved game cat setting (party_night.dart:26-44; new host = A little), the last round stays cat-free, and Kids nights are capped at "A little" (to build in B7; NightSettings.chaos has no reader today). The plan's Calm/Lively/Wild is the cat pace (CatPreset), not Off/A little/Party: re-map owner Q4 (present replaces the knock) before B10-B11. (3) "Try the shop" stays for test builds; remove or gate it and restore Games cards 340/186 before the public build. pausewire verified PASS (tip d469c4de). Next: B7 night2a.
- **B6 merged into m17 (Nov 26, merge df3dbc76 of m17side a4e7a378):** B6 verified PASS; B4 verified PASS (tip 6a367dde). Full check on the merge: All checks passed (386s, 1 cached). Next: pausewire (ChoiceRound into NightFlowController.addPausable), then B7 night2a. Pending owner (Fable-reviewed): skip keeps 5 games (A) vs uses the round (B); cat on nights: A no cat for night and Kids per plan "Calm" / B Kids keeps a little / C a little on both; Try the shop: A keep for test builds, remove before public / B hide now. Notes in docs/code-health.md "phone1b merge notes".
- **B5 merged into m17 (Nov 26, merge 96a5225e of m17side e621f4a2):** one STATUS conflict, both lines kept; full check on the merge: All checks passed (469s, 1 cached). B3 night1b verified PASS (tip 832914c5). Owner Nov 26 "Q1 A Q3 A": the night controller owns ChoiceRound pause (end and grace timers freeze, picks kept, no default for drops until resume); a tapped but unconfirmed card counts at timer end, and a dropped player given Save +2 can change it before the timer ends. ChoiceRound pause()/resume() is built in B6 y0p on m17side; n1g calls it after B6 merges. Next: B4 night1c on main; B6 phone1b running on m17side.
**Resume here (pausewire) done (Nov 26, see docs/briefs/m17/pausewire/REPORT.md):** ChoiceRoundPausable (night pause seam for a ChoiceRound, unexported; no night path creates a round yet, wire in M17b). Full check passed. tip 3721f2a9
**Resume here (night1c) B4 done (Nov 26, see docs/briefs/m17/night1c/REPORT.md):** n1f settings/Kids, n1h controller, n1g pause/skip/reroll/roster, n1i round-start hook, n1j champions wired, e0d ring for players 7/8 (host only), f1-f4 fixes. Pending owner question: skip/reroll never burn a round (built default). Skipped-game points rule not verified (replaceRound stub). Next: B6 merge (ChoiceRound NightPausable), B7 director. Full check passed. tip ad3ba673 plus the closing commit.
**Resume here (night1b) B3 done (Nov 26, see docs/briefs/m17/night1b/REPORT.md):** n1c 5-round cap, n1d scoring pins + ChampionChain.quickNight via NightState.championsAmong (not wired to the scoreboard yet), e0c night autosave/resume (prefs key party_night_v1), e0e "Game full", e0g fix. Place meaning left as the scoreboard's shared place; pause rules unchanged. Next: B4 night1c (n1f-n1j); wire championsAmong there; code-health list in docs/code-health.md "night1b". tip 1c138f94
- **B2 night1a done (Nov 26, batch tip 067e3b2f, see docs/briefs/m17/night1a/REPORT.md):** NightFlow/NightEvent contract, captionFor stub, Arena race roundResult with placing, ChampionChain (pure, not wired). Owner pick O1 (Nov 26): "I am good with the defaults suggested": Quick night champion = most points, ties share; City Rush = Plaza distance, then Bolts, then shared; the "best place in the last game" step stays an optional added step. Next: B3 night1b (n1c, n1d, e0c, e0e, e0g); open: pause rules, "place" meaning (REVIEW.md). iOS HOLD stays.
- **Resume here (phone1b done, side line, Nov 26): B6 phone1b landed; batch tip see docs/briefs/m17/phone1b/REPORT.md; no build, no push; iOS HOLD.** tip 74360bca
- **B6 phone1b in progress (side line, Nov 26). Owner answers Nov 26 "Q1 A Q3 A", FINAL: Q1 pause = night controller owns it, timers freeze (ChoiceRound.pause/resume, y0p); Q3 = the last tapped card counts at the timer end; a dropped player given Save +2 may change it before the timer ends, then Save +2 stands.**
- **B5 phone1a done on side line m17side (Nov 26, batch tip 00dcf982):** choices contract, ChoiceRound host side, old-phone fallback in connection+protocol; dormant until B6 (y0d phone screen). Owner picks O2/O3 (Nov 26, "I am good with the defaults suggested"): TV reveals all choices at once at timer end then road tiles one by one; old phones A Build 1 (taps add up to a cap), B Save +2, X Roadworks (last place only), Y Clear, lock at timer end; undo until timer end; no choice = Save +2 (Vote abstains); dropped player same default; lobby "[Name] has an old app and will play with simple buttons." Report: docs/briefs/m17/phone1a/REPORT.md. Merge into m17 only while the main driver is idle.
- **B1 m17prep done (Nov 26, batch tip 048af4d5):** home search-wait fix, 8-phone load tool, night-card fit measure (head and strip fit nowhere on host cards; phone card at 667x375 yes), stale plan text, CI timeout 45 + tests once (ships with the next tag). Next: B2 night1a (and board-1 / B5 on a side line); read docs/briefs/m17/m17prep/REPORT.md first. iOS HOLD stays (see Next).
- **Owner go:** "Build, 1A 2A" on Nov 26, using the fast track.
  - 1A = toolchain checks, then the upgrade-only build.
  - 2A = the board line runs alongside M17a in its own copy and with its own review.
  - Standing: "Remember to run questions and recommendations by fable. Stop and ask me in case there is a major change to the plan above".
  - Standing (Nov 26): "Make sure going forward to remember to check all your recommendations with fable agent." Every recommendation goes to the fable-review agent before the owner sees it: lettered picks, go/wait calls and next steps as well as design questions. Each message to the owner says Fable reviewed it.
- **Plans (read these first, in E:\AI\m17-scoping\):**
  - `M17a-batches.md` is the build order: 11 batches B1-B11 (52 jobs) plus the 3-batch board line. Its "Fable review — adopted" and "Home search wait" sections at the end override the table where they differ.
  - `city-rush-plan.md` covers the City Rush rules and the owner's answers. The end of the file has the build stop as a phone shop, one fixed road per district, 6 colours plus badges, and the choices screen in M17a.
  - `M17-dev-plan.md` is the original M17 job list. It has stale parts, listed in M17a-batches.md section 5; job p0b fixes them.
  - The mock-up page is https://claude.ai/artifact/Qesc8AcF6qow8qK9MuP3e1 (panel 3 is the build stop as a phone shop). The review deck is https://claude.ai/artifact/Xtq5f2xLCfe99aUZZnc1H5.
- **Worktrees:**
  - Main line: E:\AI\game-controller-m17, branch m17, from 18a95647 (the m16.6 tip).
  - Side line (to create): E:\AI\game-controller-m17side, branch m17side.
  - Board line: branch board-line.
- **Done before M17a:**
  - Xcode 27.2 is pinned (codemagic.yaml:28). Build 1718 passed and the owner's part-1 device checks passed. Flutter stays 3.47.8.
  - m16.6 holds Pause in the compact game bar and the B-042 mini board (strip/corner, 1.5 mm floor). The owner said "Go for the tag on m16.6", and thumb-release was running when this was written. Check `git tag -l m16.6` and the GitHub/Codemagic runs.
- **Next:** start B1 (m17prep) once the m16.6 release's check has finished; only one full check runs on the machine at a time.
  - Nov 26 owner pick "B": wait until the m16.6 TestFlight build (Codemagic, Xcode 27.2) is confirmed before starting B1. The GitHub release (build 1737, Android and Windows) passed. If TestFlight fails, an m16.7 check has priority over B1's check.
  - Nov 26 evening: the m16.6 iOS build never started. Codemagic answered all four GitHub webhook deliveries for the tag (18:43-18:44Z) with HTTP 402 (most likely build minutes or billing; manual build 1718 ran in between). m16.5's got 202. The owner was asked to check Codemagic billing/usage, then start exactly one manual build (Tag m16.6, ios-testflight), with no webhook redelivery. Fable recommends starting B1 now rather than waiting (owner to pick).
  - main CI analyze-test-android times out at 30 min (4 of the last 6 runs). It is slower (Coverage 15m vs 11m40), not hung. Proposed: a B1 job replacing p0d that raises ci.yml:35 to 45 min, checks whether Coverage re-runs the Test steps, checks windows-desktop's margin (ci.yml:110) and why it got 25-30% slower. It ships with the next tag (owner to pick).
  - **Owner, Nov 26: "I confirmed I ran out of build minutes. Go ahead with a B1 and 2A. Let's discuss the iOS builds separately".** So B1 starts now, and the CI timeout job replaces p0d in B1 and ships with the next tag. The m16.6 iOS build and Codemagic minutes are a separate discussion; nothing iOS until then.
  - Owner picked "A" on Nov 26 (Fable-reviewed): after B1, remove the push-to-main trigger from Codemagic's ios-check-main (codemagic.yaml, around lines 75-83) and keep the manual start. It goes on whichever branch releases next. Reason: in November it used 203 of 488 minutes (42%), and it repeats a subset of the TestFlight tag build on the same commit. The owner is moving to Codemagic pay-as-you-go ($0.095/min, 500 free minutes a month). Condition: after any codemagic.yaml, ios/ or Flutter-version change that reaches main without a tag, start the check by hand (done on m17 at a9f5a88f; reaches main with the next push from m17).
  - **iOS build HOLD (owner, Nov 26):** "I have setup pay-as-you-go in codemagic. I want to try the next iOS build only when the check builds have been disabled. Do not start a new iOS build until that's happened." So: no manual Codemagic build and no tag push (a tag starts ios-testflight automatically) until the trigger removal is on main. m16.6 iOS stays unbuilt until then. How the yaml change reaches main (with the next release, or a separate untagged fast-forward) is decided then, with Fable first.
  - **When to run the iOS check by hand** (Codemagic > Start new build > iOS check): (1) a change reaches main without a release tag and touches codemagic.yaml, controller_app/ios/, the Flutter or Xcode version, or native plugins in controller_app/pubspec.yaml; (2) optionally, before tagging a release that contains such a change, on the release branch, to find iOS breakage before the tag. Otherwise the tag's TestFlight build is the iOS test.
- **Driver cost plan (owner picked "A" on Nov 26, Fable-reviewed):**
  - **Why:** on Nov 25 Sonnet cost $35.54 of $63.54. Batch drivers were $22.29 of it: 117-168 calls each, re-reading 165k-230k of context per call (about 60% of driver cost), plus inline wait loops and cache expiry on waits over 5 minutes (about $0.5 per wake-up at 230k). Measure with `bash tools/agent-cost.sh --since <time>`.
  - **Step 1, trim every driver (still Sonnet), from B1 on:**
    - At most one short inline wait per run, then thumb-wait. agent-cost flags repeated inline waits.
    - Cap the call count rather than banning short reads (a 20-line sed inline is fine).
    - Hand off to a fresh driver at stage boundaries only (after a run and its repairs, before review wrap-up, before a long run), never mid-repair, when the prompt nears 100k. DRIVER-NOTES carries the ladder state and repair classes.
    - B1's agent-cost line is the new Sonnet baseline (estimate about $1-1.5 per batch, not yet measured).
  - **Step 2, Haiku-driver trial on board-1 (board3a, branch board-line), after B1's baseline:**
    - Run thumb-batch with a per-call `model: haiku` override. Don't edit thumb-batch.md's model line; the Sonnet path stays for B2-B4.
    - A short Sonnet judge is called on fixed triggers only: every brief, every STOPPED, every ladder step 3 or later, every REVIEW finding, every tracker note. At most about 6 judge spawns, each with a pack of 30 lines or fewer, all counted in the cost.
    - The Haiku driver writes the tracker (ArtifactData with if_version) from the judge's text.
    - Pass gates: thumb-verify PASS, no missed design stop, no extra ladder step against the judge's advice, total cost below the B1 Sonnet baseline, driver prompt under 100k throughout.
    - Spec: docs/design/haiku-driver-trial.md. Expect about $1 per batch more saving; step 1 is the bigger lever.
  - B1 now also holds the home search-wait job (owner picked A): show "Looking for a screen…", fix "Search again" and resume, log time-to-first-host, keep 3 s.
- **Owner questions to send at batch start, each with a default:**
  - O1, the champion chain: before B2 ends.
  - O2/O3, choices screen states and the old-phone mapping: at B5 start.
  - O5, Vote defaults: at B7 start.
  - Q5, the kid playtest: needed before B11, so the owner was asked to line up a date.
- **Internal builds BP1 (after B6) and BP2 (after B8)** each need the owner's word.

## M17 job list (p0c, Nov 26; source E:\AI\m17-scoping\M17a-batches.md, its adopted sections override the table)
| Batch | Jobs | Needs |
|---|---|---|
| B1 m17prep | p0a night-card fit at 360x640 and 667x375; p0b stale plan text; p0c this hand-over; e0f 8-phone load tool; home search-wait fix; ci timeout 45 min and tests once (replaces p0d) | m16.6 tip |
| B2 night1a | n1a NightFlow/NightEvent; n1b caption consumer + flow test; e0a Arena placing; e0b Champion type; n1e fix | B1 |
| B3 night1b | n1c 5-round cap; n1d scoring v2; e0c autosave/resume; e0e "Game full"; e0g fix | B2 |
| B4 night1c | n1f auto-advance; n1g skip/reroll/pause/join/leave; n1h settings + Kids preset; n1i round-start hook; e0d players 7-8; n1j fix | B3 |
| B5 phone1a | y0a choices contract; y0b host side; y0c old-phone fallback; y0g fix | B1 only (side line) |
| B6 phone1b | y0d choices screen; y0e lobby names old phones; y0f "Try the shop" demo; y0h fix. Ends at BP1 | B5 |
| B7 night2a | d2a-d2e difficulty, rate maps, Variant, NightDirector, pickers; fix | B4 |
| B8 night2b | d2f Vote picker; d2g setup screen; d2h caption; d2i pool honesty; d2j fix. Ends at BP2 | B4, B6, B7 |
| B9 race1a | f1a-f1d 3v3/4v4, maxPerSide, side panel, 2-pieces rule; f1e fix | B7 (d2a merged), e0e, e0f |
| B10 race1b | r3a-r3d present state, rules, cat preset wiring, painter; | B9 |
| B11 race1c | r3e golden slot; r3f host UI; r3g fuse values; r3h fix. Ends at BP3 (M17a tester build) | B10 |
Board line (branch board-line, own worktree, 11 jobs, new directories only): board-1 board3a (g3a, g3s, g3b, g3f); board-2 board3b (g3d1, g3d2, g3d3, g3g); board-3 board3m (g3m, g3n, g3h). board-1/2 any time after B1; board-3 and the merge after B3, suggested after B4 and before B7. g3c moved to M17b.
Lines: at most two at once (main m17, one side line m17side); full checks never on both at once.

## Owner decisions, Nov 26 (record)
- "Build, 1A 2A": fast track; 1A toolchain checks then the upgrade-only build (done: Xcode 27.2, build 1718); 2A board line alongside M17a in its own copy with its own review.
- Home search wait: "A": show "Looking for a screen…", fix Search again and resume, log time-to-first-host, keep 3 s.
- "Go ahead with a B1 and 2A": B1 starts now; the CI timeout job replaces p0d; it ships with the next tag. iOS builds and Codemagic minutes are a separate discussion (out of build minutes): nothing iOS in B1.
- "Let's do A": driver cost plan step 1 (above) from B1 on; Haiku-driver trial on board-1 after B1's baseline.
- City Rush: full City Rush + Shape Race 3-4 a side; build stop is a phone shop (choices screen, y-jobs in M17a); one fixed road per district; 6 colours plus badges; Option-B policy research is M18 (p0d dropped).
- Standing: every recommendation goes through the fable-review agent before the owner sees it.
