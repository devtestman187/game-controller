# p5a report: tools/claude-worker.sh, the Haiku worker, and its stand-in CLI

## Summary

- NEW `tools/claude-worker.sh` (41 lines): the thin wrapper the decision names. It exports
  `FLASH_WORKER=claude` and execs `tools/flash.sh "$@"`, so the Haiku worker is flash.sh with a
  different `wkind`: subscription login, `--safe-mode --strict-mcp-config --disable-slash-commands
  --no-session-persistence` instead of `--bare`, model `claude-haiku-5-5`, `--max-turns 35`. The
  header says what that isolates and what it does not, the two knobs and the exit codes.
- NEW `tools/fake-claude-worker.sh` (124 lines): stands in for the `claude` CLI itself, four
  `FAKE_CLAUDE_MODE` answers (ok, denial, max_turns, auth) with the real JSON line and exit codes,
  and `FAKE_CLAUDE_ARGS_FILE` for the argument list plus an `env: base= key=` line.
- NEW `tools/tests/claude-worker-test.sh` (165 lines): 15 cases, 6 s. Dry run under the wrapper
  (`worker: claude`, `model: claude-haiku-5-5`, `max-turns: 35`, `--safe-mode`, no `--bare`), the two
  knobs, plain flash.sh unchanged (`worker: flash`, `--bare`, `max-turns: 150`), `--web` exit 2,
  `--preflight` 0 in ok and 7 in denial/max_turns/auth, the stub's three JSON shapes, and the empty
  `env:` line even when `ANTHROPIC_BASE_URL`/`ANTHROPIC_API_KEY` were exported.
- Tests-first (exempt: new shell tool): before the two scripts existed, 14 of the 15 cases FAILED
  and the plain-flash.sh case passed (it needs no new file). The 14 lines are quoted below.
- `tools/check.sh tools`: **PASS** (586 s, run 18:33 on the final files).
  `tools/selftest.sh tools/tests`: 22 scripts passed (558 s), `claude-worker-test.sh` 6 s (limit 60 s
  in the brief, 120 s in selftest). `tools/review.sh`: `review: 0 fail, 0 note`.
- Values the cases assert: wrapper dry run `worker: claude | model: claude-haiku-5-5 | max-turns: 35`;
  override `model: claude-haiku-9-9-test | max-turns: 7`; plain flash
  `worker: flash | model: deepseek-v4-flash | max-turns: 150` with `--bare`; preflight through the
  wrapper exits 0 (ok), 7 (denial, max_turns, auth), the CLI is run with `--max-turns 8`; the stub's
  `num_turns` is 3 in ok, `--max-turns 4` gives `num_turns` 5 and exit 1 in max_turns, auth exits 1;
  tokens 1200 in / 80 out / 9000 cache read / 400 cache write, `costUSD` 0.0012.
- One finding cost a round and matters to every test that fakes `claude`: on Windows a `C:\...`
  folder is split at its colon when it is a PATH entry, so a shim there is never found and the real
  CLI runs. See "The PATH colon" below.
- Not done here: no runner wiring, metrics or docs (per the brief); `docs/dev-tools.md` and
  `docs/design/claude-only-model.md` still describe the scripts only in the design doc.

## Files

| file | lines | what it is |
|---|---|---|
| `tools/claude-worker.sh` | 41 | `FLASH_WORKER=claude` + `exec bash tools/flash.sh "$@"`; the header carries the isolation list, the knobs and the exit codes |
| `tools/fake-claude-worker.sh` | 124 | the CLI stand-in: `--model`/`--max-turns` parsed, four `FAKE_CLAUDE_MODE` answers, `FAKE_CLAUDE_ARGS_FILE` |
| `tools/tests/claude-worker-test.sh` | 165 | 15 cases in the style of `tools/tests/flash-prompt-test.sh` (PASS/FAIL lines, `RESULT:` last) |

