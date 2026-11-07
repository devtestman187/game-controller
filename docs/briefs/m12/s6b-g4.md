job: m12 step6 s6b G4 — the joined view, complete
stop: after G4.
read: docs/design/m12-joined-view.md (contract: §0.1, §0.3, §0.5, §0.6, §5) · docs/briefs/m12/s6b-g3-report.md · docs/coding-guidelines.md · controller_app/lib (providers/view.dart, ui/joined_view.dart, ui/connect_screen.dart, discovery.dart, host/{host_start_sheet,hosting,phone_host,host_screen}.dart, ui/diagnostics_screen.dart, providers/connection.dart) · controller_app/test (joined_view_test, connect_screen_test, host_mode_test, diagnostics tests, support/) · packages/connection/lib/src/{viewer_stats,client_controls}.dart · packages/party_host/lib/src/host_identity.dart

Claude's corrections to your G4 plan: the host list labels are the phone's connect screen (`discovery.dart` reads TXT `kind`; `ui/connect_screen.dart` draws the list), not `host_games.dart` · the start sheet is the phone app's `host/host_start_sheet.dart`: it sets the phone host's `service.shareView` (true for "Play on this phone", false for "Show on this device"); no party_host change · the sound restart goes in `JoinedView` (an `AppLifecycleListener` `onShow` → `party.soundPlayerProvider` `restart()`, like `host_screen.dart`) · the waiting card keys off the client's own events, plus the connection state for the fallback.

do:
1 Waiting card (contract §0.3): `hostWaitProvider` in providers/view.dart → `({int? secondsLeft, int sinceMs})?`, null when not waiting. Waiting starts on (a) a `HostAway(s)` (countdown from `s` at its arrival) or (b) a view running while the client isn't connected (countdown from `hostGraceS` = 30 at the moment it dropped); it ends on `HostBack`, `ViewStarted`, `ViewEnded`, or (b) reconnecting with no `HostAway` pending. `ui/waiting_card.dart`: centred over the game, "Waiting for the host to come back" and, below, "The game goes on if they're back in 23 s" counting down once a second on the client's clock; at 0 "The host may have left". Shown only while a view is active. Use the existing `hostGraceS` (move it somewhere both `phone_host.dart` and providers/view.dart can import, if needed; one constant).
2 Abandoned notice (§0.5): a `ViewEnded` with reason `abandoned` shows "The host was away too long, so the round ended." over the controls for 4 s (key `abandonedNotice`); other reasons show nothing.
3 Host list labels (§0.6): `DiscoveredHost.kind` (`HostKind?`, from TXT `kind`; unknown or missing → null). Icon: tv → `Icons.tv`, pc → `Icons.computer`, phone → `Icons.smartphone`, tablet → `Icons.tablet`, null → `Icons.tv`. The subtitle starts with "Phone", "Tablet", "TV" or "PC" and " · " before what it shows today; nothing added for null. Heading "Games on this Wi-Fi". If `HostKind` lives only in party_host, import it `as party`; don't duplicate the enum.
4 shareView from the start sheet (above).
5 Sound restart on app show in `JoinedView` (above).
6 Diagnostics "Game view" (§5): after the existing sections, when `viewerStats?.summary` has entries: a heading "Game view" and one line per frame rate, e.g. `60 Hz: touch-to-frame 41 ms median, 58 ms p95 (1834 samples) · jitter 3/9 ms · frames 7210, late 12, gaps 0`. Also in `buildReport` (the text the owner pastes). `diagnostics_screen.dart` is 355: put the section in a new `ui/diagnostics_view_section.dart` and the report lines in a function there, so the screen file grows by at most 10 lines.

tests (controller_app):
- waiting: `HostAway(30)` → the card with "30 s"; 5 s on the client's clock → "25 s"; `HostBack` → gone. `HostAway(2)` and 3 s → "The host may have left". A view running and the fake client's state going to disconnected → the card counting from 30; connected again → gone. No view running and disconnected → no card. A `ViewStarted` clears it.
- abandoned: `ViewEnded(abandoned)` → the notice, gone after 4 s; `ViewEnded(finished)` → no notice.
- labels: hosts with kind phone, tablet, tv, pc and none → the five icons and subtitle words; the heading text. `discovery.dart` parses `kind` from TXT attributes (a unit test on the parsing function, including an unknown value → null).
- start sheet: "Play on this phone" → the fake host's `shareView` true; "Show on this device" → false.
- sound restart: hidden then shown with a view active → the fake sound player restarted once.
- diagnostics: summary entries at 60 and 30 Hz → two lines in the screen and in `buildReport`, with the numbers formatted as above; no summary → no "Game view".
- existing tests: list any expected value that changes (old → new); the heading text change in `connect_screen_test` is expected.

in the report: line counts of files touched (flag > 300), test counts per check before and after, anything in the contract you couldn't do as written.
rules: no lib file over 400 (tests 500); every party_host import is `as party`; `controller_client.dart` untouched; `diagnostics_screen.dart` grows ≤ 10 lines · tools/review.sh: no FAIL on your lines.
allow: docs/briefs/m12/s6b-g4-report.md · controller_app/lib · controller_app/test
check: format analyze phone
report: docs/briefs/m12/s6b-g4-report.md
