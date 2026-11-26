# M16 Friendlier start: status

Branch `m16`, worktree `E:\AI\game-controller-m16`, cut from the `m14` line after `m14.9`. The
plan is `docs/PRD-v2.md` "Milestone 16", written from the evidence-driven UX review in
`docs/briefs/m16/ux-review/`.

**New developer or other agent taking over: read [docs/HANDOFF.md](../../HANDOFF.md) first.**

## How we work with the Flash agents (DeepSeek Harness, Nov 19)

The architect (deepseek-v4-pro — this session's "lead") frames, briefs, reviews, gates and commits;
the Flash workers (deepseek-account/deepseek-flash) do the mechanical work. The full method is
docs/agent-workflow.md and docs/HANDOFF.md §10. Session refinements to keep:

- **Pin the route on every child**: pass `provider: "deepseek-account"`, `model: "deepseek-flash"`
  explicitly on every `subagent` call; never rely on inheritance.
- **Slice complex items BEFORE dispatch** (one bounded change per worker). The host-away card
  failed twice as a combined connection+TV task, then succeeded split into two.
- **Skip standalone recon** when the architect already has the context (PROPOSAL/findings or its own
  read); fold "find the seam" into one tight implementer brief. Item 1 used 3 Flash workers (one per
  slice) rather than recon+implement per item.
- **The architect does the small edits itself**: test fixes, `docs/protocol.md`, tooling fixes (the
  `review.sh` map-literal fix), plus the final diff review and the `tools/check.sh`/`review.sh`/
  `coverage.sh` gate.
- **Emulator visual gate**: after each visual item, boot the `m8_pixel_tablet` AVD, build
  `controller_app`, drive the UI with `adb shell input tap`, screencap via `adb shell screencap -p`
  + `adb pull` into `docs/briefs/m16/emulator/`, and let the owner review before proceeding. The
  emulator is stopped as of Nov 19 for a harness update; the round-state strip is captured by a widget test (`docs/briefs/m16/phonefit/round-strip-852x393.png`, Nov 20); an emulator capture is still open.
- **Never take a child's word as evidence**: read the diff, re-run the gate, verify the test
  assertions, and check `git status` for churn before committing.

## Resume here (Nov 20, 2026: item 1 built; host/commentator direction settled — see `docs/briefs/m17/STATUS.md`)

**pilot1-tune (Nov 24, inline, tooling only; based on e9f25e1b):** hand-back template + REPORT.md (verify-batch `report` check), `.start` ignored, agent-cost counts headless Haiku, baselines fixed, fable-review agent added (untested as a real type until a fresh session). Report: docs/briefs/m16/pilot1-tune/REPORT.md.

**Resume here (tail, Nov 26):** Start/Pause is in the compact game bar (s1/s2, docs/briefs/m16/tail); mirror corner spot (option A) not built: measured 16/18 at 956x440 but 1/18 at 667x375, owner to decide. Nothing pushed.
Owner accepted option (a) (shrinking mini board, 1.5 mm floor) on Nov 26; Xcode 27.2 confirmed in Codemagic build 1718 log ("Xcode 27.2, Build version 27B52"); 1718 device check pending; m16.6 not tagged.
**Resume here (tune2 done, Nov 24, tooling commit d9868e10 on m16):** driver gates and tiering landed (docs/driver-kit.md sections 2, 6, 6b; report docs/briefs/m16/tune2/REPORT.md): debug-leftover and 48 dp shrink gates, `model: haiku|sonnet` per brief, run.log model/ladder/tokens, `RUN_PAUSE_AFTER_WAVE=1` fix-as-you-go, failure classes and HAND-FIX-EVENT. Nothing pushed. Next stays as the line below.
**Resume here (close done, Nov 25; base 3869ae85, tip 2dbd56c1, nothing pushed):** M16 close batch in docs/briefs/m16/close finished clean; details in the block under the coverage section below.
**Resume here (tune3 done, Nov 25; base 47ce2222, nothing pushed):** tooling fixes after wave2-789 in docs/briefs/m16/tune3 (report REPORT.md): run-stops-test fixtures, generated plugin files untracked and PNG tests write only with UPDATE_GOLDENS, churn_snapshot, rc-4 churn before the turn cap, runner-verified over-cap jobs, parked diff removed from the tree, heartbeat, batch-report.sh and batch-close.sh, thumb-batch hand-back trigger, brief-check ignores comments. Pause restart and stale waiter not reproduced. tip 0280d351
**Resume here (m165 done, Nov 25; base d4805792, tip e0482f7b, nothing pushed):** m16.5 batch docs/briefs/m16/m165 (report REPORT.md): B-043 and B-044 Fixed, unverified (device check); more menu in the bar (a1s); head-to-head tooling (apply: no, tools/h2h.sh). Open for the owner: B-042 spot and the Pause-over-board overlap (b3 numbers in REPORT.md), the 568x320 TV chip width (35.9 dp) and cut labels.
**Resume here (tune4 done, Nov 25; base 2155c70f, nothing pushed):** tooling after the m16.4 review in docs/briefs/m16/tune4 (report REPORT.md): stdin closed on every runner child and in the agent rules, tree kill (tools/proc-lib.sh, taskkill //T //F //PID plus ps walk), check.sh wall limit CHECK_MAX_MIN and kill trap, tools/proc-sweep.sh, hung-job guard RUN_JOB_IDLE_MIN, over-cap auto-apply, brief-check pins WARN, run review stub REVIEW.md, summed job-metrics usage and a runs count, phase lines in run.log, wait-run.sh --since (stale waiter cause found). Runner auto-resume after a planned pause split out (not done). tip ed66d3bb
**Resume here (wave2-789 done, Nov 25; base 70bcd97a, final tip see git log (close-out commit after a7993a07), nothing pushed):** items 8 and 9 and the remaining 7 built in docs/briefs/m16/wave2-789 (Home as the unpaired launch screen with coach marks and a Show tips switch, 48 dp chip and measuring tests, "screen" wording sweep with the tools/tv-word-check.sh guard, Resume label for resumers only; 9e closed by owner decision A). Open owner questions are in that folder's REPORT.md (round label on split screens, remembered-host behaviour with no TV found, Show tips row placement, 60 phone-host controls under 48 dp, churn_revert policy). Next stays as the line below.
**Resume here — START HERE (Nov 24, after m16.3):** m16.3 released (0.14.0, build 1429, fb2f6a5e; internal TestFlight only, not promoted). Next, by the owner's go (Nov 24): **pilot 1** (main session only orchestrates). In a fresh session: (1) answer "What's next?" from this line + memory, under 10K tokens (the cold-start measure); (2) on the owner's word, run the **pilot1-prep** batch (thumb-batch): `tools/verify-batch.sh` + test, read-only Sonnet `thumb-verify` agent + `tools/sync-agents.sh`, Fable prices in `tools/agent_cost.py` (official price list); (3) then M16 items 7-9 wave 1 as the measured batch (plan docs/briefs/m16/plan789/PLAN.md, QUESTIONS.md owner answers, re-cut per FABLE-REVIEW.md). Pilot plan and gates: docs/design/agent-issue-db-feasibility.md "Pilot proposals, merged". Pilot 2 (tracker questions/events + page tab) needs a separate owner yes. Owner device checks waiting: B-040 (small phone, two-phone night with phone host and TV host, End night), B-036 (six players), B-041 (iPad 1180x820, 1366x1024), B-035/B-037/B-038/B-039/wrap320, the m16.2 list. Open owner decision: none blocking. version-from-tag on hold. Churn: tv_test_app/windows/flutter generated files and docs/design + site/shots PNGs are modified by test runs; never commit them.
**Resume here (bugs3 done, Nov 23):** wave 2 committed on m16: b036 (centred winner banner above the Arena results card, card scrolls when full, round strip hidden; "Left wins!" is a follow-up) b1618ff6, b041 (a tablet plays Shape Race like a phone, whole match only where no mirror fits) d1baad91. B-035/B-036/B-041 updated; B-036, B-041 Fixed, unverified (device check: results banner with 6 players; iPad 1180x820 and 1366x1024 as host and joined). Nothing pushed.
**Resume here (bugs3 wave 1, Nov 23):** b037 (winner badge 48 px, crown, rank number), b038 (Shape Race clears the 52 px bar) and wrap320 (join line wraps) committed on m16; B-037, B-038 Fixed, unverified (device check). Wave 2 (b036 banner, b041 tablet like phone) waits for the usage check; see docs/briefs/m16/bugs3/DRIVER-NOTES.md. Nothing pushed.
**Resume here (identity1-clean, Nov 23):** identity1-fix leftovers done: pad painters take one `PadFill` (StickPainter now `StickGeometry` + fill, 5 params), `PadFill` test, claude-worker-test pins `turns:` and selftest unsets FLASH_WORKER. Fail-proofs run in a scratch worktree: pad_character_fill_test 12 fail with the character ignored, the fm3 crown assertion (arena_phone_identity_test:242) fails with the number-default accessory, the turns case fails with flash.sh turns line removed. Full check.sh green. Nothing pushed. Device check as before (pad colour with a chosen crown).
**Resume here (identity1-fix, Nov 23):** fix batch done (waves A+B: fm1 away keeps character, fm2 host chip/MatchView, fm3 crown mask, fq6 re-pairing hello held until round end, ft check.sh tools = `selftest.sh -j 4`, fpad phone pad fill from the chosen character); REVIEW verdicts and leftovers in docs/briefs/m16/identity1-fix/REVIEW.md and docs/code-health.md. Nothing pushed. Device check needed (Fixed, unverified): pad colour on a phone with a chosen crown. Next: item 6 (awards) only on the owner's go.
**Phone-host layout, foundation built (phonehost1, Nov 20):** S1 HostFrame/HostFrameInfo/ThumbySlot/hostFrameBuilder + ToyType.frame, S2 HostFrameScreen/ScoreRow/RoundSegment, S9a PNG guard, S7 measurement done and green (full check.sh passed). NOT wired into any app yet (TV line + phone-app gate need a decision); S3-S6, S8, S9 matrix wait for review. Details and open questions: `docs/briefs/m16/phonehost1/`.

**Resume here (phonehost2, Nov 21):** the phone-host layout is built and wired: night start, scoreboard, final scores, reveal, Arena results, puzzle results, picker and join screen are HostFrameScreen; the TV wears HostFrame at the root, the phone host inside HostFrameGate below the 52 px bar; matrix (80 cases) and TV ring test green. Open for the owner / a device: (1) at 640x360 the phone host scales 0.570 (bar), so 20 frame px = 11.4 dp, not 13.3; (2) in-game board pad clearance is wrong by the frame scale (wph-report); (3) "Bumper Round" and "Change teams" footer labels ellipsise, six-player night start names get 84 px; (4) join seats stay 2 a side; (5) puzzle results answers Q2-Q5 in s6b2.md. Details: `docs/briefs/m16/phonehost2/`.

**Resume here (phonehost3, Nov 21):** fix batch done, full check.sh green (12/12), nothing pushed. (1) 640x360 floor: owner chose "Accept 11.4 dp" (frame stays below the 52 px bar, 20 px floor unchanged; accepted pending a real small-phone check). (2) Pad clearance fixed (730140fa scale by HostFrameInfo, 4ed8c34e bar mapping: the board is asked about the room plus the bar, shifted up). (3) Labels fixed: night footer pair sized by label (4217bdad, budget 480 -> 640, pair 521 px), six-player night names on two rows of three, results controls weighted by label (1b0ae28d). Still open for the owner: (4) join seats 2 a side, (5) puzzle results Q2-Q5, five players 3 + 2, whether the 640 footer budget stays. Device checks (unverified): pad clearance on a real phone and a notch, 13.3 dp small phone, reveal crown at 640x360, join hint pill. Details: docs/briefs/m16/phonehost3/REVIEW.md.
**Resume here (identity1 wave 2, Nov 22):** i1d (8e19e4cb host), i1f (a7125f73 arena), i1e (hand-applied, cb3e5a7d) + i1e2 (dfbefcf3), f1 (c188841b host lists identity) committed; nothing pushed; wave 3 (i1g) NOT started (owner go needed). Open: the phone's own host mode (controller_app storage.dart:55) still lists no identity (needs joined_view_test.dart:38 first; f1-report Q1); blank nickname "Player N" is unreachable from the real hello (phoneName sends "Phone AB12": owner call on hello vs display); results-band colour change and the other REVIEW.md shoulds are in docs/code-health.md. Device checks needed (Fixed, unverified). Details: docs/briefs/m16/identity1/REVIEW.md, DRIVER-NOTES.md.
**Resume here (identity1 wave 3 + Claude-only model, Nov 23):** wave 3 done (i1g1 Haiku-direct d321bcdf, i1g2 flash c42ceed3, verdicts 060b66a8, trial docs/briefs/m16/identity1/HAIKU-TRIAL.md). The Claude-only model is now the default (docs/design/claude-only-model.md; Haiku coders via WORKER=claude, Sonnet driver, Opus for design): process5 worker tooling (3259ef2c..4918c13b), rehearsal1 3/3 Haiku jobs first try (2be1c198: blank nickname "Player N" display, taken-notice docs, gating helper), lessons P1-P9 promoted (39f79d36), docs default (53b7c87c), process6 runner fix (1eacb71e). Next: identity1 wave 4 per docs/briefs/m16/identity1/NEXT-wave4.md (five owner questions first), then a tools speed-up batch and the identity1 milestone-end review. Nothing pushed; device checks waiting.

**bugs1 owner answers (Nov 21):** B-034 footer stays flush at 84 px (no top gap); B-032 quitting round 1 from the pause menu also cancels the night — wanted.

**Bug tracker:** https://claude.ai/artifact/8vDcqYR8QghaGfVPdQDvQR (rows in its database, collection `bugs`; read with the ArtifactData tool as `docs/flash-digest.md` "Tracker" says). New bugs default to build m16.1 (0.14.0 build 981) since Nov 21.

**Next (Nov 21, owner answers after phonehost3):** all four open questions closed with no code change: join seats stay 2 a side; puzzle results Q2-Q5 kept as the main session answered them (no stars yet, per-side rows, a night's last round [Next] only, headline chip in the winning side's colour); five players as 3 + 2; night footer budget stays 640. Phone-host layout is done in code; left: the device checks listed above (owner), then item 5 identity on the owner's go. Nothing pushed since 56259780; push only on the owner's word.

- **Paused → resolved (Nov 20).** The host/commentator direction has settled: a dedicated host
  character **Thumby** (see `docs/briefs/m17/STATUS.md` and `docs/briefs/m17/ux-review/PROPOSAL.md`),
  layered on top of M16 item 6 (end-of-night awards). Item 5 (nickname + colour + accessory) and
  the rest of the build order can resume. **Confirm with the owner before continuing.**
- **ux-review (done; committed as `1d593136`).** The end-to-end player-flow review and the
  mock-ups are complete and owner-approved. Deliverables under `docs/briefs/m16/ux-review/`:
  - `PROPOSAL.md` — the 9 recommendations (five-first summary, 13-stage flow, recommendations at
    a glance, rejected ideas, decisions).
  - `APP-START.md` — the friendlier start: home screen, three device roles (Join a Game / Play
    here / Display here), coach marks, "screen" not "TV".
  - `findings/` (6 live-capture batches + 2 synthesis files), `research/` (7 digests), `mockups/`
    (`proposal-mockups.html`, 32 PNGs in Sunny + Night), `run.md`, `worker-spec.md`.
- **Owner decisions (Nov 17–18):** item 1 (round state on the phone) approved as an additive,
  capability-gated protocol field; colour + accessory approved for now, with a future path;
  Windows host parity needed for testing + automation; first-time help = coach marks on the real
  home screen (not a wizard); three device roles in a fixed button order; "screen" not "TV".
- **M16 item 3 (done; commits `416d6571` join screen, `f48b937` prefer live discovery):**
  - Join screen: the title bar now shows a "Code" chip with the 4 digits (`HostText.code`,
    `_JoinCode` in `join_screen_widgets.dart`), read from `hostStateProvider`; test
    `join_screen_test.dart` "the join screen shows the pairing code where players look".
  - Reconnect: `ConnectionActions.reconnectToLastHost()` waits up to `reconnectDiscoveryWaitProvider`
    (1 s) for discovery — connects to the remembered host's live address if found, opens Connect if
    other hosts were found but not it, and falls back to the remembered address if nothing was
    found. The wait is injectable so tests keep the instant launch behaviour. Tests in
    `connect_screen_test.dart`.
  - Gate: full `tools/check.sh` green (12/12); `tools/review.sh` 0 fail; the added lines are
    covered (coverage reads 92.8% — the Nov 16 92.9% baseline's denominator drifted +368 lines on
    this toolchain, not from this change).
  - Unverified: real-device discovery timing vs the 1 s window — needs a device check.
  - Visually verified on the emulator (owner, Nov 19): see the gate below.
- **Emulator visual-verification gate (owner reviews each item's screens before the next):** boot
  the `m8_pixel_tablet` AVD, `flutter build apk --release` in `controller_app`, install, drive the
  UI with `adb shell input tap`, and screencap via `adb shell screencap -p` + `adb pull` (never a
  PowerShell `>` redirect) into `docs/briefs/m16/emulator/`. Item 3 was verified this way
  (`01-connect`, `02-join` = "Show on this device", `03-play-phone-join`, `04-play-phone-game`):
  the join screen's "Code" chip renders in both host modes, and the pad overlay appears only on the
  game screen, clearing the game UI.
- **M16 item 4 (done; commit `b79ca83d`): the six sub-3:1 contrast fixes.**
  - "Ready"/"+43" text `good` → `ink` (4.5:1); D-pad centre dot → `padFaintAlpha` 0.5 (3.26:1);
    unused face circles → paper disc + ink dashes; state dot → paper core + state ring + ink edge;
    stick knob → full-ink edge (6.05:1).
  - Tests: new `toy_look` contrast test ("the pad parts keep 3:1") fails on old code (2.17:1) and
    passes after; `pad_look`/`phone_look`/`arena_waiting`/`night_screens` tests pin the new colours.
    Full `tools/check.sh` green (12/12); `tools/review.sh` 0 fail; coverage 92.8% (held).
  - Visually verified on the emulator (owner, Nov 19): `05`–`15` in `emulator/`.
- **M16 item 2 first half (done; commit `de4d4bd5`): hold a dropped player's slot in the lobby +
  restore their side.**
  - `AwaySlots.noteRoster` now holds a slot regardless of round (the `roundRunning` gate is gone);
    the join screen keeps an away player's team, dims their row (`_awayRowOpacity`) and labels it
    "… is away" (`HostText.awayLabel`, mock-up frame 1). Re-entry restores the same side.
  - Tests: `player_away_test` "drops with no round running keeps its slot, away" (fails on old code,
    passes after); a `join_screen_test` asserts the side is held and restored; the phone-host
    crash-scrubber test was updated (a dropped name now stays while away). Full `tools/check.sh`
    green (12/12).
  - Visual: unit-tested (a real two-device drop is needed to show it on the emulator — deferred).
- **M16 item 2 second half (done; commit `0aedb09`): the host-away card on the phone.**
  - `ServerGameHost.hostAway` now sends `host_away`/`host_back` even without a shared view; the TV
    app installs a `HostPresence` (AppLifecycleListener, `tv_host_presence.dart`, `hostAwayProvider`
    override, mirroring the phone host). The phone's card already showed on `HostAway`, so no phone
    change was needed.
  - Tests: `host_away_test` (hostAway reaches a phone with no view) + a new `host_away_tv_test`
    (lifecycle flips the away value and sends the messages). Full `tools/check.sh` green (12/12).
  - Unverified: real-device backgrounding on Android TV, and the abandon-after-grace path.
- **M16 item 1 slice A (done; commits `3b15897` protocol, `2fdda979` threading, `cfb805c` phone UI):**
  the round's clock and number on the joined phone.
  - Protocol (A1): `ViewStartMessage` gains optional `round`/`rounds`, `FrameMessage` gains optional
    `timeLeftMs` (additive, omitted when null, so an older peer decodes as before); `GameSnapshot`
    exposes a generic `timeLeftMs`; both games' snapshots expose their clock. `docs/protocol.md`
    updated.
  - Threading (A2a): party_host passes `round`/`rounds` from `NightState` (new `nightRoundNumbers`)
    into the game views → sessions → `view_start`.
  - Phone (A2b): a `roundStateProvider` reads the fields, and a paper strip over the pad shows
    "Round N of M" + a clock chip (mock-up frame 0). Tests: night/arena e2e + `round_state_test`.
    Full `tools/check.sh` green (12/12).
  - Visual: not captured — the emulator was stopped for the harness update.
- **M16 item 1 slice B (done): the phone's own coins and its place in the round.**
  - No wire change: a frame already carries every player's coins (`players[].coins`), so each phone
    reads its own from the decoded snapshot by its player id; an older peer is unaffected.
  - `GameSnapshot` gains `coinsOf(playerId)` / `placeOf(playerId)`; the Arena overrides them for the
    Bumper Round (place = coin rank, ties share the higher place), and the puzzle's snapshots keep
    null. `PhoneText.place(n)` says the ordinal ("1st", "2nd").
  - The strip adds a coin + the count and, right-aligned, the place, read from the last frame this
    phone drew (`viewDrawnProvider` + its own id). Tests: `arena_snapshot_test`, a puzzle snapshot
    test, `phone_text_test` and `round_state_test`. Full `tools/check.sh` green (12/12);
    `review.sh` 0 fail; coverage 92.8% (held).
  - Visual: not captured — the emulator is still stopped for the harness update (slice A's strip is
    also still uncaptured).
- **Thumby hooks added to the M16 spec (Nov 20).** The AI host Thumby is built in M17
  (`docs/briefs/m17/ux-review/PROPOSAL-v2.md`); M16 must be built ready for it. See PROPOSAL.md
  "Thumby integration (M17)" and PRD-v2.md "Prepares for M17 Thumby". Items that gained work: **5**
  (stable ID + spoken name per colour+accessory), **6** (caption/bubble slot, 3rd->2nd->1st order,
  timing for speech), **7** (host-side first-time-host flag with the coach marks), the picker (Party
  card first, highlighted), the phone-host fit of the night cards (measure first), lobby events as
  providers, and no growth of `sound.dart`. Item 5 onward resumes with these included.
- **Next (owner, Nov 20): "option C" is now the FIRST remaining M16 item, "Phone-host layout".** Build order:
  1) phone-host layout (slices below), 2) item 5 identity, 3) item 6 awards, 4) item 7 home screen + coach
  marks, then M17 Thumby. The owner said **not to start building yet**: slices are planned, nothing is
  briefed or dispatched. Design: `phonefit/optionC/design/DESIGN.md` (owner answers + review fix at the end);
  measurements: `phonefit/optionC/FINDINGS.md`.
