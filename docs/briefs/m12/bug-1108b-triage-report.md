# m12 bug 1108b — triage (G1)

*Triage only: this report, the six log lines that name the start's steps, and their tests. No behaviour change.*

The freeze happens on the frame in which the mode sheet is closed and the picker is pushed: the sheet's
`Navigator.pop` and the route's `Navigator.push` happen in the same event-loop turn, so the frame that removes the
sheet is also the frame that first builds the host route (`HostScreen` → `gameSoundsProvider` → `soundPlayerProvider`
→ `SoLoudSoundPlayer.load()` → `SoLoud.init()`). Anything long and synchronous in that build holds the whole frame,
which is exactly the picture in `bug-1108b-frames.png`: the sheet stays painted, nothing moves for ~1.6 s, then the
picker slides in normally. The app's own Dart work measured here is far below 1.6 s; the sound engine is the
remaining suspect and is the one thing this machine cannot run.

## 1. Tap → the picker's first settled frame, in order

`s` = runs synchronously on the UI isolate before the next frame can be drawn; `a` = async (awaited, resumes later);
`a→s` = async, but its continuation runs on the UI isolate and costs the frame it lands in.

| # | What runs | Where | s/a | Cost on an iPhone (estimate) |
| - | --- | --- | --- | --- |
| 1 | "Play on this phone" `onPressed` → `choose()`: `hostStartLog.tap()` (one clock read + one log line), then `Navigator.pop(choice)` | `host_start_sheet.dart:26,43,52` | s | <1 ms. Marks the sheet gone; no frame drawn yet |
| 2 | The sheet's route result completes; `await showHostStartSheet` resumes | `connect_panels.dart:87` (sheet at `host_start_sheet.dart`) | a (microtask) | 0 ms |
| 3 | `hosting.start(playsHere:)` builds `PhoneHost.live`: `InProcessListener`, `LiveHostService`, `ControllerClient` (no I/O), sets `shareView`, `ownClientProvider.set`, `gameShownProvider.set`; logs `host built`; `unawaited(host.start())` | `connect_panels.dart:91`, `hosting.dart:24-27`, `phone_host.dart` | s | ~10–20 ms (12 ms measured on Windows) |
| 4a | `service.start()` → stats: `_directories.sessions()` (path_provider platform channel) + file work | `host_service.dart:215-224` | a | 5–30 ms, off the frame |
| 4b | `HttpServer.bind` (port listen) | `host_service.dart:226` | a | 1–5 ms |
| 4c | `_refreshAddresses` → `NetworkInterface.list` | `host_service.dart:233,329` | a→s (parse) | 2 ms measured on the owner's phone (1107 log); 10–100 ms on iOS, the enumeration is the slow part |
| 4d | `_startAdvertising` (bonsoir / mDNS) | `host_service.dart:236,326` | a | **646 ms measured on the owner's phone** (1107 log, "Addresses" → "Advertising"); 100–600 ms on iOS |
| 4e | Each 4a–4d continuation lands between frames and costs its own few ms (log line, `_emit`, listeners) | — | a→s | a few ms each, several chances to stutter |
| 5 | `Navigator.push(MaterialPageRoute → HostScreen)` — schedules the route, slide starts at the next frame | `connect_panels.dart:92` | s | <1 ms; the slide itself is a normal 300 ms transition |
| 6 | That frame's build of `HostScreen`: `gameSoundsProvider` → `soundPlayerProvider` constructs `SoLoudSoundPlayer` and calls `unawaited(load())`; `keepAwakeProvider` (wakelock channel); `ControllerMenus`, `ControllerScreen`, `HostGames` build the picker and its thumbnails | `host_screen.dart:56-75`, `providers.dart:222,265` | s | 20–60 ms for the widget tree (image decodes included) |
| 7 | `SoLoud.init()` — flutter_soloud 5.2.1 creates the engine and opens the audio device (AVAudioSession/CoreAudio on iOS) | `sound.dart:96` | a, but its native part runs on the calling thread | **the suspect for the bulk: 0.3–1.2 s** in profile, more in debug (inferred, see Questions 1) |
| 8 | `findSound` × 10 — each re-loads and re-parses the whole `AssetManifest.bin` (`AssetManifest.loadFromAssetBundle`) | `sound.dart:106` → `assets/lib/asset_manifest.dart:51` | a→s | ~1–4 ms each: 10–40 ms, all of it redundant |
| 9 | `soloud.loadAsset` × 10 + `getLength` — OGG decoded to PCM | `sound.dart:111-114` | a, part on the calling thread | 20–150 ms; files are 5–14 KB, so no raw-decode story for 1.6 s on its own |
| 10 | Logs `sound engine init`, then `sounds loaded` | `sound.dart:102,120` | s | <1 ms |
| 11 | Logs `first frame` at the route's first frame (start of the slide) | `host_screen.dart:46-48` | s | <1 ms |
| 12 | The slide runs its 300 ms; nothing else is scheduled for it, so the settled frame is 300 ms after #11 | framework | — | 300 ms, by design |

