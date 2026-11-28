# m2d report: frame-time sampler, draw-call budget, on-screen measure hook

## Files changed

- `packages/party_host/lib/src/city/art/frame_probe.dart` (new, 150 lines): `FrameStats`, `FrameProbe` (window and budget injected, no clock), `CityFrameHook` (widget; reads an injected `Stream<Duration>` or the scheduler's timings; text in a corner via Stack; cancels or removes its listener in dispose). Nothing mounts it.
- `packages/party_host/test/city/art/city_frame_test.dart` (new, 236 lines): sampler tests, hook test at two sizes, dispose test, and the draw-call budget tests with a counting canvas.
- `docs/briefs/m17/map2b/m2d-report.md` (this file).

## Computed values

- Budget `overlayDrawCallBudget`: eight tokens on the standard board, 1920x1080. Menu look made 74 canvas calls. The TV look passed with the budget set to 74, so it is at most 74. Budget set to 93 (74 x 1.25, rounded up).
- Cached CityPainter frame: exactly one `drawImage`, no other calls.
- Sampler: 10 and 20 ms give average 15 ms, dropped 0. Twenty frames of 1 to 20 ms give p95 19 ms (nearest rank: ceil(20 x 0.95) = 19, the 19th value) and average 10.5 ms. Frames 10, 25, 30, 40, 16 ms give dropped 2 (25 ms is not over the 25 ms budget). Window 100 ms with three 40 ms frames keeps 2 frames, average 40 ms. Empty gives zeros.
- Hook: frames 10 and 30 ms show `avg 20.0 ms, p95 30.0 ms, dropped 1`.
- Last `tools/mine.sh` run: 11 tests OK, analyze clean, 2 files formatted.

## Tests-first note

The first run against the stub did not produce a clean red result. It hung past the timeout, and then failed to compile on two errors in my own test file (`bolts` required, unused `_eightPlayers`), which I fixed. The budget test then failed on the real menu count (74), which is the failure that measured the budget. I did not see the stub-stage tests fail one by one, so the runner's red-first proof may need a rerun on the stub.

## Decisions

- Kept the three public types in one file because the brief names that file as the only one I may change. Coding rule "one public type per file" is not met; see questions.
- `CityFrameHook` calls `setState` on every frame timing, so while mounted it keeps the app rendering at frame rate. Acceptable for a debug hook that nothing mounts; flagged below.
- The hook's text uses `Theme.of(context).textTheme.labelSmall`, so it has no fixed size and no hard-coded colour.
- The window rule keeps the newest frame even when it alone is longer than the window.

## Self-check (review-rules part A)

1. Host setups: not applicable, the hook is not mounted; the budget test covers the city painters only.
2. Kept state: the probe starts empty and holds frames for `window`; the hook cancels its subscription or removes its timings callback in dispose (test "dispose cancels the stream subscription").
3. Combination with pause, away, results and leaving: not applicable, nothing mounts the hook.
4. Files: only the two allowed files and this report.
5. Nothing overstepped.
6. Looks: the hook test runs at TV (1920x1080) and phone portrait (360x640) sizes; the budget test runs both menu and TV looks.

## Hand-over

- The 60 fps check on a TV box is an owner device check and was not done here.
- `tools/check.sh` was not run by me; `mine.sh` covered format, analyze of party_host and the touched test file.

## Commit message — a draft: a subject line under 72 characters, a blank line, then at most 8 lines on what changed and why.

map2b: frame sampler, draw-call budget test, measure hook

Adds FrameProbe and FrameStats (window and dropped-frame budget,
injected times, nearest-rank p95) and CityFrameHook, an unmounted
corner overlay that reads frame times from a stream or the scheduler.
Adds city_frame_test.dart: sampler and hook tests, and a draw-call
budget with a counting canvas: a cached CityPainter frame is one
drawImage, and eight tokens make at most 93 canvas calls (menu 74).
A stub painter that redraws the static layer is flagged.

## Status row — one line for the milestone's STATUS.md: what is now done, and what is open.

m2d: done: frame sampler, CityFrameHook (unmounted), budget test (overlayDrawCallBudget 93, menu look 74). Open: owner 60 fps device check on a TV box; hook not mounted; one-public-type rule not met in frame_probe.dart; red-first stub run not seen cleanly.

## Questions

1. May `FrameStats`, `FrameProbe` and `CityFrameHook` be split into one file each? The brief names only frame_probe.dart, so I kept them together; the coding rule says one public type per file.
2. Should the hook throttle its `setState` (for example, only when the text changes) so that it does not keep the app rendering at frame rate while mounted?
3. Is the stub-stage red run required again to prove the tests fail on the old code, given the first attempt did not produce a clean result?

## Delete

- none