`tools/flash.sh` is protected and unchanged; its `wkind` block already had the claude worker
(lines 236-246, the `iso` array at 243) and the env clean-up (`unset ANTHROPIC_BASE_URL
ANTHROPIC_API_KEY ANTHROPIC_AUTH_TOKEN`, `CLAUDE_CODE_DISABLE_AUTO_MEMORY=1`, lines 360-365), so the
wrapper only has to set `FLASH_WORKER`.

## What the wrapper's header promises

- **Achieved:** `--safe-mode` in place of `--bare` (no CLAUDE.md or user memory, no hooks, MCP
  servers, skills, agents or plugins); `--strict-mcp-config`; `--disable-slash-commands`;
  `--no-session-persistence` (no session file to resume); `CLAUDE_CODE_DISABLE_AUTO_MEMORY=1`; no
  `ANTHROPIC_BASE_URL`, `ANTHROPIC_API_KEY` or `ANTHROPIC_AUTH_TOKEN` in the run's environment.
- **Not achieved (and said so):** admin-managed settings still apply; the run shares the account's
  5-hour and weekly limits, so a plan cutoff ends it; the CLI still reads its own auth files (it must,
  to use the login); `CLAUDE_CODE_*` variables exported by the caller reach the worker (flash.sh sets
  the output caps on purpose).

## The stand-in's answers

| `FAKE_CLAUDE_MODE` | subtype | is_error | num_turns | result | denials | exit |
|---|---|---|---|---|---|---|
| ok (default) | `success` | false | 3 | `PREFLIGHT-DONE` | `[]` | 0 |
| denial | `success` | false | 3 | `PREFLIGHT-DONE` | one entry (`Bash` / `tools/check.sh --list`) | 0 |
| max_turns | `error_max_turns` | true | `--max-turns` + 1 | `Stopped at the maximum number of turns` | `[]` | 1 |
| auth | `error_during_execution` | true | 3 | `Invalid API key - Please run /login` | `[]` | 1 |

Every answer is one line: `type`, `subtype`, `is_error`, `num_turns`, `result`, `session_id`, `usage`
(the four token counts), `modelUsage` keyed by the `--model` value, `permission_denials`, and
`terminal_reason` (`completed`, `max_turns`, or absent for auth). `denial` is exit 0 because a denied
tool is not a CLI error — what fails is flash.sh's preflight grep, which is the behaviour under test.

## Cases (15)

| case | asserts |
|---|---|
| wrapper dry run | `worker: claude \| model: claude-haiku-5-5 \| max-turns: 35` |
| isolation flags | `--safe-mode`, `--strict-mcp-config`, `--disable-slash-commands`, `--no-session-persistence` present, `--bare` absent |
| the two knobs | `model: claude-haiku-9-9-test \| max-turns: 7`, `--model ...` and `--max-turns 7` in the command |
| plain flash.sh | `worker: flash \| model: deepseek-v4-flash \| max-turns: 150`, `--bare`, `--max-turns 150` |
| `--web` under the wrapper | exit 2, `DeepSeek-only` |
| `--preflight` ok | exit 0, `preflight ok` |
| preflight args | the args file has `--safe-mode`, the preflight's own `--max-turns 8` and its task text |
| preflight env line | line 2 is `env: base= key=` |
| preflight env line, variables exported | still `env: base= key=` with `ANTHROPIC_BASE_URL`/`ANTHROPIC_API_KEY` set before the run |
| preflight denial | exit 7, `PREFLIGHT FAILED`, the denial JSON in the message |
| preflight max_turns | exit 7, `PREFLIGHT FAILED (exit 1)` |
| preflight auth | exit 7, `PREFLIGHT FAILED (exit 1)` |
| stub ok | one line, `type`/`subtype`/`is_error`/`permission_denials`/`terminal_reason` fields, `modelUsage` keyed by `--model` |
| stub max_turns | exit 1, `error_max_turns`, `is_error:true`, `num_turns:5` for `--max-turns 4`, `terminal_reason:"max_turns"` |
| stub auth | exit 1, `is_error:true`, `Invalid API key - Please run /login` |

