# M14 c3 — the phone (nicknames, characters, results, a phone host's night)

Stop: the brief's `stop:` is "after it", so the job runs through the protocol, the phone's settings and profile, the
results card, the colour-taken line, the host's own results in a night and the checks, then stops there.

## Protocol changes (all additive; docs/protocol.md lists each)

- **hello `name`**: now the player's nickname (M14 N13), or the phone's own `Phone 1A2B`. The host cuts it to 10
  (`nicknameOf`, `maxNicknameLength`) and a blank one shows as `P1`.
- **hello `character`** (new, optional): `{"c": 4, "a": "crown"}`, a colour slot 1–6 and an accessory name. The host
  gives the nearest free colour and accessory (`PlayerCharacter.nearestFreeIn`), first come first served; a phone
  without it (an older build, a local player) gets `PlayerCharacter.forPlayer(number)`.
- **`player`**: optional `character`, the host's answer to the hello's wish. A `player` without one clears it — a
  host one build older, so the phone draws the number's default as before.
- **`view_end`**: optional `result` — `outcome` (`win`, `loss`, `draw`, `done`), `time`, `count`/`countOf`
  (`pieces`, `coins`), `points`, `round`, `of`, `place`, `winners`, `standings` (`{n, name, pts, character}`). The
  phone keeps its last frame and draws the card over it; the card goes on the next `view_start` or a later end
  without a `result`. A phone that gets none behaves as in M12.
- **Both ways**: an older hello still decodes and joins, an older host ignores `character`, an older phone ignores
  `result` (tests in `packages/protocol/test/m14_test.dart`, `packages/connection/test/m14_test.dart`).

## The phone's profile

