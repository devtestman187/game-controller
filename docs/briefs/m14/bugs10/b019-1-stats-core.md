job: M14 bugs10 b019-1-stats-core: LiveStats ends and uploads a session when the host pauses or leaves (B-019, phase 1 of 2)
pub: no
stop: after it. Do not touch controller_app (phase 2 wires the app lifecycle).
read: packages/party_host/lib/src/live_stats.dart (_checkPlayers, endSession, uploadNow, sessionGap) · packages/party_host/lib/src/stats_service.dart · packages/party_host/lib/src/testing/fake_stats.dart · packages/party_host/test/live_stats_test.dart (how it builds LiveStats, the injected clock) · docs/coding-guidelines.md
decide: low-usage mode: never stop for a question. Make the safest choice and list each under "Decisions" with one line of why. Stop only if the job truly cannot be done; then say why under "Blocked".

Owner row B-019 (phone/tablet host, m14.4): a phone host's own player counts as present, so the session only ends after sessionGap (2 min) with nobody connected, which never happens while the host app is open; on iOS the background suspends the timers, so the session sits on disk and uploads only at the next app start. Cause read from the code, not measured on a device.
do:
1 TEST FIRST, new file packages/party_host/test/live_stats_lifecycle_test.dart (must fail on the old code), with an injected clock and a short sessionGap: (a) a session with only the host's own in-process player is ended and saved by `pause()`, and with consent the uploader gets it; (b) `resume()` retries the unsent sessions through `uploadNow()`; (c) a session ended by `pause()` starts a NEW session when a player changes afterwards; (d) a TV-style host with two remote phones: `pause()` is never called, its session stays open past sessionGap while they are connected and ends only after they leave (current behaviour kept); (e) dispose still ends and saves.
2 In live_stats.dart add `Future<void> pause()` (ends the session like endSession, so the file is saved and queued) and `Future<void> resume()` (calls uploadNow). Add both to StatsService and FakeStats (FakeStats counts calls). Also: when the only presence is the host's own player (in-process or local) and that player leaves the game (host.players has no local player), start the sessionGap timer as it does for nobody. If this cannot be decided from host.players without changing a TV host's behaviour, skip it and list it under Decisions.
3 Report: which of the three was done.
tests-first: the new test file must fail on the old code.
rules: aim for 80-150 turns · no lib file you touch may end over 380 lines · write only inside allow: · stage nothing yourself · never use git add -A · tools/review.sh: no FAIL on your lines.
allow: packages/party_host/lib/src · packages/party_host/test · docs/briefs/m14/bugs10/b019-1-stats-core-report.md
check: format analyze host
report: docs/briefs/m14/bugs10/b019-1-stats-core-report.md
in the report: start with `## Summary` (at most 30 lines): what changed, tests seen failing and passing with counts, decisions, "Fixed, unverified: needs device check" (the cause was not measured on a device). End with `## Hand-over` (the exact method names).
