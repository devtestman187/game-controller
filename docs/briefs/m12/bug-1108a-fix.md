job: m12 bug 1108a fix G4 — "Show on this device" has no player of its own
stop: after G4.
read: docs/briefs/m12/bug-1108a-shot.png (the owner's iPhone, look at it as an image: "Show on this device", its own phone listed as "Not joined: P1 iPhone 6D8B", which can never join: there is no pad) · controller_app/lib/src/host/{hosting,phone_host,host_screen,host_overrides,host_start_sheet}.dart · controller_app/lib/src/ui/{connect_panels,controller_screen,controller_top_bar}.dart · controller_app/lib/src/providers/connection.dart · packages/party_host/lib/src/ui/join_screen.dart · packages/party_host/lib/src/providers.dart · docs/design/m12-host-touch.md · docs/review-rules.md

The owner (build 4): "If I say host a game and select show on this device I am now unable to join and start the game as it's expecting me to press A but the gamepad is no longer showing."

Claude's cause: `PhoneHost.start()` always pairs this phone's own player on the in-process link, and the choice is applied only after (`connect_panels.dart`: `hosting.start()` then `shareView = …`). In "Show on this device" that player has no pad, so it takes P1, is listed as not joined and can never join. Confirm, or say what you found.

Claude's rules (approved): "Show on this device" makes the phone the game's screen, like the TV: everyone joins from another phone.
A In "Show on this device" the phone pairs no own player: nothing on the in-process link, no "P1 …" on the join screen, no "(you)", and the first phone that joins is P1. The own-client seam stays null, so the bar falls back to what it shows without a player.
B The phone's bar in that mode shows no player badge (no P1): the host chip with the code, and Diagnostics. Say what it showed before and after.
C "Play on this phone" unchanged: the own player pairs and auto-joins as today.
D The choice is known before the host starts (pass it into `HostingNotifier.start`), so no own player is ever paired and then dropped.
E Nothing else in Show mode reads the own player: list every reader of the own client and `ownPlayerIdProvider` and what each does in Show mode.

do: rules A–E.
tests (each failing first): Show mode: the join screen lists no own player, a joining phone gets P1, the bar has no player badge, the in-process link has no client; Play mode: own player pairs and auto-joins as today; stop then host again in the other mode works both ways (Show → Play and Play → Show). Existing tests: list any old → new.
in the report: test counts before and after, the files changed, the readers table (E), the bar before and after.
self-check: docs/review-rules.md part A, items 1–5, one line each in the report with the test that shows it.
rules: no lib file over 400 · tests first, each failing for the bug's reason · tools/review.sh: no FAIL on your lines · write only inside this job's folder.
allow: docs/briefs/m12/bug-1108a-fix-report.md · controller_app/lib · controller_app/test · packages/party_host
check: format analyze host phone tv
report: docs/briefs/m12/bug-1108a-fix-report.md
