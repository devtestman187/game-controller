# M16 items 7, 8, 9: scope and plan (read-only scoping, Nov 24)

Nothing built. File:line from worktree `m16`. B-040 (joined-phone result card) is being fixed elsewhere; I flag where it meets us.

## Headline
- **Item 7 is mostly built.** The host draws, decides, reveals and scores three awards since M14 (c2). What is left is small: a pinning audit, device checks, and M17 hooks. The bigger extras (awards on joined phones, a 3rd-to-1st ceremony) are not in the acceptance test and should wait (Q1).
- **Item 8 is the real build.** There is no Home, no coach marks, no Show-tips and no tips flag in the code today.
- **Item 9 is many small fixes**, plus the 320 px connect row. It should go first: it is disjoint and clears `connect_screen.dart` for item 8.

## Item 7: end-of-night awards
**Exists**
| Part | Where |
|---|---|
| 12 awards, draw of 3 (one losable, one either-game) | `party_host/lib/src/night/night_awards.dart:28-180` |
| Qualifiers, ties (every player level on the best value wins), +3 points | `night_award_results.dart:60-162`, `awardPoints` :45 |
| Night keeps counters, decides at last round, +3 in totals | `night_state.dart:164-272`, `party_night.dart:78-110` |
| Start card names the three, "i" popover | `award_tile.dart`, `night_start_screen.dart` |
| Reveal, fanfare, 4000 ms won / 2000 ms missed, Esc and Back skip | `night_reveal_screen.dart:25-29,71-152`, `night_reveal_widgets.dart` |
| Final scores with "Back to games" | `night_scoreboard_screen.dart:92-98` |
| Tests: reveal, tie, results, every look | `night_reveal_test`, `night_reveal_tie_test`, `night_award_results_test`, `award_explanation_looks_test`, `end_night_*_test` |

**Missing against the acceptance test** ("three awards shown and awarded at the end, tied players each get one"): nothing visible in code. The gaps are proof, not code:
1. No single test follows start-card names to reveal order to final totals with a tie, on both a TV host and a phone host. A pinning job closes it.
2. Device-unverified (the Fixed, unverified list in STATUS).
3. **Possible mismatch to check with B-040:** `round_results.dart:27-28` projects the final round with `night.record(result)`, which has no award outcomes, so the joined phone's last `place` and `standings` may leave out the +3 the host's final scores include. Needs a failing test first, then the Q1 decision.

**Not built, not in acceptance:** awards on joined phones (option B), 3rd to 2nd to 1st on the final scores (shown all at once now), a Skip button (owner: waits for M17, `STATUS.md:174`), speech-tolerant timing (the 2 s missed beat).

**Dependencies**
- B-040: option A (place and standings on the phone) is B-040's. Option B needs a new additive field on `view_end.result` (`awards`: list of award + winners), behind the existing `view` capability, with an older-peer test in `protocol/test/m14_test.dart` and `docs/protocol.md` section 10a. Sizes: `view_result.dart` 222, `view.dart` 352, `controller_app/lib/src/providers/view.dart` **380 (at cap)**, `result_card.dart` 260. Recommend not now.
- M17: the reveal's timing constants (`night_reveal_screen.dart:25,29`) should become one injectable value later; the Thumby slot already exists in the frame (`host_frame.dart:112-126`, `ThumbySpot`). No Thumby lines here.
- Phone host: the reveal already runs inside `HostFrameGate`, with tests at five sizes.
- Both looks: any new widget test uses `all_looks.dart`.

## Item 8: friendlier start
**Exists:** launch goes to the pad screen, which pushes `ConnectScreen` when not paired (`controller_screen.dart:85-106`). "Host a game" and its two ways live only inside the connect panel (`connect_panels.dart:111`, `host_start_sheet.dart`): "Play on this phone" is **Play here**, "Show on this device" is **Display here**. Consent is asked on the first frame of `ConnectScreen` (`connect_screen.dart:58-68`), or on the controller's first frame when paired (`controller_screen.dart:106-111`), once per launch through `launchConsentAskedProvider`; the consent state is built in `main.dart:_consentAtStartup` (:75-83). Nickname and character row: `your_character.dart`, `connect_panels.dart` `_YourCharacter`.

