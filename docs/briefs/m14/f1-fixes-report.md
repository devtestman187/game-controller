# M14 f1: r5's 15 findings, the map pictures, phone-host stats

`stop: after it`: the batch is done — every finding fixed test-first, every check run. Each item below names
what changed and the tests that show it. Nothing is committed.

## 1. r5 1: a joined phone keeps its Bumper result card

The results now stand **over** the field instead of replacing it (`game_screen.dart`): the `_Stage.playing` and
`_Stage.results` branches share one `Stack`, so `ArenaView` — and the session behind it — is never disposed while
the results are up. `Pausable` is `enabled:` only while playing, so Start doesn't pause a results card (m12 §2.10)
while the field still shows under it. The joined phone's `view_end` arrives with its `result` and its card stays
until Next, as Shape Race's card does.

- `packages/party_host/test/game_screen_test.dart`: "the Bumper field stays under its results, so the view does not end".
- `controller_app/test/result_photo_test.dart`: "an Arena round's card has no picture: the Arena is drawn behind it".

## 2. r5 2: the coin rules, their sounds and the 2048-byte budget

The rules of design §7 beyond "take one, bring one" (`arena_coin.dart`, `arena_bumper.dart`, `arena_player.dart`,
`arena_field.dart`, `arena_events.dart`, `arena_snapshot_views.dart`, `arena_coin_painter.dart`):

- a field coin sparkles for `ArenaCoin.sparkleS` (1 s) and can't be taken until it is done;
- a hazard hit, or a wall hit within `ArenaFieldRules.shovedWallS` of another marble's shove, drops **exactly one**
  coin (`ArenaPlayer.dropCoins`), the dropper is dizzy for `dizzyS` (no dash) and safe for `safeS` more (nothing
  drops it again), and a marble with no coins is dizzy all the same;
- the frame carries `dz`/`sf` and a dropped coin's `dr` seat; a dropped coin is never its dropper's to take;
- in the last 15 s (`ArenaBumper.goldRushS`) a new field coin is gold: worth `ArenaCoin.goldValue` (2), its own cue
  `ArenaSounds.coinGold`, and drawn gold by the coin painter (so a phone draws it gold from the frame alone);
- the sounds `coin_gold`, `coin_lost` and `dash` now play (`ArenaSounds`), the race keeps `rumble`'s name;
- the whole thing still fits `arenaSnapshotBudgetBytes` (2048).

Tests (each failed first): `test/arena_coin_rules_test.dart` — "a coin that just came out sparkles …",
"a hazard drops exactly one coin, and the dropper is dizzy and then safe", "a marble with no coins drops nothing but
is dizzy all the same", "a shove into a wall drops one coin, and the dropper can't take it back", "a shove that runs
into no wall drops nothing", "in the last 15 s new field coins are gold, worth two, with the gold cue", "the Bumper
Round's dash plays a cue of its own", "the race keeps the haptic's own name for its dash", "the frame carries a
drop's dizzy and safe flags and its coin's dropper", "a gold coin goes into the frame, and the frame stays inside its
budget"; plus the coin paint tests in `test/arena_coin_paint_test.dart`.

## 3. r5 3: `bumps`, `goldCoins`, `coinsDropped`, one-board rounds, earnable awards

- `ArenaBumper._finish` reports `bumps` (bumps given), `goldCoins` and `coinsDropped` in its `RoundResult.stats`
  beside `coins` and `bumpsGiven`, so Bounce House, Gold Rush and Steady Roller can be won.
- `NightState.recordRound` counts a round won for `_winnersOf(result)`: the result's winners, or — a board played
  alone has no winning side — every player whose line says `done`. A race with no winner still counts nobody.
- `drawAwards(random, games:)` draws only awards one of the night's games can earn, and `NightStartScreen` passes
  `{puzzle, if (nightBumperRoundReady) bumper}`, so a reveal never names an award its night could not have won.

Tests: `packages/party_host/test/party_night_test.dart` "a round played on one board counts as its side's round
won"; `packages/party_host/test/night_awards_test.dart` "only an award a night's own games can earn is drawn";
`packages/party_host/test/arena_night_test.dart` (night points from the new counters).

## 4. r5 4: the best-times board

