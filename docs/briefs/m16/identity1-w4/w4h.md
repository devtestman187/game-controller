job: M16 w4h the frame shortcut compares entries, not lengths
pub: no
turns: 30
expected-min: 20
stop: after RoundView._withCharacters. No other change.
read: docs/briefs/templates/COMMON.md · packages/connection/lib/src/server_game_frames.dart:140-172 (_withCharacters) · packages/connection/test/identity_host_test.dart:1-60 (harness to copy) · packages/protocol/lib/src/character.dart (PlayerCharacter equality)
changes: _withCharacters
decisions (REVIEW.md could): `shown.length == frame.characters.length` returns the incoming frame even when a roster player's entry disagrees with the host's roster.
do:
1 `_withCharacters`: return the incoming `frame` only when `shown` has the same keys and equal values as `frame.characters`; otherwise build the new FrameMessage as now.
2 New test packages/connection/test/frame_characters_test.dart (fails on old code): a frame whose `characters` has a roster player's entry that differs from the host's character reaches the viewer with the host's; a frame that already agrees is sent with the same content.
3 Report: one line.
allow: packages/connection/lib/src/server_game_frames.dart · packages/connection/test/frame_characters_test.dart · docs/briefs/m16/identity1-w4/w4h-report.md
check: format analyze connection
report: docs/briefs/m16/identity1-w4/w4h-report.md
