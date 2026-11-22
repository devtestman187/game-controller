# identity1 run review: dd51e607..7598faea read as one change

## Summary

- Verdict: **one fix batch** (two musts, both local and both visible in the tree; nothing needs a design pass first).
- Counts: **2 must · 8 should · 10 could**; all carried wave-1 and wave-2 findings were re-checked against the final code.
- The five that matter most:
  1. `arena_character_painter.dart` is still untracked and `lib/test_game.dart`'s export still uncommitted, so HEAD cannot analyze `packages/test_game` (must 1).
  2. The host apps list no `Capability.identity`, so no phone ever sends `set_character` from the real apps: the character change is inert there (must 2). The wave-2 review repeated i1d's claim that `players`/`chars` are blocked too; that half is wrong.
  3. The owner's "empty nickname shows Player N" is unreachable: `phoneName` still sends "Phone AB12" and the host passes it through; the new tests use hand-made `name: ''` rows.
  4. `protocol.md:235`'s "never during one" is false for a re-pairing hello's character.
  5. i1e was hand-applied with no report and no tests-first proof (HAND-FIX i1e), the only job whose new tests were never shown to fail on the old code.
- Owner-only questions: the blank-nickname name (hello vs display); whether a dropped player's pick waits the reserve minute; the results band's new colour; local and away players in `players`; whether a mid-round reconnect's hello is gated; `ViewContext` characters for a joined phone; the six-parameter painters' value object.
- Computed here: new tests 80 (protocol 19, connection 30, phone 23, arena 8); `host_connection.dart` ends at exactly the 380-line ceiling; turns over cap: i1e 151, i1d 134, i1e2 76 (cap error), i1f 105 over its 70–100 aim.

## Findings