- **Carried into M16** (unchanged): the ten device checks the owner has not run, and the open
  Stats question (whether dropped sessions show on the Stats screen). **Do not decide the Stats
  question; wait.** See docs/HANDOFF.md section 7.

## Phone-host layout: slices (planned Nov 20, not started)

Scope: night start, scoreboard, final scores, awards reveal, Arena results, puzzle results, game picker
(`games_screen.dart`), join screen (`join_screen.dart`). In-game boards are out. Each slice is one flash job
(at most 150 turns, one bounded change, brief of about 350 words, tests first in a new test file). All
paths below are under `packages/party_host/` unless noted. Note: `ui/host_screen.dart` already exists; read it
before S2 and extend or rename rather than clash with the design's new `HostScreen`.

- **S1 Frame scaler.** `HostFrame` + `HostFrameInfo` + `ToyType.frame` (title 40 / button 28 / body 22 / small
  20) in a new file wrapped in `lib/party_host.dart` above the Navigator; `ThumbySlot` empty. Test: new file
  reusing the harness of `test/phone_fit_option_c_test.dart` (frame size, s, MediaQuery override, tap hit-test
  still lands). Needs: none.
- **S2 Screen scaffold + shared widgets.** `HostScreen` (header / flexing body / always-visible footer),
  `ScoreRow`, `RoundSegment`. Test: footer never scrolls at the five sizes. Needs: S1.