`controller_app/lib/src/profile.dart`: `ControllerProfile` (nickname, character; `ControllerProfile.load`/`save` in
SharedPreferences under `profileNickname`/`profileCharacter`), `phoneName` and `nicknameOfText` (letters, numbers and
spaces, cut to 10, blank → null). `providers/profile.dart`: `profileProvider` with `setNickname`/`setCharacter`,
which save and then apply the profile to the existing clients **in place** (`client.identity = …copyWith`), so a
running link is not torn down; `identityProvider` watches the profile, so a client made later (the host's own player)
carries it too. `tvClientProvider` now **reads** the identity for that reason.

## Screens against the mock-ups

- **Phone settings** (`m14-night-17-phone-settings.png`, the sunny variant is the same frame): a "You" section with
  the `Nickname` field, its `3 / 10` count and the hint "Up to 10 characters: letters, numbers and spaces."; six
  colour buttons (48 px, the look's player colours, ink ring, a paper inner ring when picked); six accessory buttons
  (paper disc over a body in the picked colour, the accessory drawn with `paintAccessory`); a "You" preview at worker
  and marble size and "Shows next time you join.". Look and sound stays above it (M13 3c's order), haptics below.
- **Colour taken** (`m14-night-18-phone-colour-taken.png`): a green band (`look.colors.good`, ink outline) under the
  bar reading "Blue is taken tonight, you're Teal", while the host's colour differs from the phone's pick; the bar's
  badge and the game already wear the host's character. It takes no touches of its own and goes when the host gives
  the phone its own colour.
- **Results card** (`m14-night-12-phone-result.png`): "You win!" (or `You lose`/`Draw`/`Done! 1:42`) as the card's
  header, a row with the 32 px badge, the name and the time (`0:58`), "+12 points" in the look's good colour,
  `Standings` with a 24 px badge, name and points per row (this phone's row bold), and "Waiting for the host to pick
  what's next." under it. The game's last frame stays drawn beneath, dimmed with the look's ink at a fifth; the card
  is at most 420 wide and takes every touch, so the pad under it can't be pressed.
- **Host badge, roster and scoreboards** (mock-ups 3, 4, 7 and the join screen): every badge now draws
  `ToyCharacter.of(player.character, number)` — join rows, the away card, the pause menu, the results side rows and
  the night scoreboard — so the nickname and the character agree on the TV and on the phones.
- **A phone host's own results in a night** ("Show on this device"): the results offer Next as the TV's do; Next
  records the round, then the scoreboard (c1), tested in `packages/party_host/test/night_round_test.dart`.

## Tests, before and after (each new test failed first)

| Package | Before | After | New |
| --- | --- | --- | --- |
| protocol | 107 | 116 | `m14_test.dart`: hello round-trip with and without name and character, an older hello, a bad character, the `player` message, `nearestFreeIn` (taken → nearest, all taken → stands), `view_end` with and without a result |
| connection | 284 | 290 | `m14_test.dart`: a phone keeps its choice / a taken one gets the nearest (pairing), the host cuts a nickname to 10 and a blank one falls back to P1, a round's end sends each viewer its own result and the view stays open — each over both transports |
| toy_look | 126 | 130 | `m14_test.dart`: the host's choice maps to the look's colours and accessories, no choice → the number's default, colour names and accessory labels |
| party_host | 316 | 320 | `m14_character_test.dart`: the join screen shows a nickname and wears its character; a phone that chose nothing wears its default. `night_round_test.dart`: every joined phone gets its own result; a phone host's night results offer Next |
| controller_app | 439 | 445 | `m14_phone_test.dart`: the saved profile rides in the hello (else `Phone 1A2B`), the nickname rules, the settings save and the next hello says them, the colour-taken line, the result card over the last frame, a new view clears it |

`tools/check.sh format analyze protocol connection look host phone tv` passes: format, analyze, protocol (116),
connection (290), look (130), host (320), phone (445), tv. `tools/review.sh`: no FAIL on my lines (NOTEs only, listed
under *Not sure*).

## Decisions

1. The nickname rides in the hello's existing `name`, not a new field — N13 says "sent in the hello" and every host
   already shows `name`.
2. The phone's own name stays `Phone 1A2B` (10 characters) — a TV and a log recognise it, and the host's cut keeps it
   whole; a blank nickname sends that name, and only the roster falls back to `P1`.
3. `character` names the colour slot and the accessory rather than an ARGB colour — the six player colours are shared
   by every device (D6), so a name keeps the phone and the host on one list.
4. Uniqueness is the host's job, at pairing (`HostServer._reserveCharacter`) — only the host sees the whole roster; a
   phone can't know who took what.
5. A tie for the nearest free slot goes to the later one — deterministic, and easy to say in the line.
6. With all six colours (or all six accessories) taken the wish stands — a seventh player still has a character and
   nothing hangs.
7. Settings save the moment they change (no Save button) and apply in place to a running link — "Shows next time you
   join" is about the TV, not about needing a restart.
8. `tvClientProvider` reads the identity instead of watching it — watching would rebuild the provider and drop the
   client the link lives in each time a key is pressed.
9. `view_end` carries the phone's result and the view stays logically on (`ViewActiveNotifier`) — one message, and the
   phone keeps the last frame under the card without a second "frame" message.
10. `gameViewEventsProvider` holds result ends back from `FrameView` — games clear their view on any `ViewEnded`, so
    filtering here keeps `game_kit` and every game untouched.
11. The card clears on the next `view_start` or a later end without a result — Next starts the next view in a night,
    and the host's own way out of the results ends without one.
12. The taken line names colours only ("Blue is taken tonight, you're Teal") — the mock-up's words; an accessory that
    was taken alone changes the badge without a line, as the mock-up shows no wording for it.
13. The preview draws `ToyBadge` at 48 (worker) and 32 (marble) with those captions — `toy_look` has no body
    painters; the worker's and marble's bodies are the arena's game art.
14. The results card keeps the mock-up's fixed 420 width, the standings' own badges at 24 and the scrim at the look's
    ink with alpha 0.2 — one number each, named, so the look can take them over later.
15. The section order is Look and sound, You, Haptics — M13 3c's test and the fact a nickname is set once while the
    tuning is tried twice.
16. `party_host/lib/src/night/round_results.dart` projects the night from a copy (`remember(...).record(...)`) — the
    card must show the round's points before Next records them, and the night's own state must not move.

## Self-check (docs/review-rules.md part A, 1–5)

1. **Every host setup.** `HostServer._reserveCharacter` gives the character for every pairing, whatever the host, and
   the connection `m14_test` covers a phone keeping its choice and a taken one getting the nearest; a phone host's
   night results offer Next (`night_round_test`); "Show on this device" shares no view, so `showResults` is ignored
   there (`ServerGameHost.startView` keeps none) and the host's own results are the screen's; a joined phone shows its
   card (`m14_phone_test`); a one-build-old host sends no `character` or `result` and the phone draws the number's
   default and its pad (`protocol` `m14_test`, `m14_phone_test` "a phone sent no result keeps its pad"); a one-build-old
   phone's hello still joins (`protocol` "an older hello, without a character, still decodes", `connection`
   `m14_test`).
2. **When kept state starts and ends.** The profile starts at `ControllerProfile.load` (or `initial`), ends at each
   save (unknown saved JSON → `initial`) and survives restarts; the card starts on a `view_end` with a result and ends
   on `view_start`, a later end without one, or the link dropping; the taken line starts on a player message whose
   colour differs and ends when it matches. Nothing shows with no round: `m14_phone_test` "a new view clears the card,
   and a phone sent no result keeps its pad".
3. **How it combines.** The card is the last child of the controller screen's stack — over the game's frame, the
   waiting card and the taken notice — and `_ResultOverlay` puts a non-dismissible `ModalBarrier` under it, so a
   press falls on the barrier rather than the pad (by construction; the result tests assert the card, its rows and
   the frame under it, not a tap). A joined phone has no pause menu, and the taken line is `IgnorePointer`, so the pad
   under it still works.
4. **Stay in the job's folder.** Every file I wrote is under `allow:` (the list under *Files changed*). The three
   `tv_test_app/windows/flutter/generated_*` files show as modified in `git status` from a Flutter run, not from me —
   see *Not sure*.
5. **Stop rather than overstep.** Nothing needed outside `allow:` and no rule can't be met; the only extra is the
   stray `packages/connection/report.json`, which I can't delete and list under *Delete*.

## Files changed

Protocol: `packages/protocol/lib/src/character.dart` (new: `PlayerAccessory`, `PlayerCharacter`, `nearestFreeIn`);
`lib/src/view_result.dart` (new: `ViewOutcome`, `ViewCount`, `ViewStanding`, `ViewResult`, split out of `view.dart`);
`lib/src/messages.dart` (hello/player `character`, `part`s); `lib/src/view.dart` (`view_end`'s `result`, classes moved
out); `test/m14_test.dart` (new).

Connection: `lib/src/host_server.dart` (`_reserveCharacter`, sent in `player`); `lib/src/host_connection.dart`
(`character` on the session and `ControllerInfo`); `lib/src/host_types.dart` (`HostDetails` moved here);
`lib/src/server_game_host.dart` (`GamePlayer.character`, `showResults`); `lib/src/game_host.dart` (`showResults`);
`lib/src/memory_game_host.dart` (records `shownResults`); `lib/src/game_types.dart` (`GamePlayer.character`,
`maxNicknameLength`, `nicknameOf`); `lib/src/client_types.dart` (`ClientSnapshot.character`);
`lib/src/client_messages.dart` (player message updates the character too); `lib/src/controller_identity.dart`
(`copyWith(name:)`); `lib/connection.dart` (exports); `test/m14_test.dart` (new), `test/wire_phone.dart` (name and
character), `test/player_away_test.dart` (the 10-character cut).

toy_look: `lib/src/toy_character.dart` (`ToyCharacter.of`, `colourNames`, `colourName`, `ToyAccessory.label`);
`test/m14_test.dart` (new).

party_host: `lib/src/night/night_state.dart` (character on `NightPlayer`/`NightRow`); `lib/src/night/round_results.dart`
(new: `viewResultsFor`); `lib/src/ui/puzzle_screen.dart` (`showResults` on a round's end); `lib/src/ui/player_badge.dart`,
`join_screen_widgets.dart`, `away_card.dart`, `pause_menu_widgets.dart`, `puzzle_screen_widgets.dart`,
`night_scoreboard_widgets.dart` (badges draw the player's character); `lib/src/text/phone_text.dart` (the new words);
`lib/src/testing/host_fakes.dart` (`shownResults`, players' characters); `lib/src/testing/samples.dart`
(`phoneInfo` name/character); `test/night_round_test.dart` (two tests); `test/m14_character_test.dart` (new).

controller_app: `lib/src/profile.dart` (new); `lib/src/providers/profile.dart` (new) and `providers.dart` (export);
`lib/src/providers/device.dart` (identity carries the profile), `providers/connection.dart` (identity read, not
watched); `lib/src/providers/view.dart` (`gameViewEventsProvider`, `viewResultProvider`, an end with a result keeps
the view on); `lib/src/storage.dart` (name and character in the hello); `lib/src/ui/settings_screen.dart` and
`settings_profile_section.dart` (new part: nickname, colours, accessories, preview); `lib/src/ui/controller_screen.dart`
(the notice and the card in the stack), `controller_parts.dart` (`_ResultOverlay`), `result_card.dart` (new),
`taken_notice.dart` (new), `bar_connection.dart` (badges wear the character), `joined_view.dart` (filtered events);
`test/m14_phone_test.dart` (new). `docs/protocol.md` (hello, player, view_end); this report.

## Not sure

- `tv_test_app/windows/flutter/generated_plugin_registrant.cc`, `.h` and `generated_plugins.cmake` are modified in
  `git status`. I didn't write them: they look regenerated by a Flutter run in this session. Nothing in this job
  needs them; they can be reverted with `git checkout -- tv_test_app/windows/flutter`.
- `packages/connection/report.json` is a stray JSON test log (a `dart test --reporter json` run sent to a file). I
  couldn't delete it; it is under `## Delete`.
- `tools/review.sh` leaves NOTEs on my lines that the guidelines allow as "aims": `settings_profile_section.dart` 367
  lines (aim 300), `settings_screen.dart` 318, `providers/view.dart` 305, `result_card.dart`'s `_night` and
  `identityProvider` over 40 lines. No FAIL.
- One full `tools/check.sh` run failed `host_mode_test.dart` "Start on the pad pauses the round" on a timeout-ish
  step; the file passed on its own and the whole phone suite then passed (445), so it is a flake, not this change.

## Suggestions (for Claude; not acted on)

- `FakeGameHost` still puts the raw `c.name` in `nickname`, where `ServerGameHost` uses `nicknameOf` (cut to 10). One
  line in the fake would make them agree, but it rewrites ~29 test expectations (`Phone phone-1` → `Phone phon`).
- The phone settings' "Defaults" does not reset the nickname or the character. If the owner wants it to, it is one
  call in `_LookAndSoundSection` next to the other defaults.
- The card's 420 width, the scrim's alpha and the standings' badge size would sit better in the look's sizes than as
  `static const`s in `result_card.dart` when the look grows a results token.

## Commit message

M14 c3: nicknames, characters and results on the phone

hello `name` is the nickname and `hello`/`player` carry an optional character; the host gives
the nearest free colour and accessory. The phone's settings pick a nickname, colour and accessory,
saved and sent on the next join; a taken colour is said in a line. `view_end` carries the phone's
own result and the phone draws the results card over its last frame, in a night with points and
standings. Badges and scoreboards draw the host's character. A phone host's night results offer
Next. Protocol, connection, look, host and phone tests all pass.

## Status row

M14 c3 done: nicknames in the hello, a per-game character (nearest free, said in a line), results on joined phones' `view_end`, a phone host's night results offering Next; format, analyze, protocol (116), connection (290), look (130), host (320), phone (445) and tv pass; open: none.

## Delete

- packages/connection/report.json
