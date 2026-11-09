# M14 scan: what the party features would touch (G0 survey)

Read-only. No code changed; every fact below is from the tree at this job's start (M13 branch, step 4a running: docs/briefs/m13/STATUS.md:24). Sources named in the brief were read; the code behind each claim is cited as `file:line`. The last section is the suggested cut.

Paths: a citation gives a file once, then repeats its bare name. The folders are `packages/puzzle_game/lib/src` (rules, snapshot, session, report, settings), `packages/party_host/lib/src` and its `ui/` (host service, storage, screens), `packages/protocol/lib/src` (messages, haptics), `packages/game_kit/lib/src` (session, view) and `controller_app/lib/src` with its `ui/` (the phone app).

## 1. Rules: where a chaos event or a power-up would live

**The tick.** `PuzzleGame.update` is the whole step (`packages/puzzle_game/lib/src/game.dart:231-333`): it prunes/joins players (232-237), clamps dt to 0.1 s (240), runs the clock and the tick event (244-247), reads A presses on the press edge (250-255), moves dots and pieces (259-271), turns held pieces (275-286), computes drop-ready and hint glow (289-306), handles pickup/drop (311-321), then ends the round (323-331). `PuzzleMatch.update` calls each side's `update` and decides the result (`match.dart:164-209`).

**How pieces move.** A dot moves at 48 field units/s (`game.dart:83`) clamped into the field (`puzzle_carry.dart:19-21`); an ordinary held piece copies its dot's position (`game.dart:262-263`); a team big piece moves itself and drags its carriers (`puzzle_carry.dart:28-40`). Tray pieces never move after `_layOutTray` (`game.dart:124-142`).

**Events.** A step returns `List<PuzzleEvent>` (`puzzle_values.dart:24-40`), applied on the host by `PuzzleEffects.apply` (`puzzle_events.dart:25-55`) and reported through `GameHost` (`packages/connection/lib/src/game_host.dart:13-103`). The `apply` switch is exhaustive over `PuzzleEventKind`, so every new kind needs a case there.

**Random and seeding.** `PuzzleGame` takes a required seeded `Random` (`game.dart:58-64,75`), used only for start angles and tray retries (`game.dart:130-134`); `PuzzleMatch` makes one seed from the injected `Random` and gives both sides `Random(seed)` (`match.dart:85-93,102,108,112,118`); the screen makes `Random()` at the edge (`packages/party_host/lib/src/ui/puzzle_screen.dart:78`). A cat must draw from that same source, never `Random()` inside the rules (coding-guidelines §5:54).

**Round start and end.** Start = the session constructor (tray layout, `round_start` record: `packages/puzzle_game/lib/src/puzzle_session.dart:67-76`) plus the get-ready beat held by `Pausable` (`pause_menu.dart:93-110`). End = `PuzzleGame.stop()` (`game.dart:222-226`) called by `PuzzleMatch._decide` (`match.dart:183-209`), then `PuzzleReport.write` on that step only (`puzzle_session.dart:136-140`, `puzzle_report.dart:23-72`).

**What must not change.** The tolerances (`settings.dart:5-17`, used at `puzzle_drop.dart:122-123`), the locked-piece rule (locked pieces are skipped on pickup: `puzzle_drop.dart:10`; `PieceState.locked`, `puzzle_values.dart:17-18`), `_filled` (`game.dart:94`), the ending rules (`match.dart:183-209`), the fixed step and the snapshot contract.

**Shape of a first slice.** `game.dart` is 365 lines (hard limit 400) and `update()` is already 103 lines (code-health.md:51), so a chaos/points tick needs a split first (guidelines §3:38). The natural seam is a per-side tick that runs between the clock and movement, returning events, plus a `puzzle_chaos.dart` holding the scheduler's state.

## 2. The snapshot and the protocol

**Today.** `PuzzleSnapshot` carries puzzle ID, time left, warning, phase, piece list (`[x,y,angle,state,holders…]`), player list (`[number,x,y,held]`), draw order, ready/hint targets and finish time (`snapshot.dart:49-119`); version 1 (`:63`), budget 2048 bytes (`:66`), decoded field by field (`:125-154`), lerped piece-wise with the shortest turn (`:162-191`). `MatchSnapshot` wraps one or two boards plus the layout seed (`:206-255`). A joined phone gets `view_start` (setup) then frames of `MatchSnapshot` JSON (`protocol.md:236-248`; `puzzle_module.dart:20-26,37`).

