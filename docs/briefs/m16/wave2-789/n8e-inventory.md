# n8e inventory: the word "TV" in user-visible strings

Read-only inventory (n8e0). Scope: string literals in `controller_app/lib` and `packages/*/lib`.
Comments, identifiers, keys and `tv_test_app` are left out. Rule (owner decision 7, APP-START.md:60-90):
generic display-device text says "screen"; "Thumb Party TV" and "Android TV" stay.
"TV app" is short for the Thumb Party TV app: CHANGE it to the spelled-out name (Q1).

Method: `rg` for `TV`/`tv` inside a quoted literal on the same line, comment lines dropped by hand.
Test columns come from `rg -F` of the old text under `controller_app/test` and `packages/*/test`.
A "none" test column means no test asserts the literal text. Tests may still pin it through a constant;
each job re-runs `rg -F` before it edits.

## Line counts (lib files that hold a hit)

| File | Lines | Hits |
|---|---|---|
| controller_app/lib/src/local_network.dart | 78 | 4 |
| controller_app/lib/src/discovery.dart | 210 | 1 |
| controller_app/lib/src/providers/game_feedback.dart | 105 | 1 |
| controller_app/lib/src/ui/controller_parts.dart | 196 | 1 |
| controller_app/lib/src/ui/diagnostics_screen.dart | 363 | 3 |
| packages/connection/lib/src/client_connection.dart | 241 | 1 |
| packages/connection/lib/src/client_messages.dart | 243 | 8 |
| packages/connection/lib/src/host_connection.dart | 304 | 1 |
| packages/connection/lib/src/host_address.dart | 177 | 2 |
| packages/game_kit/lib/src/frame_view.dart | 318 | 1 |
| packages/party_host/lib/src/text/settings_text.dart | 251 | 10 |
| packages/party_host/lib/src/text/consent_text.dart | 30 | 1 |
| packages/party_host/lib/src/text/host_text.dart | 379 | 1 |
| packages/party_host/lib/src/text/phone_text.dart | 265 | 15 |

## controller_app/lib (hits)

| File:line | Text (abridged) | Verdict | Replacement | Tests asserting it |
|---|---|---|---|---|
| local_network.dart:44 | "A TV was found or connected, so local network access is on." | CHANGE | "A screen was found or connected, …" | none |
| local_network.dart:59 | "No TV found yet. …" | CHANGE | "No screen found yet. …" | none |
| local_network.dart:60 | "…check that the TV app is open …" | CHANGE | "…check that the Thumb Party TV app is open…" (Q1) | none |
| local_network.dart:65 | "…as soon as a TV is found." | CHANGE | "…as soon as a screen is found." | none |
| discovery.dart:171 | log "A TV was found but its address could not be resolved" | CHANGE | "A screen was found but …" | none |
| providers/game_feedback.dart:90 | log "The TV asks how the controls felt (…)" | CHANGE | "The screen asks how …" | phone_metrics_test.dart:266 (check the text it pins) |
| ui/controller_parts.dart:143 | "Demo: a TV would get …" | CHANGE | "Demo: a screen would get …" | store_builds_test.dart:16, 20 |
| ui/diagnostics_screen.dart:293 | "Connection: …, TV ${hostLabel}, …" | CHANGE | "…, screen ${hostLabel}, …" | none |
| ui/diagnostics_screen.dart:299 | "…TV events … received … played (last …)" | CHANGE | "…screen events …" | none (haptics_test.dart:87, 130 pin "TV events"/"Last TV event": check which lib text) |
| ui/diagnostics_screen.dart:306 | "TV event strengths: …" | CHANGE | "Screen event strengths: …" | none |

## packages/connection/lib (hits)

