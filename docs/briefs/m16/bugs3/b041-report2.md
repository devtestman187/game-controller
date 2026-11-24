# B-041 report (hand-finished by the driver)

Owner pick: "Phone rule where it fits". Worker (61 turns, cap 60) wrote MatchView.wholeIfNoMirror (side camera -> whole where PuzzleCamera.mirrorPlace is null), PuzzleModule passes the tablet flag as wholeIfNoMirror, and the new test match_view_whole_if_no_mirror_test.dart. Driver finished: PuzzlePlayView/PuzzleScreen pass wholeMatchProvider as wholeIfNoMirror (host tablet), puzzle_module_test and puzzle_screen_test pins, rule 6 of m12-opponent-mirror.md. controller_app untouched: its tablet flag now means "mirror where it fits, whole match where not" (1180x820 with the stick pad keeps the whole match; 1366x1024 and 1024x1366 get the mirror).
Not device-verified: the real fit with the app's real pad on an iPad.
