job: m12 bug 1108a fix2 G4 — "Show on this device": no link dot, and the screen stays on
stop: after G4.
read: docs/briefs/m12/bug-1108a-fix-report.md (yours: Questions 1–4) · controller_app/lib/src/ui/{controller_top_bar,bar_connection}.dart · controller_app/lib/src/host/{host_overrides,host_screen}.dart · packages/party_host/lib/src/providers.dart (`keepAwakeProvider`) · docs/review-rules.md

Claude's answers: Q1 hide it: a phone that only shows the game has no link of its own, so the compact bar over a round shows no dot (and no Connect button behind it); the chip with the code stays. Q2 keep the screen on for the whole time a phone hosts, in both modes: a phone that dims or locks while waiting for players pauses and then abandons the game. The TV keeps today's rule (on while any controller is connected). One seam in party_host (default false, so the TV is unchanged), the phone app overrides it. Q3 not now: Claude logs "dispose waits for a start in flight" in code-health. Q4 keep the pairings: a host remembers phones.

do: Q1 and Q2 as above.
tests (each failing first): Show mode over a round: no dot, the chip there; Play mode: the dot as today. The phone host keeps the screen on with no controller connected (Show mode, on the join screen) and lets it sleep when hosting stops; the TV's rule unchanged (off with none, on with one).
in the report: test counts before and after, the files changed.
self-check: docs/review-rules.md part A, items 1–5, one line each in the report with the test that shows it.
rules: no lib file over 400 · tests first, each failing for the bug's reason · tools/review.sh: no FAIL on your lines · write only inside this job's folder.
allow: docs/briefs/m12/bug-1108a-fix2-report.md · controller_app/lib · controller_app/test · packages/party_host
check: format analyze host phone tv
report: docs/briefs/m12/bug-1108a-fix2-report.md
