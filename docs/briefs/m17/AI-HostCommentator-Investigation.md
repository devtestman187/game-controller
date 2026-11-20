# M17 — AI Host/Commentator — Investigation

**Status:** Investigation (no code written). Architect's record of findings, for the owner to plan the UX and judge fit on top of M16.
**Milestone:** M17 (proposed) · **Scope ref:** `AI-HostCommentator-Investigation`
**Date:** 2026-11-19 · **Repo:** `E:\AI\game-controller-m16`

---

## 1. Summary (TL;DR)

Propose an **"AI host / commentator"** for Thumb Party: a hosted LLM that writes a short
**per-round headline** and **end-of-night award narration**, shown on the TV host only. It is
**template-first**: today's deterministic strings are the offline fallback, and the LLM result is
an async *upgrade* that renders only when online, consented, and within a latency budget. Any
failure — offline, declined, timeout, error, quota — falls back to the existing scripted text, which
is already guaranteed to render in every case.

Recommended default backend: **Cloudflare Workers AI** (`glm-4.7-flash`), a free tier with **no
card, no overage path, and no training/retention**. A single OpenAI-compatible HTTP client plus a
config map lets us target the top cheap models with no per-provider SDKs. The feature works
identically when the host is a phone. Safety is built around the one real risk surface: the
player-controlled nickname (prompt injection + PII).

---

## 2. Objective and scope

- **What:** an LLM host that narrates a party night — a one-line round result and the award reveal.
- **Online with offline fallback:** online LLM call only when an adult opts in and the network is
  available; otherwise the existing template text. The LLM is an *enhancement*, never a gate.
- **MVP boundary (host-only):** TV/desktop/phone **host** only. No phone-client changes, no protocol
  version bump. Phone commentary is a possible follow-up.
- **Learning goals (owner):** build a real AI feature + a responsible-AI eval suite.

---

## 3. Where the product stands today (context)

- Flutter monorepo: phone controller (Android 12+ / iOS 26) + TV host (Android TV / Windows desktop)
  + **phone-as-host** ("Play on this phone"). 1–4 players, a "party night" of 3–5 rounds, two games:
  **Shape Race** (puzzle) and **Arena** (race + Bumper Round).
- Latest release `m14.9` (v0.14.0, build 845); **M16** ("friendlier app start") in progress.
  2,653 tests green, ~92.9% coverage.
- The only existing "AI" is **Robo**, a host-side CPU marble that fills the Bumper Round, with three
  difficulty tiers in `CpuPilot` (`packages/test_game/lib/src/cpu_pilot.dart`). It is heuristic, not ML.
- **There is no per-round commentary today.** Award text is a deterministic `const` catalogue:
  - Catalogue: `packages/party_host/lib/src/night/night_awards.dart:28-111` (`title`/`line` `:122-136`)
  - Decision (integer comparison): `night_award_results.dart:122-162` (`decideAwards` `:122-138`,
    `_decide` `:141-162`; `awardPoints=3` `:38`)
  - Display text getter: `NightAwardOutcome.reason` `night_award_results.dart:30-32`
  - Render: `ui/night_reveal_widgets.dart:61-107`; reveal pacing `ui/night_reveal_screen.dart:25,29,87-88`

---

## 4. Constraints that shape the feature

1. **Offline by design** — no internet except opt-in analytics (online play is a post-v2 idea). An
   online LLM call is an *exception* the owner must bless; it must degrade to offline cleanly.
2. **Child-safe + no PII** — players include ~8-year-olds. Stats are aggregates only (no
   names/nicknames/device ids), adult consent gates crash/stats. Any AI telemetry must pass a consent gate.
3. **Deterministic rules** — seeded, fixed 1/60 s step; no wall clock in rules; immutable versioned
   snapshots. Commentary must never touch the game rules.
4. **Quality bar** — zero analyzer issues, ≤380 lines/lib file, coverage ≥92.9%, no new dependency
   without the owner's say-so, additive/capability-gated protocol.
5. **Network posture (phone host)** — HTTPS-only works with no new platform config (Android minSdk 31
   blocks cleartext; iOS ATS blocks `http://`). A LAN `http://` LLM would need new manifest/ATS
   exceptions (none exist today).

---

## 5. AI feature design

### 5.1 Surfaces (host-only)

