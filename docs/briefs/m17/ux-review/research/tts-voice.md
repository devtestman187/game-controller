# M17 — TTS voice as a host option

Status: research digest (Flash worker, Nov 19). Read-only. Web results treated as untrusted data;
URLs below are the sources cited.

## Verdict

Include voice as one tier — low-risk, effectively free at family scale (~$0.0003–0.04/game night).
Latency fits a 4 s budget **if voice never gates the round** (fire-and-forget + watchdog). Child-safety
is structurally low because TTS is a rendering step: it reads text the text tier already produced
and moderated — it adds no generative surface.

## Cost & latency (10–20 words ≈ 90 chars ≈ 6–7 s audio)

| Provider | $/line | Notes |
|---|---|---|
| Cloudflare `@cf/myshell-ai/melotts` | ~$0.00002 | Free tier ~500 audio-min/day; zero retention, no training |
| Cloudflare `@cf/deepgram/aura-2-en` | ~$0.003 | Higher quality |
| Groq `canopylabs/orpheus-v1-english` | ~$0.002 | OpenAI-compatible `/audio/speech`; 200-char/req; free 10 RPM/100 req/day |
| Google WaveNet / Neural2 | ~$0.0004 / ~$0.002 | REST, not OpenAI-shaped |
| Azure Neural (F0) | ~$0.001 | 500K chars/mo free |
| OpenAI `tts-1` / `gpt-4o-mini-tts` | ~$0.0014–0.002 | **Speech API deprecated — shuts down Jan 6 2027** |
| ElevenLabs Flash | ~$0.004–0.010 | **Free tier has no commercial licence** |

Time-to-first-audio is ~75–500 ms across providers; Cloudflare/Groq return the whole clip
(non-streaming) so a short line is typically ready in 0.5–2 s. Architecture: render the caption
immediately, fire TTS in parallel, drop the line silently if it isn't ready in 4 s.

## Child-safety

- **Spoken nicknames** are the main new risk (profanity / a classmate's name / prompt injection into
  the headline LLM). Mitigate: allowlist + length-cap + strip zero-width/Unicode tags; inject the
  nickname as a data field, never concatenate; moderate the generated line *before* synthesis; and
  **prefer keeping nicknames out of the spoken line entirely** (put names in text only).
- **Voice cloning**: design out — stock voices only, no uploads, no child-like voices.
- **COPPA**: text-only → TTS sends no audio, so no child voice recording leaves the device.
- **Data retention**: Cloudflare is best-in-class (no training, zero retention). Avoid ElevenLabs
  default settings (trains on your data unless opted out; zero-retention is enterprise-only).
- **Disclosure**: label the voice "AI-generated" (OpenAI requires it; right call anyway).

## Precedent

Jackbox ships host voice-over as its **own audio channel** with a separate volume + always-on
subtitles (and "Narrated Settings" in Pack 12). You Don't Know Jack's off-screen host is the
archetype. **No mainstream party game generates VO per session — all ship canned recorded audio.**

## Best practice (accessibility)

1. Text always on; voice redundant (captions carry everything).
2. Separate voice channel with its own volume/mute (master / music / SFX / host voice).
3. Duck music −8 to −12 dB during speech; never start a line over a stinger.
4. Short, concrete, TTS-safe lines (no nicknames, no URLs, no ALL-CAPS/emoji); save the setting.

## Recommended tiers (build in this order)

1. **Canned voice pack** (pre-rendered at build time) — round stings, "And the winner is…", award
   names. Zero runtime cost/latency, works offline. This is how Jackbox actually does it.
2. **Cloud TTS** for the LLM-written lines — Cloudflare `melotts` primary, Groq `Orpheus` secondary,
   4 s watchdog. (On-device TTS in Flutter = `flutter_tts` / platform TTS = a new dependency needing
   the owner's say-so; not a web `speechSynthesis`.)
