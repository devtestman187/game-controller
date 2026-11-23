# identity1 milestone-end review: verdicts (main session, Nov 23, 2026)

Worker reviews (Haiku, read-only): [milestone-review-host.md](milestone-review-host.md) (must 2, should 4, later 8) and [milestone-review-ui.md](milestone-review-ui.md) (must 0, should 4, later 8). Range dd51e607..29cc80d2. Each must and should below was checked at its file:line by the main session.

## Real: proposed fix batch (on the owner's word)
- fm1 (connection, protocol): (1) **must** away_slots.dart:139 rebuilds the away `GamePlayer` without `character`, so a dropped player shows their number's default in `players` and frame `chars` for the whole away slot (breaks owner Q5); identity_rows_test.dart:53 pins only the default → pass `character`, test with a non-default pick. (2) host_character_reservation.dart:42-53: local players' `forPlayer(number)` is not in `taken`, so a phone can be given a local player's look (Q4 "phone lobby matches the TV") → count the game's local players. (3) character.dart:107 `Map<dynamic, dynamic>` (review.sh types FAIL).
- fm2 (controller_app, puzzle_game): host_chip.dart:31 build 63 lines (review.sh FAIL) → extract the badge widget; play_view.dart:11 re-exports MatchView → puzzle_module.dart imports match_view.dart.
- fm3 (test_game test): arena_phone_identity_test.dart:118-127 compares whole renders → pin a crown pixel mask as arena_identity_test.dart:241-260 does.

## Not a finding / accepted
- Host must 2 (re-pairing hello's character applied mid-round): the owner never answered REVIEW Q6; code and protocol.md:235 agree ("the one exception"). Owner question, below.
- Host should 2 (reserve minute shorter than the away slot): the away grace is `hostGraceS` = 30 s (controller_app/lib/src/host_grace.dart:6), under the 60 s reserve, so the away slot ends first. Not real with the default.
- Host should 4 (DateTime clock seam, not `nowMs`): main-session design call (the number reserve already used `DateTime.now()` in host_pairings.dart); behaviour pinned by identity_reserve_minute_test.dart. Accepted.

## Owner questions
1. Q6: may a phone that drops and re-pairs mid-round change its look at once (current, documented exception), or is its hello's character held until the round ends like `set_character`?
2. Phone pad fill (pad_drawing.dart:7, used by pad/stick/tilt views) is still `colors.player(number)`, so a player who chose a crown sees the number's colour on their own pad. Take the fill from the chosen character? (A visible change no brief asked for.)
3. f1 Q1: `ToyBadgeFace` beside `ToyBadge` in toy_badge.dart: keep (small, used only with paintToyBadge) or split?

## Later (to docs/code-health.md at the fix batch)
Host: character.dart:144 palette literals in protocol; host_connection.dart:198 `_handle` 41 lines; host_server.dart 378 and server_game_host.dart 357 lines; identity.dart two public messages; `playerSource` public mutable callback; two row builders and two hand-copied FrameMessage builders; `_roundRunning` cleared only by endView; frame_characters_test.dart:60 does not pin the shortcut. UI: score_bar_identity_test second test is a default guard; no mirror-dot colour test; connect_panels.dart:83 passes a colour slot as `number`; no host-chip character test; side colours by player 1/2; connect_panels/settings_screen/puzzle_screen near the 380 aim; i1g1-report.md:29 wrong toyTvProvider claim.

## Coverage
The UI review lists 30 drawing places: all use the chosen character or are intended defaults (Robo, palette picker, award colours, mirror dots, side colours), except the phone's own pad fill (owner question 2).

## Owner answers Nov 23 (review)
- "Run the fix batch fm1-fm3": yes (batch folder docs/briefs/m16/identity1-fix/).
- Q6: a phone that drops and re-pairs mid-round: its hello's character "should be held until the round ends" (like set_character). docs/protocol.md:235's "one exception" sentence is corrected in fq6 (wave B).
- Switch `check.sh tools` to `selftest.sh -j 4`: yes (job ft, wave B; first make claude-worker-test load-tolerant).
- Questions 2 (pad fill, job fpad) and 3 (ToyBadgeFace) are still open; fpad is not written until the main session says so.