| File:line | Text (abridged) | Verdict | Replacement | Tests asserting it |
|---|---|---|---|---|
| client_connection.dart:148 | log "…without the TV, reconnecting now" | CHANGE | "…without the screen…" | none |
| client_messages.dart:71 | log "Ignoring unexpected … from the TV" | CHANGE | "…from the screen" | none |
| client_messages.dart:90 | log "The TV made this phone player N" | CHANGE | "The screen made …" | none |
| client_messages.dart:149 | log "The TV uses protocol v…, this phone uses v…" | CHANGE | "The screen uses protocol v…" | none (pairing_test.dart:132, transport_test.dart:135 match "protocol v": check) |
| client_messages.dart:152 | "TV protocol v…, phone v…" | CHANGE | "Screen protocol v…, phone v…" | none |
| client_messages.dart:156 | log "Bad message from the TV: …" | CHANGE | "Bad message from the screen: …" | none |
| client_messages.dart:179 | log "Welcome from … (TV app …" | CHANGE | "(Thumb Party TV app …" (Q1) | none |
| client_messages.dart:218 | log "The TV no longer knows this phone…" | CHANGE | "The screen no longer knows …" | none |
| client_messages.dart:227 | log "Too many wrong codes, the TV shows a new one" | CHANGE | "…the screen shows a new one" | none |
| host_connection.dart:193 | close reason "The TV app uses protocol v…" | CHANGE | "The Thumb Party TV app uses protocol v…" (Q1) | none |
| host_address.dart:35, 56 | "Enter the address shown on the TV" (FormatException) | CHANGE | "Enter the address shown on the screen" | none (host_address_test pins "Thumb Party TV" = KEEP) |

## packages/game_kit/lib (hits)

| File:line | Text | Verdict | Replacement | Tests asserting it |
|---|---|---|---|---|
| src/frame_view.dart:20 | "Update the TV to see this game" | CHANGE | "Update the screen to see this game" | none |

## packages/party_host/lib/src/text (hits)

| File:line | Text (abridged) | Verdict | Replacement | Tests asserting it |
|---|---|---|---|---|
| settings_text.dart:18 | "…and the TV's game events" | CHANGE | "…and the screen's game events" | none |
| settings_text.dart:21 | tvEvents = "TV events" | CHANGE | "Screen events" | haptics_test.dart:87 (check) |
| settings_text.dart:23 | "How strong each event from the TV feels…" | CHANGE | "…from the screen…" | none |
| settings_text.dart:70 | "Share control stats with the TV" | CHANGE | "Share control stats with the screen" | none |
| settings_text.dart:138 | tvRow = "TV" | CHANGE | "Screen" | none |
| settings_text.dart:140 | tvIdRow = "TV ID" | CHANGE | "Screen ID" | none |
| settings_text.dart:163 | eventStrengthsRow = "TV event strengths" | CHANGE | "Screen event strengths" | none |
| settings_text.dart:165 | tvEventsRow = "TV events" | CHANGE | "Screen events" | haptics_test.dart:87 (check) |
| settings_text.dart:167 | lastEventRow = "Last TV event" | CHANGE | "Last screen event" | haptics_test.dart:130 (check) |
| settings_text.dart:227 | playerOnTv: "P2 on the TV" | CHANGE | "P2 on the screen" | none |
| consent_text.dart:17 | "…(on the TV, on the Stats screen)…" | CHANGE | "…(on the screen, on the Stats screen)…" | none |
| host_text.dart:272 | "…(on the TV, on the Stats…" | CHANGE | "…(on the screen, on the Stats…" (shorter, no line growth) | none |
| phone_text.dart:19 | connectTitle "Connect to a TV" | CHANGE | "Connect to a screen" | connect_screen_test.dart:31, 76, 114, 138, 163, 177; connect_consent_pop_test.dart:26; joined_view_test.dart:205; launch_consent_test.dart:64, 72; phone_fit_test.dart:60; phone_home_screen_test.dart:80; store_builds_test.dart:11, 14 |
| phone_text.dart:26 | kindTv = "TV" (kind label) | CHANGE | "Screen" | none found (check list rows in tests) |
| phone_text.dart:37 | "Searching… Open the Thumb Party TV app on the TV or PC…" | CHANGE | "…on the screen or PC…" (the app name stays) | none |
| phone_text.dart:39 | "Type the address shown on the TV below." | CHANGE | "…shown on the screen below." | none |
| phone_text.dart:45 | tryWithoutTv "Try without a TV" | CHANGE | "Try without a screen" | store_builds_test.dart:9 |
| phone_text.dart:63 | pickATv "Pick a TV on the left, or type its address." | CHANGE | "Pick a screen on the left, …" | none |
| phone_text.dart:102 | "Check that the TV app is open…" | CHANGE | "…the Thumb Party TV app is open…" (Q1) | none |
| phone_text.dart:103 | "Check the code on the TV…" | CHANGE | "…on the screen…" | none |
| phone_text.dart:104 | "The TV now shows a new code." | CHANGE | "The screen now shows …" | none |
| phone_text.dart:106 | "The TV doesn't remember this phone…" | CHANGE | "The screen doesn't remember…" | none |
| phone_text.dart:108 | "The TV app and this app use different protocol versions…" | CHANGE | "The Thumb Party TV app and this app…" (Q1) | none |
| phone_text.dart:109 | "…connected to the TV again…" | CHANGE | "…connected to the screen again…" | none |
| phone_text.dart:110 | "The TV rejected a message…" | CHANGE | "The screen rejected a message…" | none |
| phone_text.dart:119 | demoLink "Demo, no TV · tap to connect" | CHANGE | "Demo, no screen · tap to connect" | store_builds_test.dart:15 |
| phone_text.dart:141 | "You are player N on the TV" | CHANGE | "You are player N on the screen" | none |

