## Summary

**STOPPED on `.github/workflows/ci.yml`:** this worker's permission settings deny every edit inside `.github/` ("File is in a directory that is denied by your permission settings", tried twice). The brief allows `ci.yml`, the coding guidelines say to stop and name the file rather than work around it, so the two `ci.yml` changes are **not applied**. The exact patch is in "What changed" below, ready to paste.

- Done: `docs/dev-tools.md` — a new "Coverage: tools/coverage.sh" section (what the script does, its options, the table, exclusions, exit code, how CI uses it, artifact name and retention, no threshold yet), a row for the script in the tools table, `coverage.sh` added to the list of scripts that work on all three OSes, and the Format step mentioned in the `check.sh` "Formatting" bullet.
- Not done: the `Format` step, the `Coverage` step with its job-summary block, and the `coverage` artifact upload in `analyze-test-android`.
- The docs describe CI as it will be once the patch is applied; until then only the local script exists.
- `tools/coverage.sh`, `tools/coverage_imports.dart` and `tools/coverage_summary.dart` are job cov-1's (same wave) and are referenced by name only; they are not in this tree yet.
- Checks: `tools/check.sh format` PASS.
- Estimated extra CI time once applied: about 3 to 5 minutes on `analyze-test-android` (see "CI minutes").

## What changed

**docs/dev-tools.md**

1. Tools table: a `tools/coverage.sh` row (what it does, "about 3 to 5 minutes (every package's tests once more)").
2. The sentence naming the scripts that work on Windows (Git Bash), macOS and Linux now includes `coverage.sh`.
3. New section "Coverage: tools/coverage.sh" between `tools/check.sh` and `tools/review.sh`: three commands, why the generated import test exists, the three steps of a run, a sample table, options (`<package names…>`, `--no-gen`), exclusions (generated files, `part of`, VM-only-impossible files), exit codes (0/1, table printed either way), the CI step and the `coverage` artifact (14 days, `gh run download <id> -n coverage`), "no threshold fails CI yet", and the CI Format step.
4. `tools/check.sh` "Formatting" bullet: CI runs the same command as a Format step before Analyze.

**Not applied — `.github/workflows/ci.yml`** (blocked; paste as is):

```diff
       - name: Get packages (pub workspace)
         run: flutter pub get
+      - name: Format
+        run: dart format --output=none --set-exit-if-changed controller_app tv_test_app packages assets
       - name: Analyze
         run: flutter analyze controller_app tv_test_app packages assets
```

and, after the `Test TV app` step and before `Build controller APK`:

```yaml
      - name: Coverage
        run: |
          status=0
          bash tools/coverage.sh || status=$?
          {
            echo '## Line coverage'
            echo '```'
            if [ -f coverage/summary.txt ]; then
              cat coverage/summary.txt
            else
              echo 'no coverage/summary.txt: the Coverage step did not finish'
            fi
            echo '```'
          } >> "$GITHUB_STEP_SUMMARY"
          exit $status
      - uses: actions/upload-artifact@v7
        if: always()
        with:
          name: coverage
          path: |
            coverage/summary.txt
            **/coverage/lcov.info
          retention-days: 14