**Missing:** Home screen; three role buttons in fixed order; coach marks (none anywhere); the Show-tips switch and its saved flag; "screen" strings (about 44 "TV" literals: `phone_text.dart` 16, `settings_text.dart` 13, one each in `arena_text`, `consent_text`, `host_text`, plus controller_app literals; "Thumb Party TV" and "Android TV" stay); a host-side first-time-host flag (Prepares for M17).

**Dependencies**
- Item 9's connect job first: `connect_screen.dart` is 378/380 and both touch the connect row and the consent ask.
- Consent order: the dialogs are modal and asked from two places today. Home becomes the one first screen, so the ask moves there, and coach marks start only after `askConsents` completes (Q2). `paired_launch_consent_test.dart` and `connect_screen_test.dart` pin today's order.
- Tests pinning launch: 7 files pump `ControllerApp` or `ControllerScreen` (of 90 in controller_app). Expect re-pins, not rewrites. The strings sweep moves test strings with it.
- Files near cap (guideline hard limit 400, PRD says 380): `controller_screen.dart` 374, `settings_screen.dart` 369, `settings_sections.dart` 344, `host_text.dart` **379**, `connect_screen.dart` 378, `phone_text.dart` 244. Home, marks and the tips switch go in new files.
- No protocol change. Both looks: test Home in the menu look and the TV look.
- Release: the iPad plist allows all four orientations (`Info.plist:72-81`), so Home must work in Slide Over and Stage Manager widths. Android `sensorLandscape` (`AndroidManifest.xml:21`) is ignored on 600 dp+ screens at targetSdk 36 (`build.gradle` uses `flutter.targetSdkVersion`, minSdk 31), so tablets and foldables can show Home in portrait. Test Home at 568x320, 640x360, 320x640, 375x667 and 1.3x text.
- M17: the three-role home stays; the first-time-host flag is a saved bool plus a provider in `party_host`.

## Item 9: consistency and hygiene
| Part | Today | Where |
|---|---|---|
| Round number | Arena HUD says "Round N" inside the game, not the night's "N of M" | `test_game/lib/src/arena_hud_widgets.dart:177`; night numbers `party_night.dart:138`, `NightText.roundOf` `night_text.dart:36` |
| Map name | none on any in-round surface | snapshot has the map id (`arena_snapshot.dart:78`); `arena_map.dart` is 395 |
| Clock red, last 15 s | Puzzle has a warn pill (`board_hud.dart:36-72`, `match_painter.dart:147`); the Arena clock is ink always | `arena_hud_widgets.dart:158-178` |
| Resume colour | TV card, tablet and a third pill differ | `pause_menu_widgets.dart:80`, phone pad |
| 48 dp | mode control is 40 dp (compact density) | `bar_modes.dart:89-91` |
| Truncation | pill reads "Connecting... · tap to con…" at 667x375; its a11y label differs from the visible text | `bar_connection.dart:44`, `phone_text.dart:136` |
| Slider a11y | 4 `Slider` sites, none set `semanticFormatterCallback` | `settings_screen.dart:240`, `look_and_sound_section.dart:158`, `gyro_dialog.dart:122`, `stick_dialog.dart:107` |
| 320 px connect | manual row overflows 39 px (menu look), 109 px (TV look); app bar 45 px | `connect_screen.dart:348,102` |

Dependencies: joined phones get the night's round number from item 1's round strip (`ViewResult` round/of); if a HUD ever needs it from the snapshot, that is an additive key with an older-peer test. Plan: host HUD only, through an `ArenaView` parameter (`arena_view.dart:106` already takes `round`). `game_screen.dart` is 379 (extract before adding); `toy_button.dart` 372 is not touched.