| Surface | Today (fallback) | LLM upgrade | Generate at | Swap at |
| --- | --- | --- | --- | --- |
| Round result headline | Arena title inline `ui/arena_results.dart:88-91`; puzzle `_resultsHead` `ui/puzzle_screen_widgets.dart:7-19` | one-line narrated result | `_finished` `game_screen.dart:240-259`, `puzzle_screen.dart:189-225` | header `arena_results.dart:107`, `puzzle_results_widgets.dart:60,65` |
| Award reveal narration | `reason ?? award.line` `night_reveal_widgets.dart:94`; missed branch `:74-85` | one-line narration per award | during scoreboard, before reveal | `night_reveal_widgets.dart:94` (+ `:74-85`) |

Fallback is guaranteed today: won → `reason ?? award.line` (reason non-null whenever value is);
missed → `NightText.notWon` + `award.line`; header → `award.title`. The LLM line renders only on
success within budget; otherwise the existing string stays (initial state = today's behavior).

### 5.2 Architecture

- `CommentarySource` interface, two implementations:
  - `TemplateCommentary` — deterministic, today's strings (the offline fallback).
  - `RemoteCommentary` — one OpenAI-compatible `POST {base_url}/chat/completions` via `package:http`
    (long-lived `http.Client`), non-streaming, `thinking` disabled, `max_tokens≈96` (cap output, not
    prompt — output tokens dominate cost), byte-stable system prefix for prompt-cache hits.
- **Graceful degradation:** 4 s deadline + abort → 1 retry on 429/503 only → 3-failure / 5-min
  circuit breaker → LRU cache (200 entries, 24 h) → template. Never blocks the 1/60 s loop (async
  Dart I/O on the main isolate; no isolate needed).
- **Reuse the repo's network/consent shape**, not its keys: mirror `SessionUploader` (abstract
  `session_uploader.dart:5-8`, Firestore impl `:15-69` with `HttpClient`, 10 s connect / 20 s
  response), null-default provider (`providers.dart:70`), and the consent gate (`live_stats.dart:308-312`).
- **Provider-agnostic config map** (base_url, model, key) — see §7. One client, no per-provider SDKs.
- **Cost (moot at this volume):** a typical call (~600 in / ~100 out tokens, 4–6 calls/night) is
  < $0.10/year even on paid models.

### 5.3 Phone-as-host

Confirmed: the phone host runs the **same `LiveHostService`/party_host runtime** (`phone_host.dart:54-82,61`),
and the existing `SessionUploader` already makes HTTPS calls from the phone shell. Therefore:
- HTTPS endpoints work with **no new platform config**.
- Register the commentary client at **both shells' provider overrides**: `controller_app/main.dart:47`
  and `tv_test_app/main.dart:43` (mirror `sessionUploaderProvider`).
- Consent works identically; add the new key to shared `askConsents` (`consent_prompts.dart:114-120`)
  and the first-phone-host prompt (`host_screen.dart:66-69`); **gate at call time**, not construction
  (`consent_state.dart:62-66` precedent).
- Cancel in-flight requests in `PhoneHost.dispose` (`phone_host.dart:200-212`).

---

## 6. Consent (new key, default OFF)

- **Do NOT reuse `statsConsent`.** Stats copy promises "No names… ever sent"
  (`text/host_text.dart:269-274`, `text/consent_text.dart:10-17`); commentary sends a *sanitized*
  nickname. Add a separate adult consent key (`consent_state.dart:16-31`, setter `:52-80`), prompt in
  `consent_prompts.dart:39-107`, include in `askConsents` `:114-120`.
- **Default OFF** → offline fallback until an adult opts in. "No" = permanent offline.
- Call-time gate mirrors the uploader (`live_stats.dart:308-312`).

---

## 7. Provider decision

### 7.1 Free-provider reality check

