# M17 — "Thumby", the AI host: UX proposal

Status: **proposal** (owner reviewed the mockups; nothing implemented).
Milestone: M17 (proposed) · Date: 2026-11-20.

## 1. The decision (owner-approved)

| Axis | Decision |
|---|---|
| Persona | A dedicated host character, **Thumby** — a cute cartoony thumb |
| Final look (Nov 20) | Rally's tall leaning thumb body + Cheer's grinning face (brows, small nose, wide grin) set high under the pad + a small handheld mic + a smooth lower body (no joint folds) + a bright six-stripe rainbow nail |
| Voice | V1 — text + a canned voice pack (captions always on) |
| Cadence | L1 — ceremony (round result · award reveal · final crown) + between-rounds (scoreboard quip · round intro) |
| Scope | Host screen only (TV / Windows / phone-host) — no phone-client change this cut |

## 2. Why a dedicated host character

The peer evidence (`research/host-commentator-synthesis.md`) shows the ceremony-style narrators —
Toad's recap + last-to-first reveal, Party Phil's frame, Ted Talker + Paige Turner's show — are all
*dedicated* host characters, never player-characters. A dedicated host is cleanest for an
8-year-old and avoids the "Robo plays *and* hosts" confusion. Thumb Party's Toy Box Toon world
already has the character pipeline (worker/marble, eyes + accessories) to give it a face cheaply.

## 3. What Thumby is

- A cute, cartoony **thumb**: Rally's tall leaning silhouette (~6°, pad head, narrow neck, slim
  mitten arms), Cheer's friendly face (brows, small nose, wide grin) set high under the pad, one
  small handheld mic, and a smooth lower body.
- **Colour**: peach-cream `#FFD1A8` skin, navy `#1E1646` ink outline + hard shadow, with a bright
  **six-stripe rainbow nail** (red/orange/yellow/green/blue/purple) as the one colour pop. Never a
  player colour, never Robo.
- **Presence**: a small character in the corner of the relevant cards, with a speech bubble holding
  the narrated line. The existing inline text stays as the **always-on caption**, so the fallback
  never looks broken.

## 4. Where Thumby appears (L1 surfaces)

| Moment | Surface | Thumby's line (sample) |
|---|---|---|
| Round result | Arena/puzzle results card header ("Robo wins!") | "Robo takes the round!" |
| Between rounds | Night scoreboard "Round 2 of 3" | "Robo's ahead — but it's early!" |
| Round intro | Get-ready / 3-2-1 card | "Round 2 — here we go!" |
| Award reveal (won) | Award card (winner + reason + "+3") | "For the most carries home together — Robo!" |
| Award reveal (missed) | Award card ("Not won tonight") | "Nobody took it tonight!" |
| End of night | Final scoreboard (crown) | "And the champion is… Robo!" |

Placement rule: Thumby + bubble sit in **empty space** (bottom-left), never covering text, buttons,
badges, the crown, or the "+3".

## 5. Voice (V1)

- A **canned pack** (pre-rendered at build time): round stings, "And the winner is…", award names,
  the night intro/outro. Zero runtime cost/latency, works offline — how Jackbox actually does it.
- Captions always on; a **separate host-voice channel** with its own volume/mute (master / music /
  SFX / host voice), ducking music −8 to −12 dB during speech.
- **Optional V2 (cloud TTS)** for the LLM-written lines later: Cloudflare `melotts` primary, Groq
  `Orpheus` secondary, 4 s watchdog so a slow line is silently dropped. ⚠️ Avoid OpenAI's Speech API
  (deprecated — shuts down Jan 6 2027) and ElevenLabs free tier (no commercial licence).

## 6. Guardrails (non-negotiable)

- **Template-first**: today's deterministic strings are the offline fallback; the LLM line is an
  async *upgrade* that renders only on success within budget.
- **Adult opt-in, default OFF**; sanitized nickname only (allowlist, Unicode-strip); ≤140-char plain
  text; 8-year-old-friendly tone; no URLs/markup.
- **Never touch the game rules**; the round never waits on the LLM or the voice.

## 7. M16 fit

- The **award reveal already exists in code** (`night_reveal_screen.dart` + `night_reveal_widgets.dart`):
  Thumby layers on top of it; the narration seam is `outcome.reason ?? outcome.award.line` (:94).
- The **round-result headline** is the `ToyCard` header (`arena_results.dart:88-90`,
  `puzzle_screen_widgets.dart:7-19`): Thumby's bubble narrates beside it.
- **No phone-client changes** in this cut — host screen only (TV / Windows / phone-host).

## 8. Evidence

- `research/host-commentator-synthesis.md` — the six-peer host/announcer synthesis.
- `research/tts-voice.md` — TTS cost/latency/safety and the tier recommendation.
- `findings/night-reveal-capture.md` — live capture of the reveal + exact placements.

## 9. Mockups

`mockups/` holds the Thumby flow frames (round result, night scoreboard, round intro, award reveal
won + missed, final crown) and the final character sheet, in Sunny and Night, plus the HTML sources
(`thumby-flow.html`, `thumby-final.html`).

## 10. Open questions for the owner

1. Thumby's name and look are final (owner, Nov 20).
2. Whether Thumby should also appear on joined phones (a future protocol bump) — deferred in this cut.
3. Consent prompt wording and settings placement (new adult opt-in, default OFF).
