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
| **Host writes:** only the session file catches and logs a failure. Uncaught: the sessions folder listing (`session_store.dart:46-47`, so a broken folder can throw into `_refreshCounts`), export's create/copy, the unawaited preferences saves (pairings, consent, puzzle settings; the host id write retries and reports, `host_id.dart`), and `uploadNow`'s try with no catch; two reads drop errors silently (`saved_pairings.dart:18`, `providers.dart:317`). One storage boundary with narrow catches, one log line, plain-words snackbars for the adult's buttons. ([N9 Q2, Q3](briefs/m12/fix-n9-triage-report.md)) | Medium: a wider catch could hide real bugs; keep it to IO; injects a `SessionStore` | A host on a full or locked disk keeps playing and says why | when touched: stats or storage; **before M13** (best times are saved) |
| The beat counts 16 ms ticks, not the host's clock (3008 ms; a stall stretches it). (R2 should) | Low | An exact beat; the same clock as the rest | when touched: `Pausable` |
| The away log lines remember numbers forever, so a reused number logs wrong. (R2 should) | Very low | Correct logs | when touched |
| Sizes: `server_game_host.dart` 399 (split before it grows: the away slots' wiring could go with `away_slots.dart`), `pause_menu.dart` 385, `host_fakes.dart` 382, `join_screen.dart` 363, `providers.dart` 389 (the next host provider wants its own file), `host_service.dart` 359; `games_screen.dart` holds two screens (picker, level list). (1107f Q5) | Low | Room for M13's round moments | when touched; `pause_menu` and `providers` before M13 |
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
- **party_host (screens)**: `game_screen.dart` 373/380 (before bugs11's next change) and `puzzle_screen.dart` 380/380 lines; `_Results` takes nine parameters (guidelines allow five). Rec.: split each along its waiting/pick seam and fold the results card's menu options into one value object as the next change to either.
- **puzzle_game (carry)**: `_isPlacing` scans every piece per carrier per step; Fixed, unverified: needs device check of the frame budget. Rec.: reuse one buffer and skip filled pieces.
- **party_host (settings)**: `reset()` drops a device test's `CAT_PRESET` define; wrap the reset value too. Risk: debug-only.
- **party_host tests**: `controller_menus_test.dart:143` uses a bare 24 press count; name it or count the buttons.
- **puzzle_game (messages)**: Medium's big-piece message reads `Mark 1 or 2 pieces "big".`; restore "one or two" if the wording matters.
- **metrics**: the recorder's `player_result` path (moving/placing seconds) has no party_host test; add one before the next metrics change.
- **puzzle_game (tray packing)**: the tray-packing test's visible-share floor is 0.50 (raised from 0.45 in b012c) because the lowest piece is now the lighthouse's `tower top`, 0.518 in the narrowest made-up tray (seed 0, flat, width 19); every piece of the redone dragon, tower and tractor sits above it. Risk: a Hard piece partly hidden in a very narrow tray. Rec.: a device look at the three redone Hard pictures on the smallest phone — their tray is unmeasured on a device — or reshape a piece that reaches the floor; the Medium butterfly also loses its mirror on the 852 px phone (pinned in mirror_pad_test).
- **party_host (best times)**: the old Medium best times were cleared once by `bestTimesVersion` 1 (B-012; Fixed, unverified: needs device check on a real host). Debt: `redoneMediumPuzzleIds` is six puzzle ids as literals in `party_host` (guideline §2), pinned by a test against the library's Medium puzzles; a later redo extends the list and bumps the version. Rec.: read a `redrawn` field from the puzzle data. The Hard dragon, tower and tractor times were not cleared (the owner said Medium only): owner decision, tracker B-012. Also `packTray` stays 104 lines (above) and `split_layout.dart` is 389 lines (split with its next change).
- **puzzle_pick.dart (Back during load)**: `_picked` has no `mounted` check after `await puzzleLibraryProvider.future`, so pressing Back while the library loads can throw. Rec.: `if (!mounted) return;` after the await, with a test.

- **toy_look ListTile colour (B-017)**: `toy_theme.dart:41` gives every ListTile `colors.onBackground` (white at night), so a tile on paper is only ink where something puts it back: `ToyCard` and `controller_app/lib/src/ui/paper_tiles.dart` (two copies of the rule). Rec.: make `toyTheme` take `colors.ink` only for tiles on paper (the TV app too), then delete `paperTileTheme` and ToyCard's copy in the same job.
- **Contrast helper twice**: the WCAG ratio maths sits in `packages/toy_look/test/contrast_test.dart` and `controller_app/test/stick_text_contrast_test.dart`. Rec.: one helper in `toy_look`'s testing library.
- **Tests rewrite tracked pictures**: a full suite run rewrites `docs/design/maps/*.png` (map_render_test) and `site/shots/*.png` (site_shots.dart). Rec.: write them to a temp dir unless a flag is set. Also the PNG tests in `packages/puzzle_game/test/*_png_test.dart` (m13 sheets, puzzles) rewrite `docs/design/**`; the runner now drops that churn on a result-4 stop (Nov 15), but the source fix is the same flag.

- **B-019 review leftovers (bugs10, Nov 15)**: (1) `packages/party_host/lib/src/live_stats.dart` is 380 lines (the brief cap, over the ~300 aim); split the upload queue and the ping sampling out at the next stats job. (2) `StatsService.pause()`/`resume()` end and save a session, which the names do not say; rename (`endForBackground`/`resumeForForeground`) at the next stats job. (3) `live_stats_lifecycle_test.dart` (TV case) and `live_stats_test.dart` wait on real time (`sessionGap` is a real `Timer`); drive them with `fake_async` when the timers are injectable. (4) The runner's `run-base` for a multi-job run is the last job's own commit when a run is restarted after a hand-fix; the later reviews then see only the second job's diff. Rec.: write `run-base` once at the first start. (5) The runner skips tests-first proof and the worker review of a job hand-committed after a stop, and a review job's `site/shots` churn is not dropped (result 4, report not applied). Rec.: fix in `tools/run-jobs.sh`.

### M14 bugs11 leftovers (run review of Nov 15, 2026)

- **solo_arena_card_test (the map played)**: "opens on Surprise me" (`solo_arena_card_test.dart:52`) is proved only by the absent `chosenMap-pinball` key, not by the map the round played. Rec.: also assert `arenaSnapshot(tester).mapId` is not `pinball` after `roundStarted`.
- **solo_arena_card_test (the helper)**: `openNightBumperCard` (`solo_arena_card_test.dart:17`) serves test 2 only and repeats the setup of test 1. Rec.: parameterise it with the `setMap` case or inline it into test 2.
- **night_start_screen (the comment)**: `night_start_screen.dart:74` says "for two" where the Shape Race join screen shows for two or more. Rec.: say "for two or more".
- **next-map proposal (a report only, not built)**: for the follow-up brief of `b020-next-map-report.md`, carry the sizes 373 / 381 / 370 (not 379 / 387 / 376); the Right press at `menu_press_test.dart:61-64` moves off Change mode when the button goes second; a step for `docs/design/party-night.md:107` (the button line of the results); how the callbacks of `_ResultsBody` are carried (it has nine parameters, the proposal adds the tenth) and that the `Wrap` at `:68` belongs to `_ResultsBody`; and that the base of `game_screen.dart` in the run report was 379, not 380.
- **B-021 review leftovers (bugs11, Nov 15)**: (1) `_ResultsBody.build` in `arena_results.dart` is 67 lines (guideline ~60); extract the night's Next/End night row and the plain three-button wrap into two widgets at the next results change. (2) `debugKeys` in `game_debug_overlay.dart:12` is a public top-level set exported by `party_host.dart`; hang it on `GameDebugOverlay`. (3) `end_night_arena_test.dart:66` asserts `5 + points` where the played round's points were 0 (Robo took the coins), so it cannot fail on lost points; end the night on a card with known non-zero points. (4) `end_night_arena_test.dart:90` and `end_night_puzzle_test.dart:100` run the phone-host case at 960x540 where `shareView` changes no layout; use a phone surface (852x393). (5) No focus pins: Next keeps the first focus on the Arena card, and Right from Next reaches End night on Shape Race's card. (6) `_showAfterNight` is copied in `game_screen.dart:281` and `puzzle_screen_results.dart:20`; one helper beside `isGamePickerRoute` in `leave_round.dart`. (7) `arena_touch_solo_night_test.dart` now loads fonts from `../toy_look` so it fails when run from the repo root (as `arena_touch_ready_test.dart` already does); make `toy_fonts.dart` find the package root; its comment says "measured" though the test measures nothing. (8) `roundsLeft` now answers 0 for a night ended early (pinned by a test in bugs11 wrap-up); no `lib` code reads it. (9) The `site/shots/*.png` churn in the two b021 runs was generated by the check and dropped by the runner, not written by the workers. (10) The solo-card stability fix (`playedMap`) was a real flake (1 in 6): the unseeded `Random` in `game_screen.dart:88` picks the Surprise me map.

### M14 stats1 (metrics report)

| What | Risk | Benefit | Rec. |
| --- | --- | --- | --- |
| `ModeRow._row` (`report.dart:217`) is 57 lines, against the guideline ~40, and each stats column added since lengthens it (a1 review, fix1). | Low: the row builder, covered by the report and CSV tests | A new report column does not grow one function | when touched: the next report column |
| `session.dart` was 340 lines when measured, 364 after stats2 (aim 330 in the b5-1 brief, ~300 in the guidelines, 400 limit): the split left 324 and b5-2's round offset took it back over (run review). | Low: a pure move, covered by the metrics tests | Room for the next metrics addition | when touched: move the round-map block into `roundEnded`'s helper first, as the value object takes the collection with it |
| `SessionCollector.roundEnded` (`session.dart:244`) takes 9 parameters (a2 added `robotWin`; the guidelines allow 5) and its body (`:238-278`) is 41 lines, against ~40. Rec.: a `RoundEnd` value object and the round-map block (`:246-263`) as a private helper (a2 and b5-2 reviews). | Low: the session's record, covered by the stats tests | A new round field does not touch the arguments of every call | when touched: the next round field, as one job before it |
| `session_clean.dart`'s name fits half its contents: it holds `HostType` and `cleanDevice` beside the string cleaning b5-1 moved there. | Low: a rename, no behaviour, `metrics.dart` keeps its exports | A reader knows what the file holds | when touched: rename it `session_format.dart` |
| `cleanDevice` (`session_clean.dart:40-44`) keeps bare `16`, `40` and `2000` for its text and device-size bounds, against the magic-number rule; the move re-added them unchanged. | Low: it only changes what a bad device reports | One place to change a bound | when touched: name them (`maxModelChars`, `maxDeviceMm`) with the reason in the doc |

### M14 bugs12 leftovers (B-023 review of Nov 15, 2026)

- **Host Stats row hint logic**: `_HostStatsStatus` (`settings_sections.dart`) tests `state.consent == null` for the "Tap to choose" hint; the text layer could return a nullable hint (`SettingsText.hostShareHint(StatsState)`). Low risk, when the row is touched next.
- **Host Stats row on error**: `SettingsText.hostShareLine` shows "last try failed" and drops the uploaded/waiting counts, while `HostText.statusLine` keeps them. Kept short on purpose; revisit if the owner wants the counts.
- **Consent test key**: tests spell the prefs key `'statsConsent'` (private in `live_stats.dart`); a `party_test` accessor would keep it in one place. Pre-existing in `host_stats_test`.
- **Host disposed under the prompt (f1 review, 4)**: `HostScreen`'s "host disposed" pop pops the top route, which would be the dialog; pop the host route itself. Needs the host to die while the prompt is up (Stop is behind the dialog), so very unlikely.
- **`joinPhone` helper copied** in `first_host_consent_link_test.dart` and `host_focus_pad_test.dart`: `test/support/host_app.dart` has the one `first_host_consent_input_test.dart` uses; move the other two to it when those files are next edited. The link test also repeats `first_host_consent_test.dart`'s assertions, and joins over a real socket like the focus-pad test (guidelines section 9 allows that only for connection tests): write the exception down there.

### M14 bugs13 leftovers (arena-waiting review of Nov 15, 2026)

- **Arena card split**: `_cardBody` is 56 lines and `_tick` 43 (guidelines: about 40); `arena_waiting_card.dart` (365) and `arena_waiting_widgets.dart` (354) grew for B-013, B-024 and B-025. Split the ready row, roster and maps into their own widgets in the next card job (*before a milestone* that touches the card).
- **Doubled pins**: `arena_row_touch_test.dart` re-pins three paths (Ready button, a joined phone's A, remote OK/Enter on the focused row) that `arena_touch_ready_test.dart`, `arena_phone_card_test.dart` and `arena_waiting_test.dart` already pin; move them back when those files are next edited. The run is not broken by it (the file as a whole fails on the old code).
- **Narrow touch card**: an own player's Ready line beside Back below 852 px wide (the 600 px window) is untested.

### M14 stats2 (build columns)

| What | Risk | Benefit | Rec. |
| --- | --- | --- | --- |
| The "+build" rule lives in three places: `controller_app/lib/src/app_info.dart:19` writes it, `packages/party_host/lib/src/host_identity.dart:69` builds it from a display label, and `packages/metrics/lib/src/session_clean.dart:42` splits it again (run review). | Low: all three cap the build at 9 digits today, so nothing is sent and then silently dropped | One rule for the two writers and the reader | when touched: move one `appWithBuild` into `metrics` and call it from both apps |
| `HostIdentity.appWithBuild` (`host_identity.dart:70`) takes the build from a regex match on `versionLabel`, a display string, so a rewording of the label ("1.2.3 build 45", a TestFlight label) drops the build from the session and no test notices (run review). | Low: today's labels carry "(123)" | The display string can change without losing data | when touched: a `build` field the shell passes; the phone's host identity (`controller_app/lib/src/host/phone_host_setup.dart:31`) is the wiring that comes with it, pending bugs12 |
| `host_service.dart` is 359 lines, back under `m12-report.md` §2's 360 budget after the host id handling moved to `host_id.dart` (sentry1 host-id). | Low: covered by the host tests | Room for the next host change | when touched: split the service before adding to it |

### M14 bugs14 leftovers (B-027 watchdog, B-028 band; reviews of Nov 15, 2026)

- **Watchdog**: a `play()` that throws restarts the whole engine (one bad effect key restarts every 5 s; restrict to "loop voice also gone"); "frozen" is exact equality of the loop's place (carry the loop length in `SoundPulse`); fixed 5 s cooldown never widens for an engine that cannot come back; `SoundPulse` sits in `sound_watchdog.dart` though `sound_loop.dart` imports it (move beside `SoundLoop`); a paused loop whose engine failed waits for the resume; `isLoopWanted` is public only for the test; no player-level test of `_loadTried` (needs a fake engine seam); `sound.dart` is ~350 lines (split the watchdog/lifecycle wiring when next touched); `_load` is 45 lines.
- **Band**: `TakenNoticeNotifier.build()` returns null and only listens (seed from the snapshot, up to 1 s late); no test for the `_announced` reset in `build()` and the `asked == null` branch; its tests wait a literal 5 s instead of `takenNoticeDuration`; the notifier could move to `providers/view.dart`; `askedCharacter` dartdoc should say it is also null after a drop. The phone host's own band (Play on this phone) ends on the 5 s only; an accessory that was taken shows no band; the band can sit over the host-away card up to 5 s (all left on purpose).

### Coverage and Arena music leftovers (bugs15, Nov 16)

- party_host, `arena_music_test.dart`: no test that Back from the Arena card leaves the lobby loop playing (`HostMusic._waiting` is cleared on `roundScreenClosed`). *when touched*
- party_host: `game_screen.dart` (378 lines) and `lobby_music.dart` (364) sit past the about-300 aim; split the stage reporting out of `GameScreen` and the round/lobby choice out of `HostMusic` at the next change. After Play again one frame of the `arena_final` loop can sound before the phase is `playing`: guard clock reports until then. *when touched*
- tools: `coverage_imports.dart` and `coverage_summary.dart` each hold the generated-suffix list (keep one); the generated `coverage_all_test.dart` has an empty body, so a lib file added without rerunning the generator stays uncounted until `tools/coverage.sh` runs (it regenerates); `assets` has one lib file and no test setup, so it is not counted (419 of 420 files). *leave*
- The generated coverage tests are excluded from the analyzer in each `analysis_options.yaml` because their imports are unused on purpose (`review.sh` forbids ignore comments). A broken import still fails the test run.

### M14 sentry1 (phone consent, Nov 16)

- controller_app, `settings_screen.dart` (371 lines): the crash reports row's words live in the app because `SettingsText` and `ConsentText` have no switch text; move them next to `ConsentText.crashBody` when the TV's Stats screen gains its "Crash reports: on/off" row, so both apps say the same thing. *when touched*
- controller_app: the connect screen asks the two questions only in a launch (`launchConsentAskProvider`, turned on in `main()`), so a widget test that mounts `ControllerApp` starts past them. A test that wants the prompt overrides it; keep the pair of providers together if a third launcher (a screenshot tool, the Windows shell) ever needs the same. *leave*
- party_host crash: four `on Object` catches hold only a comment (`crash_reporter.dart:72`, `sentry_reporter.dart:80`, `:90`, `crash_start.dart:58`): log one line with no error text through the package's `LogSink`, so a reporter that always fails is visible. `installCrashHandlers` chains a new handler pair on every call: make it install once. `scrub.dart` replaces names as case-insensitive substrings ("Sam" turns "same" into "[name]e"): match on word boundaries or say the over-replacement is intended. *when touched*
- party_host: `LiveStats.setConsent` and `ConsentNotifier.setStats` both write `statsConsent` (the design says the notifier is the only writer): let `setConsent` change only its state on that path. `crashNamesProvider` has no `ref.onDispose` clearing `CrashReports.playerNames`. `settings_text.dart:72` still says stats are sent "only if an adult allows it on the device that hosts", while the switch is the phone's own answer. The ~490-character crash prompt body sits in a plain `Text` in a fixed 560 px box (wrap it in a scroll view if a small panel clips it).
- Tests: `launch_consent_test.dart:68`, `settings_consent_test.dart:24` and `consent_migration_test.dart:15` assert less than their names say (the first two also hold on the old code); `stats_retry_once_test.dart` "reading flag clears when a read fails" repeats `stats_screen_failure_test.dart`; `fake_crash_off_test.dart` "kept once on" repeats `crash_reports_test.dart`; party_host's own tests import `src/testing/fake_crash.dart` where the apps use `package:party_host/testing.dart`. `controller_app/test/coverage_all_test.dart` got two imports by hand: rerun `tools/coverage.sh`.
- `tv_test_app/lib/src/app_info.dart` holds a second copy of `appWithBuild` (identical to the phone's): share one helper when a file both apps may import exists.
- Sizes past the ~300 aim after sentry1: `host_text.dart` 374, `settings_screen.dart` 371, `live_stats.dart` 369, `connect_screen.dart` 353: split at the next touch.
- Not verified by any test or review: `sentry_flutter` 10.4.0 internals (whether its integrations install their own error handlers, whether `Sentry.close()` then `enable()` restarts it); the in-app prompts' look on a phone and a TV; the legacy `shareStats` migration on a real phone. Device check in the owner list.

### Fire-and-forget futures the strict lints surfaced (bugs15, Nov 16)

Each is now `unawaited(...)` with no behaviour change; the failure would be lost silently. *when touched*

- party_host: `night_scoreboard_screen.dart:83` and `pause_menu.dart:342` discard dialog futures (no ordering risk).
- controller_app: the four `SharedPreferences` writers (storage, profile), `discovery.restart` (no internal catch), `host.disposed.then` without `onError`, and the two shader/consent loads; see lint-3-apps-report.md.
- connection: the swallowed close errors at `host_connection.dart:120` and `client_connection.dart:139`, `host_server` close, `frame_view` cancels (lint-2-core-report.md); `in_process_link.dart` now closes `toHost` before `toController` whichever end closes (not observable today).
- `FakeHaptics`/`FakeStats` `failWith` wrap a non-Error, non-Exception value in `Exception`: no test sets one. `pause_menu.dart` is exactly 400 lines: split it at the next edit.

## Carried into M16 (M14 closed, Nov 17, 2026)

M14 closed at `m14.9` with no code left in flight. These cross the milestone boundary:

- **Ten device checks the owner has not run yet:** B-017, B-018, B-019, B-020, B-021, B-023, B-027, B-028, B-029, B-030. Each fix is in and unit-tested; what is missing is one real-device look, and what to check is in [briefs/m14/STATUS.md](briefs/m14/STATUS.md). This is not code debt: no change is needed unless a check fails.
- **One open owner question:** should dropped sessions (not uploaded, no share marks) show on the Stats screen? It is decided in M16, not before.
- **The deferred items below**, still taken when their area is next touched. The M14 leftovers most likely to meet M16's work: the stale-lift pattern the sticks no longer have on the D-pad, small button and face buttons (`pad_widgets.dart`, `face_buttons.dart`); the uncaught `pad.stick` in `_AnalogStickViewState.dispose`; the `live_stats.dart` 380-line split; and Sentry name scrubbing over-blanking one-letter nicknames.

M15 streaming is parked: its own open items stay in [briefs/m15/STATUS.md](briefs/m15/STATUS.md) and are not M16's.

## Before a milestone

| Before | What | Risk | Benefit of doing it first | Rec. |
| --- | --- | --- | --- | --- |
| **M14 stats / the next report table** | The new round columns have no reader: per-round frames and fps (`frames_drawn`, `frames_late`, `fps`, a3) and the round's start offset (`start_s`, b5-2) are in the summary and the CSV only (run review). | Low: the CSV is tested; a table is one new reader | The table shows the columns mean what they say, before anything charted depends on them | **do** before the milestone whose report ends with a new table |
| **M13** (countdown, celebration, last-15-s warning) | A round's moments and log lines live in the puzzle's screen; the Arena logs no start or end. Move them to the shared round flow (`GameSession`/`Pausable`). (R2 later) | Medium: both games' screens | M13's moments are written once for every game | **do** before M13 |
| **M13** | "Seconds left" is computed three times from three clocks (the slot, the host card, the phone card). One countdown rule. (R1 later) | Low-medium | The last-15-s warning has one source | **do** before M13 |
| **Look-and-sound** | Colours and card text as literals: the mirror's orange copies `playerColors[1]`; the cards' opacities; "P2 is away" vs "Player 2 is away" already differ. One palette and one string table. (R3 + R2 later) | Low | A re-skin changes one place | **do** at its start |

## Done
- connection, before adding a message (sentry1 stats-optb): `host_connection.dart` 392 lines split into it and `host_connection_info.dart` (`toInfo`, `latencyLine` as library-private functions), and `client_messages.dart`'s `onData` (60 lines) split into it plus `_onControlMessage` and `_onViewEvent`. Now 364 and 44 lines, `onData` 35.

### M14 sentry2 (unmarked sessions dropped, Nov 16)
Review of `docs/briefs/m14/sentry2/REVIEW.md`, minor items left open: `live_stats.dart` is at the 380-line cap with the drop rule in three places, so split the upload queue into `session_upload_queue.dart` at the next stats job; `skippedSessions` is written once per dropped file and never pruned (batch the write, prune ids whose file is gone); a dropped file leaves no log line; `StatsState.waiting` doc should say unmarked sessions never count; add tests for all-`share: false` (still uploads totals) and consent off (no skip written); `live_stats_unmarked_test.dart` spells prefs keys as literals and uses real-time `waitFor` (B-019).

### M14 bugs16 (B-031 stick dispose, Nov 16)
Review of `docs/briefs/m14/bugs16/REVIEW.md`, minor items left open: the D-pad, small button and face buttons (`pad_widgets.dart:147`, `:283`, `face_buttons.dart:23`) keep the stale-lift pattern sticks now survive (`UnmountedRefException` only when the root scope goes; add the mounted guard and a dispose release in a later wave); the deferred release in `_AnalogStickViewState.dispose` has no catch around `pad.stick` (log through `LogSink`); the tests-first gate runs a new test file whole, so one failing test proves the file (run per test name or fail on a mixed result). Ruling: `stick_dispose_test.dart`'s normal down/move/up test is the named regression guard of brief item 1(c), an allowed exception to "fails on the old code".

### M16 phonehost1 (frame foundation, Nov 20)
Minor items from `docs/briefs/m16/phonehost1/REVIEW.md` and `wave3-review-report.md`, left open: give the other picture tests in `packages/` the `UPDATE_PNG` guard from one shared helper (every `tools/check.sh puzzle` still rewrites committed PNGs; `m13-tablet-board.png` is committed stale at 126,808 bytes); the `_updatePng` write branch is run by nothing; `host_frame_test.dart` focus test should also assert the moved button's rect is its frame rect times the scale, and `_ignore(_Seen seen)` has an unused parameter; `host_frame_screen_test.dart` restates 64/84/48 instead of the exported height consts and does not assert the title's left edge; the 960x540 frame and `s = min(W/960, H/540)` are written in four places (export the design frame or move the five-device table to `test/support/`); `s7-report.md` "smallest text" covers paragraph text only (painted badge numbers are not counted); `safe_area_test` keeps an unread `bodyFill` key and `host_frame_look_test.dart:139` comment claims a device-px assert it lacks; `f1-report.md:13` wording on `ToyLookScope.of`; `live_stats_share_test` failed once in a full host run (shared state with another test).
