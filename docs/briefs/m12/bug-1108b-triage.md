job: m12 bug 1108b triage G1 — "Host a game" freezes for about 1.6 s after a mode is picked
stop: after G1 (report only, plus the timing log lines in do 3; no other code change).
read: docs/briefs/m12/bug-1108b-frames.png (look at it as an image: the owner's iPhone recording from 1.0 s to 4.5 s at 10 frames a second, left to right, top to bottom: the tapped "Play on this phone" stays lit and the dialog doesn't move for about 1.6 s, then the picker slides in) · controller_app/lib/src/ui/connect_panels.dart (the button) · controller_app/lib/src/host/{hosting,phone_host,phone_host_setup,host_screen,host_games,host_overrides}.dart · packages/party_host/lib/src/{host_service,providers,sound}.dart · packages/party_host/lib/src/ui/games_screen.dart · the flutter_soloud 5.2.1 source in the pub cache (`init`, `loadAsset`: what runs on the UI isolate, what is a sync FFI call) · docs/briefs/m12/device-1107-session2.txt (a host start's log lines with times) · docs/review-rules.md

The owner (build 4, iPhone): "When I select a mode for hosting, the transition seems to pause for a split second." Both modes do it.

Claude's lead (unconfirmed): the dialog's close and the route's push happen in the frame where `HostScreen` first builds; it watches `gameSoundsProvider` → `soundPlayerProvider` → `SoLoud.init()` and ten `loadAsset`s. If any of that is synchronous on the UI isolate (an FFI call, iOS audio-session activation, decoding), the frame stalls and the dialog freezes mid-close. Other candidates: `PhoneHost.live` and `LiveHostService`'s constructor (prefs reads, pairings), `service.start()` before its first await, the server's bind, interface listing, Bonsoir, the puzzle library's load, the first build of the picker.

do:
1 List everything that runs on the UI isolate from the tap to the picker's first settled frame, in order, each marked sync or async and with your estimate of its cost on an iPhone, from the code (yours and flutter_soloud's).
2 Measure what can be measured here: the phone app on Windows in profile mode if it builds, or timed widget tests with the real classes where possible; say what each number is worth for an iPhone.
3 Add log lines with elapsed ms (tag `host`, short): tap → host built, service started, own player paired, sound engine init, sounds loaded, the host route's first frame. They ship in the next build so the owner's Diagnostics name the step. Tests for the lines.
4 Propose the fix, ranked, with risks: e.g. push the route first and start the host and the sounds after its transition; start the sound engine earlier (app start) or later (first round); move work off the UI isolate. Say which one removes the freeze rather than moving it to a moment the player still sees.
in the report: the ordered list, the measurements, the log lines, the ranked fixes, Questions.
self-check: docs/review-rules.md part A, items 1–5, one line each.
rules: no lib file over 400 · tools/review.sh: no FAIL on your lines · write only inside this job's folder.
allow: docs/briefs/m12/bug-1108b-triage-report.md · controller_app/lib · controller_app/test · packages/party_host
check: format analyze host phone
report: docs/briefs/m12/bug-1108b-triage-report.md
