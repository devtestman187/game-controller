# M12 build 4 — review R1: the wire (protocol · connection · game_kit · metrics)

Range `git diff 526a6fc 9df6884` (build 3's tag to build 4's last code commit): 25 files, +1103 −26. Read-only: only
this report changed, nothing fixed. `tools/review.sh --base 526a6fc`: **0 FAIL, 37 NOTE** — nothing to copy. In this
area the notes are sizes (`host_connection.dart` 398 of the hard 400, `host_server.dart` 385, `server_game_host.dart`
375, `game_session.dart` 319, `session.dart` 309; aim 300) and `client_messages.dart:34 onData` at 58 lines (aim 40).

## Findings

1. **must** · `docs/protocol.md:237` · guideline §8 · the wire changed and the doc did not. The frame row still says "`n`: step number from 0" and §10a "each `frame` … is one step"; build 4 sends a frame with `n: -1` before step 0 (`game_session.dart:250`, every round a phone host holds for the 3 s beat), then none for 3 s. A controller built from the doc reads a step number outside its range and a 3 s hole where a step should be; nothing says which fields that frame leaves out (finding 2) or that a held round publishes nothing more.
2. **should** · `packages/game_kit/lib/src/game_session.dart:250` · B5 · the beat frame is `n`, `at`, `s` only — no `roster`, no `acks` (`view.dart:53` defaults the roster empty). `ArenaHud` (`arena_view_widgets.dart`) draws its P1/P2 rows from the frame's roster, so on a joined phone every phone-hosted round now shows the board with no counters for 3 s and then pops them in; the step frames it precedes carry both.
3. **should** · `packages/game_kit/lib/src/game_session.dart:248` · B3/A1 · `_publishFirstFrame` returns when `hasViewers` is false, and only the `paused` setter calls it, so a round held with no viewer attached never sends one. `_sendView` (`server_game_host.dart:352`) then sends `view_start` and no frame: a TV or phone that pairs during those 3 s draws nothing until the beat ends — the case the method's own doc says it covers.
4. **should** · `packages/protocol/lib/src/view.dart:61` · B7/§8 · `FrameMessage.n`'s doc says "from 0", so the package states as impossible a value it now publishes; the next host or viewer written against it asserts on -1.
5. **should** · `packages/metrics/lib/src/session_player.dart:107` · 1107e Q4a · `'ratings': p.ratings` still hands the live list to a summary, two lines under the `games` copy and beside `rounds`' (`session.dart:278`). A rating that lands after a checkpoint (`session.dart:158`) changes the summary `LiveStats` keeps in `_state.current` with no new state emitted, so what the screen shows and what the next write encodes drift; the aliasing test (`metrics_test.dart:197`) rates nothing after its summary.
6. **should** · `packages/connection/lib/src/host_connection.dart:1`, `client_messages.dart:34` · §3 · 398 of the hard 400 and a 58-line `onData`: the client's message path holds four kinds already, so the next one is a file split, not an edit.
7. **later** · `packages/connection/lib/src/away_slots.dart:122` · B2/C · the grace is a wall-clock `Timer`, so it runs while the round stands still: host opens the menu for 40 s with P2 away → P2's slot ends and the round plays on without them though no step ran; the same timer runs while the app is hidden. Cheap now (the stop is one signal); later, two clocks for one wait.
8. **later** · `packages/connection/lib/src/away_slots.dart:150` and the two cards · C (M13 one round flow) · "seconds left" is computed three times from three clocks, and M13 puts a countdown and a last-15-s warning on the same second: one rule for `s` now, three copies to reconcile later.
9. **later** · `packages/connection/lib/src/server_game_host.dart:352` · B3 · `_sendView` re-sends the layout, the panel, the latest frame and the away slots, not `host_away`: a viewer pairing while the host is away sees a frozen board with no card and no Leave game. Pre-existing; small while the function is open.
10. **later** · `packages/connection/lib/src/viewer_stats.dart:143` · B2 · no draw gap is capped, so the beat's 3 s hole marks one `late` draw on every phone-hosted round and a press made during the beat lands a ~3 s `touch_to_frame` sample (`:158`). 1107e fixed the host's side of a pause; the phone's counts were outside it. Part C holds nothing else: these four are what would cost more later.