- **S3 Night start + awards tile.** `night_start_screen.dart`, `AwardTile` with "i" popover; delete
  `nightStartCardWidthPx`. Test: no scroll, button visible, 4 players, five sizes. Needs: S2.
- **S4 Scoreboard + final scores** (4 and 6 players). `night_scoreboard_screen.dart`,
  `night_scoreboard_widgets.dart`; delete `nightScoreCardWidthPx`. Needs: S2.
- **S5 Awards reveal.** `night_reveal_screen.dart`, `night_reveal_widgets.dart`; delete
  `nightRevealCardWidthPx`; no Skip button (owner: waits for M17). Needs: S2.
- **S6 Arena results + puzzle results.** `arena_results.dart`, `puzzle_results_widgets.dart`,
  `puzzle_screen_results.dart`; delete `arenaResultsWidthPx`; badge number minimum 20 px (`player_badge.dart`).
  Needs: S2.
- **S7 Measure picker + join screen (no fix).** Extend the phone_fit test to `games_screen.dart` and
  `join_screen.dart` (never measured); report scroll, button, smallest text at the five sizes. Needs: S1.
- **S8 Fix picker + join screen** from S7's numbers (one job per screen if S7 shows both fail). Needs: S2, S7.
- **S9 Test hygiene + final gate.** Stop `packages/puzzle_game/test/tablet_board_png_test.dart:84` rewriting
  `docs/design/m13-tablet-board.png` on every run (write only under an env flag such as `UPDATE_PNG=1`);
  then the full phone_fit matrix (4 and 6 players, 5 sizes, smallest text >= 13 dp at 640x360) and the TV
  check at 1920x1080. Needs: S3-S8 for the matrix; the PNG change has no dependency and can run any time.

