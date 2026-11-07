# m12 cleanup c1 G4 — review

## Findings
- should packages/connection/test/haptic_test.dart:55 — the round trip does not show what the report says (§2 row 13, §6.2): a haptic sent while the phone was unpaired is dropped by the client (`client_messages.dart:49`), so `unpairedGot` is 0 whether or not `sendToAll` sent one; only `expect(sendToAll(...), 2)` (line 48) checks the skip. Brief item 2 ("a wait that checks something does NOT happen uses such a round trip").
- should packages/connection/test/m10_test.dart:73 — same false negative for layout/status: a client without those capabilities ignores them (`client_messages.dart:62,65`), so `client.layout.isStandard` holds even if the host had wrongly sent one; the haptic proves only that the channel is alive. Brief item 2.
- nit packages/connection/test/reconnect_test.dart:145 — the expectation changed (was `connected` isEmpty) against brief item 3 "the same expectations"; the report's line 33 claims none changed and its §6.1 discloses this one. What it proves is the same fact, made exact.
- nit docs/briefs/m12/c1-g4-report.md:102 — lists `packages/connection/lib/src/game_host.tmp` as a leftover; no such file exists (not on disk, not in `git status --short`), so the Delete list (line 141) and question 2 (line 114) are stale.
- nit docs/briefs/m12/c1-g4-report.md:73 — the kept 20 ms loop is at `m6_test.dart:140`, not 130; the m10 one (line 101) is right.
- nit packages/connection/test/m9_test.dart:65 — `host.messages.firstWhere` with no `.timeout`, so a miss fails at the 30 s test timeout instead of 5 s with a message; same at m9_test.dart:112 and m10_test.dart:28, 38, 52, 163, while every other new wait in the job carries `.timeout(5 s)`.
- nit packages/connection/test/m10_test.dart:150 — "two samples" is two heartbeat pings answered, ~100 ms apart only because `hb` is 100 ms in `helpers.dart:10`; nothing ties the wait to `minPressMs`, so bundled pongs could let the check run before the 50 ms window closed.

## Brief — 4 of 4 items done; 1 done differently
- 3 — one expectation differs (`reconnect_test.dart:145`, above); test names and counts per file are unchanged.
- 2 — two `Future.delayed` stimulus loops stay (`m10_test.dart:101`, `m6_test.dart:140`); the reasons are in the report §3, so the rule is met and this is Claude's decision, not a finding.

## Checked
- Pure move: read `git show HEAD:packages/connection/lib/src/game_host.dart` against all five new files, member by member. Every member (GamePlayer, LatencyStage, StageSample, GameRecord, GameHost, PlayerLatency, LocalPlayer, ServerGameHost, `_samePlayers`, MemoryGameHost) is there verbatim; only imports and the blank lines between file blocks differ; `_samePlayers` now sits in `server_game_host.dart:239` (the report says so).
- Exports: `connection.dart:12-24` shows the same nine public names the old single export gave; nothing else in the repo imports `src/game_host.dart` (grep over packages/, controller_app/, tv_test_app/).
- Sizes: `wc -l` → 79 / 85 / 28 / 240 / 128 (old 538); all ≤300.
- `tools/review.sh` → `review: 0 fail, 0 note` (the whole uncommitted tree, so no FAIL on the job's lines or the others').
- `tools/review.sh --strings` → `strings: 0 removed, 0 added, 7 unchanged or moved`: no added or removed text to mark allowed / not in the brief.
- `dart format --output=none --set-exit-if-changed packages/connection` → "Formatted 49 files (0 changed)".
- `dart analyze` in `packages/connection` → "No issues found!".
- `dart test` in `packages/connection` → 176 tests, all pass, ~10 s (report: 13 s via check.sh). Re-run of the six changed files → 102 tests, all pass. Report's 176 confirmed; its "176, 26 s before" cannot be checked without the old tree.
- Test declarations per changed file, now vs `git show HEAD:` → haptic 4/4, input 12/12, m10 6/6, m6 14/14, m9 14/14, reconnect 10/10; no `test(`/`testWidgets(` line added or removed.
- Real time left in `packages/connection/test`: no `settle`, `sleep`, `Timer(` or polling loop; exactly two `Future<void>.delayed` (`m10_test.dart:101`, `m6_test.dart:140`), both in the loops the report names. (A grep for the literal `Future.delayed` misses these: the code writes `Future<void>.delayed`.)
- Each replaced wait lands on an event that really fires: `host.changes` emits on every pong (`host_connection.dart:248`), `client.changes` on every pong (`client_messages.dart:96`), `host.messages`/`changes` are broadcast (`host_server.dart:90-101`), haptic/layout/status streams are broadcast (`client_controls.dart:11-14`); `_onInput` sets the snapshot before forwarding (`host_connection.dart:252-261`), so the quick-tap release wait proves the snapshot; `sendInput` always sends a new seq (`controller_client.dart:169`), so the "later input" in `m9_test.dart:62` cannot be deduplicated; pairing sends a neutral input (`client_messages.dart:138`); `_ended` forwards the neutral release with `seq + 1` (`host_connection.dart:369-372`).
- Report's table line numbers, spot-checked against the files: m9 65/79/91/94/112/140/153/187/200 and m10 28/29/38/39/52/53/73/85/104/149/150/163/167 all match.
- Two files named in the report but absent from the diff (`game_host.tmp`): `ls packages/connection/lib/src` and `git status --short` agree it is not there.
