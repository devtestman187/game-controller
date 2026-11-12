# lean-agents and per-turn re-send: research report

Researched 2026-11-11 (web). Source numbers in [brackets] refer to `## Sources`.
"Inference" marks my reasoning, not a sourced fact.

## Summary

lean-agents is a prompt collection (AGENTS.md, agent files, skills), MIT, 39 stars, one contributor, created 2026-10-16 [1][6][7]. It contains no proxy, no request rewriting and no pruning: its only mechanism is a short shared policy telling a primary agent to delegate to scoped "CODER" workers and to think, read and test less per step [2][3].

Fit for flash-worker: **partly, prose only**. Its Claude Code install path is `.claude/agents/` plus `claude --agent build`, i.e. subagents [2]; we run `--bare` (which skips subagents) [16] and deny Agent/Task, so the delegation half cannot run. Its ~10 lines of "Work" rules (batch reads, never re-read, run tests once, 150-word thinking budget) can be pasted into our existing `--append-system-prompt` at ~1 KB [3].

Its "~70% Faster & Less Tokens" tagline [6] is not supported by its own BENCHMARK.md, which says "No speed or token savings are claimed" and reports one test that found none [4]. Best measured: ~47% fewer fresh tokens, 12 vs 25 steps, on a *vague* task (n≈7–8); no gain on an exact-spec task, n=3 [4].

Cost arithmetic (DeepSeek flash list prices, peak [10]): 2,770 M cache reads = $16.62; 33.7 M cache misses = $10.11; 20.4 M output = $24.48; **≈ $51.21 for 193 jobs (≈ $0.27/job)**. The cached re-send is **32.5% of the bill**, not the bulk; output is **47.8%**. Off-peak is exactly half ($25.61) with identical shares.

So: removing the re-send entirely caps the saving at 32%. Anything that rewrites the prefix every turn multiplies the input line by **50x** (miss $0.30 vs hit $0.006/M): $841 instead of $16.62 for the same volume [10][11].

Three changes, ranked by saving per effort (inference from our numbers plus [4][10]):

1. Cut per-turn *additions*: `bashOutputMaxChars` from 30k to ~8k chars and `CLAUDE_CODE_FILE_READ_MAX_OUTPUT_TOKENS` from 25k to ~10k, plus "read in ranges" in the brief [20][18]. Worth ~5–10% of the bill ($3–5). Risk: agent re-reads and adds turns.
2. Cut turns/output at job level: phase splits with a hand-over file, "no re-reads, tests once, terse output" prompt lines, `--max-turns` as a guardrail [25][24][15]. A 20% turn cut ≈ 25% of the bill ($13). Risk: incomplete work, truncated jobs.
3. Adopt lean-agents' "Work" block verbatim into the appended prompt. Expected 0–20%; cost ≈ 0, risk ≈ 0, but its delegation rules must be deleted or the model will waste turns trying an unavailable tool [2][3].

Do **not** add a pruning proxy: it would sit on the DeepSeek key, and at 98.8% cache hit any per-turn rewrite is ~17x our current bill (see Cost).

## lean-agents

**What it is.** A repository of markdown agent configuration, not software. Layout: `AGENTS.md`, `agents/` (`build.md`, `general.md`, `worker.toml`), `skills/lean-code|lean-java|lean-web|lean-plan`, `extensions/` (Pi subagent tool, TypeScript), `mods/` (Command Code `lean-primary.ts`), `plugins/` (legacy no-op), `.chatgpt/` [1][2]. GitHub reports language TypeScript (from the `.ts` extension/mod files), MIT licence, 39 stars, 0 forks, 0 watchers, 0 open issues, 45 commits, 1 contributor (`linsaftw`), created 2026-10-16T16:19Z, last push 2026-11-12T03:33Z (fetched 2026-11-11; UTC stamps are one day ahead of the local date) [1][6][7][9].

**Mechanism of "less re-send".** There is no proxy and no request transformation. Two things only:

- *Role routing*: primary = ORCHESTRATOR, does only single-line fixes; features/refactors/multi-file work go to a `general` worker with `Role: CODER`, up to 10 in parallel; workers never delegate; no questions to the user [2][3].
- *Per-step prompt frugality*: "Thinking budget: 150 words before your first action, then 50 words between actions. Short fragments, no recap, no plans. Read all needed files in one batch, then one batch of edits, then run checks once. Never re-read a file you already read or edited. Run tests once after all edits; rerun only what failed. No scratch scripts. Run multiple tool calls in one single turn." [3]

