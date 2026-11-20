# M17 — AI Host/Commentator ("Thumby"): status

## Where it stands (Nov 20, 2026)

**`ux-review/PROPOSAL-v2.md` is the settled plan** (owner accepted all ten answers, Nov 20).
`ux-review/PROPOSAL.md` (v1) is **superseded**; the sections below describe v1 and are kept for
history (v2 drops run-time LLM text, cloud TTS and the adult opt-in). No code written. **Next:** the M16
Thumby hooks (`docs/briefs/m16/ux-review/PROPOSAL.md` "Thumby integration (M17)"), then M17 Phase 0
(decisions + measure the night cards at ~360x640 dp). PRD-v2.md has "Milestone 17".

Status (v1, superseded): **UX design complete and owner-approved (Nov 20, 2026). No code written.** Resume
implementation from here. Seed thinking: `AI-HostCommentator-Investigation.md` (this folder).
Evidence + proposal: `ux-review/` (same template as M16's `docs/briefs/m16/ux-review/`).

## What this is

An "AI host/commentator": a named host character — **Thumby**, a cute cartoony thumb — who
narrates the party night with a short line at each beat. **Template-first**: today's deterministic
strings stay as the offline fallback; the LLM line is an async *upgrade* that renders only on
success within a latency budget. Backend / provider / consent / safety / eval design lives in
`AI-HostCommentator-Investigation.md` (Cloudflare Workers AI default, adult opt-in default OFF,
sanitized nickname only, ≤140-char plain text).

## Decisions (owner, Nov 19–20)

- **Concept:** a dedicated host character (not Robo, not the players), named **Thumby**.
- **Final look:** Rally's tall leaning thumb body + Cheer's grinning face (brows, small nose, wide
  grin) set high under the pad + a **small handheld mic** + a **smooth lower body (no joint folds)**
  + a **bright six-stripe rainbow nail**.
- **Voice:** V1 — text + a canned voice pack (captions always on; a separate host-voice channel).
- **Cadence:** L1 — ceremony (round result · award reveal · final crown) + between-rounds
  (scoreboard quip · round intro "get ready").
- **Scope:** host screen only (TV / Windows / phone-host). No phone-client change in this cut.

## Surfaces (the seams commentary swaps into)

| Moment | Seam (file:line) | Today's string |
|---|---|---|
| Round-result headline | `party_host` `lib/src/ui/arena_results.dart:88-90` (header); `puzzle_screen_widgets.dart:7-19` | "Robo wins!" / "Done!" / "Draw" / "Left wins!" / "Right wins!" |
| Award-reveal narration | `party_host` `lib/src/ui/night_reveal_widgets.dart:94` (`outcome.reason ?? outcome.award.line`); missed branch `:74-85` | "Most carries home together" / "Not won tonight" |
| Award catalogue | `party_host` `lib/src/night/night_awards.dart:28-111` | 12 awards × title + line, 3 per night |
| Reveal pacing | `party_host` `lib/src/ui/night_reveal_screen.dart:25,29` | won 4000 ms, missed 2000 ms |

## Deliverables (all under `docs/briefs/m17/`)

- `ux-review/PROPOSAL.md` — ranked shortlist, the decision, the Thumby design, voice/cadence, guardrails, M16 fit.
- `ux-review/research/host-commentator-synthesis.md` — six-peer host/announcer synthesis.
- `ux-review/research/tts-voice.md` — TTS cost/latency/safety + the tier recommendation.
- `ux-review/findings/night-reveal-capture.md` — live capture of the reveal + exact placements.
- `ux-review/mockups/` — Thumby flow frames (round result, scoreboard, round intro, award won/missed,
  final crown) + the final character sheet, Sunny + Night, with HTML sources.

## Next (Claude drives; Flash workers do the work)

1. Port the final Thumby drawing into the app (a host-side widget/painter, reusing the toy_look
   character pipeline).
2. Implement `CommentarySource` (Template + Remote) per the investigation file §5.2; wire the two
   swap points above; register the client at both shells' provider overrides
   (`controller_app/main.dart:47`, `tv_test_app/main.dart:43`).
3. New consent key + prompt, default OFF (investigation file §6).
4. Canned voice pack (build-time) per V1; optional cloud TTS after.
5. Responsible-AI eval suite (investigation file §9).
Build order: land **after M16 item 6** (end-of-night awards) is stable — the reveal already exists
in code; commentary layers on top.

## How we work with the Flash agents

Claude Code drives (per `docs/HANDOFF.md` §10 Claude side + `docs/agent-workflow.md`); Flash workers
(`deepseek-account/deepseek-flash`) do the mechanical work via `tools/flash.sh`. Slice before
dispatch; one bounded change per worker; the driver reads the diff and re-runs
`tools/check.sh`/`review.sh` — never take a child's word as evidence. (This M17 UX work itself was
done in DeepSeek Harness with pinned `subagent` calls; the artifacts above are the handoff.)