**A cat, star, pop-ups, scoreboard** would each be **new optional top-level keys** in `PuzzleSnapshot` (e.g. `cat:[x,y,kind]`, `st:[[side,x,y]]`, `pp:[[side,points,ms]]`, `sc:[left,right]`). They must be top-level: the piece and player lists are positional (`snapshot.dart:106,114`; decoded at `:137-147`), so appending a value to them makes an older decoder read the wrong field.

**Compatibility.** Unknown types and unknown fields are ignored (`protocol.md:33`), so a top-level key is additive; an older phone simply doesn't draw it. If the phone *must* draw it (a cat that changes play), raise `MatchSnapshot.version` (`snapshot.dart:209`, reported by `puzzle_module.dart:37`): a phone of another version shows "Update the app to see this game" instead of drawing wrong (`frame_view.dart:15,159`; `protocol.md:246`), and that is the honest outcome. A one-off "awards" beat is better as a new capability-gated message than as a snapshot field (guidelines §8:76-78), following M14's planned optional `view_end` field (PRD-v2.md:717).

**Lerp.** Any new field needs a rule in `lerpTo` (`snapshot.dart:162-191`): a cat position lerps; a pop-up or a score is this frame's, like phase, so it must not lerp (or it will show twice).

**Size.** The budget test passes today, 4 players on the biggest puzzle (`packages/puzzle_game/test/match_test.dart:398`). A cat (3 numbers), a star (3) and a scoreboard (2) are tens of bytes; a long pop-up list is not, so cap it (one pop-up per side).

## 3. The phone: labels, status, buzz, "what you got"

- **Labels** arrive as a `layout` message and land in `gameLayoutProvider` (`controller_app/lib/src/providers/game_feedback.dart:9-19`), read by `face_buttons.dart:23`, `pad_widgets.dart:215` and `bar_modes.dart:50,93`. The puzzle sends them from `puzzle_session.dart:22-30,118-125`, and again after a resume (`:108`).
- **Status** is `StatusMessage` (24 characters, 10/s: `packages/protocol/lib/src/game_controls.dart:143-190`), kept in `gameStatusProvider` (`game_feedback.dart:22`) and drawn by `StatusPanel` in the top bar (`status_panel.dart:24-99`), but only when this phone is **not** showing the game (`bar_connection.dart:49-51`; `showsGameProvider` `game_feedback.dart:53-55`). So the status panel is not a channel for a power-up message on a phone drawing the game.
- **Buzz** comes as a per-player `haptic` (`protocol.md:157`), played by `TvHapticsNotifier` (`game_feedback.dart:61-79`) with a pattern per event in `HapticPattern.forEvent`, an exhaustive switch (`haptic_patterns.dart:54-78`). A new event needs a pattern there; phones of older builds ignore the unknown name (`haptic.dart:82-89`).
- **Sound** rides the frame's `snd` and is played by the phone (`game_session.dart:123-128`, `joined_view.dart:128,138-143`); an unknown name is silent (`asset_manifest.dart:35`, `sound.dart:145-147`).
- **"What you got"** therefore has two viable homes: a snapshot field the game's own painter draws (same picture on host and every phone), plus a new haptic event and a new sound key for the buzz and the chime. The sentence must stay short (coding-guidelines §7:72).

## 4. Points and awards: what is counted today

Per player, in the rules: `pickups`, `snaps`, `wrongDrops`, `rotatingS`, `overshoots`, and for teams `helpCalls`, `soloBigCarries`, `soloBigS` (`game.dart:36-47`). They are written once at the end as `player_result` (`puzzle_report.dart:30-49`) beside `round_end` (`:57-70`) and stored as game values in the session summary (`session_recorder.dart:92-100`).