So savings can only come from fewer turns, fewer tool calls, smaller tool outputs and shorter output text. It cannot change how the prefix is sent; the agent loop, and therefore the re-send, is still the harness's [1][2].

**Requirements.** Any harness that reads a system/agent prompt: OpenCode, Claude Code, Codex, Command Code, Pi [2]. No OS requirement stated; no runtime except the optional TypeScript extension/mod files for Pi and Command Code [1][2]. For Claude Code: copy `agents/build.md` and `agents/general.md` into `.claude/agents/` or `~/.claude/agents/` and run `claude --agent build`; add `@AGENTS.md` to CLAUDE.md if needed [2]. `build.md` frontmatter carries `mode: primary`, an OpenCode field [5]; Claude Code's `--agent` flag only "specifies an agent for the current session" [15], and the worker is spawned through the Agent tool [20].

**Does it work with `claude -p` at a custom `ANTHROPIC_BASE_URL`?** Not as designed. `--bare`, which our worker uses, "skips auto-discovery of hooks, skills, custom commands, subagents, installed plugins, MCP servers, auto memory, and CLAUDE.md" [16], so `.claude/agents/` is never read. Our `--disallowedTools` also names Agent and Task as bare tool names, which "removes the matching tools from Claude's context" [15]. Both kill the ORCHESTRATOR/CODER split. Only the prose in `AGENTS.md` survives, and only if pasted into `--append-system-prompt` (the documented way to pass context in bare mode [16]).

**Does it see the API key or our code?** No. The core is markdown copied into the repo or home directory: no proxy, no server, no credential handling anywhere in the README or AGENTS.md [1][2]. The only executable files are integrations for other harnesses — `extensions/lean-subagents.ts` (Pi) and `mods/lean-primary.ts` (Command Code) — which load only if you use those hosts [1][2]. Installation is a file copy; no daemon, no global install [2].

**Age, activity, contributors, security.** Created 2026-10-16; 45 commits, all by one author; commits on Nov 10 and Nov 12 2026; 0 open issues and an empty issue list, 0 forks ⇒ no independent review and no bug reports to learn from [1][6][7][8][9]. The only risk found is behavioural: the prompt tells the model to delegate and to run up to 10 workers, which in our setup would burn turns on a tool we deny [2][3].

**Savings claims and whether they are measured.** The About line says "~70% Faster & Less Tokens, The only AI coding workflow you need. Tested on DeepSeek." [6]. `BENCHMARK.md` opens with "No speed or token savings are claimed. One small test found none." [4]. What it does report, all by the author, on a synthetic shop-lib fixture:

| Round | Setup | Result | n |
|---|---|---|---|
| 1 | Sonnet 5.5 subagent, 3-file fix | A (no prompt) 39,448 tok / 13.5 s; C (AGENTS.md) 40,870 / 14.5 s — "all differences are noise" | 1 per variant [4] |
| 9 | opencode, deepseek-v4.1-flash, vague task | no prompt 47.7k fresh, 25 steps, 272 s; shipped prompt 25.5k fresh, 12 steps, 128 s (−47% fresh, −75% cache read) | 8 vs 4 [4] |
| 11 | same, exact spec, 3 modules | no prompt 22.4k, A 20.8k, shipped 23.3k — "within noise", no delegation | 3 each [4] |
| 13 | delegating prompts, summed session tree | short prompt 50.5k fresh vs original 48.4k — no gain | 6 [4] |
| 15–16 | devin, orchestrator only | W5 18.6k fresh vs TD 22.4k (−17%); worker tokens not measured | 20 [4] |

Caveats the author states himself: small n, wide spread, provider errors, two early "wins" that flipped at higher n, other models untested [4]. No third-party benchmark, no issue reports, no forks to compare against [1][9].

## Cost

**DeepSeek prices, per 1 M tokens, `deepseek-flash` (model version DeepSeek-V4.1-Flash-1017), read 2026-11-11 [10]:**

| | Off-peak | Peak |
|---|---|---|
| Input, cache hit | $0.003 | $0.006 |
| Input, cache miss | $0.15 | $0.30 |
| Output | $0.60 | $1.20 |

