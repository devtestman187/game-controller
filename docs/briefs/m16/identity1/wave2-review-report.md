# Wave 2 review (i1d, i1f, i1e2): host identity, Arena characters, phone tests

## Summary

- Verdict: **needs Claude** — i1f's commit does not build without a file it never committed, and three of its
  choices are the owner's to confirm.
- must 1 · should 3 · could 4.
- i1f's `arenaCharacterFor` lives in a NEW `packages/test_game/lib/src/arena_character_painter.dart` that is
  untracked, and its `lib/test_game.dart` export is an uncommitted edit: HEAD (b50355bf) fails to analyze
  `packages/test_game` (finding 1). Both edits are also outside i1f's `allow:`, while its report says only
  allowed files changed (finding 2).
- i1d's new protocol sentence "never during one" (protocol.md:235) is false for a re-pairing hello's
  character, which i1d's own Q4 names but the document does not (finding 4).
- Checked values: identity_host_test 6 tests × 2 transports = 12; arena_identity_test 8, every drawing test
  looping menu (`sunny`) and TV (`ToyLook.build(…, tv: true)`); host_chip_test 4 (2 address, 2 looks); line
  counts host_connection 380, host_server 371, server_game_host 342, server_game_frames 172,
  host_players_broadcast 133, arena_roster 38, arena_marble_painter 190, arena_painter 323,
  arena_hud_widgets 327, arena_view_widgets 187, arena_identity_test 368 — each as its report claims.

## Findings

- **must** packages/test_game/lib/src/arena_character_painter.dart:11 — this new file holds `arenaCharacterFor`,
  but it is untracked and `packages/test_game/lib/test_game.dart:8`'s export of it is an uncommitted edit, while
  committed `arena_roster.dart` no longer defines it and committed `arena_hud_widgets.dart:5`,
  `arena_marble_painter.dart:6` and `arena_view_widgets.dart:7` import it, so a clean checkout of HEAD cannot
  analyze the package → commit the file and the export, then rerun the arena suite from HEAD.
- **should** docs/briefs/m16/identity1/i1f-report.md:26 — the report places `arenaCharacterFor` in
  `arena_roster.dart` and lists neither the new file nor `lib/test_game.dart`, so its self-check at line 93
  ("Only the seven allowed lib files … changed") is false and both edits are outside the brief's `allow:` →
  list the two files, say why the function moved, and let Claude accept the widened allow.
- **should** docs/protocol.md:235 — "A change is allowed in the lobby and between rounds, and never during one"
  does not hold for a phone that drops and re-pairs mid-round, because `_accept` takes the hello's `character`
  at once (host_connection.dart:337), as i1d's Q4 admits → say the hello's pick is taken at once, or hold it
  like `set_character`.
- **should** packages/test_game/lib/src/arena_painter.dart:82 — `ArenaPainter` now takes six parameters (and
  `ArenaMarblePainter`, arena_marble_painter.dart:60, six), one over the guideline's five, and i1f's Q3 leaves
  it open → bundle roster and characters in one value object in a job that may edit the call sites.
- **could** packages/test_game/lib/src/arena_view_widgets.dart:158 — the results band now takes the winner's
  character colour, a visible change the brief did not ask for (it asked for the marble and the HUD dot) → get
  the owner's yes (i1f Q4) or revert to `colors.player(winner.number)`.
- **could** packages/connection/lib/src/server_game_frames.dart:160 — the
  `shown.length == frame.characters.length` shortcut returns the incoming frame, so a frame that already
  carries a character for a roster player keeps it instead of the host's roster value → compare the entries
  (or always rebuild the frame).
- **could** packages/connection/test/identity_host_test.dart:158 — `newClient(…, capabilities: viewOnly)` reads
  as a phone without the identity capability, but the client library adds identity to every hello
  (controller_identity.dart:52), so the `s.players.isNotEmpty` wait depends on that phone hearing `players` →
  name the list `identityView`, or use a `WirePhone` for a viewer that has none.
- **could** controller_app/test/host_chip_test.dart:74 — the badge and the saved profile both hold `tealCrown`,
  so a chip that fell back to the profile would pass and the test cannot show the host's answer is what wears
  (i1e2 Q1) → occupy the teal crown with a second phone first, or change the profile after pairing.

## Decisions to confirm

- i1f's new file and its `lib/test_game.dart` edit: needed to keep `arena_roster.dart` small, but outside
  `allow:` and left uncommitted (findings 1 and 2).
- i1f's winner's band colour (Q4): the brief named the marble and the dot; the results card is a third surface.
- i1f's painters at six parameters (Q3) and the joined phone still on number defaults (`ViewContext`, Q1): the
  brief's "frame's `chars`" path is not done, only the host's players.
- i1d's host apps list no `identity` (Q1: controller_app storage.dart:55, party_host host_service.dart:142), so
  the feature is dormant in the apps although every test host lists it.
- i1d's reconnecting pick ungated (Q4) and a local player's missing `players` row (Q3): both decide what a
  phone's lobby list shows.
- i1e2's chip test cannot tell the host's answer from the saved profile (Q1): the test passes either way.

## Could not check

- `docs/briefs/m16/identity1/run-findings.md` does not exist, so there were no runner entries to weigh.
- No suite was run here: "10 of the 12 failed on the old code", the arena suite's 248 green and every test
  count above rest on the three reports and run.log, not on a run I made.
- `tools/review.sh`'s notes on these lines, and the two looks at real screen sizes: not checked.
- i1e itself (the hand-applied code i1e2 fixes) was read only where the hello's capability list lives.

## Commit message

review: wave 2 i1d i1f i1e2, one must on i1f's commit

Findings only, no code changed. i1f's arenaCharacterFor moved to a new
file and a new export in lib/test_game.dart, and the wave's commits hold
neither: HEAD cannot analyze packages/test_game. Both edits are also
outside i1f's allow list, which its self-check denies. protocol.md's
"never during one" misses a re-pairing hello's pick. Lesser points: two
painters at six parameters, an unasked winner's-band colour, a frame
characters shortcut, a viewOnly client that does list identity, and a
chip test that cannot tell the host's answer from the profile.

## Status row

| identity1 wave 2 review | done: i1d, i1f and i1e2 checked against docs/coding-guidelines.md, docs/review-rules.md and their briefs (1 must, 3 should, 4 could; verdict needs Claude) | open: i1f's uncommitted arena_character_painter.dart and test_game.dart export, protocol.md's mid-round wording, the six-parameter painters, the host apps' missing identity capability, the ungated reconnect pick and the chip test's host-vs-profile ambiguity |

## Delete

- none
