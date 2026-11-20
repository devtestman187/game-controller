# M17 — Host/Commentator competitive synthesis (six peers)

Status: research digest (Flash worker, Nov 19). Read-only; no code. Sources are the six
digests under `docs/briefs/m16/ux-review/research/` plus the URLs each digest already carries.
"Absent / no evidence" means the digest does not report it, not that the peer has none.

## The four persona models the peers use

1. **Named mascot host** — a recurring in-world character who greets, explains, reveals.
   - Wii Party: **Party Phil** ("I'm your charming host, Party Phil!"). Boot/taxonomy, rules,
     Suggestions. Speaker of result lines is *not* attributed.
   - Mario Party Superstars + Jamboree: **Toad** (board explanation, recap, final ceremony),
     with Koopa Troopa / Toadette / Kamek in supporting guide roles.
2. **Named game-show host (studio/TV framing)** — LEGO Party!: **Ted Talker and Paige Turner**,
   "a TV game show … with the players as contestants". Branded round transitions, stage entrance,
   "host commentary plays" on the Minigame Results screen, studio finale + trophy.
3. **Unattributed announcements** — result/scores lines with no evidenced speaker ("the standings
   are announced", "the interim results are displayed") in Wii Party and both Mario Parties.
4. **No narrator; "host" = structural role only** — AirConsole (Host = master controller; no
   end-of-night moment at all) and, as far as the digest goes, Jackbox (host = the person running
   the game; no per-game host persona is named — note Cookie Masterson is **not** in the digest,
   a coverage gap, not a negative finding).

## Where the narration appears (13-stage)

- **Round result / Minigame Results** — LEGO Party "host commentary plays" (closest published
  precedent for M17's round-result headline).
- **End-of-night ceremony** — Mario Party Superstars: bonus stars announced last-to-first →
  Toad's recap → commemorative photo (closest precedent for M17's award-reveal narration).
- **Rules / board intro / setup** — Party Phil (skip after first play), Toad (board explanation),
  Koopa Troopa (settings). Frame moments, not continuous in-round talk.

## Cross-cutting lessons

- **Named hosts appear at frame moments, not throughout a round.** No digest attributes continuous
  in-round commentary to the named host; in-round lines are unattributed announcements.
- **Narration is suppressible/skippable.** Wii Party: [A]-skip after first play. Superstars:
  explanation suppressed in pause settings. → supports M17's default-OFF consent + template fallback.
- **No peer uses generated/dynamic narration.** Every host line is authored content. The AI part
  is differentiation, not parity. The most phone-controller-like peer (AirConsole) has no narrator
  and no end-of-night moment — its own digest calls stage 12 the analog's biggest hole and
  "a differentiation opportunity rather than a catch-up item".

## Cautions (what the digests cannot support)

- No line-length / word-count data for any host line (M17's ≤140-char cap is a product decision).
- No voice-casting / spoken-vs-text evidence beyond the words "hear" (Wii Party, Superstars) and
  "plays" (LEGO).
- 8-year-old family tone has almost no peer narration evidence → must be an internal eval criterion.

## Decision this forces

M17 must pick **persona vs no-persona** for its "voice": named character (Models 1–2) or
unattributed game voice (Model 3). That single choice decides whether the deterministic fallback
strings and the LLM strings share one voice, and whether the TV host needs visible character art.
