# M16 Friendlier start: status

Branch `m16`, worktree `E:\AI\game-controller-m16`, cut from the `m14` line after `m14.9`. The
plan is `docs/PRD-v2.md` "Milestone 16", written from the evidence-driven UX review in
`docs/briefs/m16/ux-review/`.

**New developer or other agent taking over: read [docs/HANDOFF.md](../../HANDOFF.md) first.**

## Resume here (Nov 19, 2026: item 1 slice A built; slice B next)

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
- **Next:** item 1 slice B — the coins and the round's result on the phone (PRD-v2.md "Milestone 16").
- **Carried into M16** (unchanged): the ten device checks the owner has not run, and the open
  Stats question (whether dropped sessions show on the Stats screen). **Do not decide the Stats
  question; wait.** See docs/HANDOFF.md section 7.
