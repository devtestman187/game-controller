# B-023: the phone Settings Stats row says what sharing is doing

## Summary

**Fixed, unverified: needs device check.** The host's `Stats` row in the phone Settings now shows its sharing status
under the title, in one of five states, and a trailing chevron; before the answer an emphasised `Tap to choose` hint
sits under it. Tapping still asks first (consent null) and then opens the Stats screen, as it did.

**What changed.** `SettingsText.hostShareLine(StatsState)` builds the line from the same fields as
`HostText.statusLine`: `Sharing hosted sessions: not answered` / `off` / `no upload set up` / `last try failed` /
`on, N uploaded, M waiting`; `SettingsText.hostShareChoose` is the hint; the unused `hostStatsLine` is gone. The new
private `_HostStatsStatus` (settings_sections.dart) draws the status and, before the answer, the bold hint, and
`_StatsSection` gives the row that subtitle plus `Icons.chevron_right`; the whole tile stays tappable through
`ListTile.onTap`, as the section's other navigation rows are.

**Tests.** New `controller_app/test/settings_stats_row_test.dart`, 3 widget tests: (1) the five status lines, the bold
hint and the chevron, driven by `FakeStats.emit`; (2) an answered row opens the Stats screen without the dialog;
(3) an unanswered row asks, records the answer, then opens Stats. Before the fix test 1 failed (no status, no chevron,
no hint) and 2 and 3 passed, as that flow already worked; after, 3/3 pass. `host_stats_test.dart`,
`phone_host_stats_lifecycle_test.dart` and `settings_test.dart` still pass (23 tests together).

**Checks.** `tools/check.sh format analyze host phone`: format PASS, analyze PASS, host PASS (482 tests), phone PASS
(478 tests).

**Decisions.**
1. Bold ink for the hint, not an accent colour: the app already marks emphasis with `FontWeight.bold` (`taken_notice`,
   `result_card`), and no palette colour is verified as readable text on paper.
2. A `ListTile` with a chevron, not connect_screen's paper-and-ink-edge row: every row in a Settings card is a
   `ListTile` already, and the chevron is the part of the connect_screen look that says "another screen".
3. `lastError` is checked after `uploadConfigured`, in `HostText.statusLine`'s field order, so the states can't
   contradict each other.
4. The row lives in settings_sections.dart (a part) so no file passes 380 lines: 347, 346 and 249.

## Self-check (review-rules.md part A)

1. **Every host setup.** The row exists only on the phone Settings and only while this phone hosts; tested on "Play on
   this phone" (`settings_stats_row_test.dart`, all three). "Show on this device" and a phone one build older differ
   only in what the host holds, not in the row, so not tested separately; a TV/PC host has no such Settings screen, and
   a joined phone has no row (`host_stats_test.dart`: "a phone that hosts no game has no host's stats to show").
2. **When kept state starts and ends.** Nothing new is held or timed: the line reads `statsStateProvider`, which starts
   and ends with the host's stats service (existing, `phone_host_stats_lifecycle_test.dart`). Status test moves it
   through all five states with `FakeStats.emit`.
3. **How a new state combines with the others.** Display only: no pause, hide, wait or input is added. The consent
   dialog on tap was there before and is covered by tests 2 and 3 (answered: no dialog; unanswered: dialog, then
   Stats).
4. **Stay in the job's folder.** Done: the four lib/test files in `allow:` and this report.
5. **Stop rather than overstep.** Not needed: every file the change wanted was in `allow:`, and the brief's texts fit
   the existing `StatsState` fields.

## Files changed

- `packages/party_host/lib/src/text/settings_text.dart` — `hostShareLine(StatsState)` and `hostShareChoose` added,
  unused `hostStatsLine` removed.
- `controller_app/lib/src/ui/settings_screen.dart` — `StatsState` imported; the host Stats row's subtitle is the new
  status widget and it gets a `chevron_right` trailing icon.
- `controller_app/lib/src/ui/settings_sections.dart` — `_HostStatsStatus`, the status line plus the emphasised
  `Tap to choose` hint while the answer is unknown.
- `controller_app/test/settings_stats_row_test.dart` — new: three widget tests (states and hint; answered tap;
  unanswered tap).
- `docs/briefs/m14/bugs12/b023-stats-card-report.md` — this report.

## Computed test values

| State set on `FakeStats` | Text asserted |
| --- | --- |
| `StatsState()` (consent null) | `Sharing hosted sessions: not answered` + `Tap to choose` |
| `StatsState(consent: false)` | `Sharing hosted sessions: off` |
| `StatsState(consent: true)` (uploadConfigured false) | `Sharing hosted sessions: no upload set up` |
| `uploaded: 3, waiting: 2` (consent true, upload set) | `Sharing hosted sessions: on, 3 uploaded, 2 waiting` |
| `lastError: 'offline'` (consent true, upload set) | `Sharing hosted sessions: last try failed` |

All five are literal asserts in the new test; the numbers 3 and 2 are the ones emitted.

## Hand-over

- The device check the owner asked for: the row's five lines and the chevron on a phone build, at midday and night.
- The hint's bold weight is asserted, not seen; if Claude wants a colour instead, only `_HostStatsStatus` changes.

## Commit message

Show the sharing status on the phone's host Stats row (B-023)

The row opened another screen with only a description under the title, so the
owner read the card's green switch as the sharing setting. The subtitle is now
the sharing status from StatsState (not answered, off, no upload set up, last
try failed, or on with uploaded and waiting counts), with a bold 'Tap to
choose' hint until an adult answers and a chevron showing there is a screen
behind it. SettingsText.hostShareLine holds the words; the tap still asks
first and then opens the Stats screen. A new widget test fails on the old row.

## Status row

- **B-023 stats card:** fixed; the phone's host Stats row shows its sharing status in five states, with a bold
  `Tap to choose` hint before the answer and a trailing chevron, opening the Stats screen as before; open: the owner's
  device check.

## Delete

- none
