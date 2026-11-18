# M16 Friendlier start: status

Branch `m16`, worktree `E:\AI\game-controller-m16`, cut from the `m14` line after `m14.9`. The
plan is `docs/PRD-v2.md` "Milestone 16", written from the evidence-driven UX review in
`docs/briefs/m16/ux-review/`.

**New developer or other agent taking over: read [docs/HANDOFF.md](../../HANDOFF.md) first.**

## Resume here (Nov 18, 2026: the UX review is done; nothing is built yet)

- **ux-review (done, uncommitted as of writing).** The end-to-end player-flow review and the
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
- **Next:** start the M16 scope in build order (see PRD-v2.md "Milestone 16"). Nothing has been
  implemented — the review changed no `lib/`, `test/`, protocol, map or dependency.
- **Carried into M16** (unchanged): the ten device checks the owner has not run, and the open
  Stats question (whether dropped sessions show on the Stats screen). **Do not decide the Stats
  question; wait.** See docs/HANDOFF.md section 7.