Parallel (no shared files): after S1, S2 and S7 together; after S2, S3 + S4 + S5 (waves of up to 3 jobs);
then S6 with S8; S9's PNG change in any wave. Commit briefs before each wave; `HostFrame` edits stay in S1.

Risks: (1) a 10-character nickname in the 190 px name column was judged by eye only: measure with the font
engine in S4/S6; (2) in-game boards are out of scope and may still scroll or overflow under the new frame
scale: measure later; (3) the 20 px floor is 13.3 dp at 640x360 and needs a real small-phone check (owner
answer 1); (4) the picker and join screen were never measured, so S8's size is unknown; (5) a global scaler
touches the TV d-pad focus ring: check 1920x1080.

**Released (Nov 21): m16.1 (0.14.0, build 981)** on 6272d949; Android + Windows + iOS internal TestFlight built (not promoted). Fixed, unverified, needs device check: pad clearance on a real phone and a notch; 13.3 dp small phone (640x360 frame is 11.4 dp); reveal crown at 640x360; join hint pill; reconnect to last host; away seat in the lobby.

**Resume here (bugs1, Nov 21):** B-032, B-033, B-034 fixed in 8623c2af, f22448cb, ac1618ec, plus review fixes 962c4aa0 (award popover per look, 159 + button height) and 1e4d6cb9. Full check.sh 12/12 green, nothing pushed. Device checks: B-032 cause not measured (owner confirmed back-out); B-033 TV popover height is arithmetic plus tests; B-034 footer top stays flush. Details: docs/briefs/m16/bugs1/REVIEW.md.