| Award | Computable today? | What it needs |
| --- | --- | --- |
| Sharpshooter (fewest wrong drops) | yes | `wrongDrops` (`game.dart:38`) |
| Finishing first | yes, per side | `MatchResult.winner` (`match.dart:183-209`) → `winners` in the report (`puzzle_report.dart:23-31`) |
| Best Helper | only a proxy | `helpCalls`/`soloBigS` exist; a true "helping carry" needs a counter for time with two carriers (`puzzle_carry.dart:28-40`) |
| Speedy Snapper | no | no per-snap time today: the snap event carries the piece and errors only (`puzzle_drop.dart:80`) |
| Cat Catcher | no | no cat and no shoo counter yet |

Points need: a first-try flag per piece (a new counter on `PieceRuntime` or a per-player attempt map), +5 for the side that finished first, +1 to each helper (both-carrier time), +1 for a shoo, and +1/+2 per snap. Points must live in the rules (a field on `PuzzlePlayer`/side) so a snapshot can carry them; review-rules.md:41-42 names "scores that live in a widget" as the thing to avoid. Points per **side**, not per player, keeps 2 vs 1 fair.

## 5. A party night: how rounds follow each other

Picker → `ShapeRaceScreen` (`games_screen.dart:88-126`) → `JoinScreen` (`join_screen.dart:91-134`, teams kept at `:96-97`) → `PuzzleScreen`. The results are a card over the board (`puzzle_screen.dart:259-268`; `puzzle_screen_widgets.dart:58-96`) with Rematch / Play again / Next puzzle, Change teams and Back (`puzzle_screen.dart:153-174`; `puzzle_screen_widgets.dart:161-194`). A next round **replaces the route** and carries the teams and keyboard over (`puzzle_screen.dart:143-146`); nothing above a round knows a round happened: the host service and `party_host` hold no round state, and `RoundPhase` only says none/ready/playing (`round_phase.dart:7-19`). Round log lines live in this screen (`puzzle_screen.dart:104,135-141,215-219`), which code-health.md:73 already wants moved into the shared round flow.

So a party night is a new `party_host` state (a provider beside `puzzleSettingsProvider`, `providers.dart:347-370`): round index, rounds total (3 or 5), scores, last-round-doubles flag, and where it is saved. The results card gains the scoreboard and "Next round (2 of 3)"; the join screen is skipped after round one, which Rematch already does; the awards show is a screen or card after the last round, before Back, reading the per-player counters from section 4. Every new beat (awards, scoreboard) is a state that must combine with pause, get-ready, host away, player away and leaving, with one owner (review-rules.md A3:18, B1:25).

## 6. Storage on the host

- **Shared preferences:** `hostId` (`host_service.dart:122-125,172`), `pairings` (`saved_pairings.dart:6,11-26`), `puzzleSettings` (`providers.dart:351`), `look`/`effects` (`packages/party_host/lib/src/look_providers.dart:27-28,41-52`), `statsConsent`/`uploadedSessions` (`live_stats.dart:114-115`).
- **Files:** session summaries as JSON in the host's sessions folder, written through a temp file (`session_store.dart:32-41`), listed and exported (`:45-80`); the folder comes from `HostDirectories` (`host_directories.dart:11-18`), implemented per app (`controller_app/lib/src/host/phone_host_setup.dart:33-44`, `tv_test_app/lib/src/tv_host_setup.dart:49-58`).
- **Best times: none.** Nothing matches "best time" outside the Arena's in-memory `bestTimeS` (`packages/test_game/lib/src/arena.dart:143,390`).
- **Hall of fame:** a JSON file next to the sessions through `HostDirectories` (one storage seam with narrow catches, code-health.md:43) — a best-times table keyed by puzzle and format, plus an all-time table of wins and awards by nickname. It must work on both host kinds (PRD-v2.md:122, C29) and must never be uploaded (PRD-v2.md:197).
- **Who a player is:** the phone's stable `controllerId` (`controller_app/lib/src/storage.dart:17-21`; `protocol.md:79`) is the only durable key; the nickname today is the device's `name` from `hello` (`protocol.md:80`, `server_game_host.dart:182`). C20 (PRD-v2.md:113) adds a nickname the player types, kept on the host.

## 7. Settings

