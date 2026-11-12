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

### M15 streaming
| What | Risk | Benefit | Rec. |
| --- | --- | --- | --- |
| Sizes against §3's 400 hard limit: `streaming/player/reporter.js` 473, `streaming/bench.sh` 572, `tools/stream.sh` 634 (after M15 fix4). Split one at a time along its seam: the reporter's helpers from `:445` into a module, each script's commands into files of their own. (fix3 REVIEW:33) | Low (moves), but the scripts run as root in the distro | Room for the next stage or flag without a tangle | when touched: split the one the next change grows |
| `kindOf` (`entry.kind ?? entry.mediaType`) is defined twice, `reporter.js:320` and `stats.js:51`, each beside its own copy of the inbound-rtp parse. | Low: one helper, both pages' stats | Two copies of a parse that must agree become one | when touched: the stats parsing |
| `automation_server.dart:84` calls `onStartState?.call(null)` after a successful bind, which can never clear anything (`start()` returns early while `_startError` is set) and no test fails without it. Delete it, or let `start()` retry after a failure. (fix2 findings, still open) | Low | One dead branch gone | when touched: the automation server |
| The bench does not record the viewer's own CPU, so every h1-2 run's viewer column was sampled by hand (`utime+stime` of every Chrome pid over 2 s, in % of one core — `h1-2/evidence.txt`). That sampler belongs in `bench.sh` beside the session's `cpuPct`. | Low-medium: a new field in the summary | Both CPU columns from one file, and pinning runs readable without a second script | a small tool job, before more pinning runs |
| One viewer row per run is what a report should read, but every h1-2 summary holds four `stream.viewers` entries (one with the page's numbers, three with the session-side stages only), and why is not known (h1-2 Observation 1). | Low: a report picks the wrong row | Numbers that say which viewer they came from | a job of its own before more pinning runs |

### tools and housekeeping
| What | Risk | Benefit | Rec. |
| --- | --- | --- | --- |
| The advertising log line still tags `[tv]` on a phone host. | None | Clear logs | when touched |
| `tv_test_app/flutter_*.log` crash files pile up (git-ignored); a leftover job folder `E:\AI\game-controller-m12-jobs\flash-20261107-090106-3357`; one stray `E:\game-controller-m12-jobs`. | None | Tidy disk | leave until a cleanup |
| The PRD M12 acceptance tests aren't copied into the checklist. | None | One list for the owner | before M12 closes |

## Before a milestone

| Before | What | Risk | Benefit of doing it first | Rec. |
| --- | --- | --- | --- | --- |
| **M13** (countdown, celebration, last-15-s warning) | A round's moments and log lines live in the puzzle's screen; the Arena logs no start or end. Move them to the shared round flow (`GameSession`/`Pausable`). (R2 later) | Medium: both games' screens | M13's moments are written once for every game | **do** before M13 |
| **M13** | "Seconds left" is computed three times from three clocks (the slot, the host card, the phone card). One countdown rule. (R1 later) | Low-medium | The last-15-s warning has one source | **do** before M13 |
| **Look-and-sound** | Colours and card text as literals: the mirror's orange copies `playerColors[1]`; the cards' opacities; "P2 is away" vs "Player 2 is away" already differ. One palette and one string table. (R3 + R2 later) | Low | A re-skin changes one place | **do** at its start |

## Done
- (none yet)
