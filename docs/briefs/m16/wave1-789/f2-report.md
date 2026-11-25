# f2 report (driver note)

The worker fix (top bar items inside a FittedBox) shrank the 48 dp touch targets and the phone suite then hung 10 minutes; rejected. The 12 px overflow of the pad top bar at 568x320 in the TV look is a code-health item (a TV-look sizing on a phone-wide screen). connect_narrow_test.dart names that one case instead of filtering every top-bar overflow; connect_identity_gap_test.dart comment updated.