Peak hours are 01:00–04:00 and 06:00–10:00 UTC, Mon–Fri, excluding Chinese public holidays; off-peak is half price [10]. Context length 1 M, max output 384 K, thinking on by default with default effort high [10][14]. `deepseek-v4-flash` is a legacy alias still accepted and billed at the flash price [10].

**How DeepSeek caching works [11][12]:** automatic, on by default, no code or `cache_control`. Cache hits require an *exact, complete* prefix unit; the docs describe persistence at request boundaries (end of user input, end of model output), at detected common prefixes, and at fixed token intervals for long inputs. Storage unit is 64 tokens (content under 64 tokens is not cached) [12]. Entries are cleared when unused, "usually within a few hours to a few days" [11]; no TTL control is documented. Cache construction takes seconds and is best-effort, not guaranteed [11]. A request that diverges in the middle cannot hit the longer units, though a shared shorter prefix may still hit [11].

**Important for us:** DeepSeek's Anthropic-compatible endpoint **ignores `cache_control`** and reports `cache_creation_input_tokens` as always 0 [13]. That exactly matches our telemetry (cache-write 0 reported, 98.8% hit) — the caching is DeepSeek's own prefix matching, not Claude Code's breakpoints.

**Our bill, 193 jobs (peak / off-peak) — arithmetic:**

| Category | Volume | Peak rate | Peak cost | Off-peak cost | Share |
|---|---|---|---|---|---|
| Cache read (re-send) | 2,770 M | $0.006/M | **$16.62** | $8.31 | **32.5%** |
| Cache miss (fresh input) | 33.7 M | $0.30/M | **$10.11** | $5.06 | 19.7% |
| Output | 20.4 M | $1.20/M | **$24.48** | $12.24 | **47.8%** |
| **Total** | 38,754 turns | | **$51.21** | **$25.61** | 100% |

Per job: $0.265 peak / $0.133 off-peak. Per turn: $0.00132. Cache read is 98.8% of input tokens but only 32.5% of spend, because it is 50x cheaper than a miss and 200x cheaper than output.

**Sensitivities (peak, same volumes):**

| Change | Cache read | Miss | Output | Total | vs today |
|---|---|---|---|---|---|
| Today | $16.62 | $10.11 | $24.48 | $51.21 | 1.0x |
| Re-send became free (theoretical) | $0 | $10.11 | $24.48 | $34.59 | −32.5% |
| 10% of reads turn into misses | $14.96 | $93.2 | $24.48 | $132.65 | 2.6x |
| Every turn rewrites the prefix | $0 | $841.11 | $24.48 | $865.59 | 16.9x |

The last row is the arithmetic of a proxy that prunes the middle of the conversation on every request: 2,803.7 M tokens (33.7 + 2,770) all billed as misses. **The 50x miss/hit ratio means cache invalidation is 50x more expensive than the tokens it saves**, and our prefix is already ~99% cached, so there is almost nothing left to save by pruning. A one-off prune mid-job (prefix re-warmed afterwards) costs about 50k × $0.30/M ≈ $0.015 per job, ≈ $2.90 over 193 jobs — cheap, but it buys nothing that compaction inside Claude Code does not already do.

**What lean-agents could save, by its own measured mechanism:**

| Scenario | Turns | Cache read | Miss | Output | Cost | Saving |
|---|---|---|---|---|---|---|
| Baseline | 38,754 | $16.62 | $10.11 | $24.48 | $51.21 | — |
| −20% turns, −20% output & fresh input, −36% cache read | 31,000 | $10.64 | $8.09 | $19.58 | $38.31 | **$12.90 (25%)** |
| Round-9-like (−50% steps, −47% fresh, −40% output, −75% cache read) | ~19,400 | $4.16 | $5.36 | $14.69 | $24.21 | **$27.00 (53%)** |
| Only tool-output trimming (−20% cache read) | 38,754 | $13.30 | $10.11 | $24.48 | $47.89 | $3.32 (6.5%) |

The −36% cache read in row 2 is (inference): cumulative cache read per job grows faster than turn count because the prefix lengthens every turn; our own tiers show 44k/turn at 30–79 turns vs 75k/turn at 150+ [brief]. Round 9's −75% is what the author measured on a *vague* task, where the unprompted agent wandered (25 steps vs 12) [4]. Our jobs get a 60–120-line brief, closer to the exact-spec round 11 that showed **no gain** [4]. So the realistic range is 0–25%, and the top of it is only reached if the rules cut turn count, not just wording.

