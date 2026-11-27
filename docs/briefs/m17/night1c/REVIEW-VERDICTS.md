# Wave 1 verdicts (9 findings, driver Nov 26)
- provider select misses endNow (night_flow_provider.dart:16) - must - f1
- provider fresh controller when played == rounds (:21) - invalid: a night with round == rounds is over, NightSave never loads it; covered by f1's isOver rule
- NightSettings const ctor lets min above max (night_settings.dart:36) - minor - code-health (tryFromJson and copyWith guard it; a const ctor cannot compare enum indexes)
- provider test real 8 s Timer (night_flow_provider_test.dart:48) - must - f1
- settings test _settle delay (night_settings_test.dart:30) - must - f2
- ring test testWidgets without tester (player_badge_ring_test.dart:34) - trivial - f2
- how-to bounds test repeats the constants (night_flow_controller_test.dart:154) - minor - code-health
- n1f report says 16 tests, 17 exist - trivial - ignored
- silent decode catch without LogSink (night_settings.dart:203) - minor - code-health with night_save.dart