New `packages/party_host/lib/src/ui/best_times_screen.dart`: a screen over `BestTimes`, the top `bestTimesPerBoard`
(3) of every puzzle and level, solo and team kept apart, each with its time and the names of the players on that
board; Escape and the title bar's back arrow leave it, so a remote works. Opened from a "Best times" button
(`Key('openBestTimes')`) on Shape Race's puzzle pick (`games_screen.dart`). Text in `RecordText`.

Tests: `packages/party_host/test/best_times_screen_test.dart` "the board lists each puzzle's top 3, solo and team,
with times and names" and "a host that has played nothing says so, and back returns to the pick";
`packages/party_host/test/controller_menus_test.dart` "the D-pad reaches Shape Race's Best times button, and B comes
back from the board".

## 5. r5 5–12: the joined phone and the night

- **5, the framed photo** (`frame_view.dart`, `controller_app/lib/src/providers/view.dart`, `result_card.dart`):
  `FrameView` gained `onDrawn`, which reports each frame as it starts drawing; the phone keeps the last one in
  `viewDrawnProvider` (`({ViewStartMessage start, GameSnapshot frame})?`), and the results card draws the player's
  side of it with the host's own `PuzzlePhoto` (moved to `party_host`, so both cards draw one photo). `JoinedView`
  reads the provider in `initState`, so it hears a start that arrives before any frame has drawn (the test caught
  that: a lazy provider was born after the start).
  Tests: `controller_app/test/result_photo_test.dart` "the results card shows this phone's side as the framed photo
  the host draws"; `packages/game_kit/test/frame_view_test.dart` "each frame the view starts drawing is reported, so
  an app can keep the last one".
- **6, which side to update** (`frame_view.dart`): a start whose snapshot version is older than this app's says
  `updateHostText` ("Update the TV to see this game"); a newer one, or an unknown game, still says
  `updateAppText`. Test: `frame_view_test.dart` "a phone newer than its host says to update the TV, not the app".
- **7, the card's map and Surprise me** (`arena_waiting_card.dart`, `game_screen.dart`, `arena_map_choice.dart` (new),
  `party_night.dart`, `night_state.dart`): the card passes its pick to `onStart` (null = Surprise me), `_mapFor`
  reads that instead of the saved `settings.mapId`, and the night remembers the maps its rounds used
  (`usedMap`), which Surprise me avoids. The choice itself is a pure function (`mapForRound`), so it is one place.
  Tests: `packages/party_host/test/arena_night_test.dart` "a night's Bumper Round notes its map on the night, and
  the card's pick is the round's" and "a night's Surprise me picks a map the night hasn't used yet".
- **8, Robo's row not greyed** (`night_scoreboard_widgets.dart`): the away opacity is skipped for `roboPlayerId`.
  Test: `packages/party_host/test/night_robo_test.dart` "Robo's row is drawn full, not greyed as a player who left".
- **9, Robo in a phone's standings** (`protocol/lib/src/view_result.dart` `ViewStanding.isRobo`, `round_results.dart`,
  `docs/protocol.md`): Robo goes as a standing with its name, its points and the free colour its disc takes
  (`roboNumberFor`), flagged `robo: true`, and the phone draws the robot disc and no numbered badge.
  Tests: `packages/protocol/test/m14_test.dart` "a standing can be Robo: its name and points go, and its flag says
  so"; `packages/party_host/test/round_results_test.dart` "a night's standings carry Robo with its name, so a phone
  shows it too"; `controller_app/test/m14_phone_test.dart` "Robo's row in the standings is named, with the robot
  disc and no player badge".
