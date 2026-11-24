# Agent issue database: feasibility

Nov 24, 2026. A plan only; nothing was installed or changed.
The proposal has three parts: a main session that only orchestrates, an issue database (beads) as the channel between agents, and a `specs/` folder as the source of truth.

Numbers come from 173 transcripts since Nov 20 (8 main, 57 driver, 90 other subagents) and `tools/agent-cost.sh --since 2026-11-20`. Token counts are characters divided by 4, so treat them as rough.

## 1. What beads is and whether it runs here

Beads (`bd`) is an MIT-licensed issue tracker for agents with a command line: `bd ready`, `bd show <id>`, `bd create`, `bd update <id> --claim`, `bd dep add`, `bd close`, `bd prime`. It has JSON output, a Claude Code plugin and an MCP server.

Its storage is a Dolt database, not JSONL or SQLite. The default "embedded" mode keeps it in `.beads/embeddeddolt/` and allows one writer at a time. "Server" mode needs a running `dolt sql-server`. Sync pushes Dolt data to `refs/dolt/data` on the git remote.

| Our environment | Status |
|---|---|
| Windows 11 | Native binary; PowerShell installer or npm. |
| Git Bash | Not mentioned in the docs read. Untested. |
| Git worktrees and job worktrees | Not documented. The database is local to one folder, so job worktrees cut from the last commit would not see it unless `BEADS_DIR` points them all at one place. |
| Sessions starting in E:\AI (not a repo) | Repo discovery fails; needs `BEADS_DIR`. |
| Parallel agents (driver plus up to 3 coders per wave) | Embedded mode reports "database is locked" on concurrent access. Server mode fixes it but adds a background service to keep alive. |
| Headless `claude -p` Haiku coders | Would need `bd` on PATH and an allow rule. Today they cannot reach the tracker at all, by design. |
| Owner on a phone | No owner-facing page. |

Blockers:

1. **Concurrency needs a server.** Embedded mode cannot serve a wave of parallel writers.
2. **Sync is a push.** `bd dolt push` writes to the git remote, which the owner's rule forbids without his word. Without it the database lives only on this PC, outside git history.
3. **`bd init` edits AGENTS.md and installs Claude hooks** unless told not to. That is a config change the owner must approve.
4. **Installing is the owner's step.** The installer downloads and runs a script.
5. **Churn.** About 1,100 open issues; a release candidate on Nov 20; version 1.4.0 is a one-way schema migration.
6. **Worktree behaviour is unknown** until tested.

## 2. Mapping

| Today | With an issue store | Verdict |
|---|---|---|
| Job briefs (`<job>.md`, about 650 tokens) | Issue body | Keep as files. Coders already read only their brief, and job folders are cut from git. |
| waves.txt, done.txt, run.log | Dependencies and status | Keep. The runner writes them and they cost little per read. |
| DRIVER-NOTES "Next action" | Epic issue with dated events | Replace. |
| STATUS.md "Resume here" stack (6.2K tokens, read 116 times) | Query "open epics, newest event" | Replace. The file becomes a short pointer. |
| code-health.md leftovers (14.2K tokens) | One issue per leftover, closed when done | Replace. This is the best fit: agents now load the whole file to find one row. |
| REVIEW.md findings | One issue per real finding, linked to the job | Adapt. Keep REVIEW.md as the review record; only findings that need work become issues. |
| Owner questions | Issue type `question`, blocks its epic | Replace. Today they travel inside reports. |
| flash-lessons, driver-kit, memory files | none | Keep. They are rules, not work items. |
| Subagent reports to main | Issue ID plus one line | Adapt. |

**The bug tracker: keep it and make it the store.** The owner files bugs from a phone on the artifact page, and beads has nothing for that. Syncing two stores would create the drift this proposal is meant to end. The tracker's database can hold more collections, so agent issues can live beside `bugs` and the owner sees questions and blockers on the same page.

## 3. Token savings estimate

Total spend since Nov 20: **$229.65** (Sonnet drivers $144.51, Opus main $83.72, Haiku $1.44).

