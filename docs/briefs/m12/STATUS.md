# M12 status (read this first when resuming)

Updated Nov 6, 2026, 15:15. Branch `m12`, worktree `E:\AI\game-controller-m12` (the main checkout `E:\AI\game-controller` stays on the frozen `demo-video`). Design: [../../design/m12.md](../../design/m12.md). Rules: [../../coding-guidelines.md](../../coding-guidelines.md). Working model: [../../project-notes.md](../../project-notes.md#how-we-work).

## Steps

| Step | State |
| --- | --- |
| 1 Extract `party_host` | **Done** (`490633d`, pushed). All 10 checks pass (613 tests). Not yet done: the step's exit check "the Windows build runs" (build `tv_test_app` for Windows and start it once) |
| 1b Follow-ups (next job) | Pending, see below |
| 2 Transport | Not started; contract (`MessageChannel`, `InProcessLink`, listeners, connectors) to write |
| 3–9 | Not started |

## Follow-up queue (one worker job, "1b", gated G2→G4)
1. `tools/review.sh`: mechanical guideline checks that print only violations (file/function sizes, `Platform.isX` in packages, upward imports, TODO, print, `// ignore:`, empty catch, numeric literals in new lines of the diff).
2. Break the `providers.dart` ↔ `ui/controller_menus.dart` import cycle: `ControlsClaims` to `ui/controls_claims.dart`.
3. Split `tv_test_app/lib/src/ui/home_screen.dart` (635 lines) per s1-g1-plan.md Q8.
4. One shared test helper for select/Enter → `ActivateIntent` (now duplicated in two harnesses and `TvTestApp`).

## How to run a job (lessons from step 1)
- Brief in `docs/briefs/m12/s<step>-g<gate>.md`, compact format (see s1-g3.md / s1-g4.md); the task argument only points at it (Windows' 32 KB command-line limit).
- `tools/flash.sh --allow … --check "…" --report docs/briefs/m12/<job>-report.md "Your brief is …"`, run with `run_in_background` (never `&` inside it: no completion notice). Load the key first: `export DEEPSEEK_API_KEY="$(powershell.exe -NoProfile -Command "[Environment]::GetEnvironmentVariable('DEEPSEEK_API_KEY','User')" | tr -d '\r\n')"`.
- The worker can't delete files or run `flutter pub get`: Claude deletes what the report lists under DELETE and edits pubspecs plus runs `pub get` before or after the job.
- `tv_test_app/windows/flutter/generated_*` show as modified after any Flutter run: never commit them.
- Review: read the summary; open the report only for questions; grep for guideline violations; run `tools/check.sh`; commit the report with the work.
