job: night1a n1b — stub caption consumer and a full-night flow test
stop: no UI, no voice, no wiring into the controller or party_night.dart; do not edit night_flow.dart (it is the contract: if it misses something, say so in the report)
read: docs/briefs/templates/COMMON.md · packages/party_host/lib/src/night/night_flow.dart (whole file, written by n1a this batch) · packages/party_host/test/night_flow_test.dart (n1a's test, for the style) · plan, quoted: "A stub caption consumer turns each event into a plain caption string, with tests. Thumby (P4) replaces the stub; it does not edit the controller, the state machine or the event type."
changes: NightCaptions · captionFor
model: sonnet
turns: 50
expected-min: 25
tests-first: exempt the consumer is new and its test feeds a whole night: the first run of the test is the red step
do:
1 New packages/party_host/lib/src/night/night_captions.dart (under 150 lines, pure Dart): `String captionFor(NightEvent event)`, an exhaustive `switch` over the sealed NightEvent (no default), returning a short plain English caption per event, built from facts only: round numbers, "last round", "doubled points", "avatar <id>" for joined and left, and a reason phrase per NightReason. Never a nickname. A doc comment: "Stub: Thumby (P4) replaces this; the event type does not change."
2 New packages/party_host/test/night_captions_test.dart: (a) a full 3-round night: a list of the legal events in order including a skip, a reroll, a pause and resume, a player joining between rounds and one leaving, and the last-round doubling; fold them through NightFlow.apply (every step must be legal) and collect captionFor each; assert the exact caption list. (b) every one of the 14 event kinds gives a non-empty caption (build one of each). (c) no caption contains a nickname-like field: feed avatar ids such as 'a1' and assert the caption holds the id and nothing else personal. (d) the last-round captions say "last round" and the doubling caption says "double".
3 Report: any event the flow could not express, and the caption list.
4 Before finishing run `dart analyze` on the files you changed and fix every info, warning and error.
allow: packages/party_host/lib/src/night/night_captions.dart · packages/party_host/test/night_captions_test.dart
check: format analyze party_host
report: docs/briefs/m17/night1a/n1b-report.md
