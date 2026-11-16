## Summary

small fixes — 0 must, 1 should, 5 could. The applied CI change matches the brief (step order, the exact format command, fenced job-summary block, `coverage` artifact with retention 14 and the file's `upload-artifact@v7`); `tools/check.sh format` passes on the committed tree (4 s).
- **should:** the report still says the two `ci.yml` changes are "not applied" and lists them as open, but commit c968b552 contains both; the next reader would redo finished work.
- **should:** `docs/dev-tools.md:114` says `part of` files are left out of the table; `tools/coverage_summary.dart` counts them.
- **could:** the rest is in `docs/dev-tools.md`'s Coverage section — two generated suffixes missing from the exclusion list, a sample table whose shape and row names differ from the script's output, and an exit-code line without 2.

## Findings

- **should** docs/briefs/m14/bugs15/cov-2-ci-docs-report.md:3 the report says the `ci.yml` changes are "not applied" and lines 21-22, 95 and 122 keep them open, but commit c968b552 contains them (.github/workflows/ci.yml:49-50 and 71-93, applied by hand at 12:33 per run.log) → rewrite the Summary, the "Not applied" section, Hand-over item 1 and the Status row to say the steps are in the commit, and note the committed step is named "Coverage (line % per package; no threshold)", not "Coverage".
- **should** docs/dev-tools.md:114 the exclusions bullet says "`part of` files are left out of the import test and of the table", but tools/coverage_summary.dart:131-135 drops only generated files, so a part file's lines are counted through the library that owns it → say part-of files are left out of the import test only and their lines are counted in the table.
- **could** docs/dev-tools.md:114 the generated-file list names `*.g.dart`, `*.freezed.dart` and `*.gr.dart`, but tools/coverage_imports.dart:38 also skips `*.config.dart` and `*.mocks.dart` → add the two suffixes.
- **could** docs/dev-tools.md:106 the sample table has no column pipes or rule line and shows a `protocol` row, while tools/coverage_summary.dart:68-80 prints `package | lines hit | lines found | %`, a dash rule and folder names such as `packages/protocol` and `packages/party_host` → paste a real table, or label it as illustrative and use the folder names the script prints.
- **could** docs/dev-tools.md:115 the exit-code bullet lists 0 and 1, but tools/coverage.sh:57 and 82 also exits 2 for a bad argument or a missing tool → add 2 to the bullet, as the `tools/check.sh` section does.
- **could** docs/dev-tools.md:100 "as the test steps do" suggests every coverage run mirrors CI's test steps, but ci.yml:53-58 runs `dart test` for protocol and connection while tools/coverage.sh:108 uses `flutter test --coverage` in every package → say `flutter test --coverage` runs in every package, the pure Dart ones too.

## Decisions to confirm

- The report's Decision 3 (plain package names in the docs' options line): the options text is right (coverage.sh accepts a folder's last part), but the sample rows show names the table never prints — decide which the sample should show, with finding 4.
- The report's Decision 5 (docs written for the patched CI): the patch is now in the commit, so the "until the patch lands" wording and the report's Question 1 have no target left; confirm they come out in a small report edit rather than by changing the docs.
- The step's `status=0 … || status=$? … exit $status` shape and the two-step split (report Decision 1): both look necessary in a `bash -e` step; no action unless a threshold is wanted later.

## Could not check

- The Coverage step and the `coverage` artifact on a GitHub runner: not run, since `bash tools/coverage.sh` writes `coverage/` files and this review may change only its report; the step's shape was checked against ci.yml and tools/coverage.sh only.
- Whether `flutter test --coverage` writes a separate lcov record for each `part of` file: inferred from tools/coverage_summary.dart (it counts every `SF:` record that is not generated); no lcov.info is in the tree to read.
- The worker's account that its permission settings refused edits under `.github/`: not testable from here.

## Commit message

```
Review cov-2: 0 must, 1 should, 5 could

Read the committed ci.yml Format and Coverage steps, dev-tools.md and the
worker's report against the brief, the guidelines and the tools they
describe. The CI steps match the brief; the findings are text: the report
still says the ci.yml patch was not applied although the commit has it,
and the Coverage section's exclusion list, sample table and exit code do
not match tools/coverage_summary.dart and tools/coverage.sh.
```

## Status row

**bugs15 cov-2 review (Nov 16, 2026, read-only, nothing built):** 0 must, 1 should, 5 could; the CI Format and Coverage steps and the `coverage` artifact are in c968b552 and match the brief, and the format step passes on the tree; open: the report's stale "not applied" lines and the dev-tools Coverage section's exclusion list, sample table and exit-code line.

## Delete

- none
