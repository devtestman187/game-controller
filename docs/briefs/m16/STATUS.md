# M16 Friendlier start: status

Branch `m16`, worktree `E:\AI\game-controller-m16`, cut from the `m14` line after `m14.9`. The
plan is `docs/PRD-v2.md` "Milestone 16", written from the evidence-driven UX review in
`docs/briefs/m16/ux-review/`.

**New developer or other agent taking over: read [docs/HANDOFF.md](../../HANDOFF.md) first.**

## Resume here (Nov 18, 2026: item 3 built; item 4 next)

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
- **Next:** item 4, the sub-3:1 contrast fixes (PRD-v2.md "Milestone 16").
- **Carried into M16** (unchanged): the ten device checks the owner has not run, and the open
  Stats question (whether dropped sessions show on the Stats screen). **Do not decide the Stats
  question; wait.** See docs/HANDOFF.md section 7.