`PuzzleSettings` is one immutable value with ranges and JSON (`settings.dart:5-93`), saved in prefs (`providers.dart:347-370`) and shown on one screen of numeric step rows plus one switch card (`puzzle_settings_screen.dart:18-29,65-104`), with Reset (`:44-48`). A three-way **Chaos (Off / A little / Party)** does not fit a stepper: it takes a `SegmentedButton` row like the Look choice (`look_and_sound_section.dart:30-40`) or a small card of its own, and a new field on `PuzzleSettings` with a `fromJson` default (`settings.dart:72-93`) so the rules read it every frame (`puzzle_session.dart:112`). Both hosts share this screen — the TV from the game picker (`games_screen.dart:65-73`), the phone host through the same picker (`controller_app/lib/src/host/host_games.dart:26-34`) — so one change serves both (guidelines §6:66). The phone's own Settings screen is per-phone and holds no game settings (`controller_app/lib/src/ui/settings_screen.dart:31-93`), so Chaos does not go there.

## 8. Sound

`SoundPlayer` does load / restart / play / dispose, starts a repeat over instead of layering, and has no loop, volume or mute (`sound.dart:32-56,144-156`). Ten keys exist, each one file in `assets/audio` (`assets/lib/asset_manifest.dart:16-26,42`). M13 step 7 adds `lobby`, `countdown`, `playerJoined`, `playLoop`/`stopLoop`, volume and mute, and the settings rows (`docs/design/look-and-sound.md:155-160`; not started yet, `m13/STATUS.md:28`).

A scoreboard between rounds needs a lobby-music hold of its own: M13 stops the music while a `RoundHold` stands (`packages/party_host/lib/src/ui/lobby_music.dart`), and a scoreboard shown over no round would let the music play under it unless its screen opens a hold too.

The meow, the points chime and the awards fanfare are three new `SoundKey`s with files and CREDITS rows. A game asks for them by name through `GameHost.playSound` (`packages/connection/lib/src/game_host.dart:60`); the host plays it (`providers.dart:222-226`) and it rides the next frame's `snd` to the phones (`game_session.dart:123-128`; `protocol.md:248`). Note `snd` only goes to viewers (`game_session.dart:337-342`), so a phone **not** drawing the game hears nothing; the haptic is the per-player channel.

## 9. Overlap with the PRD's current M14 (PRD-v2.md:713-725)

| M14 bullet | Kind | Note |
| --- | --- | --- |
| Countdown, celebration, last-15 warning, hint glow, best-times board (T15) | celebration and best times are party work; the rest is round feel | warning and hint glow already run in the rules (`game.dart:245,306`); best times is the storage base of the hall of fame (section 6) |
| Nicknames (C20) | setup | the identity a scoreboard and awards need (section 6) |
| Results on joined phones (optional `view_end` field) | setup | a joined phone can't show a scoreboard or awards card before it has a results card |
| The Arena waits for its players | unrelated | no party content |
| The remaining puzzles, 9 in total | unrelated (content) | it is the key set for best times |
| Sounds for the new moments | overlap | the fanfare is the same work as the awards' sound |
| Playtest, tuning, README, checklists | unrelated | the playtest is where the three Chaos settings get compared (party-ideas.md:30) |
| Protocol spec published, `sim_controller --check` (P1, P7) | unrelated, but a constraint | any new field or message must be in the spec in the same commit (guidelines §8:78) |
| v3 recommendation | unrelated | — |

## 10. Risks