| What agents read | Calls | Result tokens | Token-turns (millions) |
|---|---|---|---|
| Code | 755 | 552K | 22.1 |
| Briefs and job reports | 380 | 302K | 13.8 |
| flash-digest | 73 | 143K | 8.6 |
| run.log | 925 | 157K | 5.7 |
| STATUS.md | 116 | 114K | 4.0 |
| REVIEW.md | 65 | 108K | 3.2 |
| done.txt, waves.txt | 89 | 53K | 2.3 |
| framework, lessons, code-health, DRIVER-NOTES, driver-kit | 180 | 125K | 6.0 |

A token-turn is one result token carried for one later turn; it is what cached input is billed on.

- Coordination docs take 55% of driver tool-result tokens and 50% of the main session's. By token-turns they outweigh code 1.7 to 1 in drivers. The premise of the proposal holds.
- **Imagined saving.** Briefs, job reports and run.log are 19.5M of the 43M coordination token-turns. An issue database would hold the same text; reading it through `bd show` costs the same.
- **Real but small.** STATUS, DRIVER-NOTES, code-health and part of REVIEW come to about 9M token-turns. Fetching one issue instead of a whole file might halve that. At cached-read list prices that is a few dollars of $230, about 1–2%.
- **Already available without any tool.** flash-digest was read 73 times against 10 for driver-kit, which was written to replace it. A likely cause: the worktree's CLAUDE.md still tells batch work to read flash-digest.md, and every agent loads CLAUDE.md. Pointing that line at driver-kit.md (an owner-approved config edit) saves more than the issue database would on reads.
- Exact repeat reads of one file are negligible (9 calls, 4.6K tokens). Repeated `cat` of run.log is the larger pattern, and thumb-wait already addresses it.

**The large cost is elsewhere.** Sonnet drivers resumed after the 5-minute cache window 183 times and re-wrote 26.05M tokens, about 142K per resume. At list price for cache writes that is about $98, two thirds of the Sonnet bill. This figure is derived from list prices, not read from the script. Drivers sit idle while a wave runs, their cache expires, and the whole context is written again.

This is where the proposal pays. If a driver can end when it launches a wave and a fresh one can start from an issue ID, each resume costs a small new context (perhaps 25K) and not 142K. The saving comes from disposable drivers. The issue store is what makes them safe; any store that does this would work.

The main session's median peak context was 200K, maximum 300K. Coordination docs were half its tool-result tokens.

## 4. The three ideas

**Pure-orchestrator main session: adapt.**
We are most of the way there; drivers already brief, run, repair, verify findings, check and commit. What the main session still does, and where it would go:

| Task | Moves to |
|---|---|
| Verifying driver work, reading REVIEW files | A Sonnet verify agent that returns a verdict of 10 lines or fewer |
| Writing docs | A subagent, or the driver |
| Commits | Drivers, as now |
| Design calls, owner questions, go or no-go | Stays |
| Full review at milestone end and before public builds | Stays (review policy) |

"Never reviews" goes too far for us: the review policy keeps Claude as the final check before a public build. The rule to adopt is that the main session reads verdicts and issue lines, not files.

**Issue database: adapt.**
Adopt the idea: small linked units, dated events, agents given one ID. Do not adopt beads now. The blockers in section 1 are real, and the tracker database already gives us a store with a phone page. Revisit beads if the pilot shows the store is too slow or too limited.

**specs/: skip for now, with a small trial later.**
"OKF 0.2" could not be found; the helper had no search tool and did not guess. Our docs/ already hold architecture.md, protocol.md, PRD-v2.md and sixteen design notes, but no per-screen map of actions. Code reads are the largest single category (22M token-turns, somewhat overstated because script runs count as code), so a map could help triage and brief writing. The cost is a write step after every batch and a second description that goes stale. If tried, each spec should list its source files and the commit it was written at, so a script can flag stale ones.

## 5. Risks

