1 must frame_probe.dart one public type per file - must - f1 (guideline docs/coding-guidelines.md:45 confirmed)
2 real-time wait in map view test - should - f2
3 line over 120 columns - should - f2
4 duplicate board helper - should - f3
5 unbounded size guard - could - f2
6 hook setState every frame - could - f1
7 _withoutChips copy - minor - code-health (a copyWith needs city_scene.dart, a map2a file outside the fence)
8 unchecked cast in test - could - f2
9 _untilBuilt no timeout - could - f3
10 doc wording - trivial - f1
Q chip threshold 14 vs 20 - the brief's 14 contradicted its own 360x640 case (tile 17.4); keep 20; not a rule constant. Q mounted nowhere - by design (6B).
