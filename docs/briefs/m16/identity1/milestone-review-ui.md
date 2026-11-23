# M16 identity1 milestone review, part 2: phone app, TV host UI, games

Scope: `git diff dd51e607..HEAD -- controller_app packages/party_host packages/puzzle_game packages/test_game packages/toy_look` at HEAD 29cc80d2. Read-only. Tests were not run.

## Findings
should controller_app/lib/src/ui/host_chip.dart:31 — guideline 3 (build about 60 lines) — `tools/review.sh --base dd51e607` FAILs it at 63 lines; the badge line and the character line (38-39, 51-54) added the excess. Extract the badge into a named widget.
should packages/puzzle_game/lib/src/play_view.dart:11,19-20 — guideline 3 (public surface minimal) and code-health "MatchView shares play_view.dart" (half done) — MatchView is moved to match_view.dart but play_view.dart re-exports it "because puzzle_module.dart reaches it through this file"; puzzle_module.dart imports play_view.dart only for that. A later change to play_view's exports silently breaks the module. Import match_view.dart in puzzle_module.dart and drop the export.
should controller_app/lib/src/ui/pad_drawing.dart:7 (used at pad_widgets.dart:230,340, stick_widgets.dart:247, tilt_view.dart:41) — owner decision "identity everywhere players are drawn" (PLAN) — the phone's own pad fill is `colors.player(number)`, so a joined player with a chosen crown sees the number colour on their pad while the TV and the phone's badge show the crown. Code not touched by this batch, so it is a coverage gap. Take the fill from the player's `character.colourIn`.
should packages/test_game/test/arena_phone_identity_test.dart:118-127 — guideline 9 (tests pin the rule) and code-health leftover "crown test compares renders only" (still open) — `expect(crown, isNot(equals(variant)))` on whole-screen bytes passes for any render difference, not for the crown. Pin a crown pixel mask, as arena_identity_test.dart:241-260 does.
later packages/party_host/test/score_bar_identity_test.dart:71-86 — code-health leftover "second test is a default guard" (still open) — passes if the default is drawn, so it guards nothing new; test 1 (47-69) carries the rule.
later packages/party_host/lib/src/ui/score_row.dart + packages/puzzle_game/lib/src/mirror_painter.dart:128,214 — owner kept player 2's colour (REVIEW Nov 22) — no test in packages/puzzle_game/test pins `player(2)` for the mirror dots, so a change to the colour would pass.
later controller_app/lib/src/ui/connect_panels.dart:83 — `ToyBadge(number: character.colourSlot, ...)` passes a colour slot as the player number. Harmless while `numbered: false`, but the parameter now means something else on this line. Pass the number the badge is for, or document the colour slot use.
later controller_app/test/host_chip_test.dart (and host_own_player_test.dart) — no test pins the character on the host chip (host_chip.dart:52); host_chip_test covers Wi-Fi addresses only.
later packages/toy_look/lib/src/toy_badge.dart:26 — guideline 3 (one public type per file) — `ToyBadgeFace` sits beside `ToyBadge`. Small and used only with `paintToyBadge`, so the exception may cover it; say so or split it.
later packages/party_host/lib/src/ui/puzzle_screen_widgets.dart:15-16, packages/party_host/lib/src/ui/join_side_panel.dart:30 — side colours by player 1/2 — side identity, not player identity; intended by design, but a side's header on a character-coloured board may disagree with the chosen colour. Note in design docs.
later controller_app/lib/src/ui/connect_panels.dart (373), settings_screen.dart (369), packages/party_host/lib/src/ui/puzzle_screen.dart (379) — guideline 3 aim 300 (hard limit 400 passes; review.sh NOTE) — no action needed in this batch, but these are next in line for a split.
later docs/briefs/m16/identity1/i1g1-report.md:29 — report says `toyTvProvider` "does not exist"; it exists and join_badge_test.dart uses `party.toyTvProvider`. Correct the report (code-health leftover still open).

## Owner answers
- Join-screen badge no number, no "Player N" (connect_panels.dart:83 numbered:false; join_badge_test.dart:54-65 flag and 66 paint, 88-100 Settings preview): done. Caveat: the ConnectionPanel is used only by connect_screen.dart:121, so the badge is never numbered, even after pairing. Consistent with "until paired" only if the connect screen is pre-pair; confirm.
- Settings preview no number (settings_profile_section.dart:295 numbered:false): done, same caveat.
- Blank nickname shows "Player N" in phone lobby and result card (phone_text.dart:124 playerName; lobby_players.dart:37-45; result_card.dart:33-36 and 238-245): done. Tests phone_name_display_test.dart:48-61, identity_phone_test.dart:43, 75.
- Results band keeps the winner's character colour (arena_view_widgets.dart _winnerBanner, ~line 158): done. Test arena_identity_test.dart:345-351 (pins the band header colour).
- Shape Race mirror dots stay on player 2 (mirror_painter.dart:128,214 unchanged): done/kept. No test pins it (see later finding).
- ArenaPainter and ArenaMarblePainter take one value object (arena_roster.dart ArenaCast; arena_painter.dart:82; arena_marble_painter.dart:61; arena_map_picture_widgets.dart:41 passes ArenaCast({})): done. No test names ArenaCast; behaviour is pinned through arena_identity_test.dart.
- paintToyBadge parameters folded into a value object (toy_badge.dart:26-44 ToyBadgeFace, :57 paintToyBadge with 5 parameters): done. Test toy_badge_unnumbered_test.dart:26-58.
- Phone-only: Q10 phone_metrics_test group renamed to "in the app, and what the hello says" (phone_metrics_test.dart:123): done.
- Q2, Q4, Q5 are host-side (part 1), not checked here.

