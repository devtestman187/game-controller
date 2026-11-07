job: m12 cleanup c1b G4 — the connection tests' "nothing was sent" checks look at the wire
stop: after G4 (these test fixes only). No change in packages/connection/lib.
read: docs/briefs/m12/c1-g4-review-report.md (the findings) · packages/connection/test/helpers.dart (rawPeer and the round trip) · packages/connection/lib/src/client_messages.dart · docs/coding-guidelines.md §9

why: the c1 review found two checks that pass whether or not the host sends the message, because the phone ignores it anyway. The rule they test is the host's ("don't send X to a phone that can't use it"), so they must look at what the host sends.

do:
1 haptic_test.dart (~line 55, the unpaired phone): prove the host sent no haptic event to the unpaired phone by what arrives on the wire, with a raw peer (rawPeer, or the test Connector) in that phone's place, followed by a round trip that proves the channel is drained. Keep the `sendToAll(...)` count check.
2 m10_test.dart (~line 73, the client without the layout and status capabilities): the same, for layout and status messages.
3 Every new `firstWhere`/`first` wait from c1 without a timeout (m9_test.dart ~65, ~112; m10_test.dart ~28, ~38, ~52, ~163) gets `.timeout(const Duration(seconds: 5))`, like the others.
4 m10_test.dart ~150 ("two samples"): tie the wait to what the test is about (the 50 ms `minPressMs` window has passed by the host's own measure, or a round trip sent after the window), not to the heartbeat's 100 ms; say how in the report.
5 Each fixed test must fail if the rule broke: show it by temporarily breaking the rule in your head and saying which expectation would fail (don't change lib/ to try it).

rules: test files only · same test names and counts · no `Future.delayed` added · `tools/review.sh`: no FAIL on your lines.
allow: packages/connection/test
check: format analyze connection
report: docs/briefs/m12/c1b-g4-report.md
