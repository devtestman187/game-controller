## Summary

Job f2: the map view test waits on the cache's image build instead of 50 ms of real time, and
`CityMapView` throws a clear `FlutterError` when its parent gives it unbounded constraints.

Files changed:
- packages/party_host/lib/src/city/art/city_map_view.dart: a guard at the top of the `LayoutBuilder`
  builder throws `FlutterError('CityMapView needs a bounded size, but its parent gave it unbounded
  constraints: ...')` when `hasBoundedWidth` or `hasBoundedHeight` is false. One doc sentence added to the class:
  the parent must give a bounded width and height.
- packages/party_host/test/city/art/city_map_view_test.dart:
  - `_pump` now calls `_untilImageBuilt`, which returns at once if `cache.imageFor(size)` is set, else
    listens to the cache (copied from `_untilBuilt` in city_frame_test.dart) and awaits it with a 5 s
    `_imageBuildTimeout` in `runAsync`. The listener is removed in a `finally`.
  - `_imageBuildWait` (50 ms) replaced by `_imageBuildTimeout`.
  - `_paintOf<T>` now uses `whereType<T>().first`, so `_overlay` and `_board` return typed painters with no `! as`.
    The over-long line is gone.
  - New group `CityMapView needs a bounded size` with two tests: a Column in a vertical
    `SingleChildScrollView` and a Row in a horizontal one. Each asserts `takeException()` is a `FlutterError`
    whose text contains `bounded size`.
  - `import 'dart:async';` added for `Completer`.

Tests-first: with the guard missing, both new guard tests FAILED (mine.sh: "FAILED: 1 check(s) failed"). The
other tests in the file, using the new wait, passed. After the guard: `OK 12 tests packages/party_host`.

Self-check (review-rules part A), test that shows it:
1. Host setups: `fits every size` tests (OK).
2. Kept state: the guard throws before `_layoutFor`; `cache` test (OK).
3. Combinations: guard applies in every state; suite OK.
4. Only the two allowed files changed.
5. Nothing stopped.
6. Looks: guard tests use `HostLook.menu` (the guard is look-independent); `fits every size` runs every look.

Checks run:
- `tools/mine.sh` red (before the guard): 2 guard tests FAILED, others passed.
- `tools/mine.sh` after the guard: `OK 12 tests packages/party_host`.
- `dart analyze` on the two changed files: No issues found.

## Hand-over

Decisions:
- The guard tests sit in `city_map_view_test.dart`, not a new file. The brief's allow list names only this file, and
  the G9 rule says new tests go in a new file. That is a conflict; see the question below.
- The guard checks both axes, so a view with unbounded width or height throws.
- The timeout is 5 s, a named constant, so a build that never finishes fails the test instead of hanging.

Questions:
1. The G9 rule says new tests go in a new file, but the brief's allow list has no new file. Should the two guard tests
   move to a new file (for example city_map_view_bounds_test.dart) in a follow-up?
2. `_untilImageBuilt` should move to the shared test helper that the later job will create (REVIEW.md finding 4),
   together with `_untilBuilt`.

Suggestions:
- `_withoutChips` copies `CitySnapshot` field by field (REVIEW.md finding 7). Not in this job; a `copyWith` would fix it.

## Commit message — a draft: a subject line under 72 characters, a blank line, then at most 8 lines on what changed and why.

map2b f2: wait on the image build in map view tests; guard unbounded size

CityMapView now throws a FlutterError naming the bounded size when its parent gives
unbounded width or height, instead of laying out an infinite board. The map view
test waits on the cache's image build through a listener with a 5 s timeout, not
50 ms of real time, and its painter helpers return typed painters with no cast.
The guard tests failed on the old code and pass now.

## Status row — one line for the milestone's STATUS.md: what is now done, and what is open.

map2b f2 done: map view test waits on the image build (no real-time wait, no unchecked cast, long line wrapped); CityMapView throws a clear FlutterError under unbounded constraints (tested red then green). Open: the guard tests sit in the existing test file, not a new one (G9); `_untilImageBuilt` and `_untilBuilt` await the shared helper job.

## Delete

- none
