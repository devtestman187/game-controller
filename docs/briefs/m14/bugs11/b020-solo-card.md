job: M14 bugs11 b020-solo-card: a one-player night's Bumper Round shows the waiting card again, with its map choice (B-020)
pub: no
stop: after it. No Next-map button yet (a separate proposal, b020-next-map).
read: packages/party_host/lib/src/ui/solo_skip.dart · packages/party_host/lib/src/ui/game_screen.dart (_alone, _stageBody, _start) · packages/party_host/lib/src/ui/arena_waiting_card.dart · docs/design/party-night.md (N6, section 7b, section 8) · tests the change could break: packages/party_host/test/solo_skip_test.dart, night_round_test.dart, night_reveal_test.dart, arena_night_test.dart, arena_touch_ready_test.dart, arena_waiting_test.dart (while working run only `flutter test` on your files plus these; the full `tools/check.sh host` runs once, at the end)
decide: low-usage mode: never stop for a question. Make the safest choice that fits the design and list each under "Decisions" with one line of why. Stop only if the job truly cannot be done; then say why under "Blocked".

Owner row B-020 (build m14.3, Arena, Major): "Single player arena does not show map selection or game type (bumper or arena) anymore. The requirement is to show the map and game type selection." Cause: B-002 (d4b8731) made a night's one player start the Bumper Round at once (SoloRoundStart), so the card with its map choice never shows. Outside a night the card already shows.
Design:
1 TEST FIRST, new file packages/party_host/test/solo_arena_card_test.dart (must fail on the old code): a one-player night entering the Arena shows ArenaWaitingCard (map choice present, Surprise me first as for a night), and no round starts until Start is pressed; two players and a non-night one player unchanged.
2 Fix: the Arena no longer skips its card for one player (remove the `_alone` branch and SoloRoundStart; delete solo_skip's Arena part). Shape Race's solo skip (its puzzle pick straight to a solo board) stays. skipsLobby stays for Shape Race only; update its doc comment.
3 Update the pins your change breaks (tests that assumed the card-less start) keeping their intent. Update party-night.md N6 and section 8 to say the Arena's card always shows. Game type: the night's card keeps its Bumper-only mode button (section 8: points need the Bumper Round); say so under Decisions and in the Summary as an open owner question ("show both modes in a solo night?").
in the report: start with `## Summary` (at most 30 lines, within its first 40 lines): what changed, test counts you saw, decisions, the open question. End with `## Hand-over`. Do not claim a test passes unless you ran it in this job and saw it.
self-check: docs/review-rules.md part A, items 1-5, one line each in the report with the test that shows it.
tests: each new test goes in a NEW test file and must fail on the code as it was (the runner proves it and stops otherwise). await every async side effect before teardown.
rules: aim for 80-150 turns · no lib file you touch may end over 380 lines: split it (the runner stops the run otherwise) · write only inside allow: · stage nothing yourself · never use git add -A · tools/review.sh: no FAIL on your lines.
allow: docs/briefs/m14/bugs11/b020-solo-card-report.md · docs/design/party-night.md · packages/party_host/lib/src/ui · packages/party_host/test
check: format analyze host phone
report: docs/briefs/m14/bugs11/b020-solo-card-report.md
