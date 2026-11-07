# M12 step 3a — G2 report: view messages, the viewer's timing and stats

Job: [s3a-g2.md](s3a-g2.md). Contract: [../../design/m12-sessions.md](../../design/m12-sessions.md) §1, §2 ("The
controller side"), §4 "Playout" and "Measurements".

## Stopped: the three view messages don't fit the sealed `Message` without two G4 files

`Message` is `sealed` (`packages/protocol/lib/src/messages.dart:27`). Adding three subtypes
(`ViewStartMessage`, `FrameMessage`, `ViewEndMessage`) makes the two exhaustive switches over it non-exhaustive, and the
Dart compiler then refuses to build the `connection` package:

```
error - packages/connection/lib/src/client_messages.dart:38:5 - The type 'Message' isn't exhaustively matched by the
        switch cases since it doesn't match the pattern 'ViewStartMessage()'. - non_exhaustive_switch_statement
error - packages/connection/lib/src/host_connection.dart:213:5 - The type 'Message' isn't exhaustively matched by the
        switch cases since it doesn't match the pattern 'ViewStartMessage()'. - non_exhaustive_switch_statement
```

Both files are on the brief's `stop:` list (G4: "Don't touch … HostConnection, ControllerClient or client_messages.dart").
The brief expected the pieces to be "self-contained, so checks pass"; they are not, because any new `Message` subtype is
seen by those two switches. The brief's contract therefore can't be met inside `allow:` as written, so I stopped there
(coding-guidelines §11) and did not work around it (making `Message` non-sealed, or decoding the view types to `null`,
would both change the contract).

The smallest fix, for a later brief that allows the two files (or for G4, which owns them anyway):

```dart
// client_messages.dart:38, next to the last case
      case ViewStartMessage() || FrameMessage() || ViewEndMessage():
        // G4 routes these to ControllerClient.view instead of logging them.
        _host.log('Ignoring unexpected ${message.type} from the TV');

// host_connection.dart:213, next to the last case
      case ViewStartMessage() || FrameMessage() || ViewEndMessage():
        close(CloseCodes.protocolError, 'Unexpected ${message.type}');
```

I verified the rest of the job with exactly those two cases added temporarily: all 199 `connection` tests pass, 23 of
them new (see *Checks*). The cases were then removed and `git status` shows both files unmodified — the diff does not
touch them.

## What changed, file by file

| File | Lines | What it holds |
| --- | --- | --- |
| `packages/protocol/lib/src/messages.dart` | 354 (was 353) | only the `part 'view.dart';` line |
| `packages/protocol/lib/src/view.dart` | 193 (new) | `ViewStartMessage` (`game`, `sv`, `setup`, `hz`), `FrameMessage` (`n`, `at`, `s`, `snd` omitted when empty, `acks`, `pl`), `ViewEndReason` (`finished`, `quit`, `abandoned`, `all`) and `ViewEndMessage`; the field readers `_objectField`, `_intMapField`, `_rosterField` (private: they stay inside the library) |
| `packages/protocol/lib/src/codec.dart` | 72 (was 69) | the three decoders registered |
| `packages/protocol/lib/src/metrics.dart` | 220 (was 166) | `MetricsMessage.maxStageSamples = 256`, optional `stages` (`Map<String, List<int>>`, omitted when empty, unknown stage names kept, more than 256 per stage rejected) and `view` (`({int frames, int gaps, int late})?`, wire `view: {frames, gaps, late}`, omitted when null); `_stageSamples` and `_viewCounts` decode them. Existing fields, their order and their tests untouched, so old batches decode as before |
| `packages/protocol/lib/src/capabilities.dart` | 117 (was 116) | `Capability.view` loses "Reserved": a controller that lists it gets view_start, frame and view_end |
| `packages/protocol/test/view_test.dart` | 335 (new) | 29 tests: view messages, every field's `FormatException`, the size budget, the unknown type, the metrics fields |
| `packages/connection/lib/src/game_types.dart` | 95 (was 85) | `LatencyStage.touchToFrame` and `frameJitter` with the §4 definitions; the class comment drops "frame drawn on a joined phone" from the future list (it is here now) |
| `packages/connection/lib/src/viewer_timing.dart` | 153 (new) | `ViewerTiming` (base, lateness, nearest-rank p95, clamped delay, `renderAtMs`, `reset`) and `PlayoutBuffer<T>` (`add` in order, `pick`, `clear`, `length`), both from §4 |
| `packages/connection/lib/src/viewer_stats.dart` | 140 (new) | `ViewerStats`: `inputSent` (last 256), `frameArrived` (gaps, frame_jitter), `frameDrawn` (frames, late, touch_to_frame), `drain` (capped, keeps the acked seq and sent times), `reset` |
| `packages/connection/lib/connection.dart` | 35 (was 33) | exports `viewer_stats.dart` and `viewer_timing.dart` |
| `packages/connection/test/viewer_timing_test.dart` | 158 (new) | 15 tests: the brief's (A)–(G) and the `PlayoutBuffer` cases |
| `packages/connection/test/viewer_stats_test.dart` | 107 (new) | 8 tests: touch_to_frame, gaps, late/frames, the drain cap, reset |

New files are all under 300 lines; nothing in `lib/` is over 300 except `messages.dart` (354, pre-existing and 1 line
bigger by the `part` line the brief requires). No `DateTime.now`, no `Timer`, no `Future.delayed`, no `dynamic`, no `print`
in the new code: every time is passed in. Every parameter list is at most 5. `ViewerTiming`/`PlayoutBuffer`/`ViewerStats`
are pure Dart with no Flutter import.

Constants instead of bare numbers: `ViewerTiming.defaultWindowMs` (2000), `delayPercentile` (95), `PlayoutBuffer` none;
`ViewerStats.simStepHz` (60), `gapStrideFactor` (1.5), `lateDrawMs` (25), `maxRememberedInputs` (256), and
`MetricsMessage.maxStageSamples` (256).

## Computed test values

Clock offset 5000 in every timing case, so a frame's skew is `5000 + network`.

| Case | Arithmetic | Expected |
| --- | --- | --- |
| (A) 10 frames, `at = 16n`, network 30 | skew 5030 for all; base = min skew | base 5030, every lateness 0, delay 0, `renderAtMs(5190)` = 5190 − 5030 − 0 = **160** |
| (B) as (A), n = 5 arrives 12 ms later | skew 5042, base stays 5030, lateness 5042 − 5030 | `addFrame` returns **12**; nearest rank of `[0×9, 12]` is index ⌈0.95 × 10⌉ − 1 = 9 → delay **12** (clamp 33.33 not reached) |
| (C) as (B), then n = 10…140 steady | newest arrival 140 × 16 + 5030 = 7270; window keeps arrivals > 7270 − 2000 = 5270; the late frame's arrival 5122 is out | base 5030, delay **0** |
| (D) 20 frames, one 12 ms late | 19 zeros and one 12; rank index ⌈0.95 × 20⌉ − 1 = 18 → the 19th smallest | delay **0** (this is what separates nearest rank from interpolation) |
| (E) 10 frames, two 50 ms late | rank index ⌈9.5⌉ − 1 = 9 → 50; clamp to 2 × 1000 / 60 = 33.333 | **33.33** (±0.01); with `maxPlayoutFrames: 0`, the clamp is [0, 0] → **0** |
| (F) n = 0…4 at 30 ms, then a frame at 80 with network 20 | new skew 5020 becomes the base; that frame's lateness 0 | base **5020**; the next 30 ms frame returns 5030 − 5020 = **10**, delay **10** |
| (G) reset(hz: 30) | window cleared | base null, delay 0, `hz` 30 |
| PlayoutBuffer, frames at 0/16/32 | `pick(8)`: 0 ≤ 8 < 16, t = 8 / 16 | a 0, b 16, t 0.5 |
| | `pick(16)` drops the frame at 0 | a 16, b 32, t 0 |
| | `pick(40)`: at or after the newest, so it holds at it | a 32, b null |
| | `pick(-5)` on a fresh buffer (before the oldest) | a 0, b null, t 0 |
| | `pick(20)` then `length`, then `pick(8)` | a 16, b 32, t 0.25; length 2; then a 16, b null |
| | empty buffer / `add` at 32 twice | null / length 3, the second 32 ignored |
| touch_to_frame: seqs 1@100, 2@110, 3@120 | ack 2 at 150: highest newly acked seq 2, sent 110 | **40** |
| | ack 2 at 166 (not above the acked 2) | nothing |
| | ack 3 at 182: 182 − 120 | **62** (so `[40, 62]`) |
| | ack 5 at 200: 4 and 5 were never remembered | nothing (the acked seq still becomes 5) |
| | ack null at 216 | nothing |
| gaps at 60 Hz, n 0, 1, 2, 4 | stride 1, limit 1.5; 4 − 2 = 2 > 1.5 | **1** |
| gaps at 30 Hz, n 0, 2, 4, 7 | stride 2, limit 3; jumps 2, 2, 3; 3 is not > 3 | **0** |
| gaps at 30 Hz, n 0, 2, 6 | 6 − 2 = 4 > 3 | **1** |
| late: draws at 0, 16, 50 | 16 − 0 = 16 ≤ 25; 50 − 16 = 34 > 25 | frames 3, late **1** |
| drain of 1000 samples 0…999 | `i * 1000 ~/ 256` for i = 0, 1, …, 255 → 0, 3, …, 255 × 1000 ~/ 256 = 996 | 256 samples, first **0**, second **3**, last **996**; a second drain is empty |

## On the wire

`FrameMessage(n: 42, atMs: 672, snapshot: {'v': 1, 't': 61000}, sounds: ['snap'], acks: {'p1': 12},
roster: {'p1': (1, 'Ada'), 'p2': (2, '')})` encodes to:

```json
{"v":1,"t":"frame","n":42,"at":672,"s":{"v":1,"t":61000},"snd":["snap"],"acks":{"p1":12},"pl":{"p1":[1,"Ada"],"p2":[2,""]}}
```

`snd` is absent when there are no sounds; `acks` and `pl` are always sent, as `{}` when empty; a roster name is `""` when
the player has none. The size test's 4-player frame (20 pieces on each of two boards) has a 1829-byte snapshot and
encodes to **2011 bytes**, under the 2500-byte budget. `view_start` is
`{"v":1,"t":"view_start","game":"shape_race","sv":1,"setup":{…},"hz":60}`; `view_end` is
`{"v":1,"t":"view_end","reason":"finished"}`; a metrics batch with samples is
`{…,"data":{},"stages":{"frame_jitter":[0,12,3]},"view":{"frames":60,"gaps":1,"late":2}}`, and both keys are left out
when empty.

## Checks

`tools/check.sh format analyze protocol connection`:

| Check | Result |
| --- | --- |
| format | **PASS** (12 files formatted; the 3 changed by the formatter are all mine) |
| analyze | **FAIL** — the two `non_exhaustive_switch_statement` errors above, both on lines this job must not touch; the one `info` (`metrics/lib/src/segment.dart:319`) is pre-existing and on an untouched file (`dart analyze packages/metrics` alone exits 0) |
| protocol | **PASS** (102 tests; 73 before, 29 new) |
| connection | **FAIL** — the package doesn't compile because of those two switches; no test runs |

With the two stand-in cases from the top of this report applied temporarily (and then reverted): `dart test` in
`packages/connection` passes **199 tests** (176 before, 23 new), including the 8 real-socket suites. Nothing else in the
package changes behaviour: the new code is only exported, never called yet.

`tools/review.sh`: **0 fail, 1 note** — the note is `messages.dart 354 lines`, pre-existing growth (353 before this job;
the brief's `part` line is the +1).

## Questions and things I wasn't sure about

1. **Unblocking the messages**: allow the two files (or one of them) in the next brief, or write the two cases yourself
   before committing — they are 5 lines in total and G4 needs them anyway. Until then `analyze` and `connection` fail.
2. **`docs/protocol.md`**: coding-guidelines §8 says every protocol change updates it in the same commit. It is not in
   `allow:` and §7 of the design puts the "Viewing the game (M12)" section in G4, so I left it alone. Flagging it so the
   commit isn't taken as done without it (or add it to the G4 brief).
3. **`touch_to_frame` when the ack matches nothing remembered**: I move the acked seq to `ackSeq` anyway (ack 5 at 200 in
   the brief's case), so a later frame acking 4 or 5 records nothing rather than an older measurement. The contract's
   "then `lastAcked = ackSeq`" reads that way; say if it should only move when a sample is recorded.
4. **`FrameMessage.atMs`' name**: the wire key is `at` (contract) and the field carries ms, so I named the field `atMs`
   and `ViewStartMessage.snapshotVersion` for `sv`, following the repo's unit-in-name rule. Both are trivially renameable
   if the contract names them differently.
5. **`MetricsMessage.view`** is the record type the brief gives, `({int frames, int gaps, int late})?`, not a class: it
   keeps the payload a plain map and the message stays small. `==` on it works by value.
6. **The size test's snapshot** is built in the test (two boards, 20 pieces each) because `protocol` can't depend on
   `puzzle_game` to make a real `MatchSnapshot`. It is 1829 bytes, so it stands in for the 4-player Shape Race frame the
   contract describes; a test in `puzzle_game` with the real snapshot is still worth having in s3b.
7. **Shared decode helper**: `_objectField` lives in `view.dart` and `metrics.dart` uses it (same library, part files
   share scope). It is private, so `protocol.dart`'s export list needs no `hide` entry and the public surface is
   unchanged.
8. **`ViewEndReason.all`** is public for the decoder's validation and for callers that check a reason; it mirrors
   `RatingTag.all`. Tell me if `protocol.dart`'s surface should stay at the three constants only.
9. The working tree already had `docs/design/m12-sessions.md` and `tv_test_app/windows/flutter/generated_*` modified
   before this job started; I didn't touch them.

## Commit message

Add the view messages and the viewer's timing and stats (m12 s3a G2)

- protocol: ViewStartMessage, FrameMessage and ViewEndMessage in a new part file, registered in the codec;
  MetricsMessage gains optional stages and view counts, capped at 256 samples per stage.
- Capability.view loses "Reserved"; LatencyStage gains touch_to_frame and frame_jitter.
- connection: ViewerTiming and PlayoutBuffer turn frame arrivals into a playout delay and a render time;
  ViewerStats collects touch_to_frame, frame_jitter, gaps and late draws for one metrics batch.
- 29 new protocol tests and 23 new connection tests, with the brief's computed values.
- Stopped at G2: the new sealed Message subtypes leave two exhaustive switches in the G4 files
  (client_messages.dart:38, host_connection.dart:213) non-exhaustive, so analyze and connection fail until they
  gain a case each.

## Status row

| 3 Sessions — s3a G2 | **Stopped, needs a decision**: protocol view messages (`view.dart`), `MetricsMessage.stages`/`view`, `LatencyStage.touchToFrame`/`frameJitter`, `ViewerTiming`, `PlayoutBuffer` and `ViewerStats` are written and verified (protocol 102 tests PASS; connection 199 tests PASS with a stand-in for the two switches), but the new sealed `Message` subtypes break the exhaustive switches in `client_messages.dart:38` and `host_connection.dart:213` (G4 files), so `analyze` FAILs and `connection` can't compile. Open: those two cases, `docs/protocol.md`'s "Viewing the game" section, the rest of s3a G4 (client `view` stream, `GameHost` members, server wiring) |

## Delete

- none