## Decisions

1. **`export` + `exec` instead of the one-line `FLASH_WORKER=claude exec bash ...`**: the brief names
   the behaviour, and two statements are the same behaviour with nothing left to bash's assignment
   rules; the test shows the wrapper's dry run is the claude worker, so the export reaches flash.sh.
2. **The shim execs the stub, and its folder goes on PATH through `cygpath -u`**: see "The PATH
   colon"; on macOS/Linux `cygpath` is absent and the plain path is used.
3. **Extra JSON fields** (`session_id`, `costUSD`, `webSearchRequests`): the brief fixes the fields a
   reader needs; the others are there so the line looks like the real CLI's and a future
   `job-metrics.sh` test can read the same shape. `session_id` is a fixed sample, no reader keys on it.
4. **`auth` uses `subtype error_during_execution`** (the brief fixes `is_error`, the result text and
   exit 1 only): `success` with `is_error: true` would read as a contradiction in a log.
5. **`denial` exits 0**: a denied tool is not an error for the CLI, and the case that matters
   (`--preflight` exit 7) is flash.sh's grep finding a non-empty `permission_denials`.
6. **The stub validates its inputs** (`FAKE_CLAUDE_MODE` value, `--max-turns` digits) and exits 2 on
   a typo, as `tools/fake-flash.sh` does: a silent default would turn a test into a no-op.
7. **The args file records the argument list and the two variables, and nothing else**: the test
   proves the key and base URL are gone; the list proves `--safe-mode` and the preflight's own
   `--max-turns 8` reach the CLI, which is what the preflight's success rests on.

## Tests-first (exempt: new shell tool)

Run before `tools/claude-worker.sh` and `tools/fake-claude-worker.sh` existed
(`tools/selftest.sh tools/tests`, `FAIL tools/tests/claude-worker-test.sh (2s)`):

```
FAIL the wrapper runs the claude worker on claude-haiku-5-5 with a 35-turn cap
FAIL the claude worker isolates with --safe-mode and its three flags, never --bare
FAIL CLAUDE_WORKER_MODEL and CLAUDE_WORKER_MAX_TURNS set the model and the turn cap
FAIL --web under the claude worker is refused with exit 2 (a DeepSeek-only job type)
FAIL --preflight through the claude worker exits 0 when the CLI answers ok
FAIL the CLI gets --safe-mode and the preflight's own --max-turns 8 with its task
FAIL the stand-in's env line is empty with no API variables set
FAIL the CLI's env line stays empty when ANTHROPIC_BASE_URL and ANTHROPIC_API_KEY were exported
FAIL --preflight exits 7 when the CLI reports a permission denial
FAIL --preflight exits 7 when the CLI stops at its turn cap (the CLI exits 1)
FAIL --preflight exits 7 when the CLI reports an auth error (the CLI exits 1)
FAIL the stand-in's ok answer is the CLI's one-line JSON, modelUsage keyed by --model
FAIL a max-turns stop is exit 1 with error_max_turns and num_turns one past the cap (4 gives 5)
FAIL an auth answer is exit 1 with is_error true and the CLI's /login message
```

14 of 15 failed; "plain flash.sh still runs the DeepSeek worker with --bare and 150 turns" passed,
because it needs no new file. The same script passed 15 of 15 in 6 s after the two files existed.

## The PATH colon (cost one round; worth a lesson)

The first run with both scripts in place had the ok preflight failing with
`PREFLIGHT FAILED (exit 1) ... "terminal_reason":"api_error","fast_mode_state":"off"` — that is the
**real** `claude` CLI, not the stub. Cause: `mktemp -d "${TMPDIR:-${TEMP:-/tmp}}/..."` returns
`C:\Users\mrman\AppData\Local\Temp/...` here, and a PATH entry with `C:` in it is split at the colon,
so `$tmp/bin` was never searched. Three of the four preflight cases still "passed" because any
preflight failure exits 7 — a false green. Fixed with `cygpath -u "$stubbin"`; the test now records
the args file, which is the evidence the stub itself ran.
`tools/tests/flash-prompt-test.sh` has the same latent issue (its `claude` stub is only asked for with
`command -v`, never executed, and it passes only because a real `claude` is installed).

