# Agent workflow: a Pro architect with Flash workers (DeepSeek Harness)

This file says **who does what, and with which model**, in a DeepSeek Harness session on this repo. It does not replace any rule: the coding rules (HANDOFF section 3), the test rules (section 4), the git and owner rules (section 5) and the daily routine (section 9) still apply in full.

A Claude Code session ignores this file. That line keeps using `tools/flash.sh` and its framework, as HANDOFF section 10 says.

## 1. Roles

| Role | Model | Owns | Never does |
| --- | --- | --- | --- |
| Architect | Pro | Framing, design, briefs, diff review, integration, the gate, commits, the report to the owner | Writes application code, or accepts a child's claim as evidence |
| Recon worker | Flash | Reading the repo and returning a compact map (file:line, line counts, existing tests) | Writes files |
| Implementer | Flash | One bounded change, tests first, with the failing-on-old-code output | Runs git write commands, or `tools/check.sh` |
| Adversarial reviewer | Pro, fresh context | Stress-testing a risky diff against `docs/review-rules.md` | Edits code |

Pro is used for judgment, not for typing better Dart. Its value is refusing bad work and knowing exactly what to ask for.

## 2. The loop, per task

1. **Frame (architect).** Read HANDOFF section 7 and only the area under change. Write the rule to enforce in one sentence and the acceptance criteria. If the rule cannot be stated, the task is not ready to delegate.
2. **Recon (Flash, read-only, parallel).** Ask for call sites with file:line, current line counts, and the tests that already touch the area. The architect reads the digest, not the files.
3. **Design (architect).** Choose the seam. Produce the exact list of files to change and the test names **with their assertions**. This is what makes a Flash worker reliable.
4. **Implement (Flash, one task each).** Tests first, then the fix, then the pasted failing output on the old code.
5. **Review (architect).** Read the diff. Confirm the test asserts the bug's own behaviour rather than passing trivially. Confirm nothing outside the brief was touched.
6. **Gate (architect).** One `tools/check.sh`, once. `tools/review.sh --base origin/main`. Coverage if lines were added.
7. **Commit and record (architect).** Named paths, a message that explains why, a line in `docs/briefs/m16/STATUS.md`, leftovers in `docs/code-health.md`.

## 3. Non-negotiable mechanics

- **Only the architect runs git write commands.** Children may run `git status`, `diff`, `log` and `show`. Concurrent `git add` in one worktree races the index, and `git add -A` is forbidden here anyway.
- **Parallel writers need disjoint files.** Team write scopes are advisory, not a lock. Fix overlap before dispatch; do not accept it as a risk.
- **Order real dependencies** with task `blocked_by`, not with hope.
- **A finished task does not wake anyone.** The board never starts an owner; use `wait_agent` or `send_message` when something must happen next.
- **One full check at a time.** If a check dies early on an environment fault (a pub-cache entry mid-write, for example), stop it, fix the cause, run once.
- **Churn never gets committed:** the regenerated PNGs under `docs/design/` and `site/shots/`, and `generated_plugin_registrant.*` / `generated_plugins.cmake`. Restore them before every commit with `git checkout -- <exact path>`.
- **Children stop; the architect decides.** A child that needs a design decision, a new dependency, a protocol change or a file outside its scope halts and says so.

## 4. The worker brief

Every brief carries all of this, or it is not ready:

```
Task: <one sentence, one outcome>
Worktree: E:\AI\game-controller-m16
You may modify ONLY: <exact paths>
Do NOT run: git add/commit/push/stash; tools/check.sh
Rule to enforce: <one sentence from the PRD, a bug row or a code-health item>
Test: <file> :: "<test name>" asserting <exact expected behaviour>
Required evidence: paste the test FAILING on the old code (with the error), then PASSING
Constraints: lib/ files <= 380 lines; dart format 120 columns; zero analyzer issues
             (infos included); imports per docs/coding-guidelines.md section 1;
             no new dependency; no magic numbers; no Future.delayed; no // ignore:
Report: files changed with line counts, both test outputs, anything unverified
Stop and ask if: the fix needs a file outside the list, or a design decision
```

Briefs are written for a worker that cannot see this conversation, cannot ask a follow-up question cheaply, and will not infer what was meant.

## 5. Model pinning

Pass `provider` and `model` explicitly on every child. Never rely on inheritance: a child that silently inherits the parent's route costs Pro prices for mechanical work.

- `deepseek-v4-pro` for the architect's own work, for an adversarial reviewer, and for a task whose judgment is the hard part.
- `deepseek-flash` (`DeepSeek-V4.1-Flash`) for recon, mechanical edits, refactors, doc updates, screenshot and mock-up generation, and data extraction.

If a route is refused, the session is not authorised for it: fix the route or the credential, and say so. Do not fall back silently to a different model.

## 6. What the architect verifies before calling anything done

- The diff, not the summary.
- The test's assertions, not its name.
- The one critical test, re-run by the architect.
- `git diff --stat` against the brief's file list, to catch scope creep.
- The line cap, the format, and the analyzer, from the gate — not from a claim.
- `git status`, for churn files and untracked leftovers.

A child's "done" is a hypothesis. The gate is the finding.

## 7. Records

- A dated line in `docs/briefs/m16/STATUS.md`: bug id, cause, fix commit, test, status.
- Anything deferred or left over in `docs/code-health.md`, by area.
- Anything that depends on a real device is **"Fixed, unverified: needs device check"**, with exactly what the owner should do. Never plain "Fixed".

## 8. Failure modes to watch

- **Trivial tests.** `expect(found, true)` where the bug needed a behavioural assertion. Read the assertions first.
- **Scope creep.** A small fix that also reformats a file. Check the diff stat.
- **Plausible but unrun evidence.** Re-run the critical test; it costs seconds.
- **Architect context bloat.** Reading whole files means the recon step was skipped.
- **Silent model substitution.** A child on the wrong route, or a "fix" that avoided the hard part.

## 9. Calibrate on a known task first

Before delegating milestone features, send one already-specified, low-risk item through the loop — the stale-lift pattern on `pad_widgets.dart` / `face_buttons.dart` is ideal, because `docs/code-health.md` already states the fix and the tests. Review it hard and measure whether the evidence returned is real. That pilot tells you how much to delegate; this document cannot.