## Coverage
Phone (controller_app):
- join-screen badge connect_panels.dart:83 — character, unnumbered — OK
- Settings preview settings_profile_section.dart:295 — character, unnumbered — OK
- phone lobby list lobby_players.dart:37 — character — OK
- result card own and standing badges result_card.dart:212, 243 — character (Robo keeps RoboBadge) — OK
- host chip own badge host_chip.dart:52 — character — OK (not pinned by a test)
- bar connection badges bar_connection.dart:31, 88, 213 — character — OK
- pad fills pad_widgets.dart:230,340; stick_widgets.dart:247; tilt_view.dart:41 via pad_drawing.dart:7 — colors.player(number) — GAP (should)
TV / host (party_host, puzzle_game, test_game, toy_look):
- score rows bar score_row.dart:260 (score_row_bar.dart:33-40) and badge score_row.dart:328 — character — OK
- join side panel badge join_side_panel.dart:200 — character — OK
- puzzle results badge puzzle_results_widgets.dart:335 — character — OK
- round results round_results.dart:40,48 — character, Robo forPlayer — OK
- night reveal badge night_reveal_widgets.dart:141 — character — OK
- night reveal disc night_reveal_screen.dart:142 and award tiles night_start_screen.dart:196 — award colours by index — intended
- night start names night_start_names.dart:82 — character — OK
- arena waiting player row arena_waiting_widgets.dart:52 — character — OK
- arena map cards arena_waiting_card.dart:328 and header :251 — map and card colours — intended
- pause menu badge pause_menu_widgets.dart:118 — character — OK
- away player badge away_card.dart:161 — character — OK
- Shape Race workers worker_painter.dart:83 — characters map, default by number — OK
- match split board match_painter.dart:137, 186 — passes characters to both boards — OK (match_split_identity_test.dart:65)
- mirror dots mirror_painter.dart:128,214 — player(2), owner kept — intended
- arena marble arena_marble_painter.dart (arenaCharacterFor) — OK
- arena HUD dot arena_hud_widgets.dart (character.colourIn) — OK
- arena winner band arena_view_widgets.dart (_winnerBanner) — OK
- arena phone viewer arena_module.dart (view.characters from the frame) — OK (arena_phone_identity_test.dart:103)
- arena TV host arena_view.dart:146 (arenaCharactersOf) — OK
- Robo badge player_badge.dart:89 player(number) — intended (Robo has no character)
- toy_look default paintToyBadge toy_badge.dart:61 colors.player(face.number) — intended default
- settings colour picker settings_profile_section.dart:97, 202 — palette — intended
- confetti celebration_paint.dart:81, night_widgets.dart:169 — decoration — intended

## Checked
- Read every changed lib file in scope (diff of controller_app/lib, party_host/lib, puzzle_game/lib, test_game/lib, toy_look/lib).
- `grep` for `colors.player(`, `player(number)`, `forPlayer(`, `paintToyBadge(`, `ToyBadge(`, `PlayerBadge(`: every hit classified in Coverage.
- Layers: no import of party_host, controller_app or a sideways game in puzzle_game/test_game/toy_look; test_game depends on protocol (pubspec.yaml:22, pre-existing).
- Sizes: every changed lib file is at most 379 lines (puzzle_screen.dart). No lib file over 400.
- `tools/review.sh --base dd51e607`: 3 FAIL, 20 NOTE. In scope: host_chip.dart:31 (should). Out of scope, not reviewed here: protocol/character.dart:107 (dynamic), :144 (colour outside toy_look).
- Types: ViewContext.characters is keyed by player ID (game_module.dart:78); _charactersOf (puzzle_module.dart) keys by ID and then by number; PuzzleScreen and PuzzleView key by number. Consistent.
- Tests with flag-only asserts: join_badge_test.dart:61,100 are paired with paint tests (66, 88), so not weak.
- all_looks.dart: only score_bar_identity_test.dart uses forEachLook. The other new tests use their own look lists (menu and TV) — accepted.
- Code-health "i1g wave 3 leftovers": status per item —
  - i1g1-report toyTvProvider claim: OPEN (later).
  - i1g1-report self-check lines 1-5: not checked.
  - crown test arena_phone_identity_test.dart:125: OPEN (should).
  - MatchView move to match_view.dart: PARTLY (file moved; play_view re-export remains, should).
  - split-board MatchPainter character test: CLOSED (match_split_identity_test.dart).
  - score_bar second test default guard: OPEN (later).
  - puzzle_screen_test.dart:177 Robo comment: reworded, no longer names Robo; not verified.
  - mirror dots player 2: kept per owner; not pinned by a test (later).
- Not run: flutter test, dart analyze. Only static review.
