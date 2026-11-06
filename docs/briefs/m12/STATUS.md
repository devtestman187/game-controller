# M12 status (read this first when resuming)

Updated Nov 6, 2026, 15:50. Branch `m12`, worktree `E:\AI\game-controller-m12` (the main checkout `E:\AI\game-controller` stays on the frozen `demo-video`). Design: [../../design/m12.md](../../design/m12.md). Rules: [../../coding-guidelines.md](../../coding-guidelines.md). Working model: [../../project-notes.md](../../project-notes.md#how-we-work).

## Steps

| Step | State |
| --- | --- |
| 1 Extract `party_host` | **Done** (`490633d`, pushed). All 10 checks pass (613 tests). Windows exit check passed Nov 6 (release build ok; `tools/tv-dev.sh start` hosts on 45780 and advertises; sounds untested here because Claude's sandbox blocks %TEMP%) |
| 1b Follow-ups | **Done**: `tools/review.sh`, `controls.dart` (cycle broken), home screen split into `ui/home/`, `hostActivateShortcuts`. Answers to s1b-report Q1–5: Q1 default base is now `HEAD` (one job's diff; `--base origin/main` for the branch) · Q2 TODO in tests too, ok · Q3 export `ClaimHandle` only when a caller needs it · Q4 `number` stays a NOTE; spacing scale is tech debt · Q5 long members are tech debt (project-notes) |
| 2 Transport | Contract written: [../../design/m12-transport.md](../../design/m12-transport.md). Next: G1 plan (`s2-g1.md`) |
| 3–9 | Not started |

## How to run a job (lessons from step 1)
- Brief in `docs/briefs/m12/s<step>-g<gate>.md`, compact format (see s1-g3.md / s1-g4.md); the task argument only points at it (Windows' 32 KB command-line limit).
- `tools/flash.sh --allow … --check "…" --report docs/briefs/m12/<job>-report.md "Your brief is …"`, run with `run_in_background` (never `&` inside it: no completion notice). Load the key first: `export DEEPSEEK_API_KEY="$(powershell.exe -NoProfile -Command "[Environment]::GetEnvironmentVariable('DEEPSEEK_API_KEY','User')" | tr -d '\r\n')"`.
- The worker can't delete files or run `flutter pub get`: Claude deletes what the report lists under DELETE and edits pubspecs plus runs `pub get` before or after the job.
- `tv_test_app/windows/flutter/generated_*` show as modified after any Flutter run: never commit them.
- Review: read the summary; open the report only for questions; grep for guideline violations; run `tools/check.sh`; commit the report with the work.
- Don't write files in the repository while a job runs: `flash.sh` reports them as changed outside `--allow` (exit 4).
- Before committing a job: `tools/review.sh` (the job's diff, FAIL lines only matter) and `tools/check.sh`.