```

Why the step is written that way: a `run:` step on GitHub is `bash -e`, so a `coverage.sh` that exits 1 on a failing test would end the step before the summary block; `|| status=$?` keeps the table going into the job summary and still fails the run at the end (a failed test is a failure, a low percentage is not). `**/coverage/lcov.info` covers both the app and the `packages/*` layouts; `coverage/summary.txt` is the repo-root table. The unnamed artifact step matches the existing `android-apks` one; `if: always()` means it still uploads when an earlier test failed.

## Decisions (low-usage mode)

1. **One Coverage `run:` step plus one upload step**, not one step doing both: the upload action can't be inside `run:`, and keeping the table in the step's own output is what puts it in the job log.
2. **The summary block reads `coverage/summary.txt`** (written by `coverage_summary.dart`) instead of capturing stdout with `tee`: one source of text, and it works when the script fails after printing part of the table.
3. **Package names in the docs' options line** (`puzzle_game`, `controller_app`), from cov-1's brief ("optional arguments: package names"), not check.sh's check names (`puzzle`, `phone`).
4. **The sample table is marked "(sample)"** and shows plain package names, since cov-1's report has the real numbers and this job can't run the script (it isn't in the tree).
5. **Docs describe the CI steps as the brief specifies**, although `ci.yml` was refused: the section is written once, for the patched workflow, rather than twice. The blocker is above and in the Status row.
6. **No threshold, no coverage service, Analyze untouched**, as the brief says.

## CI minutes

- Format: about 5 to 10 seconds (the local `tools/check.sh format` run takes 5 s including script startup).
- Coverage: the eight suites in `tools/check.sh` take about 90 s locally (169 s total minus analyze 75 s and format 3 s); `--coverage` adds an instrumented build of each package and an lcov write, roughly 1.5 to 2 times, so about 2.5 to 3 minutes locally and about 3 to 5 minutes on the ubuntu runner (cold Flutter, per-package startup). The step re-runs the tests the six test steps just ran, which is the cost the brief accepts.
- The job's 30-minute timeout is not at risk: the two release APK builds dominate it.

## Self-check (review rules, part A)

- **Every host setup:** no host, client or app code changed; docs and config only.
- **When kept state starts and ends:** no kept state; coverage files under `coverage/` are generated by cov-1's script and ignored, nothing of ours persists between runs.
- **How a new state combines with the others:** no state.
- **Your folder only:** changed `docs/dev-tools.md` and this report; `ci.yml` was refused by the tool, not edited by another route (no shell write, no permission override).
- **Stop rather than overstep:** stopped on `ci.yml` and reported it, with the patch, instead of writing it some other way.

## Checks

| Check | Result |
| --- | --- |
| `tools/check.sh format` | PASS (5s) |

No test suite run: no Dart changed (and the brief exempts CI config and docs from tests-first).

## Hand-over

1. Apply the two `ci.yml` blocks above (a worker with `.github/` write access, or Claude in the main session).
2. When cov-1's `tools/coverage.sh` lands, run `bash tools/coverage.sh` once on the runner or locally and replace the sample table's numbers with the real row names and TOTAL; if the table's header differs from `package | lines hit | lines found | %`, fix the two sample lines and the header line in the docs section.
3. After the first CI run with the patch, check the run's summary page shows the fenced table and the `coverage` artifact holds `summary.txt` plus every package's `lcov.info`, and note the step's real duration in the docs table if it differs from 3 to 5 minutes.
4. A later job adds `--fatal-infos` to Analyze (brief: do not change it here).

## Questions

1. Should `.github/` be in this worker's write permissions? The brief allows `ci.yml`, the framework refuses it; every CI job in this wave will hit the same wall.
2. Is the docs' sentence about CI's Format step wanted even though the step exists only in the patch? I kept it so the doc and the patch land as one story; if the patch is dropped, that sentence and the CI bullet in the Coverage section must go.

## Commit message

```
Document tools/coverage.sh and the CI checks it feeds

Add a Coverage: tools/coverage.sh section to docs/dev-tools.md: what the
script does (generated per-package import test, tests with --coverage, the
table in coverage/summary.txt), options, exclusions, and how CI uses it
(job summary table, `coverage` artifact, no threshold yet).

List the script in the tools table and in the cross-OS line, and name CI's
Format step in the check.sh bullet. The ci.yml Format/Coverage steps are
drafted in the report but blocked: this worker cannot write .github/.
```

## Status row

**bugs15 cov-2 (Nov 16, 2026, docs only, nothing built):** docs/dev-tools.md has the "Coverage: tools/coverage.sh" section, the tools-table row, the cross-OS line and CI's Format step; open: the ci.yml Format and Coverage steps and the `coverage` artifact (patch in the cov-2 report, this worker cannot write .github/), and the docs' sample table to replace with cov-1's real numbers once `tools/coverage.sh` lands.

## Delete

- none