## Self-check (docs/review-rules.md part A)

1. Host setups: not applicable — no app code; no TV/PC host, phone or joined phone is involved, and
   the tests run only shell scripts (all 15 cases).
2. Kept state: none starts or ends. The stand-in writes one args file per run into the test's temp
   dir, removed by the test's `trap` (cases 7-9, 13-15).
3. Pause menu, host away, player away, "Get ready", dropped link, results, leaving: not applicable.
4. Inside allow: `tools/claude-worker.sh`, `tools/fake-claude-worker.sh`,
   `tools/tests/claude-worker-test.sh` and this report (`git status --porcelain -uall`: those three
   untracked, plus churn the worktree setup made in `docs/design/*.png` and
   `tv_test_app/windows/flutter/generated_*`, which no case touches).
5. Nothing to stop for: no file outside allow: was needed. `tools/flash.sh` is the protected file the
   brief says not to edit, and it needed no change.
6. Every look: not applicable — no widget, no menu look and no TV look, no pixel height.

## Questions

1. Should the auth answer's `subtype` be `success` to match a real CLI's auth failure exactly? I used
   `error_during_execution` (decision 4); the brief fixes only `is_error`, the result text and exit 1.
2. Should `fake-claude-worker.sh` also answer a non-JSON `--output-format` (text), for a flash.sh
   change that reads the text output? No reader needs it today.

## Suggestions (not acted on)

- `docs/dev-tools.md` should list `tools/claude-worker.sh` and `tools/fake-claude-worker.sh` (it is
  outside this job's allow:); `docs/design/claude-only-model.md` already names them.
- `tools/tests/flash-prompt-test.sh`: put its `claude` stub on PATH through `cygpath -u` too. As it
  stands the stub is never executed and the test leans on a real `claude` being installed.
- `tools/project-notes.md` (or `docs/flash-lessons.md`): add the PATH-colon lesson — a `C:\` PATH
  entry is split at its colon, so a shim folder must go through `cygpath -u`; and a preflight exit 7
  proves nothing on its own, only the args file proves which CLI ran.
- `tools/flash.sh` (protected): the preflight replaces the task by index `${#iso[@]} + 2`, which
  silently breaks if the `iso` array's length changes. A named lookup would be sturdier.

## Commit message

```
tools: claude-worker.sh, the Haiku worker on the subscription login

Add tools/claude-worker.sh: flash.sh with FLASH_WORKER=claude, so the worker
keeps flash.sh's worktree, allow and deny lists, turn cap, preflight and report
handling, and runs on the subscription login with --safe-mode in place of
--bare, claude-haiku-5-5 and a 35-turn cap (CLAUDE_WORKER_MODEL,
CLAUDE_WORKER_MAX_TURNS).
Add tools/fake-claude-worker.sh, the CLI stand-in: ok, denial, max_turns and
auth answers with the real JSON line and exit codes, plus an args file that
shows the key and base URL were unset.
Add tools/tests/claude-worker-test.sh: 15 cases, 6 s; 14 failed before the
scripts existed. tools/check.sh tools passes (586 s).
```

## Status row

| p5a | done: `tools/claude-worker.sh`, `tools/fake-claude-worker.sh`, `tools/tests/claude-worker-test.sh` (15 cases, 6 s; `tools/check.sh tools` PASS 586 s; review 0 fail) | open: `docs/dev-tools.md` entries, the `flash-prompt-test.sh` PATH fix, a real Haiku rehearsal (p5b/p5c), and the runner wiring |

## Delete

- none
