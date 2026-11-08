# m12 build 4 review R3 — the phone (controller_app) and the puzzle's mirror

Range: `git diff 526a6fc HEAD -- controller_app packages/puzzle_game`, 31 files, +1920/−287 (code ends 9df6884). Read: review-rules A–D, coding-guidelines, the build 4 briefs and reports, m12-host-touch, m12-opponent-mirror, m12-joined-view §0.3, protocol.md (§4, §10a), and the tests of every file in the range.
`tools/review.sh --base 526a6fc`: **0 FAIL**, 37 note (sizes: gyro 353, host_connection 398, host_server 385, server_game_host 375, game_session 319, session 309, host_service 361, providers 328, host_fakes 382, join_screen 349, pause_menu 381, match_painter 332; numbers: host_chip:94, waiting_card:80/84/114/144, away_card, join_screen_widgets, ready_card, piece_size:29, client_messages:34). Nothing to copy.
`tools/check.sh format analyze phone puzzle`: format PASS (3 s), analyze PASS (10 s), puzzle PASS (118 tests), phone PASS (348 tests), 134 s.

## A. Self-check, per job (no build 4 report has one; these answers are mine)

- bug-1107b (Wi-Fi address, host_chip) — A1: the host phone's chip alone; the TV and joined phones draw no chip, not affected; `host_chip_test`'s two tests. A2: the list is the host state's, nothing held. A3: no state.
- bug-1107c (a joined phone can leave; the card) — A1: a joined phone (card, dot, compact bar); a host phone gets no view messages, so no card. A2: false at the `_away` end, see finding 1. A3: the table.
- bug-1107d a2c (phones learn a player is away) — A1: joined phones; the phone that was away is skipped (view.dart:130). A2: ends on player_back, view_start, view_end, idle, or the first frame past `s` (view.dart:140). A3: the table.
- bug-1107d g1-plan, a1, b — no file in this range, not this area; their phone-visible half is a2c's, checked above.
- bug-1107e (back on the results) — A1: the phone host only; a TV/PC host has its own route. Tested by host_mode_test's two back tests. A2, A3: a stateless route action.
- s10a (phase, pad only in a round, the bar) — A1: the host phone only (`_Controls` gates on `hosting`); joined phones and "Show on this device" unchanged (joined_view_test). A2: the phase starts at claim, ends post-frame at release; the gyro end is finding 4. A3: the table.
- s10b (own player joins itself, no pad on the join screen) — A1: the phone host only. A2: the own player joins with the join screen and goes with the host. A3: phase `none` × the join screen, table.
- s10c (the Get ready beat) — A1: the phone host only (host_overrides.dart:32), the TV asks none. A2: the beat restarts while something waits and ends at the results. A3: table.
- s11 (the mirror) — A1: phones in a race, hosting and joined; absent solo, team, tablet, TV (`mirror_test`). A2: drawing only, no state. A3: the mirror and the pad together are not tested (finding 3).

## B. Findings

**must** · `controller_app/lib/src/providers/view.dart:127` (and `:156`) · B3, A2 · a `host_away` whose `host_back` is missed is never cleared: `HostBack` is the only end for `_away` short of a `view_start`, a `view_end` or idle, and the reconnect branch clears only `_dropped`. Host hides its app mid-round (the iOS case §0.3 names), so `host_away` goes out; the phone's link drops; the host comes back and the round ends before the phone re-pairs (its `host_back` went nowhere, and a phone that pairs after `view_end` is sent nothing). The phone reconnects: nothing clears `_away`, so the countdown runs to 0 and the card says "The host has left" for good, with the last frame still drawn under it (`showsGameProvider`), over a link that is up. Only Leave game or the dot gets out. Not tested: no test puts `hostAway` and a drop together, or reconnects with `_away` set.

**must** · `packages/puzzle_game/lib/src/mirror_painter.dart:111` · B5, owner rule 2 · their dot is drawn at `PuzzleGame.dotRadius` (2.6 world units) on the mirror's scale: 2.59 px radius, 5.2 px across, 0.82 mm at 852×393, and 2.5 px, 0.79 mm at 667×375 — under the 2.2 mm the same change calls the smallest that reads (`mirrorMinPieceMm`, piece_size.dart:29, kept by `mirrorFraction`) and a quarter of the 20 px their own board draws it at. The 1 px white ring is 2 of the 5 px. The one thing the owner asked for ("see where their player is") is a mark at a third of the mirror's own floor. `mirror_test.dart:256` asserts one pixel's colour and that 10 units away is board, so it would pass at any radius down to a dot.

**must** · `packages/puzzle_game/lib/src/camera.dart:181` · owner rule 5 ("clear of the stick") · the mirror's rect starts at 0.14 x box height: y 55.02–125.82 on 852×393. In stick mode the left stick is `stickLayout(Size(852, 341))` → Rect(16, 56, 163, 163) in the body, i.e. circle centre (97.5, 189.5), r 81.5, top at y 108 on screen: the mirror's bottom-right corner (x 46.6–77.8 along its bottom row, y 110.4–125.8 along its right edge) is inside that disc, which is painted and then dimmed to `ControlsSettings.defaultOpacity` 0.6, so the mini board's corner is dimmed by default and gone at 1.0. Same at 667×375 (mirror bottom 120.1, stick top 108). Nothing tests the pad and the mirror in one box.

