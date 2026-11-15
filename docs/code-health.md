# Code health

Every known code change that isn't a feature: review findings and tech debt, grouped by where the code lives, so the work happens when that code is next changed. Started Nov 7, 2026 from the build 4 review ([R1](briefs/m12/build4-review-r1-report.md), [R2](briefs/m12/build4-review-r2-report.md), [R3](briefs/m12/build4-review-r3-report.md)) and the M12 tech debt in STATUS. The owner: "group them accordingly so they can be tackled when that portion of code needs to be modified again … weigh in risks and benefits."

**How it's used**
- A brief that touches an area reads its section, and takes the items marked *when touched* that fit the job (the job template says so). Done items move to the log at the end with their commit.
- *Now* items block the next build. *Before <milestone>* items are done before that milestone starts, because they'd cost much more after it.
- Risk is what a change could break and how well tests guard it; benefit is what it saves. Recommendation: **do**, **when touched**, or **leave**.

## Now: before build 4 (owner's yes pending)

| # | Area | What | Risk of the change | Benefit | Rec. |
| --- | --- | --- | --- | --- | --- |
| N1 | party_host, away card | B on any phone while the away card is up quits the round (the card hands B to the menus, and B pops the round's route). Every drop makes it reachable; it lands one step short of the picker. (R2 must) | Low: the card's controls only; a test presses B | A stray press can't end everyone's round | **do** |
| N2 | controller_app, waiting card | A `host_away` whose `host_back` was missed is never cleared: after a host lock, a link drop and the round ending, the phone says "The host has left" for good over a working link. (R3 must) | Low: clear the host's wait when the link is back; one provider, tested | No stuck card after a host lock | **do** |
| N3 | puzzle_game, mirror | Their dot draws 0.8 mm across, under the mirror's own 2.2 mm floor; it's what the owner asked to see. (R3 must) | Low: drawing only; a size test | The mirror does its job | **do** |
| N4 | puzzle_game, mirror | The mirror's bottom corner sits under the left stick in stick mode, dimmed by it. (R3 must) | Medium-low: the mirror's place changes; camera tests at 3 phone sizes | Nothing under the thumbs | **do** |
| N5 | party_host + connection | The host phone's own player can be held as "away" when its in-process link drops (it does, on every return from a lock): "P1 is away" flashes, the round pauses, other phones get `player_away` for the host. (R2 should, raised: the host log shows this drop after each lock) | Low-medium: the own player never gets a slot; tests for both host kinds | No false pause after the host locks | **do** |
| N6 | game_kit + protocol doc | The "Get ready" frame (`n: -1`): not in protocol.md, has no player list (a joined Arena shows no counters for 3 s), and isn't sent when no viewer is attached yet (a phone joining during the beat sees nothing). (R1 must + 2 should) | Low: one frame's fields and a doc row; tests on both | The beat looks right on every phone; the wire is documented before testers have it | **do** |
| N7 | metrics | `ratings` still shared with the live list (the aliasing 1107e fixed for rounds). (R1 should) | Very low | Saved summaries don't drift | **do** |
| N8 | controller_app, gyro | Tilt mode keeps sending on the host phone outside a round (start-up and resume ignore the phase). (R3 should) | Low: one gate, tested | Sensors off on the menus; the rule the pad follows | **do** |
| N9 | the TV app, storage | Triaged ([report](briefs/m12/fix-n9-triage-report.md)): **no crash**. Nothing is saved at a disconnect, the session write already catches and logs, and "Lost connection to device" was smoke stopping the app after the step failed. The storage holes it found are below (party_host, "Host writes"). | — | — | **closed** |

## When touched, by area

### connection
| What | Risk | Benefit | Rec. |
| --- | --- | --- | --- |
| **Smoke's `disconnect` step on the owner's PC:** the TV log had `Session of Smoke controller ended after 11 s` **twice** and no `Smoke controller disconnected` line, which `onClosed` always writes (`host_connection.dart:118`). So the session ended by another path, or the log lost lines. The phones' own logs on Nov 7 show the line as usual. Triage before relying on that step. | None (a triage) | Know whether a host-side close path is wrong | when touched: `host_connection.dart`, or run smoke once from the owner's terminal |
| `host_connection.dart` is 398 of 400 lines, `client_messages.dart` `onData` 58 of 40: the next message means a split first. (R1) | Low (a move), but in the busiest code | The next protocol change stays readable | when touched: before the next message |
| The away grace is a wall-clock timer: it runs while the round stands still (a menu, the app hidden). (R1 later) | Medium: two clocks to reconcile | Fair grace when the host pauses too | when touched: pause or away code |
| `_sendView` re-sends everything to a re-pairing viewer except `host_away`. (R1 later) | Low | A late viewer sees the right card | when touched |

### game_kit, metrics
| What | Risk | Benefit | Rec. |
| --- | --- | --- | --- |
| The phone's viewer stats count the beat's 3 s as a late draw and a press during it as a 3 s touch-to-frame. (R1 later) | Low | Clean phone numbers in the report | when touched; before the M13 report at the latest |
| `game_session.dart` 319, `session.dart` 309 lines (aim 300). | Low | — | when touched |

### party_host
| What | Risk | Benefit | Rec. |
| --- | --- | --- | --- |
| **Host writes:** only the session file catches and logs a failure. Uncaught: the sessions folder listing (`session_store.dart:46-47`, so a broken folder can throw into `_refreshCounts`), export's create/copy, the unawaited preferences saves (host id, pairings, consent, puzzle settings), and `uploadNow`'s try with no catch; two reads drop errors silently (`saved_pairings.dart:18`, `providers.dart:317`). One storage boundary with narrow catches, one log line, plain-words snackbars for the adult's buttons. ([N9 Q2, Q3](briefs/m12/fix-n9-triage-report.md)) | Medium: a wider catch could hide real bugs; keep it to IO; injects a `SessionStore` | A host on a full or locked disk keeps playing and says why | when touched: stats or storage; **before M13** (best times are saved) |
| The beat counts 16 ms ticks, not the host's clock (3008 ms; a stall stretches it). (R2 should) | Low | An exact beat; the same clock as the rest | when touched: `Pausable` |
| The away log lines remember numbers forever, so a reused number logs wrong. (R2 should) | Very low | Correct logs | when touched |
| Sizes: `server_game_host.dart` 399 (split before it grows: the away slots' wiring could go with `away_slots.dart`), `pause_menu.dart` 385, `host_fakes.dart` 382, `join_screen.dart` 363, `providers.dart` 389 (the next host provider wants its own file), `host_service.dart` 361; `games_screen.dart` holds two screens (picker, level list). (1107f Q5) | Low | Room for M13's round moments | when touched; `pause_menu` and `providers` before M13 |
| `GameField` takes 9 constructor parameters (`game`, `playing`, `debug`, `hosting`, `keyboard`, `roundTags`, `onEvent`, `onClock`, `onFinished`; `game_field.dart:18-29`), where a parameter object is due past 5. | Low: the round's wiring, a test at the call site | A new field joins one object | when touched: a parameter object |
| The local-pad filter is written in two places, in opposite senses: `arena_waiting_card.dart:142` reads only local pads, `controller_menus.dart:155` addresses only phones (the same split in `pause_menu.dart:313`, `pause_menu_widgets.dart:18`). | Low: which pad each screen reads | One rule for local against a phone's pad | when touched: one shared helper |

### puzzle_game
| What | Risk | Benefit | Rec. |
| --- | --- | --- | --- |
| Long functions: `_computeScreen` 120, `packTray` 104, `game.dart` `update()` 103 lines. (M12 debt) | Medium: layout and rules, but well tested | Easier chaos events and new modes | when touched |
| A carried full-size piece can be clipped at the world's top. (M12 debt) | Low | Looks right | when touched: the camera |
| `_puzzleLoad` reads the files a second time, with no seam. (M12 debt) | Low | Faster start, testable | when touched: the library |
| `match_painter.dart` 332 lines. | Low | — | when touched |

### controller_app
| What | Risk | Benefit | Rec. |
| --- | --- | --- | --- |
| `gyro.dart` 353 lines; `DiagnosticsScreen.build` long. (M12 debt) | Low | — | when touched |
| `PhoneHost.dispose()` doesn't wait for a `start()` in flight: stopping within ms of hosting leaves the service's 10 s timer behind (tests wait on `host.started` instead). Make `dispose` await the start, then drop `started`. ([1108a Q3](briefs/m12/bug-1108a-fix-report.md)) | Low: the host's lifecycle, well tested | No leaked timer on a fast stop | when touched: `phone_host.dart` (likely the 1108b freeze fix) |

### tools and housekeeping
| What | Risk | Benefit | Rec. |
| --- | --- | --- | --- |
| The advertising log line still tags `[tv]` on a phone host. | None | Clear logs | when touched |
| `tv_test_app/flutter_*.log` crash files pile up (git-ignored); a leftover job folder `E:\AI\game-controller-m12-jobs\flash-20261107-090106-3357`; one stray `E:\game-controller-m12-jobs`. | None | Tidy disk | leave until a cleanup |
| The PRD M12 acceptance tests aren't copied into the checklist. | None | One list for the owner | before M12 closes |

### M14 bugs1

The "could" findings of [bugs1's review](briefs/m14/bugs1/REVIEW.md) that the fix batch left, one line each; its must and should findings are fixed, and the `cat_paint_test` rename and `PuzzleView` drawing its frame's cat were done there.

| What | Risk | Benefit | Rec. |
| --- | --- | --- | --- |
| `cat_head.dart:49` draws the pupil at the full gaze, 0.2 units out of the eye. | None | A round pupil | when touched |
| `bugs1/c1-big-cat-report.md:16` says 7 files changed in `lib` where 11 did, and misses `cat_view.dart`. | None | A true record | when next read |
| `puzzle_twins_test.dart:245` changes only the right wing's colour, so it passes whether the mirror marks look-alike targets only or all. | Low: the look-alike hint | A test that could fail | when touched |
| `twins_library_test.dart:67` calls every pair in a twin group a direct twin, though groups are chains of turns. | Low | A test that matches decision 3 | when touched |
| `twins_library_test.dart:34`'s second reading borrows the rule's own thresholds, so a wrong one is not caught. | Low | A real second opinion | when touched |
| `twins_library_test.dart:76` asserts two facts that cannot fail (`rotation` null, `containsAll`). | None | Fewer hollow lines | when touched |
| `mirror_painter.dart:134` draws a look-alike's target at 0.5/0.18 alpha; check the two wings read apart in Night on a device. | Low | A verified decision 5 | when a device is free |
| `arena_waiting_card.dart:22`'s doc still promises "Press A when you're ready" and "a ✓ once they are ready". | None | A doc that matches the card | when touched |
| `arena_touch_ready_test.dart:82` taps Ready with one player joined and passes only because no time advances between taps. | Low | A test that cannot hang on a tick | when touched |
| `arena_waiting_widgets.dart:59`'s `maxLines: 1` and ellipsis were an unlisted display change. | None | A listed change | when touched |
| `arena_text.dart:27`'s `readyButton` and `readyLabel` are both "Ready", so they can drift. | None | One word | when touched |
| `bugs1/t1-look-midgame-report.md:54` lists `round_palette_hold.dart` under Delete, though the commit deletes it from the tree. | None | Correct steps | when next read |
| `look_midgame_test.dart:84` checks no clock or coins survive the look change in the Bumper Round. | Low | The brief's promise proven | when touched |
| `look_midgame_test.dart:35` checks the painter's palette, not a colour drawn. | Low | The look shown, not handed | when touched |
| `round_palette_test.dart:17` ends while the view still runs, so no palette check follows a joined game's end. | Low: the palette | A closed loop | when touched |
| `arena_hud_coins_test.dart:124` draws four players only in the one-line bar, never the tall bar's second line. | Low | The case the brief names | when touched |
| Sizes: `match_painter.dart` 377, `lobby_music.dart` 348, `arena_waiting_widgets.dart` 343, `view.dart` 330, `puzzle_painter.dart` 326, `arena_waiting_card.dart` 324. | Low | Room under the 380 stop | split `match_painter` at the HUD seam; others when touched |

### M14 bugs6 leftovers (run review of Nov 14, 2026)

- **puzzle_game (mirror)**: the redone Medium car (9 pieces) has no opponent mirror on an iPhone-sized phone with the D-pad, though it has one with no pad. Risk: low (rule 7 allows "absent"). Rec.: a device look at Medium car on a D-pad phone; if it matters, give the mirror a smaller scale for big boards.
- **controller_app vs puzzle_game tablet_board_test**: the small iPad boat is pinned at 8.930715 / left 238.081 in `controller_app` and 8.930159 / 238.103 in `puzzle_game` for the same board and box. Risk: low. Rec.: find why before either is re-pinned.
- **party_host (screens)**: `game_screen.dart` 379/380 and `puzzle_screen.dart` 380/380 lines; `_Results` takes nine parameters (guidelines allow five). Rec.: split each along its waiting/pick seam and fold the results card's menu options into one value object as the next change to either.
- **puzzle_game (carry)**: `_isPlacing` scans every piece per carrier per step; Fixed, unverified: needs device check of the frame budget. Rec.: reuse one buffer and skip filled pieces.
- **party_host (settings)**: `reset()` drops a device test's `CAT_PRESET` define; wrap the reset value too. Risk: debug-only.
- **party_host (solo skip)**: while the map library loads, a night's solo Bumper start draws an empty box (no title or Back) for a few frames. Rec.: a one-line "starting" placeholder.
- **party_host tests**: `controller_menus_test.dart:143` uses a bare 24 press count; name it or count the buttons.
- **puzzle_game (messages)**: Medium's big-piece message reads `Mark 1 or 2 pieces "big".`; restore "one or two" if the wording matters.
- **metrics**: the recorder's `player_result` path (moving/placing seconds) has no party_host test; add one before the next metrics change.
- **puzzle_game (tray packing)**: the tray-packing test's visible-share floor is 0.50 (raised from 0.45 in b012c) because the lowest piece is now the lighthouse's `tower top`, 0.518 in the narrowest made-up tray (seed 0, flat, width 19); every piece of the redone dragon, tower and tractor sits above it. Risk: a Hard piece partly hidden in a very narrow tray. Rec.: a device look at the three redone Hard pictures on the smallest phone — their tray is unmeasured on a device — or reshape a piece that reaches the floor; the Medium butterfly also loses its mirror on the 852 px phone (pinned in mirror_pad_test).
- **party_host (best times)**: the old Medium best times were cleared once by `bestTimesVersion` 1 (B-012; Fixed, unverified: needs device check on a real host). Debt: `redoneMediumPuzzleIds` is six puzzle ids as literals in `party_host` (guideline �2), pinned by a test against the library's Medium puzzles; a later redo extends the list and bumps the version. Rec.: read a `redrawn` field from the puzzle data. The Hard dragon, tower and tractor times were not cleared (the owner said Medium only): owner decision, tracker B-012. Also `packTray` stays 104 lines (above) and `split_layout.dart` is 389 lines (split with its next change).
- **puzzle_pick.dart (Back during load)**: `_picked` has no `mounted` check after `await puzzleLibraryProvider.future`, so pressing Back while the library loads can throw. Rec.: `if (!mounted) return;` after the await, with a test.
- **game_screen.dart (late-joining phone)**: `_alone` is `late final`, so a phone joining a night's Arena mid-solo is not offered the waiting card; the Arena has no comment recording this. Rec.: decide whether a late phone should get the card (make `_alone` live) or add the comment.

## Before a milestone

| Before | What | Risk | Benefit of doing it first | Rec. |
| --- | --- | --- | --- | --- |
| **M13** (countdown, celebration, last-15-s warning) | A round's moments and log lines live in the puzzle's screen; the Arena logs no start or end. Move them to the shared round flow (`GameSession`/`Pausable`). (R2 later) | Medium: both games' screens | M13's moments are written once for every game | **do** before M13 |
| **M13** | "Seconds left" is computed three times from three clocks (the slot, the host card, the phone card). One countdown rule. (R1 later) | Low-medium | The last-15-s warning has one source | **do** before M13 |
| **Look-and-sound** | Colours and card text as literals: the mirror's orange copies `playerColors[1]`; the cards' opacities; "P2 is away" vs "Player 2 is away" already differ. One palette and one string table. (R3 + R2 later) | Low | A re-skin changes one place | **do** at its start |

## Done
- (none yet)
