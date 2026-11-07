# M12 step 9 — G4 report: the M12 docs

The four files the brief changes, written from the design docs and checked against the code wherever a doc states a
fact.
`site/privacy.html` was read only: item 4's findings and replacement text are below. Nothing else was touched.

State at the time of writing: **s8c has not landed** (there is no `s8c-report.md`). So the "Frame rate (test)" row in
Settings, the Diagnostics session line and `metrics:report --paste` are not in the code. protocol.md and
architecture.md therefore say nothing about them, and the checklist still lists them because the brief's item 5 does.

## Files changed

- `docs/protocol.md` — intro, §1 (instance name, TXT `kind`), §2 (two transports), §4 (`view` row), §5 (numbers
  for players on the host), §9 (`stages`, `view`), a new §10a with five parts, §11 and §12 rows.
- `docs/architecture.md` — intro sentence, the repo layout table, the "one host stack" principle, and a new
  "Milestone 12: phone-hosted play" section with seven subsections.
- `site/index.html` — the lead, the "You need" bullet, the "No TV nearby?" line, the new "4. No TV? Host on a
  phone" section, and one M12 fix ("Games on this Wi-Fi").
- `docs/checklists/m12.md` — the header, "What's new in build 2", eleven "Build 2 checks". Build 1 is untouched.
- `site/privacy.html` — read only, no edit. Findings in "Item 4" below.

## docs/protocol.md

Section by section:

- **Intro** — the host is "the TV app on Android TV or Windows, or the phone app hosting a game since M12".
- **§1 Discovery** — the instance name row gained the phone host's form (`Thumb Party on <phone name>`); a new TXT
  `kind` row (`tv`, `pc`, `phone`, `tablet`, left out by older hosts); one sentence on a phone's host list reading
  it.
- **§2 Transport** — the old bullet is now "On the network", and a new "Inside one process (M12)" bullet covers the
  local channel: the same messages in the same order, no address, marked `local`, pairing with the current code,
  the same heartbeats and close codes.
- **§4** — the `view` row now names all five messages.
- **§5 `player`** — "Players on the host itself (a keyboard, or the host phone's own player) take numbers too."
- **§9 `metrics`** — new `stages` and `view` rows: stage name → ms integers (at most 256 per stage; unknown names
  kept; more is a protocol error) and `{"frames", "gaps", "late"}`.