**should** · `controller_app/lib/src/ui/controller_screen.dart:122` (and `:78`) · B4, m12-host-touch rules 1–2 · the pad is gated by the phase, gyro mode only by a phase change: `restoreMode()` starts gyro on launch whatever the phase is and `didChangeAppLifecycleState`'s `resumed` resumes it unconditionally, so on the host phone a tilt streams into the host game on the picker, through the pause menu and on the results, and the sensors run there (coming back to the app undoes `_notePhase`'s pause). No visible harm today (the menus are touch-only and the game ignores input outside a round); it is the rule the pad gating exists for. Not tested: host_mode_test and host_lifecycle_test never combine gyro mode with a phase.

**later** · `packages/puzzle_game/lib/src/view.dart:94` · C row 1 (look and sound) · `_them = 0xFFFFA040` copies `playerColors[1]` (protocol/messages.dart:319) instead of referring to it: a palette change in the look milestone leaves the mirror's frame, dot and "Them n/N" on the old orange while Player 2's badge moves, and nothing ties the two. Costs one reference now, a hunt later.

## Combination table (A3, the states this range touches)

| pair | tested by / not tested, and what happens |
| --- | --- |
| hostAway × playerAway | "the host's own wait wins over a player's, and the player comes back after it" — the host's lines replace the players', which return after `host_back` |
| hostAway × dropped link | not tested — `_away` wins over `_dropped` (view.dart:181); the reconnect's `view_start` clears it while the round runs, finding 1 when it doesn't |
| hostAway × view_end | not tested — `_away` clears (view.dart:148), the same path as idle |
| hostAway × idle (Stop, Leave game) | "an idle client ends the view and the wait: Stop and Leave game both work over a game" |
| hostAway × the app hidden | not tested — no card is drawn, and the countdown is read from `nowMs` at the next build, so it comes back where the clock says |
| dropped × reconnect with a `view_start` | "a link that comes back with a view_start keeps the round on screen" |
| dropped × reconnect with no view | "a link that comes back without a view_start leaves the finished round off the screen" |
| dropped × grace out, then reconnect | "a host that comes back after the grace takes the card away" |
| dropped × playerAway | "a drop hides the line, and the view coming back with player_away puts it up again" — the drop clears the player lines |
| playerAway × playerBack, × two at once, × own id, × the frame after `s` | "it says which player is away…", "two away at once get a line each…", "the phone that was away itself shows no card for its own player", "a countdown that runs out says the game goes on without them, until the next frame" |
| playerAway × Leave game | not tested (present, never tapped under a player's wait); code: the same `_leave`, `disconnect()` then the Connect screen |
| the card × the pad under it | not tested; `WaitingCard` is a `Center`, whose `Align` takes no hits outside the Card, so the pad under it still sends (§0.5) |
| phase ready, playing, none × pad, full or compact bar, back at the picker | "a round starts with a 3 s Get ready beat…", "Start on the pad pauses the round…", "the system back on the results goes to the picker…", "the system back press stops hosting…" |
| phase none × a finger held on the pad | "a pad hidden under a held finger lets go of it with one neutral input"; one frame of window stays between the round ending in a tick and the post-frame publish, in which a new touch still reaches the results (which ignore it; not tested) |
| phase × gyro | not tested — finding 4 |
| the mirror × the pad in one box | not tested — finding 3 |
| the mirror × one board, tablet, TV, a narrow box, the tray row, 2-v-1, "Them" | "no mirror on a one-board match…", "a one-board match, a tablet's whole match and the TV draw no mirror", "placed above the board, their dot is pinned…", "a 2-v-1 draws every dot of the other side", "the count beside the mirror names the other side \"Them\"" |
| the card × the compact bar and the dot button | "a link that comes back with a view_start…" (`connectionButton` present), "the dot is a button to the Connect screen, so a joined game can always be left" |

## C. Built for what comes next

Only the `later` above. The round moments this range touches (the phase, the beat, the away card) sit in `party_host`'s `Pausable` and not in a phone screen, and the mirror's geometry sits in `camera.dart` rather than in the painter, so M13 and the look milestone have one place each to change.

## Not checked

- `party_host`'s own UI beyond what the phone's tests reach (the away card's text, the pause menu's layout, the join screen's tap targets): other areas' R1/R2.
- `connection`, `game_kit` and `metrics` except the paths the phone calls; `FrameView`'s merging and lerp were not re-reviewed.
- Real devices: the mirror's legibility at arm's length (finding 2 is computed, not photographed), the iOS suspended-host and socket-drop paths, and any timing on Wi-Fi. No emulator, device or app was started.
- The mirror's per-frame cost is computed, not measured: `_targets` allocates a `Path` and two `Paint`s per piece (5 per puzzle here), `_placed` up to 5 more, so one extra board-sized pass per frame at up to 60 Hz — B6's "bounded" holds and the class says so; no frame-time test exists, before or after this range.
- "A phone or host one build older" (A1) was read from protocol.md §4/§10a and the `view` capability only; no two-build pairing was run.
- `tv_test_app`: nothing in this range changed there, and `check.sh` did not run its tests.

## Commit message

Review build 4 R3: the phone and its mirror, 5 findings

Read the build 3 to build 4 diff of controller_app and puzzle_game against
review-rules A to D and the three owner decisions.
Two rules break: a missed host_back leaves the waiting card up for good, and
the other side's dot is drawn at 0.82 mm in the mirror.
Three smaller: the mirror's corner sits under the stick, gyro runs outside a
host phone's round, and the mirror's orange copies the protocol palette.
review.sh: 0 fail, 37 note. check.sh: format, analyze, 118 + 348 tests pass.

## Status row

- R3 review of build 4's phone area: done, 5 findings (3 must: a missed `host_back` leaves the waiting card up, the mirror's dot at 0.82 mm, the mirror under the stick; 1 should: gyro outside a round; 1 later: the mirror's palette copy); open: the three musts, and a decision on the should.

## Delete

- none