## Slices (Haiku-sized: at most about 8 files and 2 packages)
Size S/M, risk L/M/H.
| Job | What | Files | Size/Risk | Proves |
|---|---|---|---|---|
| 9a | Address row to a new file, Connect wraps under the field when narrow, app-bar title ellipsises, connect tests at 568x320, 640x360, 320x640, 375x667 and 1.3x text, both looks | controller_app, about 5 | M/M | pill and connect fit, no overflow |
| 9c | One shared slider helper with `semanticFormatterCallback`; four call sites | party_host + controller_app, 6 | S/L | slider a11y values match labels |
| 9d | HUD: night "Round N of M", map name, Arena clock `bad` at 15 s; extract from `game_screen.dart` first | test_game + party_host, about 7 | M/M | HUD names map and round, clock red |
| 7a | Pinning tests: start-card names to reveal to totals with a tie, TV and phone host; phone last-round standings (failing first if the +3 mismatch is real) | tests only | S/L | awards shown, tied players each get one |
| 9b | 48 dp: a measuring test over bar, pad, connect and settings targets at the sizes; fix the offenders (mode control first); shorten the pill label | controller_app, about 6 | M/M | every target 48 dp, pill not truncated |
| 9e | Resume in one colour on the host card, phone pad and pill (default `good`) | party_host + controller_app, 4 | S/L | Resume same colour |
| 8a | Contract: saved keys (tips on, tips seen, first-time host), providers, role and tip strings | party_host + controller_app, 5 | S/L | none alone |
| 8b | New Home screen and role buttons: nickname and avatar row, three roles in fixed order, Settings, "no screen found" chip; the controller opens Home instead of Connect | controller_app, about 6 | M/H | three roles in fixed order |
| 8c | Coach marks overlay as a pure widget (dim, arrow, tap advances, Skip) | controller_app, 3 | M/M | marks advance, Skip dismisses |
| 8d | Wire: consent first, then marks on first Home; Show-tips switch in a new settings file replays them; move the launch consent ask to Home | controller_app, about 7 | M/H | Show-tips replays; consent order kept |
| 8e | "screen" strings sweep by file group, tests moved with the strings | party_host + controller_app | M/L | generic strings say "screen" |

## Waves
1. **Wave 1 (parallel, no shared files):** 9a, 9c, 9d, 7a.
2. **Wave 2:** 9b, 9e, 8a (disjoint).
3. **Wave 3:** 8b, 8c, 8e (disjoint; 8b needs 8a).
4. **Wave 4:** 8d, then a milestone-end review (rules A1 to A6 and every look; no protocol change unless Q1 picks B).

## Order and why
Item 9 and the 7a audit first: 9a frees `connect_screen.dart` before Home changes the launch path, and 7a is cheap and may expose a real +3 mismatch that B-040's author should know about. Item 8 last: it is the only large, high-risk piece (launch path, consent order, 7 pinned test files) and should land on a clean base. The owner's device checks for item 7 can run in parallel.

## Main-session review (Opus, Nov 24)
Accepted as the plan, with these changes:
1. **The 380-line acceptance fails today, not only `arena_map.dart`.** Five `lib/` files are over 380: `controller_app/lib/src/gyro.dart` 398, `packages/game_kit/lib/src/game_session.dart` 399, `packages/test_game/lib/src/arena_map.dart` 395, `packages/puzzle_game/lib/src/split_layout.dart` 389, `controller_app/lib/src/layout.dart` 386. Add **9f: behaviour-free splits** (one job per package, wave 1 or 2, no shared files with 9a-9e; `arena_map.dart` before 9d adds the map name). Owner question Q6 settles 380 vs the guideline's 400.
2. **Coverage (≥ 92.9%) has no job.** Run `tools/coverage.sh` before wave 1 as the baseline and at the milestone-end review; any job that drops it adds tests.
3. **Wave 3 shares files.** 8b (Home) and 8e (strings sweep) both touch `phone_text.dart` and the connect/controller literals. Run 8e after 8b (wave 4 with 8d, or its own wave), or give 8e only party_host and settings strings in wave 3.
4. **7a waits for B-040 to land** (it pins the phone's last-round standings, which B-040 is changing); it reads B-040's commit and tests first. If B-040 already pinned the +3, 7a shrinks to the host-side tie test.
5. **8d also covers the paired-launch path:** a paired phone today opens the pad and asks consent there (`controller_screen.dart:106`). Decide in 8a's brief whether a paired relaunch still goes straight to the pad (recommended: yes, Home only when not paired or on Back), so returning players are not slowed.
6. **iPad windows and large text** apply to every new screen in item 8 (Home, coach marks): same test sizes as 9a.
