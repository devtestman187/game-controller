# Device checklist (manual checks)

Source: S3 in `docs/test/system-test-plan.md` (sections 2 and 6). One row per check that automation cannot do yet. Fill the "Build tested" column at each run. The list shrinks as automation grows; the real-hardware rows stay.

Who runs a row: the agent, wherever a device or emulator allows it. Owner hands are only for the narrow cases in plan section 6: the first public release's hardware list, a change only hardware can check, a one-time setup. Ask once, batched, say why and how long.

## When rows run

| Trigger | Rows |
|---|---|
| Every tester build | None by hand (automated only) |
| After a major UX change | Rows for the affected screens (D4, D6, D8) |
| After a protocol change | D1, D2, D3, D5, D9 |
| Before each public release | All rows. Agent runs what it can; one batched owner ask for the hardware-only rows (D1, D2, D7, D10) |
| Periodic (monthly or every 4th tester build, after a Flutter bump) | D3, D5, D8, D9 on the tablet or emulator |

## Rows

| # | Check | Device | Steps | Pass line | Runs | Build tested |
|---|---|---|---|---|---|---|
| D1 | Real Android TV, full night | Real Android TV + one phone | Install TV app, start a night, pair a phone on Wi-Fi, play one round, finish the night | TV and phone stay in step, remote focus works, night result shows | Before public release; after a TV remote or focus change (owner) | |
| D2 | iPhone, full night | Real iPhone | Install the TestFlight build, pair with a TV, play one round | Controller fits the screen (landscape), buttons answer, no clipped text | Before public release (owner) | |
| D3 | TV restart resume, real process | Windows TV, then Android TV | Start a night, play to round 2, kill the TV app process, start it again | Night resumes at the saved round. Round 0 and ended nights do not resume | After a protocol or save change; before public release. Windows by agent; Android TV by owner | |
| D4 | Wi-Fi discovery, "Search again" | Phone + TV on home Wi-Fi | Open the phone app with the TV off, turn the TV on, tap Search again | TV appears within a few seconds and pairs | Before public release; after a discovery change | |
| D5 | Drop under 30 s | Phone + TV | Mid-round, switch the phone off Wi-Fi for 10 s, switch back | Phone rejoins, same player, round goes on | After a protocol change; periodic | |
| D6 | Drop over 30 s | Phone + TV | Switch the phone off Wi-Fi for 40 s, switch back | Player was removed; phone gets back to the join screen, night goes on for the others | After a protocol change; periodic | |
| D7 | Guest or isolated Wi-Fi | Phone + TV on a guest network | Try to pair | Clear failure message, no crash (owner records the result; mDNS may be blocked) | Once before the first public release (owner) | |
| D8 | Kids preset and settings reset, persisted | Any phone and TV | Pick Kids preset, change a setting, close and reopen the app, then reset | Settings survive restart; reset returns defaults | After a settings change; before public release | |
| D9 | Old phone in a night | Old phone build (m16.3 APK, no `choices` capability) with an m17 TV | Join a night, play a choice round | Old phone gets answers through the fallback; round completes | After a protocol change; before public release. Unblocked: m16.3 APK now on the release and in E:/AI/old-builds/m16.3 | |
| D10 | Old app vs new app pairing | m16.3 phone with m17 TV, and the reverse | Pair each way | Pairs and plays, or shows a clear message | After a protocol change. Unblocked: old APKs now on the releases and in E:/AI/old-builds. Old iPhone check may be impossible (TestFlight expires) | |
| D11 | Other screen sizes | Pixel Tablet, small phone, emulator | Open connect, home, choices/vote, night result, shop | No overlapping or clipped text | After a major UX change, until the S2 matrix and goldens cover it | |

## Notes

- Protocol version is 1 everywhere, so the version-mismatch message cannot be device-tested yet (covered by unit or widget tests).
- Drop and discovery rows are skipped on this PC's sandboxed shell (flutter tool crash, `docs/dev-tools.md:403`); run from a terminal tab.
- Record each run in the run log at the bottom of the plan, with the build number.