## A. Part A for this area's jobs (no report in build 4 has a self-check — the rule came after them — so A1–A3 are mine)

- **1107d A1** (`a01a3c6`) — A1 true for every host: the slot lives in `ServerGameHost`/`AwaySlots` with no branch on host type, and a TV/PC host, "Play on this phone" and "Show on this device" hold it alike; only a joined phone can go away (`player_away_test`). A2: starts at `_hold` only while a round runs; ends by return (`:111`), grace (`:67`), `goOnWithout` (`:82`), the round over (`:163`) and dispose (`:192`); no round and a simulated drop leave at once (`:179`, `:148`).
- **1107d B** (`5ba119c`) — no file in this area; its pause reaches `game_session` only as `paused`, unchanged. The pairs it owns are the table's, and its tests are the evidence.
- **1107d A2+C** (`c08a161`) — A1/A2 true: both messages validate and round-trip (`view_test` "the player, their number and the seconds left round-trip…", "0 s left is allowed", "a bad player, number or seconds names the field"), are gated on `view` (`player_away_messages_test` "…need the view capability", "a controller without view gets neither"), and an old phone drops them (`view_test:296`, "a message type this app version does not know is dropped, not a protocol error"). Its docs work is finding 1: it could not know s10c's frame.
- **1107e** (`4e3f721`) — claims true: `rounds` and `games` copied (`metrics_test:197`), a paused input is no sample (`session_test:99`); a press made during the beat either, since it is older than the `_resumedAtMs` the resume sets (`game_session.dart:266`). Open: finding 5.
- **s10c** (`9df6884`) — claims true for a TV host (`ready_beat_test:155`) and a phone host with a viewer already attached (`:77`, `:116`); findings 2 and 3 are the halves it did not reach.
- **1107b** (`9b1c2a3`) — no file in this area (party_host, controller_app); not reviewed here.
- A4: each commit stays inside its brief's `allow:` (`git show --stat`). A5: none overstepped; A2+C rewrote `away_slots.dart` (135 lines) inside its allow, which is where `s` and `sendTo` live.

## B. Part B over the diff

- **B1 lifecycle:** the slot is one explicit state with one owner (`AwaySlots`), held only while `_roundRunning`; the
  round's phase has one owner (`Pausable`); no finding beyond the table's gaps.
- **B2 time:** findings 7 and 10.
- **B3 authority:** the host decides, phones only draw; `_sendView` re-sends view, panel, frame and away but not
  `host_away` (finding 9), and the beat frame can be missing (finding 3).
- **B4 input:** unchanged; away players are out of Start's reach and an away phone gets no menu
  (`pause_menu_test:162`); the drop releases the pad with the round's pause.
- **B5 snapshots:** `frame_view:134` breaks on the new types and draws frames only; the beat frame lacks a roster
  (finding 2).
- **B6 per-frame:** nothing added per frame; `noteRoster` runs on roster changes.
- **B7 compatibility:** both messages are behind `view`, an old peer drops them and plays on with no card; `n: -1` is
  not behind a capability, but an old viewer reads -1 → 0 as no gap (`viewer_stats.dart:115`) and draws it — the right
  trade, undocumented (finding 1); a new phone on an old host is untested and only lacks the messages.
- **B8 text:** "P2 is away", "The game goes on if they're back in 20 s", "The game goes on without them…", "Go on
  without them", "End round" — short and plain, and the message carries the number, not the name. No finding.

## A3. The combination table (the states this diff touches)

