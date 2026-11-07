# M12 step 9b — G4 report: the privacy page, and the host log's tag

Item 1 applies s9-report's Item 4 replacements, exactly as drafted, and moves the page's date and version. Item 2 renames the
phone host's log tag from `tv` to `host`. Nothing else changed.

## Files changed

- `site/privacy.html` — the lead's date and version, and nine sentences (old → new in "Item 1").
- `packages/party_host/lib/src/host_service.dart` — line 112, `log.sink('tv')` → `log.sink('host')` for `LiveHostService`'s
  own lines.
- `docs/briefs/m12/s9b-report.md` — this report.

No test or tool changed: none reads the old tag (see "Item 2").

## Item 1: `site/privacy.html`, sentence by sentence

The lead:

1. `Effective November 1, 2026 (version 0.9.0).` → `Effective November 7, 2026 (version 0.12.0).` (0.12.0 is the version in
   both apps' pubspecs.)

"What the apps do with data":

2. `The phone sends button presses, stick positions and tilt directly to the TV app on the same local network.` → `A phone
   sends button presses, stick positions and tilt directly to the host on the same local network: the TV app, or a phone
   hosting a game.` (the bullet's opening, "Controller input stays on your Wi-Fi.", is unchanged.)
3. `To reconnect without the code, the phone and the TV app each save a random pairing code and a random device ID.` → `To
   reconnect without the code, a phone and the host it joined each save a random pairing code and a random device ID.`
4. `The TV app shows each phone as something like "iPhone 3F1C" and the phone shows the TV's name, only on the local
   network.` → `The host shows each phone as something like "iPhone 3F1C", and a phone shows the name of the host it joined,
   only on the local network.`

"Anonymous gameplay stats":

5. `**The phone counts, the TV collects.** While a phone is connected to the TV app, … It sends these counts to the TV app on
   your Wi-Fi only. The TV app adds how quick the connection is, how the games went, and the answer to "How did the controls
   feel?" after some games.` → `**A phone counts, the host collects.** While a phone is connected to a host, … It sends these
   counts to the host on your Wi-Fi only. The host adds how quick the connection is, how the games went, the picture rate and
   frame timing of a game shown on the phones, whether each player watched the game on the host's screen or on their own
   phone, and the answer to "How did the controls feel?" after some games.`
6. New bullet after "What it includes about the device": `**What it includes about the host phone:** when a phone hosts a
   game, its battery level at the start and at the end, whether it was charging, whether it was in low power mode, how hot
   it got, and the picture rate and frame timing of the game.`
7. `**Kept on the TV either way.** The TV app keeps a summary of each play session on the device, which you can see on its
   **Stats** screen and export to a file.` → `**Kept on the host either way.** The host keeps a summary of each play session
   on the device. The TV app shows its sessions on its **Stats** screen and can export them to a file. A phone that hosts a
   game keeps its sessions on the phone, and its Diagnostics screen shows the session you just played, to send with a
   report.`
8. `Nothing is shared by default.` → `Nothing is shared by default. Sessions from a game hosted on a phone aren't uploaded at
   all.` (the sentence is added to the end of the "Sent only with an adult's yes." bullet.)

"Permissions":

9. `**Local network**: to find and connect to the TV app on your Wi-Fi.` → `**Local network**: to find and connect to a host
   on your Wi-Fi, or to host a game on the phone, so other phones can find it.`
10. `The readings are turned into controller input on the phone and sent only to the TV app.` → `The readings are turned into
    controller input on the phone and sent only to the host.`

The page's other sentences, headings and markup are untouched.

Replacement 7's last clause ("its Diagnostics screen shows the session you just played") is true once s8c lands; the brief
says it stands. Until then the page promises a Diagnostics line the app doesn't show yet (Q3).

## Item 2: the host's log tag

`LiveHostService`'s own sink was `tv` (`host_service.dart:112`), so a phone host's lines — the start line, "Addresses: …",
"Remembered …", "Log saved to …", "Stats are off", "The server could not start" — showed as `[tv]` in the phone's Diagnostics
and in an exported log. It is `host` now, the tag the server and the listener in the same service already use
(`host_service.dart:130`, `:136`).

Every other `tv` in the tree, and why it stays:

- `packages/party_host/lib/src/host_identity.dart:4` — `HostKind.tv`, the discovery kind (`TXT kind`), not a log tag.
- `packages/party_host/lib/src/providers.dart:61` — `BonsoirAdvertiser(log: …sink('tv'))`: the advertiser's own tag, in the
  shared provider, so a phone host's advertising lines stay `[tv]` (Q2).
- `packages/party_host/lib/src/providers.dart:270` — the screen-wake line's `tv` tag (the TV shell's keep-awake, M11).
- `packages/party_host/test/live_stats_test.dart:38` — `hostId: 'tv'`, a host ID in a session, not a tag.

Tests and tools that read the tag: **none matched it.** Searched for `[tv]`, `'tv'` and `"tv"` in `packages`,
`controller_app`, `tv_test_app` and `tools`, and for `.sink(`, `.tag` and `LogBuffer` in every test folder. No test asserts
the service's tag, and no test builds a log line with it; `host_log_export_test.dart:37` checks `[host]` on a line it adds
itself, so it is unaffected.

The tools, checked for their patterns:

- `tools/smoke.sh` reads the TV app's log for `Listening on port` and, in `tv_is_live`, for a `[host]` line after the last
  listening line; every other pattern matches the simulated controller's or the phone app's output. The service's own lines
  now count as `[host]` lines too, so `tv_is_live` can only fire sooner, never later. No change.
- `tools/tv-dev.sh` matches `Listening on port [0-9]+ (pairing code [0-9]+)` (a `[host]` line from `HostServer`) and the
  build's error lines (`Error: |BUILD FAILED|Exception:|Lost connection to device`). It never matches a tag. No change.

Test counts, with the old tag and with the new one (`tools/check.sh host phone tv`):

| suite | before (`tv`) | after (`host`) |
| --- | --- | --- |
| `party_host` | 75 | 75 |
| `controller_app` | 320 | 320 |
| `tv_test_app` | 28 | 28 |
| total | 423 | 423 |

The tag isn't pinned by a test, so the counts can't show the change; the proof is the line in the diff (Q4).

## Checks

- `tools/check.sh format analyze host phone tv` — **PASS**: format 2 s, analyze 8 s, host 75 tests, phone 320 tests, tv 28
  tests, "All checks passed (50s)". Run twice: once with `host` (before the temporary revert for the before-counts) and once
  on the final state; same result.
- `tools/review.sh` — 0 FAIL, 1 NOTE: `host_service.dart` 350 lines (lib limit 400, aim 300), which predates this job.
- `tools/review.sh --strings` — `'tv'` removed at `host_service.dart`, `'host'` added at `:112`; 1 removed, 1 added, 13
  unchanged or moved. No new user-facing text.

## Questions

1. The lead still says "The previous version, from October 29, 2026, said no data was collected." With the date moved to
   November 7, the previous version is the November 1 one, which introduced the stats. Left as it was ("nothing else
   changes"). Rewrite it to name November 1, or leave it?
2. `providers.dart:61` still logs the advertiser under `tv`, so a phone host's advertising lines show as `[tv]` in its own
   Diagnostics. The brief named `LiveHostService` only. Change that one too?
3. Replacement 7 promises the phone host's Diagnostics shows the session just played; s8c adds that line and hasn't landed.
   Publish the page only after s8c?
4. Should a test pin the host's tag (a `LiveHostService` line arrives as `[host]`)? None exists, so a later edit can undo
   this silently. I didn't add one: the brief's test line covers existing tests only.
5. Other TV-only wording stays and is still true but incomplete for a phone host: the "In short" card, "Deleting it"
   ("Uninstalling the TV app deletes the sessions kept on the TV"), and the children section's "only if an adult agrees on
   the TV". Leave for the next policy revision?
6. `site/index.html` and `docs/checklists/m12.md` weren't touched (outside this job's allow list); nothing there names the
   privacy version, so nothing is stale.

## Commit message

m12 privacy page for phone hosts, and the phone host's log tag

- privacy.html: the nine M12 replacements (host instead of TV, the host phone's readings, the picture rate and who watched
  where, sessions from a phone host never uploaded, the hosting permission), effective November 7, 2026, version 0.12.0.
- LiveHostService logs under `host`, not `tv`, so the phone's Diagnostics shows its own host's log under one tag.
- No test or tool read the old tag: smoke.sh's patterns are `Listening on port` and `[host]`, tv-dev.sh's are the listening
  line and build errors, so both are unchanged.
- Tests unchanged: 75 host, 320 phone, 28 tv, before and after.

## Status row

| 9b | **Privacy page done**: site/privacy.html covers phone hosting (nine replacements, effective November 7, 2026, version 0.12.0); the phone host logs under `host`. **Open**: s8c (the Diagnostics session line the page now promises), the advertiser's `tv` tag, the build 2 tag, the owner's device checks |

## Delete

- none
