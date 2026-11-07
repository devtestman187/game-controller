job: m12 step8 s8b G4 — host device samples, watched, hz per round, stages and view counts by rate
stop: after G4.
read: docs/design/m12-report.md (contract §0.1–§0.8) · docs/briefs/m12/s8-g1-plan.md (§2 s8b, §3, §4, §5 s8b: your plan, with the answers below) · docs/briefs/m12/s8a-report.md · docs/coding-guidelines.md · the files plan §2 lists for s8b and their tests

Claude's answers to the plan's questions: Q1 yes, `viewByHz` (frames, gaps, late) through the same seam, filed by the running view's hz · Q2 plan A: `charging` in each round's battery block, and the rate table skips charging rounds · Q3 `joined(inProcess:)` as an 8th named parameter; no value object now · Q4 yes, party_host depends on game_kit (name it in the pubspec comment if the file has them) · Q5 always shown (every build today is a test build; the label says "(test)") — that's s8c · Q6 yes, `StatsState.lastSaved`; the marker on its own line, the JSON on the next — s8c · Q7 yes, fill the last round, guarded · Q8 yes: battery 0..1 with two decimals; `stages` the union and `stagesByHz` the breakdown; `diagnostics_screen.dart` ≤ 364 (s8c).

do: plan §2's s8b list, in its order, with §3's and §4's seams.
tests: plan §5's s8b list, plus `viewByHz` (frames at 60 then 30 land in two entries). Existing expected values: none should change; list any old → new.
in the report: line counts (flag any lib file past 360), test counts per check before and after, anything in the plan you changed and why.
rules: no lib file over 400 (tests 500); `host_service.dart` ≤ 360; summarySchema stays 1; the TV records nothing new without a monitor · tools/review.sh: no FAIL on your lines.
allow: docs/briefs/m12/s8b-report.md · packages/metrics · packages/party_host · packages/connection/lib/src/server_game_host.dart · packages/connection/test · packages/game_kit · packages/puzzle_game/lib · packages/puzzle_game/test · packages/test_game/lib · packages/test_game/test · pubspec.lock
pub: yes
check: format analyze connection metrics kit arena puzzle host phone tv
report: docs/briefs/m12/s8b-report.md