## KEEP (names the app or platform; pinned by decision 7)

| File:line | Text | Reason |
|---|---|---|
| packages/connection/lib/src/saved_pairing.dart:39 | 'Thumb Party TV' (fallback host name) | app name |
| packages/party_host/lib/src/testing/samples.dart:12 | hostName 'Android TV' | platform name (fixture) |
| packages/party_host/lib/src/testing/samples.dart:47 | 'Thumb Party TV (Android TV)' | app and platform name |
| phone_text.dart:37 (part) | "Thumb Party TV app" | app name |

## Not user text (left alone)

- `packages/party_host/lib/src/text/phone_text.dart:34` `'tv' => kindTv`: switch key, not text.
- `packages/party_host/lib/src/host_identity.dart:4` `static const tv = 'tv'`: identifier value.
- `packages/party_host/lib/src/keep_awake.dart:47` `add('tv', line)`: log tag.
- Every other hit is a `///` or `//` comment.

## Sweep plan (one job per group, at most 8 files each, in order)

| Job | Files (lib + pinning tests) | Count | 380-line risk |
|---|---|---|---|
| J1 | phone_text.dart (265) + connect_screen_test, connect_consent_pop_test, joined_view_test, launch_consent_test, phone_fit_test, phone_home_screen_test, store_builds_test | 8 | none (265) |
| J2 | settings_text.dart (251) + haptics_test.dart + any party_host settings test found by rg | 3 | none (251) |
| J3 | host_text.dart (379) + consent_text.dart (30) | 2 | host_text at 379: rewording is shorter, but run mine.sh; split if over 380 |
| J4 | local_network.dart (78), discovery.dart (210), game_feedback.dart (105), phone_metrics_test.dart | 4 | none |
| J5 | controller_parts.dart (196) + store_builds_test.dart (if not in J1) | 2 | none |
| J6 | diagnostics_screen.dart (363) + haptics_test.dart (if not in J2) | 2 | 363: near the 380 line; the edits add no lines |
| J7 | client_messages.dart (243), host_connection.dart (304), client_connection.dart (241), host_address.dart (177) + pairing_test, transport_test (check) | 6 | host_connection 304 and client_messages 243: fine |
| J8 | frame_view.dart (318) | 1 | none |

Ordering: J1 first (largest user-visible set), then J2 and J3 (party_host text), then J4-J8.
Every job re-runs `rg -F` on its old text before it edits, because the test column is from a literal search only.
