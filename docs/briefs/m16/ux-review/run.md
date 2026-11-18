# M16 UX review — run record

Status: **Complete, pending owner review.** GATE 2 was approved (all 9 items, stay
evidence-driven, colour + accessory in scope). Nothing is implemented; this task produced
documents and mockups only.

## What was done

### Setup
- Worktree `E:\AI\game-controller-m16`, branch `m16` confirmed (`git branch --show-current`).
- Two live devices verified and used: **Pixel Tablet** (`com.thumbparty.app`, controller,
  1600x2560 @ 320 / override 354) and **Sony BRAVIA VH1** (`com.thumbparty.tv`, TV host,
  3840x2160 panel rendering 1920x1080 @ 320). Both reached over adb.
- Capture pilot passed: a Flash worker drove the tablet, captured a real screenshot, read it
  with vision, and returned a numbers-only record. Established the `screencap -p` + `pull`
  protocol (no PowerShell `>` binary redirection) in `worker-spec.md`.

### Phase 2 — live visual findings (all workers pinned `deepseek-account` / `deepseek-flash`)
One findings file per batch under `findings/`:

| File | Coverage |
|---|---|
| `vf-tv-01.md` | TV host: shell, Look and sound, game picker, Party night setup (1920x1080) |
| `vf-tab-01.md` | Tablet native: pad/connect screen + Settings |
| `vf-matrix-phones.md` | Pad at 6 phone logical sizes (667x375 … 932x430) via `wm size`/`wm density` override |
| `vf-matrix-tablets.md` | Pad at 4 tablet logical sizes (1080x810 … 1366x1024) |
| `vf-2dev-lifecycle.md` | Connection lifecycle: join, connected, drop, re-entry, host-away |
| `vf-2dev-round.md` | Live Bumper Round: countdown, in-round, results, scoreboard |

Synthesis helpers (derived, not raw findings): `_gap-inventory.md` (537 lines, per-stage
measured gaps) and `_research-matrix.md` (294 lines, per-stage benchmark).

Key measured facts that drive the shortlist:
- The controller shows **no round data** at stages 7–10 (no clock, score, coins, round number,
  winner) — cross-cutting 1.
- Drop is **invisible**: the TV slot vanishes in 0.9 s with no away state; re-entry
  auto-reconnects but does not restore the side — stage 13.
- The pairing code lives only on the host shell / Arena card, not on the join screen a player
  is looking at — cross-cutting 3.
- Contrast below bar: `good`-on-`paper` 1.97:1 ("Ready", "+43"), dashed face circles 1.82:1,
  state dot 1.00:1, D-pad disc 2.16:1, stick knob 2.57:1 — cross-cutting 12.
- Round numbering disagrees ("Round 1" drawn twice); clock never turns `bad`; Resume
  green-vs-red — cross-cutting 2, 4, 7, 19.

### Phase 3 — competitive research (6 digests under `research/`)
Mario Party Superstars, Mario Party Jamboree, LEGO Party! (real title, SMG Studio/Fictions,
2025), Jackbox Party Pack, AirConsole, Wii Party. Every claim carries a URL; fetched content
treated as untrusted data.

### Phase 4 — synthesis
Gap inventory vs research matrix compared on the 13-stage taxonomy; a ranked 9-item shortlist
(Tier 1: items 1–5; Tier 2: 6–9) was presented and **approved by the owner** (all 9, stay
evidence-driven, colour + accessory in scope).

### Phase 5 — mockups and proposal
- `mockups/proposal-mockups.html` reuses `docs/design/party-mockups.html`'s system
  (`mockup-parts.js`, `mockup-maps.js`): 10 frames (9 items, item 5 split phone+TV) at TV
  1280x720 / phone 816x384, Sunny + Night; rendered to 20 PNGs with headless Chrome.
- A vision review found and fixed 4 issues (Night title contrast, missing Save button, Night
  dashes, award-chip overlap); re-rendered and re-confirmed.
- `PROPOSAL.md` (118 lines) written: the five-first summary, the 13-stage flow (now vs proposed
  vs evidence), the 9 recommendations with impact/effort/scope, host-setup coverage, proposed
  screen states, rejected ideas, and open questions.

## How this was verified
- `git status --short`: only the 3 pre-existing churn files are modified
  (`tv_test_app/windows/flutter/generated_plugin_registrant.cc/.h`, `generated_plugins.cmake`);
  `git diff --stat` is empty. **No `lib/`, `test/`, protocol, map, or dependency file changed.**
- 15 files present under `docs/briefs/m16/ux-review/`; each findings file carries measured
  numbers and `unmeasured`/`absent` labels, never adjectives.

## What remains unproven (honest status)
- **Contrast ratios are vision-sampled estimates.** The authoritative check is the `toy_look`
  contrast test (already 4.5:1 / 3:1 by token); it was not re-run because that would mean a
  code change. Every sub-bar ratio above is a candidate to confirm, not a shipped conclusion.
- **iOS**: no simulator on this Windows machine (cloud-built only). Layout was proxied by
  Android rendering at iPhone logical sizes — valid because Flutter layout is size-driven and
  fonts are bundled — but **Safe Area insets and system text-scaling were not measured**
  (needs iOS device check).
- **Stage 4 (player creation) and stage 12 (end of night)** were not captured live; they rely
  on the static mockups (`m14-sunny-17/18-phone-settings/colour-taken`, `m14-sunny-06/07-award/
  final-scores`).
- **A peer one build older** was not exercised live (protocol compatibility is covered by
  existing tests).
- The same TV screen measured in two passes produced differing numbers (gap inventory
  cross-cutting 10); those pairs are treated as evidence-base divergence, not change.

## Known minor artifacts
- Frame 06 (both themes) has a ~10x3 px dark speck at ~(527,109), a leftover from erasing the
  banner placeholder; cosmetic only, it touches no chip and no header divider.
- The mockup TV frame is 1280x720 (the existing system's size), not the 1440x576 the task text
  mentioned; `party-mockups.html` uses 1280x720, so that was kept.

## Follow-up: app-start screen (owner request, Nov 17)
- The owner asked for proposals around the initial app start, which currently opens straight to
  the pad with no welcome, no navigation, and a stale-host connect failure.
- Wrote `APP-START.md`: three options (A home hub + auto-connect — recommended; B two-button
  split; C guided first-run), grounded in the measured stage-1 findings and the research (peers
  open on a hub/menu with explicit choices).
- Added `research/onboarding-best-practices.md`: two onboarding articles mined for coach-mark /
  contextual-tips best practice (noted: neither covers children or coach marks directly; the
  extensions are marked as inference).
- Owner decisions (Nov 17–18): landscape; auto-join the last game with a Settings toggle;
  nickname + avatar on top, tap avatar to edit; "Remember this screen" separate; three device
  roles (Join a Game / Play here / Display here) in a FIXED button order; first-time help = coach
  marks on the real Home screen (not a wizard), with a "Show tips" toggle to replay them; generic
  display strings use "screen" not "TV".
- Mocked as 6 frames (10–15: home found TV, home no TV, coach mark Join a Game, coach mark Play
  here, coach mark Display here, connection settings) in `proposal-mockups.html`; rendered
  `proposal-10-*.png` … `proposal-15-*.png` (Sunny + Night). Vision-reviewed; all pass. The
  wizard and its CSS animation were removed.

## What the owner should review
`PROPOSAL.md` and `APP-START.md`, the 32 PNGs (or `mockups/proposal-mockups.html` in a browser).
All open questions are resolved (item 1 approved; colour + accessory approved with a future path;
Windows host parity needed for testing + automation).
