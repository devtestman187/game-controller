job: m12 bug 1108g — the host log doesn't say when an away player's 30 s run out, and says "Round paused" when no round is running
stop: after it.
read: packages/party_host/lib/src/ui/pause_menu.dart (`_noteAway`, `_noteHostAway`) · packages/connection/lib/src/away_slots.dart (`onEnded`) · packages/party_host/lib/src/host_presence.dart · their tests · docs/review-rules.md

Owner's test (build 5, Nov 8), a joined phone locked for 40 s mid-race: the host carried on after 30 s, as designed, but the log had no line for it, only "P2 away: the round waits for them" at 08:14:39 and "P2 back: the round goes on" at 08:15:14, so the log read as if the round waited 35 s. Earlier the host app was left while the race results showed (the round had ended) and the log said "Round paused: the host went away" and, 7 min later, "Round resumed: the host is back".

Claude's rules:
1. When an away player's slot ends because their time ran out (not because they came back, and not Go on without them), the host logs once: `P<n> didn't come back in 30 s: the round goes on without them` (the grace's real seconds). Go on without them logs `Go on without P<n>: the round goes on` (one line per player). If they come back later in the same round the line stays `P<n> back` but without "the round goes on" when the round never waited for them: `P<n> back`.
2. "Round paused: the host went away" and "Round resumed: the host is back" only while a round is running (not on the results, not after it ended, not during the menus). Otherwise: `The host went away` and `The host is back`. The game's behaviour doesn't change; only the words.
3. Nothing else changes: the card, the timer, the countdown, the stats.

tests (each failing first): a phone that stays away past the grace: the line at the moment its slot ends, and `P2 back` after; Go on without them: its line; a phone back within the grace: today's two lines unchanged; the host leaving on the results: `The host went away` / `The host is back`; mid-round: today's lines unchanged.
in the report: test counts before and after, the files changed.
self-check: docs/review-rules.md part A, items 1–5, one line each in the report with the test that shows it.
rules: no lib file over 400 · tests first, each failing for the bug's reason · tools/review.sh: no FAIL on your lines · write only inside this job's folder.
allow: docs/briefs/m12/bug-1108g-fix-report.md · packages/party_host · packages/connection
check: format analyze connection host phone tv
report: docs/briefs/m12/bug-1108g-fix-report.md