**Resume here (process1, Nov 21):** owner items 1 and 2 done: every-look rule (review-rules A6, job template, digest rule 15), `all_looks.dart` helper plus `award_explanation_looks_test.dart`, shared worker rules in `docs/briefs/templates/COMMON.md` (briefs target ~200 words), runner skips the wave review on a one-wave run and lints `report:` lines. Details: docs/briefs/m16/process1/REVIEW.md. Nothing pushed.
**Next (trial, owner item 3):** the next batch trials "driver makes no calls while the runner works; runner writes a ~40-line digest" (docs/briefs/m16/bugs1/IMPROVEMENTS.md proposal 1); not built yet.

**Resume here (process2, Nov 21):** the flash-worker scripts are in (nothing pushed): `tools/mine.sh` (check what I touched, workers use it), `tools/churn.sh`, `tools/wait-run.sh <dir>` (no-polling trial, exits 0 DONE / 1 STOPPED / 2 STALLED or OVERRUN / 4 still running), `tools/run-stop.sh` (STOP.md at every runner stop), `tools/selftest.sh` plus `tools/check.sh tools` (shell self-tests in `tools/tests/`), the worker extract `docs/worker-extract.md` in flash.sh's prompt (flash.sh is protected: edit it by hand), and the runner split (`run-steps.sh`, `run-review.sh`) with lock, `RUN_MAX_MIN` time limit and churn auto-apply. Deferred findings: docs/code-health.md "M16 process2 leftovers". Details and verdicts: `docs/briefs/m16/process2/REVIEW.md`.