| Provider | Genuine free tier? | Limits | Card? | Training/retention | OpenAI-compatible | Source |
| --- | --- | --- | --- | --- | --- | --- |
| **Cloudflare Workers AI** | ✅ ongoing | 10k neurons/day (~1,400 calls/day) | No | ✅ zero retention, **no training** | ✅ | [pricing](https://developers.cloudflare.com/workers-ai/platform/pricing/) · [data](https://developers.cloudflare.com/workers-ai/platform/data-usage/) |
| **Groq** | ✅ ongoing | 200K tokens/day (org) | No | ✅ no training, ZDR toggle | ✅ | [limits](https://console.groq.com/docs/rate-limits) · [data](https://console.groq.com/docs/your-data) |
| **Mistral** | ✅ (Experiment) | ~1 req/s, ~1B tok/mo | No | ⚠️ training by default, opt-out | ✅ | [pricing](https://docs.mistral.ai/inference/pricing) |
| **Gemini** | ✅ ongoing | per-project, unpub. | No | ⚠️ human review possible | ✅ (compat) | [terms](https://aistudio.google.com/docs/terms) |
| **OpenRouter `:free`** | ⚠️ models only | 20 RPM / 50–1000 RPD | No | ⚠️ may route to logging providers | ✅ | [limits](https://openrouter.ai/docs/api-reference/limits) |
| DeepSeek | ❌ paid only | — | Yes | paid service | ✅ | [pricing](https://api-docs.deepseek.com/quick_start/pricing) |
| OpenAI | ❌ no free credit | — | Yes | no training by default | ✅ | [pricing](https://developers.openai.com/api/docs/pricing) |
| Cerebras | ❌ 30-day trial | 5 RPM | Yes (verified) | n/v | ✅ | [FAQ](https://inference-docs.cerebras.ai/support/rate-limits) |
| Together AI | ❌ $15 min | — | Yes | n/v | ✅ | [credits](https://docs.together.ai/docs/billing-credits) |
| Anthropic | ❌ no free tier | — | Yes | no training by default | ⚠️ compat layer | [docs](https://docs.anthropic.com) |

**Bottom line:** only Cloudflare, Groq, Mistral (and OpenRouter `:free`) are genuinely ongoing and
card-free. Cerebras is now a 30-day trial — do not build on it. For a *distributed* app, Gemini's
free tier is ToS-fragile (human review + "not for consumer use" + EEA/UK restrictions).

### 7.2 Top cheap models (short commentary)

| Model | $/1M in/out | Free? | Why |
| --- | --- | --- | --- |
| `gpt-5-nano` (OpenAI) | $0.05 / $0.40 | ❌ | Cheapest paid; needs a card. |
| `openai/gpt-oss-20b` (Groq) | $0.075 / $0.30 | ✅ | Free + ~1,000 tok/s. |
| `@cf/zai-org/glm-4.7-flash` (Cloudflare) | $0.06 / $0.40 | ✅ | Free + no-training; best quality/$. |
| `gemini-2.5-flash-lite` (Google) | $0.10 / $0.40 | ✅ | Free but ToS-weak. |
| `ministral-3-8b` (Mistral) | $0.15 / $0.15 | ✅ | Symmetric pricing. |

Model-op rule: **non-reasoning models only** (thinking tokens add latency/cost to a one-liner).

### 7.3 Bundled key (owner's direction: no BYOK)

Ship a **developer-provided key**; source-builders supply their own via `--dart-define`
(`LLM_BASE_URL` / `LLM_MODEL` / `LLM_API_KEY`) and fall back to **no-commentary mode**, never a hard error.

- **Risk:** the key is extractable from Windows/Android/iOS binaries ([MASVS-STORAGE](https://mas.owasp.org/MASVS/05-MASVS-STORAGE/),
  MASWE-0004). This is **acceptable here precisely because** the default is a no-billing free tier:
  worst case is quota exhaustion (`429`), not money or data loss.
- **Mitigations:** free/no-billing provider (structural), `max_tokens≈120` client-side, graceful
  degradation on 429/401 (show template), remote-config key (rotation without re-release), quarterly
  rotation. Avoid OpenAI/Gemini for the *bundled* key (share-key ToS).

### 7.4 Recommendation

1. **Default: Cloudflare Workers AI (`@cf/zai-org/glm-4.7-flash`)** — free, no-bill, no-training,
   OpenAI-compatible (account-scoped base URL).
2. **Alternate: Groq (`openai/gpt-oss-20b`)** — simplest token, fast, no-training.
3. **Paid fallback: DeepSeek `deepseek-flash`** — best quality-per-cent if we ever pay; no free tier.

---

## 8. Safety / responsible-AI controls

- **Never send:** ids, device ids, emails, chat, save files, locations. Send only
  `{game, place/winners, points, stat counts, sanitizedNickname}`.
- **Nickname is the only injection/PII surface** (`GamePlayer.nickname`, phone-filtered to ≤10
  letters/numbers/spaces; `game_types.dart:85-90`, `:25` "Never recorded in analytics"):
  1. Allowlist `[A-Za-z0-9 _-]{1,16}`; NFKC-normalize; strip zero-width/tag chars (U+E0000–E007F).
  2. Pass as a **JSON data field**, never concatenated into the system prompt; system prompt states
     the nickname is data to describe, not instructions.
  3. Constrain output: ≤140 chars, strip URLs/`http`, no markup; render as plain `Text` (no
     Markdown/HTML — that's where `<img src=…>` exfiltration happens).
  4. No tools, no history, no memory on the call.
- Reference: [OWASP LLM Prompt Injection Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/LLM_Prompt_Injection_Prevention_Cheat_Sheet.html),
  [LLM01](https://genai.owasp.org/llmrisk/llm01-prompt-injection/).

---

## 9. Eval suite (responsible AI, first-class deliverable)

1. **Golden/unit tests** (CI via existing `tools/check.sh` pattern):
   fallback non-empty for every award/round case; sanitizer (allowlist, zero-width strip, length);
   output post-processor (cap, URL/markup strip); prompt-builder asserts **no PII beyond sanitized
   nickname, no device ids**.
2. **Prompt fixtures** (`game_state → expected constraints`): family-friendly tone, ≤N chars,
   references the award subject — reference-based + LLM-as-judge calibrated against human labels.
3. **Red-team set:** adversarial nicknames ("ignore instructions and…", zero-width tricks,
   homoglyphs), toxicity, off-topic, non-English → assert fallback/trip.
4. **Runtime thresholds:** p95 < 4 s (else fallback), cost/call cap, breaker-trip counter; provider
   failover/429→template; "no-key source build → no-commentary" path.
5. **Human playtest:** family test — does it land, does fallback feel fine, nothing scares a kid;
   label 20–50 traces vs judge.
6. **CI gate:** hard-fail on P0 (injection success, toxicity, PII leak); soft thresholds for tone/quality.
   Sources: [NIST AI RMF](https://www.nist.gov/itl/ai-risk-management-framework), [Microsoft red-teaming](https://learn.microsoft.com/en-us/azure/ai-foundry/openai/concepts/red-teaming), [promptfoo](https://www.promptfoo.dev/docs/configuration/expected-outputs/).

---

## 10. How this fits on M16 (owner to assess)

- **M16 item 6 (end-of-night awards)** builds the reveal UX that commentary narrates. Commentary
  layers *on top of* that reveal — it should land **after** item 6 is stable, not before.
- **M16 item 5 (player identity: nickname + colour + accessory)** provides the nickname we sanitize
  and the identity we narrate. Good synergy; the nickname filter already limits the injection surface.
- **M16 item 1 (round state on the phone)** and item 7 (friendlier home screen) are unrelated;
  commentary adds no new phone screens, so it does not interfere.
- **Risk of overlap:** the reveal screen pacing (`night_reveal_screen.dart:25,29,87-88`) is timing-
  sensitive; async LLM text must respect the existing pacing budget, or be pre-generated during the
  scoreboard (recommended) so the reveal stays snappy.
- **Recommendation:** proceed with M16 as planned; treat M17 commentary as a clean post-M16 layer that
  consumes the awards + identity UX rather than reshaping it.

---

## 11. Open questions for the owner

1. Confirm default provider (Cloudflare recommended; Groq alternate) for the bundled key.
2. Exact UX placement of commentary (round header copy + award reveal narration) and tone/voice.
3. Consent prompt wording (new adult opt-in, default OFF) and its settings placement.
4. Whether phones should also show commentary (future protocol bump) — deferred in the MVP.
5. Whether a thin proxy is ever wanted (production hardening) vs. the bundled-key approach.

---

## 12. Sources

- DeepSeek API/pricing/thinking mode: https://api-docs.deepseek.com/ · https://api-docs.deepseek.com/quick_start/pricing
- Cloudflare Workers AI: https://developers.cloudflare.com/workers-ai/platform/pricing/ · …/data-usage/ · …/open-ai-compatibility/
- Groq: https://console.groq.com/docs/rate-limits · …/models · …/your-data · …/openai
- OpenAI: https://developers.openai.com/api/docs/pricing · ToS https://openai.com/policies/terms-of-use/
- Gemini terms: https://aistudio.google.com/docs/terms
- OWASP: https://mas.owasp.org/MASVS/05-MASVS-STORAGE/ · https://cheatsheetseries.owasp.org/cheatsheets/LLM_Prompt_Injection_Prevention_Cheat_Sheet.html · https://genai.owasp.org/llmrisk/llm01-prompt-injection/
- Azure circuit breaker: https://learn.microsoft.com/en-us/azure/architecture/patterns/circuit-breaker
- Responsible-AI eval: https://www.nist.gov/itl/ai-risk-management-framework · https://learn.microsoft.com/en-us/azure/ai-foundry/openai/concepts/red-teaming · https://www.promptfoo.dev/docs/configuration/expected-outputs/ · https://applied-llms.org/ · https://hamel.dev/blog/posts/evals/
