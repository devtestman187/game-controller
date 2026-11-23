# w4h report: the frame shortcut compares entries, not lengths

## Summary

- Fixed `RoundView._withCharacters` (`packages/connection/lib/src/server_game_frames.dart`). The shortcut that returned the incoming frame compared only lengths, so a frame whose roster player's character differed from the host's was sent unchanged. It now returns the incoming frame only when `shown` has the same keys and equal values as `frame.characters`; otherwise it builds the new frame as before.
- Added `packages/connection/test/frame_characters_test.dart` (new file, two tests per transport, TV and phone transports via `TestTransport.values`).
- Tests-first: before the fix, `flutter test packages/connection/test/frame_characters_test.dart` gave `+2 -2`. The failures were the disagreeing case on both transports: expected `{'phone-1': crown}` (PlayerCharacter(4, crown)), actual `{'phone-1': bow}` (PlayerCharacter(2, bow)). After the fix all 4 pass (`+4`).
- Computed values for the disagreeing case: the frame gives `phone-1: bow` (slot 2); the host's roster has `phone-1: crown` (slot 4). `shown` = `{phone-1: crown}` (length 1), `frame.characters` = `{phone-1: bow}` (length 1). The old check `1 == 1` returned the frame, so the bow went out.
- The agreeing case gives `phone-1: crown` in both, and the sent frame's `toPayload()` equals the one built from the same input.
- Checks: `tools/check.sh format analyze connection`: format PASS, analyze PASS, connection PASS (350 tests, including the 4 new ones). The whole check was run once after the fix.
- Size: `server_game_frames.dart` is 177 lines (was 172), under the 380 limit. The new test file is 84 lines.
- Decision: the agreement test checks content, not identity of the object. The old code also passes it; it guards the shortcut's fast path.
- Decision: the new check compares the maps key by key, not with `mapEquals`, to keep the connection package free of new imports.

## Self-check (docs/review-rules.md part A)

1. Host setups: a TV host and a phone host, both transports, via `TestTransport.values`. A phone on "Play on this phone" and "Show on this device" are not exercised here; this change is in the frame path shared by all views, not in the setup code. Joined phone: covered by the identity phone in both tests. Peer one build older: not in the new tests; `identity_host_test.dart` already covers it and this change does not touch that path.
2. Kept state: none added. `_frame` and `_start` are unchanged.
3. Combination with the pause menu, host away, player away, "Get ready", dropped link, results, leaving: the change only affects the content of frames built in `publish`; the paths the new states use are unchanged. Not separately tested.
4. Files: only the allowed files were changed.
5. Stopped at: nothing was blocked.
6. Looks: no UI change; not applicable.

## Hand-over

- Nothing is staged or committed. The worktree has the two code files above and this report.
- Not run: the whole workspace, `tools/mine.sh`, `tools/review.sh`.

## Commit message

Fix frame characters shortcut to compare values

_withCharacters returned the incoming frame when its characters had the
same count as the host's view, even when a roster player's entry differed,
so a stale character reached the viewer. The shortcut now also checks each
key's value. Adds frame_characters_test.dart: a disagreeing character is
replaced by the host's, and an agreeing frame is sent unchanged.

## Status row

w4h: `_withCharacters` compares values, not lengths, so a roster player's character in a frame is the host's (tests in frame_characters_test.dart pass). Open: the whole workspace check and review are not run here.

## Delete

- none
