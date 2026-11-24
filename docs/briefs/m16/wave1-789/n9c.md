job: M16 wave1-789 n9c — every slider reads its value to a screen reader (four sites)
stop: Do not write a shared helper or a new package dependency; set the callback at each of the four sites. No layout change.
read: docs/briefs/templates/COMMON.md · controller_app/lib/src/ui/gyro_dialog.dart:105-124 · controller_app/lib/src/ui/stick_dialog.dart:93-109 · controller_app/lib/src/ui/settings_screen.dart:186-262 · packages/party_host/lib/src/ui/look_and_sound_section.dart:120-169 · controller_app/test/look_prefs_test.dart (Slider finds) · packages/party_host/test/sound_settings_test.dart · decision (owner, Nov 24): "Accept all"; item 9c: the four Slider sites set no semanticFormatterCallback.
changes: semanticFormatterCallback
turns: 60
expected-min: 25
do:
1 Tests FIRST (must fail): controller_app/test/slider_semantics_test.dart opens the settings sliders and the gyro and stick dialogs and checks, per slider, that tester.getSemantics(find.byKey(key)).value equals the visible value text next to it. packages/party_host/test/volume_semantics_test.dart does the same for the music and sound volume rows (HostText.percent text). Read how an existing test opens each screen; menu look and TV look for each.
2 Add semanticFormatterCallback to each Slider: gyro_dialog.dart:122 and stick_dialog.dart:107 return the `shown` text; settings_screen.dart:240 returns `valueText`; look_and_sound_section.dart:158 returns HostText.percent of the rounded value.
3 settings_screen.dart is 369 lines: add one line at most. Report line counts of the four files.
allow: controller_app/lib/src/ui/gyro_dialog.dart · controller_app/lib/src/ui/stick_dialog.dart · controller_app/lib/src/ui/settings_screen.dart · packages/party_host/lib/src/ui/look_and_sound_section.dart · controller_app/test/slider_semantics_test.dart · packages/party_host/test/volume_semantics_test.dart
check: format analyze phone
report: docs/briefs/m16/wave1-789/n9c-report.md