**Released (Nov 23): m16.2 (0.14.0, build 1320)** on 47f056f5; Android + Windows + iOS internal TestFlight built (not promoted); main and m16 pushed. Fixed, unverified, needs device check: pad colour with a crown; rejoining mid-round keeps its look until the round ends; blank nickname; join badge shows no number until pairing; look kept for a minute after a drop.

**speed1 (Nov 23):** check.sh `-j N`, result cache (`--no-cache`; release uncached), `tools/affected.sh`, affected-only runner check, runner formats job files, brief-check test-only WARN, job-metrics WALL, worker checks with mine.sh only. Baseline 670 s serial; -j 4 cold 493 s; warm retry 125 s; affected-only (toy_look change) 259 s. Open: -j 4 made host's live_stats_unmarked_test fail once (flaky under load); next runner batch is the first real affected-only wave. Details docs/briefs/m16/speed1/DRIVER-NOTES.md, REVIEW.md.

**Resume here (bugs2, Nov 23):** B-035 (4fd7feed, 8 px gap join text/Change), B-039 (e110d713, lobby rows one left-aligned centred column), flk1 (2964c410, live_stats_unmarked_test waits for the settled pass) committed; full check.sh --no-cache green 13/13 (731 s). First real affected-only wave: combined check ran format, analyze, phone, host and skipped protocol connection metrics kit look arena puzzle tools: right. Nothing pushed. Device check needed (Fixed, unverified): join screen gap, lobby list alignment. Open: 320 px join row overflow (owner layout decision), flake proof under real load (-j 4 showed arena and tools load flakes). Details: docs/briefs/m16/bugs2/REVIEW.md.