The async service start (4a–4d) overlaps all of this: in the widget test the picker's first frame (125 ms) comes
*before* the service finishes (263 ms) and before the own player pairs (284 ms) — the phone is usable before it is
fully hosting, which is why the owner sees a freeze and not a "waiting" screen.

## 2. Measurements, and what each is worth on an iPhone

**Timed widget test** (`controller_app/test/host_start_log_test.dart` and the temporary
`controller_app/test/scratch_start_timing_test.dart`), Windows desktop, `flutter test`, the real
`PhoneHost.live`/`LiveHostService` but the fake sound player, four runs:

| line | ms (run 1 / others) |
| --- | --- |
| `tap` | 0 (by definition) |
| `host built` | 12 / 12 |
| `first frame` | 125 / 125–129 |
| `service started` | 263 / 263–279 |
| `own player paired` | 284 / 284–301 |
| whole `enterHostMode` helper (wall clock) | 425 / 425–441 |

Worth for an iPhone: **the shape, not the numbers.** `flutter test` is JIT with a test harness pacing the pumps, so
these are upper bounds on the Dart work that a phone would also do, and they say plainly that the app's own code
between the tap and a built picker is a few tens of ms — two orders of magnitude short of 1.6 s. They also say the
start's ordering (tap < host built < service started < own player paired) and that the picker's first frame does not
wait for the service.

**Device log from a real phone** (`docs/briefs/m12/device-1107-session2.txt`, the same start path): "Listening on
port" 25.747 → "Addresses" 25.749 (+2 ms) → "Advertising" 26.395 (+646 ms) → own player "connected (pairing code)"
26.396 (+1 ms). Worth: the service's own start is ~650 ms on a phone and is almost entirely the mDNS advertising,
which is asynchronous — it can cost frames through its continuations but cannot by itself hold one for 1.6 s.

**Not measured, and why:**
- The sound engine. `flutter test` needs `TestWidgetsFlutterBinding`, so `SoLoud.init()` throws
  `MissingPluginException` there; a `dart test` in `party_host` has no plugin either; and building and running the
  phone app on Windows would mean starting an app, which this job forbids (and Windows audio would not predict
  CoreAudio). The two sound lines are therefore proven by the unit test (`packages/party_host/test/host_start_log_test.dart`
  with an injected clock), not timed here.
- flutter_soloud 5.2.1's `init`/`loadAsset` source. It is in the pub cache outside this working tree and every read
  of it was refused by the sandbox; I did not try to work around that. Item #7 is inference from the API and the
  freeze's shape, not from the package's code.

## 3. The log lines (ship in the next build; the owner's Diagnostics name the step)

One line per step, tag `host`, format `Host start: <step> <ms since the tap> ms`:

| line | written at |
| --- | --- |
| `Host start: tap 0 ms` | `host_start_sheet.dart:27` — both mode buttons, before the sheet pops |
| `Host start: host built 12 ms` | `hosting.dart:27` — after `PhoneHost.live` returns |
| `Host start: service started 263 ms` | `phone_host.dart:122` — after `service.start()` returns |
| `Host start: own player paired 284 ms` | `phone_host.dart:153` — the own client's first connected snapshot, once |
| `Host start: sound engine init 1057 ms` | `sound.dart:102` — after `soloud.init()` |
| `Host start: sounds loaded 1377 ms` | `sound.dart:120` — after the last `loadAsset` |
| `Host start: first frame 1567 ms` | `host_screen.dart:47` — the host route's first frame |