- **Tool maturity.** Covered above; it applies to beads only.
- **Drift from git.** An issue store sits outside the commit history. Mitigation: issues carry commit hashes, and the runner's files stay the record of what ran.
- **Misuse.** Tracker note writes have already shortened notes by mistake. The store must be append-only: one new row per event, never an edit of a long field.
- **Agents treating issue text as orders.** Issue rows are data. Owner decisions must still be quoted by the main session.
- **Remote Control.** The owner needs to see and answer questions on a phone. The tracker page does this; beads does not.
- **Release flow.** thumb-release takes the owner's words directly. Keep it outside the store.
- **Owner's rules.** No sync command may push. Named-path staging is unaffected as long as the store is not in the worktree.
- **Coders.** Haiku coders should stay unable to write to the store; the driver records for them.

## 6. Pilot plan

**Step 0: baseline, no change.** For the next batch record driver cost per job, driver peak context, number of late resumes, main-session context growth across the batch, and minutes from a question arising to the owner seeing it.

**Step 1: one batch on a tracker-based store.**
- Add a collection `issues` to the tracker database: one epic row per batch, one row per job, question, finding and leftover, each with links and status.
- Add a collection `events`: append-only dated rows (did, failed, next action).
- The driver gets an epic ID. It writes events in place of DRIVER-NOTES and the STATUS line, and files questions as rows.
- The driver ends when it launches a wave. A fresh driver starts from the epic ID after the wait.
- Briefs, waves.txt, done.txt, run.log and REVIEW.md do not change.
- The tracker page gains a "Questions and blockers" view. That is a page change for the owner to approve.

| Measure | Pass |
|---|---|
| Driver cost per job (agent-cost) | Down 30% or more |
| Tokens written on late resumes | Down 60% or more |
| Driver median peak context | Under 90K (now 118K) |
| Main-session growth per batch | Under 15K |
| Owner question latency | Visible on the page before the next wave starts |
| Lost or shortened notes | None |
| Cold start: a fresh session answers "what's next?" from the store alone | Correct, in under 10K tokens |

**Rollback.** Export the two collections to a markdown file in the batch folder and go back to DRIVER-NOTES and STATUS lines. The runner's files were never replaced, so no run state is lost.

**Step 2, only if step 1 passes and the store proves limiting.** The owner installs beads in a throwaway clone. Test for 30 minutes: three concurrent writers in embedded mode, `BEADS_DIR` from E:\AI and from a job worktree, Git Bash, `bd init --skip-agents`, and no push.

**Alternatives.** One markdown file per issue under docs/issues/ with a small index script; or GitHub Issues through `gh`, which works on a phone but every write is a public-side change needing the owner's word.

## 7. Recommendation

**Pilot** the issue-store idea on the existing tracker database for one batch, with disposable drivers as the main thing under test. **No** to installing beads now. **Adapt** the orchestrator rule. **Defer** specs/.

Two changes need no pilot: make drivers stop reading flash-digest, and stop holding a driver open across a wave wait.

## Main-session check (Opus, Nov 24)
`tools/agent-cost.sh` split at the 1-hour cache switch (Nov 23, 20:00Z):
| Window | Opus main | Sonnet | Haiku | Total | Sonnet resumes >5 min (cache re-written) |
|---|---|---|---|---|---|
| Nov 20 to Nov 23 20:00Z (5-minute cache) | $67.86 | $133.18 | $1.35 | $202.39 | 174 (26.03M) |
| Nov 23 20:00Z to now (1-hour cache) | $15.96 | $11.46 | $0.10 | $27.52 | 9 (0.02M) |
- The 26M late-resume rewrite above is all from before the 1-hour cache; since then resumes write almost nothing, so "stop holding a driver open across a wave wait" saves little now (cost1 step d stays parked).
- Since the switch the **Opus main session is the largest share (58%)**. That makes idea 1 (a pure orchestrator that hands verification to a Sonnet verify agent) the biggest lever, more than the issue store.
- flash-digest read 73 times vs driver-kit 10: the worktree CLAUDE.md still points batch work at flash-digest.md. A one-line fix, owner's call.