- **must** packages/test_game/lib/src/arena_hud_widgets.dart:5 — it imports `arena_character_painter.dart`, which is not in 7598faea and which `lib/test_game.dart:9` never exports, so a clean checkout cannot analyze `packages/test_game` and every test that draws the HUD cannot compile → commit the new file and the export, then rerun `tools/check.sh arena` from the commit. (from: wave2)
- **must** controller_app/lib/src/storage.dart:55 — the TV/PC host's welcome lists no `Capability.identity` (and packages/party_host/lib/src/host_service.dart:142 neither), so `client_connection.dart:219` never sends `set_character` from a real app and the character change is dead there → add `Capability.identity` to both lists, as metrics/rating are; `players`/`chars` already flow from an app host because the gate is the session's hello (`host_server.dart:225`), so i1d's Q1 wording "never get players/chars" is wrong and needs correcting. (from: i1d Q1, across jobs)
- **should** controller_app/lib/src/profile.dart:57 — `phoneName` falls back to "Phone AB12", the host passes that through (`host_players_broadcast.dart:18`), so a blank nickname never shows "Player N" on the lobby list or the result card, and `identity_phone_test.dart:14` only proves the display with a hand-made `name: ''` row → decide whether the hello sends no name (the host then falls back) or the phone translates the phone-style name, then test the real path. (from: i1b wave1 finding 1, i1e)
- **should** docs/protocol.md:235 — "never during one" is false for a phone that drops and re-pairs mid-round, because `host_connection.dart:337` takes the hello's `character` at once → say the hello's pick is taken at once, or hold it like `set_character`. (from: wave2)
- **should** docs/briefs/m16/identity1/i1f-report.md:26-27 — it lists `arenaCharacterFor` under `arena_roster.dart`, and the self-check at :93 says only the allowed files changed, while the function now lives in the new `arena_character_painter.dart` and `lib/test_game.dart` was edited, both outside i1f's `allow:` → correct the file list and record the widened allow. (from: wave2)
- **should** controller_app/lib/src/ui/connect_panels.dart:82 — the join-screen badge takes the character's colour slot as its number (`settings_profile_section.dart:246` does the same), so a teal phone draws "4" and announces "Player 4" before it is player 1 → draw the number the join will get, or drop the number and its label until paired. (from: wave1)
- **should** controller_app/lib/src/providers/profile.dart:59 — the taken-notice docs still say "Blue is taken tonight, you're Teal" and that a player who changes colour while joined "sees no line, and the new colour applies on the next join", both false after i1e (the wording changed and a joined change is sent and answered), and the same old sentence is at `toy_character.dart:90` and `docs/design/party-night.md:203` → update all four. (from: across jobs)
- **should** docs/briefs/m16/identity1/i1e-report.md — the file does not exist: the hand-applied i1e has no report and no tests-first proof (run.log's HAND-FIX i1e line says both), so `identity_client_test` and `identity_phone_test` were never shown to fail on the old code → write the report, or have the batch mark them "Fixed, unverified: needs device check". (from: HAND-FIX i1e)
- **should** packages/test_game/lib/src/arena_painter.dart:82 — `ArenaPainter` now takes six parameters and `arena_marble_painter.dart:63` six, one over the guideline's five → bundle roster and characters in one value object in a job that may edit the four outside call sites. (from: wave2)
- **should** docs/briefs/m16/STATUS.md:38 — its identity1 line still says "Waves 2-3 (i1d-i1g) not started" after i1d, i1f and i1e2 were committed → replace it with the run's row (below). (from: across jobs)
- **could** packages/connection/lib/src/server_game_frames.dart:160 — `shown.length == frame.characters.length` returns the incoming frame even when a roster player's entry disagrees with the host's roster → compare the entries, or always rebuild the frame. (from: wave2)
- **could** controller_app/test/host_chip_test.dart:74 — the saved profile and the host's answer are both `tealCrown`, so a chip that read the profile would pass → change the profile after pairing so the assertion pins the host's answer. (from: i1e2 Q1)
- **could** packages/connection/test/identity_host_test.dart:158 — a real `ClientConnection` named `viewOnly` does list identity (`controller_identity.dart:52` adds it), so the `players.isNotEmpty` wait depends on that phone hearing `players` → rename it, or use a `WirePhone` hello without the capability. (from: wave2)
- **could** controller_app/test/identity_nickname_test.dart:78 — `find.text` matches the field's EditableText by construction, so "the typed text starts inside the field" cannot fail, and :81 checks only `fontSize` while the ink-coloured field text has no night case → check the painted height/decoration and add a night-clock colour assertion. (from: wave1)
- **could** controller_app/test/identity_nickname_test.dart:68 — the test scrolls the field into view before measuring, so the Settings viewport clip (the brief's 4 px) is neither fixed nor caught → measure the unscrolled screen at the finding's size. (from: wave1)
- **could** docs/briefs/m16/identity1/i1b-report.md:30 — "the M3 title size" is false (the theme's body text already was the look's body, so only the colour changed), and the host-setup answer at :85-86 lists Connect-screen states rather than the rule's setups (a joined phone, a peer one build older) → correct the line and add the one-line "none of those screens draws these words". (from: wave1)
- **could** packages/test_game/lib/src/arena_view_widgets.dart:158 — the results band now takes the winner's character colour, a visible change no brief asked for (it named the marble and the HUD dot) → get the owner's yes (i1f Q4) or revert to `colors.player(winner.number)`. (from: wave2)
- **could** packages/connection/lib/src/host_players_broadcast.dart:81 — the "identity phones only" rule is written three times (`_sendToAll`'s split, `_forSession` at :117, `capabilityFor` at host_server.dart:225) → one `takesIdentity(session)` helper. (from: across jobs)
- **could** packages/protocol/lib/src/character.dart:35 — the palette's colour words now exist twice (`PlayerCharacter.colourIds` here, `ToyCharacter.colourNames` at toy_character.dart:91), and nothing pins the two lists' order: `toy_character_name_test.dart:21` only indexes `colourNames` itself → one source, or a cross-check test. (from: i1a Q3)
- **could** packages/connection/lib/src/host_connection.dart:380 — the file ends exactly at the 380-line ceiling → split it before the next addition. (from: across jobs)

### HAND-FIX lines of run.log

- run.log:29 i1b — applied from the worktree after i1a2's base fix, 01:50; proof and review were not run then, but the log's 07:59:30 entry records tests-first ok and `i1b-report.md` exists with the wave-1 review over it → covered (late).
- run.log:48 i1e — applied after the 151-turn stop, 5 tests failing, finished by i1e2; "tests-first proof and worker review not run" and there is no `i1e-report.md` → **not covered** (the missing-report finding below).
- run.log:64 i1e2 — the brief's turn cap raised 70 → 120; no code touched → nothing to prove.
- run.log:80 i1d — applied from the worktree after the 134-turn stop; its own check failed only on `m9_test`, fixed inside i1e2; the resumed run took its proof (`identity_host_test` tests-first ok, run.log:98) and `i1d-report.md` exists, but its Q1 wording is wrong (must 2) → covered, wording to fix.
- run.log:102 i1f — the review FAIL's fix: `arenaCharacterFor` moved to the new `arena_character_painter.dart` ("exported"), arena tests pass, `review.sh` 0 fail; `i1f-report.md` exists but names the wrong home for the function and denies the two files it changed → report exists, must 1 shows the export was never committed.

Fix-job sizing (≤3 findings per job, and no two jobs share a file):

- A: must 1 — commit `arena_character_painter.dart` and the `test_game.dart` export, then `check: format analyze arena`.
- B: must 2 + the i1d-report Q1 wording — `controller_app/lib/src/storage.dart`, `packages/party_host/lib/src/host_service.dart`, `i1d-report.md`; `check: phone host` (a phone-side test that the app host's welcome lists identity).
- C: the blank-nickname "Player N", the missing i1e report, the stale STATUS line — `profile.dart`/`host_players_broadcast.dart` or `phone_text.dart`, `docs/briefs/m16/STATUS.md`; `check: phone` (phone-pinned).
- D: `protocol.md:235`, `i1f-report.md`, the join-screen badge number — `connect_panels.dart` + `settings_profile_section.dart`; `check: phone` (phone-pinned).
- E: the stale taken-notice docs (`providers/profile.dart`, `toy_character.dart`, `party-night.md`) and the two `identity_nickname_test` coulds and the i1b-report lines; `check: phone`.
- F: the two six-parameter painters, the frame shortcut, the repeated gating helper — `arena_painter.dart`, `arena_marble_painter.dart`, `server_game_frames.dart`, `host_players_broadcast.dart`; `check: arena connection`.
- G: the rest by file: `host_chip_test.dart`, `identity_host_test.dart`, `arena_view_widgets.dart`, `character.dart`, `host_connection.dart` (split it in its own job).

## Open questions

1. Blank nickname: is the owner's "Player N" about the hello name or only the TV/phone display? Suggested: keep M14's phone name in the hello (it is pinned by m14_phone_test) and treat "Player N" as the display rule, which then needs the host to send an empty name for a phone with no nickname.
2. i1c Q1: should a dropped player's pick stay reserved for the reserve minute, as the brief says? Suggested: yes for colour/accessory too; it needs the `nowMs` seam i1c Q2 asks for.
3. i1f Q4: is the results band's colour the winner's character? Suggested: yes (identity "everywhere players are drawn"), keep the test.
4. i1d Q3: should local players (TV keyboard, host phone's own player) get a `players` row with `PlayerCharacter.forPlayer(number)`? Suggested: yes, or the phone's lobby will not match the TV.
5. i1d Q5: should `players` keep an away player while the round holds their slot? Suggested: yes, same rows as the frame's `pl`, so the two lists agree.
6. i1d Q4: should a re-pairing hello's character be held during a round like `set_character`? Suggested: yes, or the protocol sentence stays false.
7. i1f Q1: which job gives `ViewContext` a characters map so a joined phone draws picks? Suggested: i1g, which owns the other viewers, with game_kit in its allow.
8. i1f Q3: a value object for roster+characters in the painters? Suggested: yes, in the same job that edits `map_flags_test`/`map_picture_test`/`look_midgame_test`.
9. i1a Q2/i1f Q2: the briefs' `check:` names (`toy_look`, `test_game`) are not `check.sh` suite names (`look`, `arena`) — the runner passes the brief's word through. Suggested: say so in the runner's brief lint; no code change.
10. i1e2 Q2: `phone_metrics_test`'s name still says "metrics and rating" while it pins six capabilities. Suggested: rename in the next phone job.
11. i1a Q3: one source for the palette words? Suggested: leave the duplicated lists (protocol cannot import toy_look) and keep the cross-check test.

## Numbers against targets

- Turn caps (briefs): i1e 151 vs 120; i1d 134 vs 120; i1e2 76 vs the driver's own 70 (a cap mistake, raised to 120). Aims: i1f 105 vs 70–100 (over by 5); i1a 66 and i1b 57 under their 80–120 aims; i1c 61 inside 60–90.
- Time: i1e2 12 min against `expected-min: 12` (met). The run's wall clock 21:34:49 → 09:35:23 (12 h 01 min) against the plan's about 2 h 05 min, from two failed combined checks and four stops; job time itself 81 min computed from run.log.
- Lines (computed): `host_connection.dart` 380 (at the ceiling), `host_server.dart` 371, `server_game_host.dart` 342, `connect_panels.dart` 372, `settings_screen.dart` 369, `messages.dart` 368, `arena_hud_widgets.dart` 327 — all within, none over.
- Parameters: `ArenaPainter` and `ArenaMarblePainter` 6 vs the guideline's 5.
- New tests (computed): 80 — protocol 12 + 3 + 4, connection 12 + 12 + 6, phone 9 + 6 + 4 + 4, arena 8. All read in the reports/run.log as green; I ran none.
- Plan: 7 jobs; the run used 8 slots (i1e replaced by i1e2) and i1g (Shape Race, score bars, badges) is not started, so the milestone's "identity everywhere" is half met.
- Diff: 134 files, 8146 insertions, 418 deletions between dd51e607 and 7598faea (includes the process3 tooling batch; see Could not check).

## Could not check

- No test suite was run in this review (read-only), so every green and every test count above rests on the reports and run.log, not on a run I made; the only things I executed were `git`, `grep` and `ls`.
- I did not make a clean checkout: the missing `arena_character_painter.dart` was confirmed with `git cat-file -e 7598faea:…` (fatal: exists on disk, not in the commit), not by analyzing from the commit.
- The tools/, `.claude/agents/` and process3 docs in the diff belong to the process3 batch and were reviewed in `docs/briefs/m16/process3/REVIEW.md`; I did not re-read them here.
- A device or a real phone at the TV look's size: the TV-look tests pump at 1180x820 (a tablet).
- i1e's own reasoning: there is no report to read.

## Commit message

review: identity1 run, two musts (arena commit, host identity)

Findings only, no code changed. HEAD cannot analyze packages/test_game
because arena_character_painter.dart and its export are still
uncommitted; neither app host lists the identity capability, so no
phone sends set_character from the apps. "Player N" stays unreachable
for a blank nickname, protocol.md's "never during one" misses a
re-pairing hello, i1f's report denies the two files it changed, and i1e
was hand-applied without a report or a tests-first proof. Ten coulds
include the six-parameter painters and one stale STATUS line.

## Status row

| identity1 (M16) | done: i1a i1a2 i1b i1c i1d i1f i1e2 committed — stable IDs and spoken names, `players`/`set_character`/frame `chars`, host gate, phone lobby/result/chip, Arena marble/HUD/band; 80 new tests per the reports | open: the uncommitted `arena_character_painter.dart` + `test_game.dart` export, `Capability.identity` in the two app host lists, the blank-nickname "Player N", the six-parameter painters, stale taken-notice docs, i1e's missing report, i1g (Shape Race, score bars, badges) not started |

## Delete

- none