**Time.** DeepSeek states caching lowers latency [12], and we are already at 98.8% hits, so extra caching cannot save much wall-clock. Any real speed-up must come from fewer turns: the author's one vague-task sample went 272 s → 128 s at 12 vs 25 steps [4]. We have no wall-clock per job in the brief, so a time estimate for our profile is not possible (marked not found).

## Claude Code settings

All settings are client-side unless stated; "works with DeepSeek" means the option is honoured before the request is sent to `api.deepseek.com/anthropic` and does not depend on Anthropic-only API features.

| Setting / flag | What it does | Works headless (`-p`)? | Works with DeepSeek? | Source |
|---|---|---|---|---|
| `--bare` / `CLAUDE_CODE_SIMPLE=1` | Skips hooks, skills, custom commands, subagents, plugins, MCP servers, auto memory, CLAUDE.md; minimal system prompt; only Bash, read, edit tools; no background tasks; doesn't read OAuth/keychain (needs `ANTHROPIC_API_KEY` or `apiKeyHelper` in `--settings`) | Yes, recommended for scripts; will become the `-p` default | Yes | [16][18] |
| `--tools "Bash,Edit,Read"` | Restricts the built-in tool set → shorter tool definitions in the prefix | Yes | Yes | [15] |
| `--disallowedTools` with bare names | A bare tool name (e.g. `Agent`) removes the tool from Claude's context, not just denies calls; scoped rules like `Bash(rm *)` leave the prefix intact | Yes | Yes | [15][21] |
| `--append-system-prompt` / `-file` | Adds text to the system prompt; the documented way to pass context in bare mode. Adds to the prefix, does not reduce it | Yes | Yes | [15][16] |
| `--exclude-dynamic-system-prompt-sections` | Moves per-user context (auto-memory paths) out of the system prompt into the first user message; "improves prompt-cache reuse across different users and machines" | Yes (built for `-p`) | Yes | [15] |
| `autoCompactEnabled`, `autoCompactWindow`, `--autocompact <auto or tokens>`, `CLAUDE_CODE_AUTO_COMPACT_WINDOW` | Sets how full the context gets before compaction; 100k–1M tokens; env var wins over flag/setting | Yes (docs name scripts/cloud for the env var) | Yes; but the window is capped at the model's assumed window | [17][18][19] |
| `CLAUDE_CODE_MAX_CONTEXT_TOKENS`, `modelOverrides`, `[1m]` suffix | Corrects the context window Claude Code assumes. Unrecognised IDs (ours) default to **200K**, so auto-compaction fires at 200K even though DeepSeek flash has 1 M | Yes | Yes — client-side assumption only | [17] |
| `CLAUDE_CODE_DISABLE_UNKNOWN_MODEL_WINDOW_ENFORCEMENT=1` | Skips proactive auto-compaction for an unknown model ID (v2.1.223+) | Yes | Yes | [18] |
| `bashOutputMaxChars` (setting) | Chars of Bash output delivered inline; clamped 4,000–128,000, default 30,000; also sizes the read-back window; overrides the env var (v2.1.261+) | Yes | Yes | [19][20] |
| `BASH_MAX_OUTPUT_LENGTH` | Read-back window, default 30,000, ceiling 150,000 chars; does not change the inline ceiling | Yes | Yes | [18][20] |
| `CLAUDE_CODE_FILE_READ_MAX_OUTPUT_TOKENS` | Per-Read token cap, default 25,000; files over 256 KB are refused and read in pages | Yes | Yes | [18][20] |
| `MAX_MCP_OUTPUT_TOKENS` | MCP responses, default 25,000; irrelevant under `--bare` (no MCP) | Yes | Yes | [18] |
| `MAX_THINKING_TOKENS`, `--effort`, `CLAUDE_CODE_DISABLE_THINKING` | Thinking is billed as output. On third-party providers `0` only *omits* the parameter, and DeepSeek's thinking is on by default at effort high | Yes | Partly: omission does not disable DeepSeek thinking; `output_config.effort` is supported by DeepSeek but Claude Code's forwarding for an unknown model ID is unverified | [18][14][13] |
| `--max-turns` / `CLAUDE_CODE_MAX_TURNS` | Hard cap on agentic turns, print mode only, no default limit | Yes | Yes | [15][18] |
| `--max-budget-usd` | Stops when the client-side cost estimate hits a cap; estimate may not match DeepSeek prices | Yes (print mode only) | Yes, but the estimate is Anthropic-priced (inference) | [15][22] |
| `includeGitInstructions` | Removes built-in commit/PR instructions from context (smaller prefix) | Yes | Yes | [19] |
| `promptCacheTtl`, `CLAUDE_CODE_PROMPT_CACHE_TTL`, `DISABLE_PROMPT_CACHING*` | Anthropic cache TTL / kill-switch controls; DeepSeek ignores `cache_control` and applies its own lifetime | Yes | No effect (inference, from [13]) | [21][18] |
| `idleCompaction` | Stops compaction of a conversation left idle; a one-shot `-p` run never idles | Not applicable | — | [19] |
| API `context_management` / `clear_tool_uses_20250919` | Server-side clearing of old tool results. Claude Code does not set it, and a mod cannot (no field in the request API) | No | No (DeepSeek doesn't document it; `cache_control` is ignored anyway) | [33][13] |
| "Microcompaction" of old tool results | Reported by third-party reverse-engineering as automatic; **not documented** in official Claude Code docs | Undocumented | Undocumented | [32][31] |

Two implications for flash-worker (inference): (a) our `--bare` already gives the minimum tool list and system prompt, so tool-list trimming is nearly exhausted; (b) the per-turn growth is now dominated by *what we let into context* — Bash output (30k chars ≈ 7.5k tokens per call) and file reads (25k tokens each). Those are the only remaining big levers, and they compound across 201 turns.

One correction to our command line, from the docs: `--allowedTools` only pre-approves tools, it does not restrict the set — "to restrict which tools are available, use `--tools` instead" [15]. Likewise, scoped deny rules such as `Bash(rm *)` or `Edit(src/*)` "don't change which tools Claude sees" and leave the cache prefix intact; only bare tool names remove a tool from context [15][21]. So our ~20 Bash patterns cost nothing in prefix size, and our existing bare `Agent`/`Task`/`WebFetch`/`WebSearch` denies are the ones that actually shrink it [15].

On compaction, if a job does hit the 200K assumption: it replaces the message history with a summary, re-injects CLAUDE.md/auto-memory/skill descriptions, and re-reads up to five recently modified files, with anything over 5,000 tokens coming back as a path reference [23]. It is therefore a real reset, not a free one, and it costs one cache rebuild on the next turn [21].

## Job-writing options

Sourced guidance first, then my reasoning.

- **Phase splitting with a written hand-over.** Anthropic's context-engineering post names structured note-taking as one of three long-horizon techniques: "after context resets, the agent reads its own notes and continues" [25]. Claude Code best practices recommends writing a `SPEC.md` and then "start a fresh session to build from it, so the build begins with a clean context" [24]. For us: a job that would exceed ~100 turns becomes 2–3 jobs, each reading a short `HANDOVER.md` (state, files touched, next step) instead of a 100-turn transcript.
- **Read in ranges.** Claude Code returns at most 25,000 tokens per Read (configurable, `CLAUDE_CODE_FILE_READ_MAX_OUTPUT_TOKENS`) and refuses whole files over 256 KB, offering `offset`/`limit` [20]. A brief line like "read only the ranges you need; never read a whole file over 400 lines" is enforceable by the same cap.
- **Quiet test output.** Claude Code's own cost page ships a `PreToolUse` hook that rewrites `npm test|pytest|go test` to `... | tail -n 100` [22]; however, **hooks do not run in `--bare` mode, even ones passed via `--settings`** [16], so for our worker the same effect comes from lowering `bashOutputMaxChars` to 4,000–8,000 [19][20]. A failure result is already truncated to ~10,000 chars; a success to ~30,000 [20].
- **No re-reads, run tests once, batch tool calls.** These are exactly the lean-agents "Work" lines [3]; the harness already appends a "file changed" system reminder instead of silently rewriting history, so re-reads are a prompt problem, not a tooling one [21].
- **Turn budget as a guardrail.** `--max-turns` exists in print mode with no default [15]; 107 of our 193 jobs ran 150+ turns, so a cap of e.g. 250 would only truncate outliers, and it surfaces runaway jobs as failures rather than silent spend.
- **Evidence on long contexts.** Chroma's report (July 2025, 18 models) shows accuracy degrading as input length grows, even on simple tasks [26]; Anthropic cites the same effect ("context rot") and recommends keeping context to "the smallest set of high-signal tokens" [25]. This is the argument for fresh phases, not for pruning a live prefix: the pruning variant also pays 50x on every rebuilt token (see Cost).
- **Brief specificity matters more than terseness.** Round 11 of lean-agents' own benchmark shows all prompt variants within noise when the spec is exact [4]; round 9's gains came from stopping a vague task from wandering [4]. (Inference: a brief with explicit acceptance checks and a file list is worth its tokens; replacing it with a "short prompt" would not be lean.)

My reasoning on turn counts, using our own tiers: 30–79 turns → 44k cache read/turn; 80–149 → 63k; 150+ → 75k. Per job that is roughly 2.4 M (at ~55 turns), 7.2 M (at ~115) and 15.1 M cached tokens (at ~200) — a 3.6x rise in turns produces a ~6x rise in cached volume. Halving turns in a long job therefore removes far more than half its cached volume, which is why phase splitting is the largest single lever available, and why "make each turn cheaper" (tool output, reads) is second.

## Other projects

- **claude-code-router (CCR)** — https://github.com/musistudio/claude-code-router — local model gateway/control plane on `127.0.0.1:3456` (v3.1.3, MIT, 38.1k stars, 3.2k forks); routes Claude Code and other agents across providers including DeepSeek, with logs, token/cost estimates and client keys. **Routing only — no context pruning or rewriting is described.** Mature, but it sits in the request path and sees the provider key [27].
- **snip** — https://edouard-claude.github.io/snip/ — Go CLI that filters *shell output* before the agent sees it, via declarative YAML filters; works with Claude Code and ~15 other agents; MIT, claims 60–90% token reduction (vendor claim, not independently verified). Does not touch the request, so it cannot break prefix caching; closest drop-in to the `bashOutputMaxChars` lever [28].
- **Pruner** — https://onegotoai.github.io/Pruner/ — local proxy on `127.0.0.1` that prunes messages (`maxMessages`) and injects prompt-cache markers; claims up to 70% savings (vendor claim). Listens only for `api.anthropic.com`, so **not usable with `ANTHROPIC_BASE_URL=https://api.deepseek.com/anthropic`**; installs via `curl … | bash`; sees the API key (it says it forwards it and never stores it). Maturity: one author, no independent data found [29].
- **ContextForge** — https://dev.to/anuj612/contextforge-a-local-proxy-that-cut-my-claude-code-token-usage-by-up-to-72-n8b — local proxy that "skeletonizes older file history (keeping only signatures) and vaults oversized responses"; claims up to 72% (author's blog, unverified). Same cache-invalidation risk as any middle-rewriting proxy [30].
- **Anthropic context editing (`clear_tool_uses_20250919`)** — server-side API beta that replaces old tool results with placeholders; not exposed in Claude Code and not settable from a mod [33]. DeepSeek's Anthropic-compatible docs do not mention `context_management`, and `cache_control` is ignored [13].
- **lean-agents itself** — https://github.com/linsaftw/lean-agents — prompt-only; see the lean-agents section. It is the only one of these that cannot see the key or the code, because it is not in the request path [1][2].

## Not found

- **Any official Claude Code documentation of "microcompaction".** Searched the docs index (`code.claude.com/docs/llms.txt`) and the web; only third-party reverse-engineering write-ups [31][32]. Treat the feature as undocumented.
- **A Claude Code switch to enable API context editing / `clear_tool_uses`.** Docs and a feature request both say no request field is exposed to users or mods; the request was open when fetched [33].
- **Whether Claude Code forwards `output_config.effort` to a custom Anthropic-format endpoint** (i.e. whether `--effort low` reaches DeepSeek). Claude Code's effort table lists only Anthropic models, and DeepSeek documents `output_config.effort` support [17][13][14]. Unverified; would need a request log.
- **DeepSeek's current minimum cacheable prefix and TTL beyond "64-token storage unit" and "hours to days".** The current caching guide states neither a minimum nor a TTL; the 2024 launch note gives the 64-token unit [11][12].
- **Any independent measurement of lean-agents** (third-party benchmark, issue, fork, discussion). 0 issues, 0 forks, 1 contributor, no discussions enabled [1][6][7][9].
- **Wall-clock time per job in our data**, so the time half of the saving estimate cannot be computed; only the author's 272 s → 128 s single-task sample exists [4].
- **Whether `tools/flash.sh` passes `apiKeyHelper` through `--settings`.** Bare mode reads Anthropic auth only from `ANTHROPIC_API_KEY` or an `apiKeyHelper` in `--settings` [16][18]; I cannot read the repo, so this is unverified.

**Questions for Claude (author of the brief):**

1. Does `flash.sh` pass the `apiKeyHelper` via `--settings`? If not, `--bare` may not authenticate.
2. What share of the 193 jobs ran in DeepSeek peak hours (01–04, 06–10 UTC weekdays)? Our bill is exactly half off-peak.
3. Can the JSON results split output tokens into reasoning vs visible text? If reasoning is most of the 20.4 M, effort/thinking is a bigger lever than anything in this report.
4. Do our jobs ever hit Claude Code's 200K assumed window (auto-compaction)? Compaction events in the logs would show up as cache-miss spikes; if they exist, `CLAUDE_CODE_MAX_CONTEXT_TOKENS` is worth setting.

## Sources

1. https://github.com/linsaftw/lean-agents — repo page, fetched 2026-11-11
2. https://raw.githubusercontent.com/linsaftw/lean-agents/main/README.md — fetched 2026-11-11
3. https://raw.githubusercontent.com/linsaftw/lean-agents/main/AGENTS.md — fetched 2026-11-11
4. https://raw.githubusercontent.com/linsaftw/lean-agents/main/BENCHMARK.md — fetched 2026-11-11
5. https://raw.githubusercontent.com/linsaftw/lean-agents/main/agents/build.md — fetched 2026-11-11
6. https://api.github.com/repos/linsaftw/lean-agents — metadata, fetched 2026-11-11
7. https://api.github.com/repos/linsaftw/lean-agents/contributors — fetched 2026-11-11
8. https://github.com/linsaftw/lean-agents/commits/main/ — fetched 2026-11-11
9. https://github.com/linsaftw/lean-agents/issues — fetched 2026-11-11
10. https://api-docs.deepseek.com/quick_start/pricing — fetched 2026-11-11
11. https://api-docs.deepseek.com/guides/kv_cache — fetched 2026-11-11
12. https://api-docs.deepseek.com/news/news0802 — cache launch note, fetched 2026-11-11
13. https://api-docs.deepseek.com/guides/anthropic_api — fetched 2026-11-11
14. https://api-docs.deepseek.com/guides/thinking_mode — fetched 2026-11-11
15. https://code.claude.com/docs/en/cli-reference — fetched 2026-11-11
16. https://code.claude.com/docs/en/headless — fetched 2026-11-11
17. https://code.claude.com/docs/en/model-config — fetched 2026-11-11
18. https://code.claude.com/docs/en/env-vars — fetched 2026-11-11
19. https://code.claude.com/docs/en/settings-reference — fetched 2026-11-11
20. https://code.claude.com/docs/en/tools-reference — fetched 2026-11-11
21. https://code.claude.com/docs/en/prompt-caching — fetched 2026-11-11
22. https://code.claude.com/docs/en/costs — fetched 2026-11-11
23. https://code.claude.com/docs/en/context-window — fetched 2026-11-11
24. https://code.claude.com/docs/en/best-practices — fetched 2026-11-11
25. https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents — fetched 2026-11-11
26. https://www.trychroma.com/research/context-rot — 2025-07-14, fetched 2026-11-11
27. https://github.com/musistudio/claude-code-router — fetched 2026-11-11
28. https://edouard-claude.github.io/snip/ — fetched 2026-11-11
29. https://onegotoai.github.io/Pruner/ — fetched 2026-11-11
30. https://dev.to/anuj612/contextforge-a-local-proxy-that-cut-my-claude-code-token-usage-by-up-to-72-n8b — fetched 2026-11-11 (vendor blog, unverified)
31. https://decodeclaude.com/compaction-deep-dive/ — third-party analysis of microcompaction, fetched 2026-11-11 (unverified)
32. https://github.com/aaronmedina-dev/claude-code/blob/main/docs/04-context-compaction.md — third-party notes, fetched 2026-11-11 (unverified)
33. https://github.com/anthropics/claude-code/issues/99594 — feature request on `context_management` in mods, fetched 2026-11-11
