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