| pair | tested by, or what happens |
| --- | --- |
| player away × menu | tested: `pause_menu_test:152` Start opens nothing; a menu cannot open during the beat (`ready_beat_test:97`) |
| player away × host away | tested: `pause_menu_test:179`, and `:279` for the phase |
| player away × beat | tested: `ready_beat_test:116` — the beat waits and starts again from 3 |
| player away × results | tested: `away_card_test:84` |
| player away × End round | tested: `away_card_test:73` — the picker, `quit` |
| player away × round end | tested: `player_away_messages_test:193`, `player_away_test:163` — no `player_back` |
| player away × grace out | tested: `player_away_test:67`, `player_away_messages_test:163` |
| player away × goOnWithout | tested: `player_away_test:82`, `player_away_messages_test:179` |
| player away × back in the grace | tested: `player_away_test:111`/`:127`, `player_away_messages_test:132` — no self `player_back` |
| player away × viewer pairs mid-away | tested: `player_away_messages_test:101` — view_start, the frame, then player_away |
| player away × another phone joins | tested: `player_away_test:51` — the number is kept |
| player away × simulated drop, no round | tested: `player_away_test:148`, `:179` |
| player away × host app hidden, past the abandon | **not tested**: the slots end silently with the view (right); but a hide whose round comes back also runs the wall-clock grace, so the player may already be gone (finding 7) |
| beat × host away or a menu | tested: `ready_beat_test:116`'s `_stopped` branch (restart from 3); a menu cannot open during it (`:97`) |
| beat × viewer pairs mid-beat | **not tested**: nothing is sent; the phone stays blank to the beat's end (finding 3) |
| beat × results | **not tested**, nothing to happen: no session runs there and the phase clears to `none` |
| one phone dropping twice in a round | **not tested**: the id stays in `players` with no slot, so `_hold` runs again with a fresh 30 s and `n` — plausible, unproven |
| a joined phone drawing the beat frame | **not tested** on the phone (only that the host published it, `ready_beat_test:77`) |

## Not checked

- party_host, puzzle_game, test_game, controller_app and the apps: the other areas' passes; 1107b's addresses live there in full (`network_addresses.dart` is outside this area's files).
- Device runs, real pairing and hardware timings; everything here is from the code, the tests and the range's diff. The other two passes' findings are not deduped against.

## Values, and what I am unsure about

`tools/review.sh --base 526a6fc`: 0 FAIL, 37 NOTE · `tools/check.sh protocol connection metrics`: PASS (107 / 295 / 89 tests) · `tools/check.sh kit`: PASS (36 tests). Files changed: this report only. `git status` also shows `tv_test_app/windows/flutter/generated_*` as modified: line endings only (`git diff --ignore-cr-at-eol` is empty), rewritten by `flutter pub get` inside the check tools — not an edit, and not mine to revert.

1. Is the beat frame meant to carry the roster (and the acks)? It decides whether a joined phone shows its counters through the beat (finding 2).
2. Should a viewer that pairs after the round is held get the beat frame, or is a blank 3 s intended? (finding 3)
3. Whose clock owns the away grace while the round stands still — the slot's or the round's? (finding 7)
4. Is the beat frame a wire change the doc must name (§8, finding 1), or does it sit outside the doc's "one frame per step"? I marked it must because a reader of the doc can neither produce nor expect it; say if you see it otherwise.

## Commit message

docs(m12): build 4 review R1 of the wire, with its findings

Review pass R1 over `git diff 526a6fc 9df6884` for protocol, connection, game_kit and metrics: the
five jobs of the area checked against their claims, B1–B8 over the diff, and the A3 pairs.

One must: the beat's `n: -1` frame is not in docs/protocol.md. Five should (no roster in that frame,
no frame for a viewer that pairs during the beat, the field's own doc, the ratings alias, two files
at their size limit) and four later (the grace's wall clock, `s` in three places, `host_away` not
re-sent, the phone's late and touch counts). review.sh: 0 FAIL. No code changed.

## Status row

- **Build 4 review R1 (protocol · connection · game_kit · metrics):** done — the away slot, its messages, the beat and
  the summaries hold for every pair tested; open: 1 must (the protocol doc), 5 should, 4 later, 6 untested pairs.

## Delete

- none