`HostStartLog` (`packages/party_host/lib/src/host_start_log.dart`, provider `hostStartLogProvider` in
`packages/party_host/lib/src/providers.dart`) holds one monotonic clock per start: nothing is logged before a tap
(the TV's host start logs no line at all), and a second start counts from its own tap. A sound restart after the app
was hidden is not a start and logs no step. If the server fails to start, `service started` is still written when
`service.start()` returns; the service's own "The server could not start" line follows immediately.

Widget-test output, in log order (the fake sound player here, so no sound lines):

```
Host start: tap 0 ms
Host start: host built 12 ms
Host start: first frame 125 ms
Host start: service started 263 ms
Host start: own player paired 284 ms
```

## 4. Fixes, ranked

**F1 — Warm the sound engine once, at app start, after the first frame.** *(recommended; removes the freeze)*
Build `soundPlayerProvider` at the app root (or `ref.read` it from a `addPostFrameCallback` in `main`'s first screen),
so `load()` runs in an idle moment instead of in the tap's frame; a host start then finds `_loading` already done.
Takes the engine's 0.3–1.2 s summary estimate out of the start entirely, for every start, not just the first.
Risks: the audio session stays open for the app's life on iOS (battery, and it can interrupt music the player has
going); needs the existing `restart()` on show to stay correct; adds ~1 s of work to app start, where a stutter is
less visible but not free.

**F2 — Load the sounds at the first round, not at the route.** *(removes the per-file part)*
The picker plays no sounds; `gameSoundsProvider` could load on the first `GameSounds` event (the "Get ready" beat is
3 s). Removes item #8/#9 from the tap, but **not** #7 unless combined with F1 — the engine init is what the tap
should not wait for. Risk: a sound asked for before the load finishes is dropped (`_sources` empty) — the 3 s beat
hides this, but the picker→round transition has to be tested.

**F3 — Push the route first, start the host and the sounds after the slide.** *(moves the freeze; not alone)*
Cheapest to write (`addPostFrameCallback` around `hosting.start`), but the 1.6 s then happens with the picker on
screen: the same freeze in plain sight, at the exact moment the player is looking at the games. Do not ship alone.

**F4 — Move the engine work off the UI isolate.** *(would remove it everywhere)*
If flutter_soloud 5.2.1 can run its engine on its own isolate (newer versions have an `isolate` option; unverified
here), #7 and #9 disappear for every path, TV included. Risk: an API that may not exist in this version, playback
differences to re-test, and a bigger diff than this bug warrants today.

**F5 — Shrink the work.** *(cheap, low risk, partial)*
`findSound` re-reads the asset manifest ten times for a set of files that is fixed in `soundFiles`; read it once (or
skip it — everything in `audio/` is bundled by contract). ~10–40 ms on a phone, and it is wasted work regardless.
Keeps its value alongside F1/F2 but does not remove the freeze on its own.

Ranked recommendation: **F1 + F5**, with **F2** if the next build's `sounds loaded` line still reads long, and F4
only if F1's line shows the engine init still blocking where it is. **F3 only as a fallback** if the engine cannot be
warmed ahead of time. The lines from §3 decide it in one run: the step with the big delta between it and the one
before is the freeze.

## 5. Files changed and why

- `packages/party_host/lib/src/host_start_log.dart` (new): `HostStartStep` labels and `HostStartLog`, one monotonic
  clock per start, an injectable one for tests.
- `packages/party_host/lib/party_host.dart`: exports it.
- `packages/party_host/lib/src/providers.dart`: `hostStartLogProvider`; `soundPlayerProvider` hands it to the player.
- `packages/party_host/lib/src/sound.dart`: logs `sound engine init` / `sounds loaded`. A restart after the app was
  hidden passes no start, so its times cannot be reported as a tap's.
- `controller_app/lib/src/host/host_start_sheet.dart`: logs `tap` on both mode buttons, before popping.
- `controller_app/lib/src/host/hosting.dart`: hands the start log to the host and logs `host built`.
- `controller_app/lib/src/host/phone_host.dart`: logs `service started` and the own player's first connection
  (`own player paired`), cancelling that subscription on pairing or dispose; nothing is logged for a host that pairs
  nobody ("Show on this device").
- `controller_app/lib/src/host/host_screen.dart`: logs `first frame` from a post-frame callback, guarded by
  `mounted`.
- `packages/party_host/test/host_start_log_test.dart` (new): the step set, the exact lines and ms, nothing before a
  tap, a second start counting from its own tap.
- `controller_app/test/host_start_log_test.dart` (new): the app's five steps in the real flow, `tap 0 ms` first,
  non-decreasing ms, the promised order, all tagged `host`, and "Show on this device" having no `own player paired`.
- `controller_app/test/scratch_start_timing_test.dart` (new, measurement only): prints the §2 timeline; delete it.

## 6. Computed test values

- `packages/party_host/test/host_start_log_test.dart`: clock deltas 0, +12, +380, +25, +640, +320, +190 →
  `tap 0`, `host built 12`, `service started 392`, `own player paired 417`, `sound engine init 1057`,
  `sounds loaded 1377`, `first frame 1567` ms. Second test: 0 → 1600 → 60000 → 60007 gives `tap 0`, `first frame
  1600`, `tap 0`, `host built 7`.
- `controller_app/test/host_start_log_test.dart`: parses each line as `^Host start: (.+) (\d+) ms$`; asserts the five
  app steps are present, the first pair is `('tap', 0)`, ms never decrease, `tap < host built < service started <
  own player paired`, every step line's source is `host`, and "Show on this device" has no `own player paired`.
- Run: `tools/check.sh format analyze host phone` → format PASS, analyze PASS, `host` 135 tests, `phone` 383
  tests, all passing.

## Self-check (docs/review-rules.md part A, items 1–5)

1. **Every host setup.** TV/PC host: no tap, so no line is written (`host_start_log_test.dart`, "nothing counts before
   the tap"); phone "Play on this phone": all five app steps (`controller_app/test/host_start_log_test.dart`); "Show on
   this device": the same minus `own player paired` (same file); a joined phone and an older build: no protocol or
   saved file changed, so nothing differs.
2. **When kept state starts and ends.** `HostStartLog` starts at the tap, keeps one clock and a started flag, and
   never times out; every later step is a no-op before a tap; the own-player subscription ends at the first connected
   snapshot, at `dispose`, or with the host; a sound restart logs no step (`sound.dart:92-93`).
3. **How a new state combines with the others.** This change adds no state that pauses, hides or blocks input; the
   lines are write-only and combine with pause, away, "Get ready" and a dropped link by doing nothing.
4. **Stay in the job's folder.** Only `controller_app/lib`, `controller_app/test`, `packages/party_host` and this
   report were written. `git status` also lists `tv_test_app/windows/flutter/generated_plugin*`; `git diff` shows no
   content change there, only line endings, written by the Flutter tool, not by me.
5. **Stop rather than overstep.** No file outside `allow:` was needed; the one thing I could not do (read the
   flutter_soloud source in the pub cache) is reported as a limitation and a question, not worked around.

## Questions

1. May I read the flutter_soloud 5.2.1 source from the pub cache (`~/.pub-cache/hosted/pub.dev/flutter_soloud-5.2.1`)?
   The sandbox refused it, so §1 #7/#9 are inference; its `init`/`loadAsset` determine whether F1 is enough.
2. Is the owner's build profile or debug? Debug FFI is several times slower and could be most of the 1.6 s.
3. Did that build's log show a `sound` line ("Sounds: … " or "Sound engine could not start")? If the engine failed to
   start, the suspect moves entirely.
4. Should the TV app get the same warm-up (F1) later, since it starts its sounds on its home screen today?

## Suggestions (not done; for the briefs that follow)

- Ship a debug-only `--dart-define` that skips `load()`, for an A/B of the freeze in one build.
- F5 (read the asset manifest once in `findSound`) is small enough to ride along with the fix.

## Commit message

```
Log each step of a host start with its ms since the tap

m12 bug 1108b: the phone freezes for about 1.6 s after a mode is
picked. The start now logs one `host` line per step (tap, host built,
service started, own player paired, sound engine init, sounds loaded,
first frame) with the ms since the tap, so the owner's Diagnostics name
the slow step in the next build. A host started without a tap (the TV)
logs nothing, and a sound restart after the app was hidden is not
counted as a start. No behaviour change; the triage and the ranked
fixes are in docs/briefs/m12/bug-1108b-triage-report.md.
```

## Status row

m12 bug 1108b: G1 triage done — freeze diagnosed (sound engine init on the tap's frame), six step lines + tests shipped, ranked fixes F1–F5 written; open: the owner's next build must show which step is slow, then F1 (+F5) is applied.

## Delete

- controller_app/test/scratch_start_timing_test.dart

## Claude's answers (Nov 8)

Q1: Claude read flutter_soloud 5.2.1: `initEngine` runs in `Isolate.run`, `loadMem`/`loadFile` in `compute`, so the engine and the decodes are off the UI isolate. On iOS only, `prepareEngineInitAsync` goes through the platform (main) thread first (`DarwinEngineLifecycle`: the audio session), which can stall frames. So the sound engine stays the lead, unconfirmed, and F1 (warm at app start) is rejected anyway: it would open the audio session, and stop the player's music, on every phone that only wants a controller. Q2: release builds (TestFlight). Q3/Q4: wait for build 5's lines. Decision: ship the step lines in build 5 and pick the fix from the owner's Diagnostics. The scratch test is deleted.