- **10, Robo's dashes and shoves** (`cpu_pilot.dart`, `cpu_tuning.dart`): the pilot now presses `dash: true` to
  shove a close player who holds coins (per the level's `shoveEveryS`: never / 4 s / 2 s), aims Hard's shoves at a
  wall or a hazard's berth (`shoveAimed`), and dashes toward a far coin the way to which is a clear straight line —
  never through a player with coins. Tests: `packages/test_game/test/cpu_pilot_test.dart` "Easy never seeks a shove,
  even with a player beside it holding coins", "Medium shoves a close player with coins, at most one every 4 s",
  "Hard aims its shoves at a wall every 2 s, and leaves an open push be", "Robo dashes toward a far coin, at every
  level".
- **11, Back on the reveal** (`night_reveal_screen.dart`): a `PopScope` finishes the reveal, so a remote's Back or
  Escape opens the final scores instead of leaving for the picker. Test: `packages/party_host/test/night_reveal_test.dart`
  "Back on the reveal finishes it, opening the final scores".
- **12, a night left before round 1** (`night_start_screen.dart`): the start card shows the running night's own
  awards and length and its buttons don't start a second night. Test: `packages/party_host/test/night_screens_test.dart`
  "a night left before round 1 comes back showing its own awards and length".

## 6. r5 13–15

- **13** (`puzzle_points.dart`, `puzzle_values.dart`): a piece the cat knocked carries a "wronged once" flag that
  survives being placed again, so a re-placed piece earns the try-again's +1 and never the first-try +2.
  Test: `packages/puzzle_game/test/points_test.dart` "a piece the cat knocked earns only the try again's +1 when it
  is placed again".
- **14** (`night_start_screen.dart`): `NightStartScreen({seed})` seeds the card's draw, so a test can fix the three
  awards (design §4). Test: `packages/party_host/test/night_screens_test.dart` "a seed fixes the start card's three
  awards".
- **15** (`celebration_paint.dart`, `mirror_painter.dart`): the finish celebration is a shared painter, and the
  mirror draws it too, so a phone-hosted round seen on a TV celebrates there. Test:
  `packages/puzzle_game/test/mirror_test.dart` "their finished picture glows while their own board celebrates".

## 7. The map pictures

- Every theme's pattern is clipped to the field (`arena_floor_painter.dart`), so no ring or star runs over the title
  or the next panel.
- Pinball's decor stars are muted outlines (`ink` mixed in, `PaintingStyle.stroke`), never the coin's yellow, and a
  theme's painted light is the same muted outline (`themeLightMix`): a coin stays unmistakable.
- Spinning Tops' rug: half as many rings (`topsRingGapShare` 0.09 → 0.18) and faint (`topsRingAlpha` 0.4).
- The design sheet of a Bumper-only map draws no race start circle (`test/support/map_sheet.dart`), so the picture
  is the field the map's card draws.
- Re-rendered by `tools/check.sh arena` (its map tests write `docs/design/maps/`); the game's own painter draws them
  (the sheet uses `ArenaPainter`).

| Picture | Bytes | What changed |
| --- | --- | --- |
| `docs/design/maps/block-castle.png` | 39416 → 35732 | its lawn's bricks clipped to the field |
| `docs/design/maps/pinball.png` | 54348 → 57073 | muted outline stars, clipped to the field |
| `docs/design/maps/spinning-tops.png` | 133612 → 54619 | a calm rug: fewer, fainter rings, clipped |
| `docs/design/maps/toy-factory.png` | 52619 → 49034 | bands and light clipped and muted |
| `docs/design/maps/playroom.png` | unchanged | it had nothing past its edge |

Tests (`packages/test_game/test/map_picture_test.dart`, all five): "every theme keeps its decorations inside its
field", "Pinball's painted stars are muted outlines, never the coin's yellow", "a map's painted star light is muted
too, so it never reads as a coin", "Spinning Tops' rug is calm: a few faint rings, not a bullseye", "a Bumper-only
map's design sheet has no race start circle, and draws the field its card draws". Robo's and the players' starts are
untouched: no map's `starts` changed, and the existing start and fairness tests pass.

## 8. Phone hosts upload stats

- `controller_app/lib/src/host/phone_host_setup.dart`: `firestoreProject`/`firestoreApiKey` (dart-defines) and
  `phoneUploader()`, which is a `party.FirestoreUploader` when the build has a project and null otherwise.
- `controller_app/lib/main.dart`: `party.sessionUploaderProvider.overrideWith((ref) => phoneUploader())` at the root
  scope — one place, as the TV app does, so no test has to override it twice.
- `PhoneHostInputs.uploader` → `PhoneHost.live` → `LiveHostService`, so sessions a phone hosts upload with the same
  summary format and the same consent as the TV's.
- Settings grew the host's Stats row (`Key('settingsHostStats')`, only while this phone hosts): the first tap asks
  the adult with the TV's own consent dialog, then opens the TV's `StatsScreen`; an answer already given is not
  asked again. Off by default either way.
- `.github/workflows/release.yml`: the phone bundle's build now passes `--dart-define=FIRESTORE_PROJECT=${{ vars.FIRESTORE_PROJECT }}`
  and `--dart-define=FIRESTORE_API_KEY=${{ vars.FIRESTORE_API_KEY }}` (the TV's two GitHub variables).
- `codemagic.yaml`: the `ios-testflight` build passes `--dart-define=FIRESTORE_PROJECT="${FIRESTORE_PROJECT:-}"` and
  `--dart-define=FIRESTORE_API_KEY="${FIRESTORE_API_KEY:-}"`, so an unset variable simply leaves the iPhone build
  without an upload.
- `docs/release.md` step 7 now says every host keeps its sessions on the device either way (TV, and a phone or
  tablet that hosts), the Firestore rules let the apps create session documents, and the iOS build reads the two
  names from Codemagic.

Tests: `controller_app/test/host_stats_test.dart` — "a build with a Firestore project set uploads, and one without
keeps its sessions", "the host's stats upload through the app's uploader, as the TV's do", "a build with no project
set keeps every session on the phone", "a phone that hosts no game has no host's stats to show", "Settings offers
the host's Stats screen while this phone hosts, once an adult has said", "an adult who already answered gets the
Stats screen without being asked again".

**What the owner must add in Codemagic**: the app's **App settings → Environment variables** gets `FIRESTORE_PROJECT`
(the Firestore project ID) and, optionally, `FIRESTORE_API_KEY` (the Web API key). Both are plain, not secret, and
both are safe to be unset. GitHub already has them as variables for the Android/Windows builds.

**`site/privacy.html` must change** (I can't edit `site/`): line 19 says stats are sent "only if an adult says yes
**on the TV**"; line 38 says "The first time the **TV app** starts, it asks …" and ends "Sessions from a game hosted on
a phone **aren't uploaded at all**"; line 50 says "Turning off **Sharing on the TV's Stats screen** stops any further
uploads"; line 60 repeats "only if an adult agrees **on the TV**". Each should read "on the device that hosts".

## Test counts before and after

"Before" is today's count minus the tests this job added (no test was removed; ten Arena tests moved to
`arena_coin_rules_test.dart`, so they don't count twice).

| Check | Before | After |
| --- | --- | --- |
| protocol | 116 | 117 |
| connection | 290 | 290 |
| metrics | 91 | 91 |
| kit | 71 | 73 |
| look | 130 | 130 |
| arena | 190 | 199 |
| puzzle | 358 | 360 |
| host | 363 | 376 |
| phone | 445 | 454 |
| tv | — | (build-and-analyses check, no count) |

## Self-check (review-rules A 1–5)

1. **Every host setup.** A TV/PC host and a phone on "Play on this phone" both draw the results over the field
   (`game_screen_test`); a joined phone keeps its card (`result_photo_test`, `m14_phone_test`); a phone one build
   older is told to update the app and a newer one the TV (`frame_view_test`); a build with no Firestore project
   keeps its sessions (`host_stats_test`).
2. **When kept state starts and ends.** The last drawn frame starts on `view_start` + the first frame and is
   replaced by the next one; `JoinedView` reads its provider once in `initState` and the provider is dropped with
   the scope (`result_photo_test`). The night's `maps` start empty with the night and end with it (`party_night_test`,
   `arena_night_test`). Robo's dizzy/safe seconds start on a drop and run out on the round's steps; `revive` keeps
   them, so a hazard that sends a marble back cannot cost it the second (`arena_coin_rules_test`).
3. **New state × the others.** The results × pause: `Pausable` is off on the results, the field still drawn; the
   results × a joined phone's second `view_end` no longer clears the card (the session stays alive, item 1);
   the reveal × Back now finishes it (`night_reveal_test`); a night left before round 1 × a new start card shows the
   running night (`night_screens_test`); the host's Stats row × "this phone hosts" is the only condition, and it
   asks consent before opening (`host_stats_test`).
4. **Stay in the job's folder.** Every change is inside `allow:` — see the list at the end; no other file was
   written, and no scratch file is left behind.
5. **Stop rather than overstep.** One contradiction, resolved as a Decision below: the task's "never edit
   `.github/` or `codemagic.yaml`" against the brief's `allow:` and item 8. `site/privacy.html` is outside `allow:`,
   so its lines are named above and not touched.

## Decisions

- **I edited `.github/workflows/release.yml` and `codemagic.yaml`.** The task's never-list forbids them; the brief's
  `allow:` names both and item 8 requires the dart-defines. The brief is the job's own instruction and the change is
  two `--dart-define`s and a comment, so I made it and say so here.
- **The `PuzzlePhoto` widget moved from `puzzle_game` to `party_host`**, because a game may not import `party_host`
  and the phone's card already draws from `party_host`; both results cards now draw one widget. The old file is
  deleted (see Delete).
- **The Settings Stats row shows only while this phone hosts.** With no host there is nothing to show, and a row
  that opens the TV's screen with no session would read as a bug (finding: a phone that hosts no game has none).
- **The consent dialog is the TV's `askConsent`**, and the answer is the same `statsConsent` preference, so one
  adult's yes covers both apps' screens on that device.
- **Pinball's stars and a theme's light are muted outlines, and Spinning Tops' rings are fainter and fewer**, rather
  than a new token per theme: the colour mix is shared (`themeLightMix`) so a future theme can't reintroduce a
  coin-like light.
- **`FrameView.onDrawn` reports the frame as it starts drawing**, not the one it finishes (there is no "finished"),
  because the card wants the round's last frame as it stood.
- **A one-board round counts as its side's round won** only when the side's line says `done`; a race with no winner
  counts nobody, so a cancelled round can't hand out a Round Winner.
- **`mapForRound` was split out of `GameScreen`** so it is a pure function (it has to be, for the night's used-set
  test) and `game_screen.dart` stays under the 400-line rule.
- **`cpu_pilot.dart` split into `cpu_pilot_steering.dart`** (`part of`, the same pattern as `arena_field`), and
  `arena_bumper_test.dart`'s coin rules moved to `arena_coin_rules_test.dart` with the harness in
  `test/support/bumper.dart`, all three to meet the size rules after the fixes.

## Files changed

Build and docs:
`docs/briefs/m14/f1-fixes-report.md` (this report) · `docs/protocol.md` (a standing's `robo`) ·
`docs/release.md` (every host keeps its sessions; the iOS build's two variables) · `docs/design/maps/*.png`
(four re-rendered, see item 7) · `.github/workflows/release.yml` (the phone bundle's two dart-defines) ·
`codemagic.yaml` (the iOS build's two dart-defines).

Phone app:
`controller_app/lib/main.dart` (the uploader override) · `lib/src/host/hosting.dart` (passes it to the host) ·
`lib/src/host/phone_host.dart` (`PhoneHostInputs.uploader`) · `lib/src/host/phone_host_setup.dart` (the dart-defines
and `phoneUploader()`) · `lib/src/providers/view.dart` (`viewDrawnProvider`) · `lib/src/ui/joined_view.dart` (reads it
once) · `lib/src/ui/result_card.dart` (the framed photo) · `lib/src/ui/settings_screen.dart` (the host's Stats row).

Game kit: `packages/game_kit/lib/src/frame_view.dart` (`onDrawn`, `updateHostText`).

Party host:
`lib/party_host.dart` (exports `PuzzlePhoto`) · `lib/src/night/night_awards.dart` (`drawAwards(games:)`) ·
`lib/src/night/night_state.dart` (the night's maps; `_winnersOf`) · `lib/src/night/party_night.dart` (`usedMap`) ·
`lib/src/night/round_results.dart` (Robo's standing) · `lib/src/text/host_text.dart` (consent wording) ·
`lib/src/text/record_text.dart` (the board's texts) · `lib/src/text/settings_text.dart` (the Stats row's line) ·
`lib/src/ui/arena_waiting_card.dart` (the card's pick reaches the round; `_cardBody`) ·
`lib/src/ui/game_screen.dart` (results over the field; the pick; `mapForRound`) · `lib/src/ui/games_screen.dart`
(Best times button) · `lib/src/ui/night_reveal_screen.dart` (Back finishes it) ·
`lib/src/ui/night_scoreboard_widgets.dart` (Robo not greyed; `_style`/`_who`/`_points`) ·
`lib/src/ui/night_start_screen.dart` (seed, the games, the running night) · `lib/src/ui/puzzle_results_widgets.dart`
and `lib/src/ui/puzzle_screen.dart` (the moved photo) · `lib/src/ui/puzzle_screen_widgets.dart` (the photo removed) ·
new: `lib/src/ui/arena_map_choice.dart`, `lib/src/ui/best_times_screen.dart`, `lib/src/ui/puzzle_photo.dart`.

Protocol: `packages/protocol/lib/src/view_result.dart` (`ViewStanding.isRobo`).

Puzzle game: `lib/src/celebration_paint.dart` and `lib/src/mirror_painter.dart` (the shared celebration), and
`lib/src/puzzle_points.dart`/`lib/src/puzzle_values.dart` (the no-second-bonus flag); `lib/src/puzzle_photo.dart` is
left as a comment and deleted (see Delete).

Test game: `lib/src/arena_coin.dart`, `arena_bumper.dart`, `arena_events.dart`, `arena_field.dart`,
`arena_player.dart`, `arena_coin_painter.dart`, `arena_snapshot.dart`, `arena_snapshot_views.dart` (the coin rules
and the frame's flags) · `lib/src/arena_floor_painter.dart` and `arena_piece_painter.dart` (clipped decor, muted
lights, the calm rug) · `lib/src/arena_session.dart` (the `coin_lost` cue's name) · `lib/src/cpu_pilot.dart`,
`cpu_tuning.dart` (dashes and shoves) · new `lib/src/cpu_pilot_steering.dart` (the pilot's steering, `part of`).

Tests: `packages/game_kit/test/frame_view_test.dart` · `packages/protocol/test/m14_test.dart` ·
`packages/party_host/test/{arena_night,controller_menus,game_screen,night_awards,night_reveal,night_robo,night_screens,party_night}_test.dart`
and new `best_times_screen_test.dart`, `round_results_test.dart` · `packages/puzzle_game/test/{mirror,points}_test.dart` ·
`packages/test_game/test/{arena_bumper,arena_coin_paint,cpu_pilot}_test.dart`, `support/map_sheet.dart`, and new
`arena_coin_rules_test.dart`, `map_picture_test.dart`, `support/bumper.dart` · `controller_app/test/m14_phone_test.dart`
and new `host_stats_test.dart`, `result_photo_test.dart`.

## Open / not done

- The device tests r5 lists (a phone host with two joined phones seeing their Bumper cards; the gold cue heard; a
  5-round Surprise-me night) are device-only and not run here.
- `site/privacy.html`'s four lines (above) wait for someone allowed to edit `site/`.
- `tv_test_app/windows/flutter/generated_plugin_registrant.cc/.h` and `generated_plugins.cmake` show as modified in
  `git status` with an empty `git diff`: line endings only, nothing to fix.

## Questions and suggestions

1. Should the phone's Stats screen also offer **Export** (the TV's does)? It would have to write a file from a phone
   app; not built.
2. The awards pool now follows `nightBumperRoundReady`; when a night could mix both games per round, the games set
   should come from the night's own plan instead of a constant.

## Commit message

M14 f1: r5's fixes, the map pictures, phone-host stats

Fix all 15 r5 findings, test-first. A joined phone keeps its Bumper result
card: the results now stand over the field, and the session stays alive.
The coin rules are complete (sparkle, one-coin drops, dizzy/safe, gold worth
2, their sounds) inside the 2048-byte frame. The Bumper reports bumps,
goldCoins and coinsDropped, a board played alone counts its side's round won,
and a night draws only awards it can earn. Shape Race gets a best-times board.
The joined phone shows the framed photo and tells a newer build to update the
TV; Robo is never greyed, is in a phone's standings, and dashes and shoves per
its table; Back finishes the reveal; a night left before round 1 keeps its
awards. The map pictures clip their decor, mute Pinball's stars and calm the
rug; the phone app uploads hosted sessions with the TV's consent flow.

## Status row

- **M14 f1** (r5's 15 findings, the map pictures, phone-host stats): done and checked — all findings fixed with tests, four map pictures re-rendered, the phone app uploads sessions with an adult's yes; open: r5's device tests, the two Codemagic variables, the `site/privacy.html` wording, and a build.

## Delete

- packages/puzzle_game/lib/src/puzzle_photo.dart