- **Frame cost.** 4 players at 60 fps is a hard requirement (PRD-v2.md:413). The cat, the spotlight and pop-ups are per-frame drawing; keep them bounded and state their cost (review-rules.md B6:31), and derive motion from the snapshot's time so phones draw the same (`look-and-sound.md:152`).
- **Drawn from snapshots only.** A joined phone draws what the frame holds and nothing else (review-rules.md B5:29; `controller_app/lib/src/ui/joined_view.dart:114`). A cat or pop-up not in the snapshot is invisible on phones, so an old phone would play a different game from the host. That forces the version-bump decision in section 2.
- **Positional snapshot arrays.** Appending to the piece or player arrays silently misreads on older builds (`snapshot.dart:106,114,137-147`).
- **Pause, away, get-ready.** Chaos must run on the step clock, not wall time (`game.dart:231-247`); the away grace is a wall-clock timer that keeps running while a round stands still (code-health.md:31). A scoreboard/awards beat is a new state that must combine with pause, get-ready, host away, player away, results and leaving, with one owner (`Pausable`, review-rules.md A3:18).
- **Determinism.** A cat picking "the side that's ahead" (`party-ideas.md:22`) needs the seeded `Random` and the step count, never `DateTime.now()` or a new `Random()` in rules (coding-guidelines §5:54).
- **Tray geometry.** The tray was packed and sized for the start angles (`game.dart:124-142`; `split_layout.dart:54-57`). A cat batting a tray piece, or "piece shuffle", can leave a piece outside the tray or overlapping, and the split layout's fit is not re-checked.
- **Fairness.** Points per action reward a side of two for work one player can't do alone; points per player in 2 vs 1 is unfair. Points per side, or normalised, is the safer model. Chaos must never touch locked pieces or filled targets (`game.dart:94`, `puzzle_drop.dart:10`; party-ideas.md:10).
- **Privacy and size.** A hall of fame holds nicknames, which never leave the host (PRD-v2.md:197, C20). New counters must not push the 50 KB summary budget (PRD-v2.md:204).
- **File sizes.** `game.dart` 365/400 and `update()` 103 lines (code-health.md:51) leave no room; split before adding.

## Suggested M14 cut

party-ideas.md:71 says the smallest first step is "points, the party-night scoreboard and the cat".

1. **Split first** (`game.dart` into rules + a per-side tick), then **points in the rules** and top-level snapshot keys for the score, drawn by host and phone alike from the frame.
2. **Party night in `party_host`**: a saved night state (3 or 5 rounds, scores, last round double), the results card gains a scoreboard and "Next round (n of N)". No new message needed; Rematch is the button.
3. **The cat**: one event kind, warned by a sound (needs M13 step 7's sound keys plus a meow), bats one loose piece, shooable with A, skipping locked pieces. Decide the snapshot version bump here, before it ships.
4. **Awards show** from the counters already recorded (Sharpshooter, finishing first, Best Helper as it stands), one at a time, after the last round.

Can wait: power-ups (they need a star in the tray, a pickup rule and five effects), the other chaos events (wind, lights out, wobble, shuffle, bubble), all-time hall of fame and wins (after C20 nicknames and T15 best times), and any per-phone celebration polish.

## Checks

- `flutter test test/match_test.dart` in `packages/puzzle_game`: PASS (18 tests), including the 4-player snapshot under 2 KB.
- Read-only job: no build, no app started, no git command that changes anything.
- `git status` also shows `tv_test_app/windows/flutter/generated_*` as modified; their diff is empty (line endings only, from the checkout), so this job did not touch them. The only file written is this report.

## Part A self-check (review-rules.md:14-20)

1. Every host setup: not affected (nothing changed). The scan records where they differ: TV has no local player (`providers.dart:95`), a phone host has one (`ownPlayerIdProvider`), "Show on this device" draws no pad (`hostPadProvider`, `:156`), a joined phone draws only frames (`frame_view.dart`), an older build ignores unknown fields and shows `updateAppText` on a version mismatch.
2. When kept state starts and ends: not affected; the report recommends one owner for each new state.
3. How a new state combines: not affected; listed as a risk in section 10.
4. Folder: only `docs/briefs/m14/scan-party-touchpoints-report.md` was written.
5. Stop rather than overstep: nothing blocked the job; nothing outside `allow:` was needed.

## Commit message

docs(m14): survey what the party features would touch

Map the rules tick, the snapshot and protocol rules, the phone's
labels/status/haptics, per-player counters, the round chain, host
storage, puzzle settings and the sound player, with file:line facts.
Chaos, power-ups and points belong in the rules and in new top-level
snapshot keys (the per-piece arrays are positional); a party night needs
a host-side night state, since nothing above a round remembers one; best
times and a hall of fame have no storage yet.
First slice: split the rules file, points plus a night scoreboard, the cat.

## Status row

Survey done: party touchpoints mapped with file:line (rules, snapshot, phone, points, nights, storage, settings, sound, M14 overlap, risks); open: the M14 cut and the snapshot version decision.

## Delete

- none
