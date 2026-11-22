job: fixture changes-hit-later-wave late: a type used in a wave 1 file and in a wave 2 file
do:
1 NEW packages/p/lib/late.dart: the file that holds the new type.
changes: NewThing (sibling of the new Thing: every switch and list over Thing)
allow: packages/p/lib/late.dart
report: batch/late-report.md
