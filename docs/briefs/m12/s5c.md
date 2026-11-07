job: m12 step5 s5c G4 — fixes from build 1's device test (m12.1 on the owner's iPhone)
stop: after G4.
read: docs/checklists/m12.md · docs/coding-guidelines.md · packages/party_host/lib/src/{sound,providers}.dart · packages/party_host/lib/src/testing/host_fakes.dart · controller_app/lib/src/host/{host_screen,phone_host,hosting}.dart · controller_app/lib/src/ui/{controller_screen,settings_sections,diagnostics_screen}.dart · controller_app/test (host_mode_test, host_lifecycle_test, settings tests, support/)

what the owner found (Nov 7, iPhone hosting, m12.1):
1 "Sound is flakey. It worked initially then stopped." The owner had been locking and unlocking the phone (checklist: lock tests). Claude's diagnosis: iOS interrupts the app's audio when the phone locks or the app goes to the background, and the SoLoud engine doesn't recover; nothing restarts it. The phone's diagnostics also carry no host log, so a sound error can't be seen.
2 The rating prompt ("How did the controls feel?") appeared while hosting. `controller_screen.dart` has the comment "Not while hosting" over the `ratingPromptProvider` listener, but no check: the controller screen *below* the host route hears the own player's prompt since G4's client switch.
3 The setting "Controls over the game" isn't clear. It's how see-through the controls are; say it so an 8-year-old understands (owner: "Like 'controller visibility (opacity)'").

do:
1 Sound restart. `SoundPlayer` gains `Future<void> restart()`, doc: after the app was in the background, start the engine again, because iOS stops the app's sound when the phone locks or another app takes it. `SoLoudSoundPlayer.restart()`: wait for a load in progress; `deinit` if initialized; clear sources and voices; load again; log `Sound engine restarted (N of 10 sounds)`; a restart already running is shared, not doubled. `FakeSoundPlayer` counts restarts. In the phone app, the host route restarts the host's sound player when the app is shown again (`AppLifecycleListener` `onShow`, or the `HostPresence` path `PhoneHost` already drives; pick one and say which). The TV app doesn't change.
2 Rating prompt: the listener ignores a prompt while this app hosts (`_hosting || hostingProvider?.live`), matching the lifecycle guard at `controller_screen.dart:76`.
3 Wording, in `settings_sections.dart`: section "Game on this phone" keeps its title; subtitle "How much you can see the buttons when a game is behind them"; slider label "Button visibility (opacity)"; the value stays a percentage. Keep `Key('controlsOpacitySlider')`.
4 Diagnostics: while hosting, `buildReport` adds the host's log after the phone's: a line `Host log (this phone is the host):` then `party.logProvider`'s `export()`. Not while not hosting.

tests:
- party_host: `SoLoudSoundPlayer` can't run under `flutter test`; test the restart wiring with `FakeSoundPlayer` only.
- phone: hosting, then the app hidden and shown → the fake sound player restarted once; not hosting → no restart.
- phone: hosting, a rating prompt from the own player → no rating dialog (`find.text` of the prompt's title finds nothing); not hosting, a prompt → the dialog (the existing rating test still passes).
- phone: the settings section shows "Button visibility (opacity)" and the new subtitle; the slider still saves `controlsOpacity`.
- phone: `buildReport` while hosting contains `Host log (this phone is the host):` and a line the host logged; not hosting, it doesn't.
- Existing tests: no expected value changes except the slider's label text; list any old → new.

report: line counts of files touched (flag > 300), test counts per check before and after, which restart trigger you chose and why.
rules: no lib file over 400 (tests 500); `diagnostics_screen.dart` (341) may not pass 360: move `buildReport` to `diagnostics_report.dart` if it would; every party_host import in controller_app is `as party`; the TV app unchanged · tools/review.sh: no FAIL on your lines.
allow: docs/briefs/m12/s5c-report.md · packages/party_host/lib · packages/party_host/test · controller_app/lib · controller_app/test
pub: yes
check: format analyze connection metrics kit arena puzzle host phone tv
report: docs/briefs/m12/s5c-report.md