## OKF 0.2 (read Nov 24; spec: GoogleCloudPlatform/knowledge-catalog okf/SPEC.md, blog of Jul 24, 2026)
Open Knowledge Format: a folder of Markdown files with YAML front matter; only `type` is required (`title`, `description`, `resource`, `tags` recommended); `index.md` lists a folder, `log.md` holds dated updates; unknown keys are kept. v0.2 adds optional trust fields: `sources` (provenance), `generated: {by, at}`, `verified: [{by, at}]` (human or machine), `status` and `stale_after`, plus attested computations. Built for data-platform knowledge; no guidance on keeping docs in sync with code; no required tooling.
Fit for a `specs/` folder here: the minimal subset is cheap (one file per screen or feature: `type`, `description`, `resource` = the Dart file, `tags`, a body listing the screen's actions; an `index.md` per folder). Of v0.2, only `generated.at` is worth keeping, so a small script can flag a spec stale when its `resource` file changed after that date. `sources`, `verified`, attestations and `log.md` are heavyweight for us. Verdict moves from "skip" to "later, small": worth a trial only after the orchestrator and issue-store pilots, measured on whether coders read fewer code files per job.

## Pilot proposals, merged after the Fable review (Nov 24)
**Pilot 1: orchestrator-only main session (items 7-9 wave 1).**
- Mechanical checks become `tools/verify-batch.sh`, run by thumb-haiku: commits and identity, the check result in run.log, the working tree, tracker rows against the driver's claims, and the STATUS block present and matching the tip.
- A read-only Sonnet `thumb-verify` (Bash, Read, Grep, Glob, tracker read) judges the open findings. It also summarises any diff to protocol or shared files in 5 lines or fewer.
- Main spawns the verifier, not the driver, so the check stays independent. Run `tools/sync-agents.sh` after adding it.
- The driver writes the STATUS block. Main writes 2-3 memory lines, design calls, Fable reviews of owner questions, and talks to the owner. Releases stay with thumb-release, and the milestone-end review stays with main.
- Gates:
  - Total $ per job, counting verify and Fable spend. Baseline bugs4: $13.81 over 9 jobs = $1.53 per job, from `tools/agent-cost.sh --since 2026-11-24T11:30 --until 2026-11-24T13:30` after the headless-Haiku fix (Nov 24, pilot1-tune). It includes headless Haiku (the runner's `claude -p` workers, read from the flash-*.log usage lines: 16 runs, $0.48; the old figure $1.48 = $13.29 / 9 missed them, the transcripts do not exist because of --no-session-persistence). It also includes $3.21 of Fable design review and the whole main Opus session ($4.72) inside that window, so it is a weak baseline: without Fable $10.60 / 9 = $1.18 per job. Opus $ is a secondary figure.
  - Main context growth per batch under 15K, measured as main session usage at batch start and at batch end (the `context` or token count the session shows, written down by main at both points).
  - Owner-question latency.
  - Cold start: growth above the empty-session floor (the tokens a fresh session already carries from CLAUDE.md, memory index and tools), not an absolute 10K. Gate: "what's next?" answered from the pilot memory note and the STATUS START HERE line adds under 10K above that floor.
  - Main fully shadow-checks one job in wave 1. Misses are counted again at the milestone-end review.
- Note: the CLAUDE.md driver-kit fix lands at the same time and moves the Sonnet numbers on its own.
- Rollback: main verifies again.

**Pilot 2: owner questions and events on the tracker database (items 7-9 wave 2, compared with wave 1).**
- New `questions` collection with states draft, Fable-reviewed, open and answered. The owner sees only reviewed rows on a new tracker page tab, which needs the owner's approval.
- An answer typed on the page is data until main quotes it in chat; only then does a driver act on it.
- Append-only `events` per epic replace DRIVER-NOTES and STATUS lines.
- Gates: cold start under 10K, a question visible before the next wave, no lost notes, driver cost not up. The "driver cost -30%" gate is dropped: the 1-hour cache removed the disposable-driver saving.
- Rollback: export to markdown.

**Later:** specs/ OKF-lite after both pilots. **No:** beads, unless the tracker store proves limiting.
