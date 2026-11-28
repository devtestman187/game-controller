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
Wave 2 and 3 reviews (no must): rebuild-test count unexplained (3 vs 2) - minor - code-health; new tests in existing files (G9) - minor - code-health (allow lists forced it); untilBuilt copies in map2a tests (city_painter_test etc.) and _boardFor copies - minor - code-health (map2a files are outside the m2f fence); no test for the untilBuilt timeout branch, 4-arg signature, duration message, players range assert, 5 s real-time bound - minor - code-health; report wording nits - invalid/ignored.