- **§10a Viewing the game (new)** — a host that shows the game on its own screen sends none of it; the message table
  with every wire key; `view_start` first and `view_end` last, with one `frame` per step; a **`view_start`'s
  `setup`** paragraph (Shape Race's `puzzle`, `level`, `timeLimitS`, `teams`, `layout` = `phones`, the Arena's
  `{}`, "Update the app to see this game"); **Sounds** (`snd`, played by every phone); **Waiting for the host**
  (`host_away`'s seconds, `host_back`, the 30 s grace, `abandoned`, the 30 s a dropped viewer counts itself);
  **`at`** and how a phone works out skew and a playout delay on its own clock; the viewer that pairs mid-game
  (the stored start and newest frame before any later frame, nothing after `view_end`); 4003 for a controller that
  sends one of these.
- **§11** — the five types, host → controller, capability `view`.
- **§12** — "Frames to a viewer | 20 to 60 a second, 60 by default (`view_start`'s `hz`)"; "Host away before the
  round ends | 30 s".

Facts checked in the code: `packages/protocol/lib/src/{view,metrics,capabilities}.dart` (the messages and fields);
`packages/connection/lib/src/server_game_host.dart` (`_sendView` to a controller that (re)joins, the start and
newest frame kept for the running view and cleared at its end, `shareView`, 4003 for host-only messages);
`packages/connection/lib/src/viewer_timing.dart` (base = the fastest of the last 2000 ms, delay from p95 lateness,
clamped by `maxPlayoutFrames`); `packages/party_host/lib/src/host_identity.dart` (the TXT keys); `puzzle_game/lib/
src/puzzle_module.dart` (the setup keys and `layout`); `packages/game_kit/lib/src/frame_view.dart` (the update
text).

Nothing in M12's messages was left out of §10a or §9; nothing was added that the code doesn't send.

## docs/architecture.md

- **The diagram and the sentence after it** — a phone or tablet can host too, and its own player reaches the host
  over an in-process link; the M12 sections say who draws and who gets frames.
- **Repo layout** — rewritten for the packages as they are (protocol, connection, metrics, game_kit, test_game,
  puzzle_game, party_host, assets, docs) and what each owns; `controller_app` now hosts and `tv_test_app` is a
  shell around `party_host`.
- **Principles** — a new bullet, "One host stack (M12)": what a TV host does, a phone host does through the same
  code.
- **"Milestone 12: phone-hosted play" (new)** with seven subsections: **Two hosts, one stack** (the phone's
  `LiveHostService` with both listeners, the `party_host` body behind the phone's controls, the own player as a
  normal `ControllerClient` over `InProcessLink`, and a table of host / `shareView` / who draws / what a joined
  phone shows); **Transport (M12 step 2)**; **Sessions and frames (M12 step 3)**; **The frame path: step → frame →
  playout → `FrameView`** (six numbered steps); **Host interruptions (M12 step 5)**; **The puzzle and the Arena on
  phones (M12 step 7)** (layout target, a `phones` side, `PuzzleCamera`, the Arena, the size check); **Battery and
  heat (M12 step 8)**.

One wording fix made while checking the code: the phone host's "Show on this device" leaves out the controls layer
(it does not remove the own player), so the section now says the phone draws the games like a TV, its own player
can't press anything then, and the other phones play.

## site/index.html

- The lead sentence now says a phone can host the game instead (step 4).
- "You need" lists one screen to play on, with the phone-hosting alternative.
- "No TV nearby?" adds **Host a game** next to **Try without a TV**.
- New **"4. No TV? Host on a phone"**, in the guide's voice and size: tap **Host a game**; **Play on this phone**
  (every phone shows the game with its buttons on top; in a Shape Race each player sees their own side) or **Show
  on this device** (the host device shows the whole game, the others use their phones as controllers); the others
  pick the host in their list, where it shows as a **Phone** or a **Tablet**, or type the code; locking the host
  phone pauses the round for up to 30 s, the other phones say **Waiting for the host to come back** and count
  down, and past that the round ends and they say why; sounds play on every phone.
- One fix outside the brief's item 3: step 3 said the TV appears under "TVs on this Wi-Fi", but the Connect
  screen's heading has been **"Games on this Wi-Fi"** since M12 (s6b). Fixed, so the guide matches the app.

All the quoted strings are the app's own (`host_start_sheet.dart`, `waiting_card.dart`, `abandoned_notice.dart`,
`connect_screen.dart`). The waiting card's exact title is "Waiting for the host to come back", not the brief's
shorter "Waiting for the host"; I used the exact text in the page and the checklist.

## Item 4: `site/privacy.html` against what M12 records

What M12 records, from the code:

- **The host phone's own readings** (`packages/metrics/lib/src/session_device.dart`, `host_device_sample.dart`):
  battery at the start and end, whether it charged, whether it was in low power mode, and the seconds spent in
  each thermal state (`host.device`), plus each round's battery start and end and thermal state. Only the phone
  host has a monitor (`hostDeviceMonitorProvider` is `NoHostDeviceMonitor` on the TV), so a TV session never has
  these fields.
