# M16 process1 f1 — report

## Summary

**Blocked: neither `do:` item can be met with the files in `allow:`.** Riverpod 3.4.3 refuses two overrides for
the same provider in one `ProviderScope` (`ProviderContainer` assertion "Tried to override a provider twice
within the same container"), and the current design of the helpers relies on exactly that:

- Step 2 (caller's `toyTvProvider.overrideWithValue(false)` wins in the TV look) needs `pumpHostLook` to
  pass *both* the look's flag and the caller's flag to `pumpHost`, which `ProviderScope` rejects.
- Step 1 (a real `lookClockProvider.overrideWithValue(_callerClock)` in the caller's `overrides`) is worse:
  `pumpHost` in `test/support/host_harness.dart:85` always adds its own `lookClockProvider` default before
  `...overrides`, so *every* caller clock override through `pumpHostLook` is a duplicate. `host_harness.dart`
  is not in `allow:`.

I made the brief's edits, measured both failures, then reverted both test files to their committed content
(`git status --short` on them is empty). No file besides this report changed.

Decisions (safest choice under COMMON's low-usage mode): revert rather than leave a red tree or invent a
dedupe/special-case workaround in a test helper; the fix belongs to a design decision (below).

Measured, with the brief's edits applied:

- `dart format` clean; `flutter test packages/party_host/test/all_looks_support_test.dart` → `+2 -2`.
- "the helper keeps the caller's own overrides in both looks": assertion
  `Tried to override a provider twice within the same container: Provider<() => DateTime>#ec7b6`, then
  `Found 0 widgets with text "tv:false hour:23"` (the probe never mounted). Values: `harnessNow` is
  2026-11-08 12:00, `_callerHour` is 23, so the expected menu text was `tv:false hour:23`.
- "a caller's own TV flag wins in the TV look": assertion
  `Tried to override a provider twice within the same container: Provider<bool>#44717`, then
  `Found 0 widgets with text "tv:false hour:12"` (expected text `tv:false hour:12`; `harnessNow.hour` is 12).

Because both new tests fail at mount time for the duplicate-override reason, the brief's break-and-restore
runs (remove the spread / restore the old order) were not done: no green baseline exists to break from.

Checks on the reverted tree: `tools/check.sh format analyze host` → PASS format (6s), PASS analyze (14s),
PASS host (188s).

## Why the order decision can't work as written

`pumpHostLook` builds one `overrides:` list for `pumpHost`. `ProviderScope` treats that list as a set of
overrides keyed by provider: two entries for the same provider is an assertion, not "last wins". So "the TV
flag goes FIRST and the caller's overrides after it" only renames which entry is *supposed* to win; the
container throws before either applies. `screen_fit_test.dart:46` gets away with its order because no caller
of `pumpIn` ever overrides `toyTvProvider` — the ordering there was never exercised.

The same holds for every provider `pumpHost` overrides itself (`prefsProvider`, `puzzleLibraryProvider`,
`arenaMapLibraryProvider`, `hostServiceProvider`, `soundPlayerProvider`, `screenAwakeProvider`,
`lookClockProvider`): a caller in `pumpHostLook` cannot override one, which is why `pumpHost` grew the
`clock:` parameter in the first place.

## Suggested fix (for Claude; not acted on)

Give the harness a merge that keeps the **last** override per provider instead of concatenating, and use it
in both places:

1. `host_harness.dart`: `pumpHost` builds `[...defaults, ...overrides]` through a
   `mergeOverrides(base, overrides)` that drops an earlier entry whose `origin` is the same provider. That
   makes the brief's step 1 work as written (`lookClockProvider` in the caller's `overrides` replaces the
   harness default, so `clock:` could even be retired).
2. `all_looks.dart`: `pumpHostLook` calls the same merge with the TV flag first, so the caller's
   `toyTvProvider` override replaces it — the order decision then means what it says.

That needs `Override.origin` (verify it is public in riverpod 3.4.3) and touches `host_harness.dart`, so it
needs its own `allow:` entry.

## Questions

1. Is the merge above the intended shape, or should `pumpHostLook` instead just *not* add the TV flag when the
   caller passed a `toyTvProvider` override?
2. If `host_harness.dart` stays out of scope, should step 1 test the spread some other way (e.g. an override
   of a provider `pumpHost` does not touch) — or is the clock test to be dropped?

## Self-check (review-rules part A)

1. Host setups: no behaviour changed; the helper only feeds test scopes, so no host type is affected.
2. Kept state: none added; `ProviderScope` overrides are per mount and `forEachLook` takes the tree down
   (`all_looks_support_test.dart:63`).
3. Combined states: the TV flag and the caller's overrides cannot combine in one scope at all — that is the
   block reported above.
4. Folder: only `docs/briefs/m16/process1/` was written; the two test files are byte-identical to HEAD.
5. Stop rather than overstep: done; the needed file is `packages/party_host/test/support/host_harness.dart`.
6. Every look: unchanged; both looks stay covered by the helper's own tests, which pass on the reverted tree.

## Hand-over

Nothing to hand over: no behaviour change, no new test. The tree is as I found it, checks green. Re-brief
with a wider `allow:` (at least `test/support/host_harness.dart`) and the merge shape decided.

## Commit message

docs: record why f1 is blocked on riverpod's duplicate-override rule

Neither item in f1 is possible with the allowed files: pumpHost always
adds its own lookClockProvider override, and ProviderScope rejects two
overrides for one provider, so the TV flag order and a caller's clock
override both assert at mount. Report the measured failures, the reason
the current order was never exercised, and the merge fix the harness
needs, including host_harness.dart in the allow list.

## Status row

M16 process1 f1: blocked — both override items hit riverpod's duplicate-override assertion; test files unchanged, format/analyze/host green; open: merge overrides by provider origin in host_harness.dart + all_looks.dart, then redo steps 1-2.

## Delete

- none