**Resume here (bugs4, Nov 24):** B-040 fixed. Cause: the joined phone's night result card overflowed small landscape screens (6 standings: Waiting line at y 341 of 320), now scales to fit; owner Q8 rework: new capability-gated `night_end` message (capability `night`, docs/protocol.md) sent when the host's awards reveal ends or is skipped; the phone's last-round card says "Awards coming..." then shows the awards, final standings and the true winner. Commits nc1 dfb3f933-ish..np2 81c3ee87 plus the wrap; full check --no-cache 13/13. Fixed, unverified, device check: phone card fit on a real small phone; night_end on a real two-phone night (phone host and TV host); early End night. Details: docs/briefs/m16/bugs4/REVIEW.md

**Released (Nov 24): m16.3 (0.14.0, build 1429)** on fb2f6a5e; Android + Windows GitHub Release and iOS internal TestFlight built (not promoted); main and m16 pushed. Fixed, unverified, needs device check: phone result card fit on a real small phone; night_end on a real two-phone night (phone host and TV host); early End night; winner banner clear of the top bar; Shape Race top bar clears pieces on a phone and a tablet; lobby row alignment; join line gap before Change.

**Resume here (pilot1-prep, Nov 24):** `tools/verify-batch.sh <batch> <base>..<tip> [--tracker-dir D --claim B-nnn=Status | --no-tracker]` (checks commits and identity, run.log full check, tree churn, tracker claims, STATUS names tip; exit 0 PASS, 1 FAIL, 2 bad use), read-only agent `thumb-verify` (Sonnet; synced to ~/.claude/agents), Fable prices in `tools/agent_cost.py` ($8 in / $40 out, cache read 0.025x; source platform.claude.com pricing page; Fable calls do appear in transcripts as model claude-fable-5-2, 1600 call lines found). Commit 2b6cb008; check.sh tools green (280 s). Done inline by the driver, no runner. Open: page lists Opus 5.5 / Sonnet 5.5 cache hits at 0.05x input but agent_cost.py uses 0.1x (overstates Opus and Sonnet cache reads 2x); owner/main call whether to change it. Nothing pushed.

