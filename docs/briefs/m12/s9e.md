job: m12 s9e G4 — CI's analyze failed on m12.2: print in a test; make the local check as strict as CI
stop: after G4.
read: controller_app/test/puzzle_size_test.dart · tools/check.sh · .github/workflows/ci.yml (the analyze step) · codemagic.yaml (its analyze step) · docs/dev-tools.md (check.sh's section)

what happened: CI's `flutter analyze controller_app tv_test_app packages assets` (Flutter 3.47.8, which fails on infos) found 5 `avoid_print` infos in `controller_app/test/puzzle_size_test.dart` (lines 122, 128, 132, 139, 143), so the main-branch check and both Codemagic iOS builds failed. `tools/check.sh analyze` runs `dart analyze`, which doesn't fail on infos, so it passed here.

do:
1 puzzle_size_test.dart: the five `print` calls become `debugPrint` (as split_layout_test does); the printed text is unchanged.
2 tools/check.sh: the analyze check runs `dart analyze --fatal-infos` so an info fails here as it does on CI; its description says so. docs/dev-tools.md, if it describes the analyze check, says the same.
3 Run `tools/check.sh analyze` and fix nothing else: if other infos now show, list them in the report (file:line, rule) and stop; don't fix them.
tests: none added; the size test prints the same table.
in the report: the change, the analyze result with `--fatal-infos`, any other infos it found.
allow: docs/briefs/m12/s9e-report.md · controller_app/test/puzzle_size_test.dart · tools/check.sh · docs/dev-tools.md
check: format analyze phone
report: docs/briefs/m12/s9e-report.md
