job: m12 step8 s8a G4 — split session.dart and metrics_test.dart as pure moves
stop: after G4.
read: docs/briefs/m12/s8-g1-plan.md §1 (the split map: follow it) · docs/coding-guidelines.md · packages/metrics

do: plan §1, nothing else. Only directives and the renames of moved private names to public ones in the new internal file (`_Player` → `PlayerRecord` and so on, as the plan lists) may change; `session_player.dart` stays unexported. If anything else must change, stop and report it.
tests: none added or changed; 38 tests in the old metrics_test split as the plan says, all metrics tests passing with the same names.
in the report: line counts of new and touched files, `tools/review.sh --strings` (0/0 apart from directives and the listed renames), test counts before and after.
rules: moves only · tools/review.sh: no FAIL on your lines.
allow: docs/briefs/m12/s8a-report.md · packages/metrics/lib · packages/metrics/test
check: format analyze metrics host
report: docs/briefs/m12/s8a-report.md