**version1 (Nov 24): the app version comes from the release tag.** Tag mX.Y -> 0.X.Y (`tools/tag-to-version.sh`); release.yml and codemagic.yaml pass `--build-name` and `--dart-define=APP_VERSION`; both app_info.dart read APP_VERSION (local builds 0.0.0-dev); pubspec `version:` lines removed; release.sh takes the version from the tag. Also agent_cost.py opus/sonnet cache reads 0.05x. Tip: e0e48c24 (code and CI; base 5a3877b7). Fixed, unverified: needs device check (the next tag, m16.4, should show 0.16.4 on TestFlight/Play/TV). Nothing pushed.

**Resume here (wave1-789, Nov 24):** tip d3410f23 (+ this STATUS commit); items 7-9 wave 1 re-cut per the Fable review: 9a Connect row fits 320 px (new connect_manual_entry.dart), 9c slider semantics at four sites, 9d1 GameScreenShell extract, 7a awards flow test (tie, TV and phone host), 9d2 Arena HUD "Round N of M" and red clock at 15 s, 9d3 map name in the HUD, plus fix round 1. Not done: Shape Race HUD round, 9b, 9e, all of item 8, TV-word guard test. Fixed, unverified, needs device check: sliders read by a real screen reader; Connect row on a 320 px phone. Nothing pushed.

## Coverage (Nov 25, close batch): TOTAL 93.0% (21419/23034), floor 92.8% met.

**Resume here (close done, Nov 25):** batch docs/briefs/m16/close finished (report REPORT.md): coverage 93.0%, full check green, milestone-end review 0 must; open owner question c4 (pad top bar 12 px at 568x320 TV). Tip 2dbd56c1. Nothing pushed.

**Released (Nov 25): m16.4 (0.16.4, build 1664)** tag on 3f32a354 (release.sh; GitHub Release run 45627438563 success, Android and Windows; iOS Codemagic TestFlight success, internal only, not promoted). Fixed, unverified, needs device check: phone result card fit on a real small phone; night_end on a real two-phone night (phone host and TV host); early End night; winner banner clear of the top bar; Shape Race top bar clears pieces on a phone and a tablet; lobby row alignment; join line gap before Change; sliders read by a real screen reader; Connect row on a 320 px phone; app shows 0.16.4 on TestFlight, Play and TV. Known, not release-blocking: pad top bar 12 px overflow at 568x320 in the TV look.

**Released (Nov 25): m16.5 (0.16.5, build 1717)** tag on fb8a71a4 (release.sh; GitHub Release run 45734110396 success, Android and Windows; iOS Codemagic TestFlight success, internal only, not promoted). Fixed, unverified, needs device check: "More" menu holds Settings and Diagnostics on every look (B-043 pad hides under the result card; "Waiting for the host" text size); round clock keeps clear of the right-hand controls (B-044) on a real phone and TV; connection chip shrinks to an icon on narrow phones; app shows 0.16.5 on TestFlight, Play and TV.

**Planned (owner, Nov 25):** January 2027 item, hard stop end of February: move iOS builds to Xcode 27 (Apple ITMS-90725, required from April 2027). Trial in ios-testflight only first; may need a Flutter bump from 3.47.8.