- **Where each player watched** (`session_player.dart`, `watchedOf`): `host_screen`, `host_phone` (the host
  phone's own player, joined in-process) or `joined_phone` (a phone that drew frames).
- **The frame rate** (`session.dart`): each round's `hz`, and each player's frame timing filed by the rate it
  arrived under (`stagesByHz`, `viewByHz`), built from the metrics batch's `stages` and `view`.
- **No upload from a phone host**: `sessionUploaderProvider` is null and only `tv_test_app` overrides it
  (`main.dart`). The phone app has no consent prompt and no Stats screen. Phone-hosted sessions are files on the
  phone and nothing more.

Sentences that no longer match, with proposed replacement text:

1. **"Controller input stays on your Wi-Fi."** — "The phone sends button presses, stick positions and tilt
   directly to the TV app on the same local network." A joined phone can now send to a phone. Replace with:
   `<li><strong>Controller input stays on your Wi-Fi.</strong> A phone sends button presses, stick positions and tilt directly to the host on the same local network: the TV app, or a phone hosting a game. Nothing goes over the internet.</li>`
2. **"Pairing and settings stay on the device."** — "To reconnect without the code, the phone and the TV app each
   save a random pairing code and a random device ID." A phone hosting also saves its pairings. Replace with:
   `To reconnect without the code, a phone and the host it joined each save a random pairing code and a random device ID.`
3. **"Device names."** — "The TV app shows each phone as something like "iPhone 3F1C" and the phone shows the
   TV's name, only on the local network." A phone's list shows a phone or tablet host's name now. Replace with:
   `The host shows each phone as something like "iPhone 3F1C", and a phone shows the name of the host it joined, only on the local network.`
4. **"The phone counts, the TV collects."** — the lead and "While a phone is connected to the TV app…", "It sends
   these counts to the TV app… The TV app adds how quick the connection is, how the games went…" The host can be a
   phone, and the host now also records where each player watched and the picture rate and frame timing. Replace
   the whole bullet with:
   `<li><strong>A phone counts, the host collects.</strong> While a phone is connected to a host, it counts things like how often each button is pressed and for how long, taps that miss a control (counted on a coarse grid, never a trace of your touches), how the sticks and tilt are used, and the settings in use. It sends these counts to the host on your Wi-Fi only. The host adds how quick the connection is, how the games went, the picture rate and frame timing of a game shown on the phones, whether each player watched the game on the host's screen or on their own phone, and the answer to "How did the controls feel?" after some games.</li>`
5. **"What it includes about the device:"** — phone or tablet, screen size, model, OS, haptics, random ID. It
   doesn't say that a phone hosting a game records its own battery, charging, low power mode and heat. The list
   stays as it is (it is about identity); add a bullet after it:
   `<li><strong>What it includes about the host phone:</strong> when a phone hosts a game, its battery level at the start and at the end, whether it was charging, whether it was in low power mode, how hot it got, and the picture rate and frame timing of the game.</li>`
6. **"Kept on the TV either way."** — "The TV app keeps a summary of each play session on the device, which you
   can see on its Stats screen and export to a file." A phone host keeps summaries too, with no Stats screen.
   Replace with:
   `<li><strong>Kept on the host either way.</strong> The host keeps a summary of each play session on the device. The TV app shows its sessions on its <strong>Stats</strong> screen and can export them to a file. A phone that hosts a game keeps its sessions on the phone, and its Diagnostics screen shows the session you just played, to send with a report.</li>`
   The last clause is true once s8c lands (it adds that line to Diagnostics); without it, the clause would be
   wrong.
7. **"Sent only with an adult's yes."** — "…Only then does it send each session summary… Nothing is shared by
   default." Still true, and worth saying why: add one sentence to the same bullet:
   `Sessions from a game hosted on a phone aren't uploaded at all.`
8. **Permissions, "Local network"** — "to find and connect to the TV app on your Wi-Fi." A phone can also host,
   which advertises. Replace with:
   `<li><strong>Local network</strong>: to find and connect to a host on your Wi-Fi, or to host a game on the phone, so other phones can find it.</li>`
9. **Permissions, "Motion sensors"** — "sent only to the TV app." Replace "the TV app" with "the host".

Sentences that still match and need no change: the "In short" card (only the TV app uploads, only with an adult's
yes on the TV); "What it never includes"; "Each phone can opt out"; "Diagnostics … They aren't sent anywhere"; the
children section; "Changes" ("the TV app will ask again": nothing new is uploaded, because the phone host never
uploads). The lead's "Effective November 1, 2026 (version 0.9.0)" is stale for 0.12.0, which is not an M12 fact,
but any edit to this page should move the date and version with it, as the page itself says.

## What the design docs say that the code doesn't do (and the reverse)

1. **`m12.md` (host interruptions): "Back within the grace period, the host resumes the round and re-sends
   `view_start` and the latest frame."** The code doesn't: `HostService.resume()` restarts the server and the
   advertising only, and `ServerGameHost._sendView` sends the start and the newest frame only to a controller that
   (re)joins, which a phone that stayed connected doesn't. It gets `host_back` and the frames go on from there.
   The design sentence should lose "and re-sends `view_start` and the latest frame" (or say "if the phone has to
   rejoin, it gets both again").
2. **The phone host has no consent prompt and no uploader.** `sessionUploaderProvider` stays null and the phone app
   has no Stats screen. The design's "consent, stats, best times and playtest settings come with `party_host`"
   holds only for the TV shell: the phone host saves sessions and shows no consent. That keeps the privacy page's
   upload sentences true, but it is a decision worth writing down.
3. **s8c is not in the code**: no "Frame rate (test)" row, no Diagnostics session line, no `metrics:report
   --paste`. Hence no mention in protocol.md or architecture.md, while the checklist has the two checks the brief
   lists. If the build 2 device tests happen before s8c, those two checks can't be run.
4. **`LiveHostService` logs under the tag `tv`** (`host_service.dart`, `log.sink('tv')`), so a phone host's log
   says "tv" in Diagnostics and in an exported log. Cosmetic; not documented anywhere.
5. **Build 1's checklist header promised that step 9 would copy the PRD's M12 acceptance tests in.** This brief's
   item 5 asks for eleven build 2 checks instead, so no PRD acceptance tests were copied. Noted as Q5 below.

## Checks

- `tools/check.sh format` needs approval in this sandbox (`cd` inside the script), so I ran its one command
  directly: `dart format --output=none --set-exit-if-changed controller_app tv_test_app packages assets` — **PASS**
  (340 files, 0 changed). Only docs and HTML changed, so nothing else was run.

## Questions

1. The waiting card's title is "Waiting for the host to come back", not the brief's "Waiting for the host": I used
   the exact text on the site and in the checklist. Keep, or the shorter phrase?
2. `m12.md`'s resume sentence promises a re-send the code doesn't do: fix the design line, or add the re-send?
3. Is the phone host staying local (no consent prompt, no upload, no Stats screen) intended for M12, so the
   privacy page keeps its upload sentences as they are?
4. Should the privacy page be edited now with the item 4 replacements and a new date and version, or with the next
   policy revision?
5. Build 1's checklist said step 9 would copy the PRD's M12 acceptance tests. Should a later job add them?
6. Should the guide's "If something doesn't work" list mention a phone or tablet host that doesn't show up?
7. Rename the phone host's log tag from `tv`, or leave it?

## Commit message

m12 docs: protocol, architecture, phone-host guide, checklist

- Protocol: the two transports, `view` and its messages, late joiners, `stages`/`view`, TXT `kind`, setup keys.
- Architecture: the packages, TV vs phone host, `shareView`, the frame path, host interruptions, phone layout.
- The guide: "No TV? Host on a phone"; "TVs on this Wi-Fi" becomes "Games on this Wi-Fi", as the app says.
- The checklist keeps build 1 and adds eleven build 2 checks, with the exact on-screen texts.
- privacy.html read against M12: nine sentences with replacements in the report; the page itself untouched.

## Status row

| 9 | **Docs done**: protocol.md (M12 additions), architecture.md (M12 section), site/index.html ("No TV? Host on a phone"), checklists/m12.md (build 2 checks); privacy.html findings in [s9-report.md](s9-report.md), not edited. **Open**: s8c (not started), the build 2 tag, the owner's device checks |

## Delete

- none
