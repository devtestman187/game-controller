# M12 bug 1107b fix — G4 report: a hosting phone shows its Wi-Fi address, never a cellular one

Done at G4, the gate the brief names. No file outside `allow:` was edited (see "Not sure" for three
`tv_test_app/windows` generated files that the Flutter tool touched while the tv check ran).

## Files changed

- `packages/party_host/lib/src/network_addresses.dart` — the address rule. `orderedAddresses(Iterable<LocalAddress>)`
  is the new pure function: it drops cellular names (`pdp_ip`, `rmnet`, `ccmni`, `wwan`) and sorts by rank — Wi-Fi `0`
  (including `en0` exactly, plus `wi-fi`/`wifi`/`wlan`/`wireless`), wired or hotspot `1` (the fallback, so "Ethernet",
  `eth0`, `bridge100` and `ap0` land here as they did), virtual, VPN or peer-to-peer `2` (the old virtual list plus
  `ipsec`, `wg`, `p2p`, `awdl`, `llw`, `anpi`). Equal ranks keep the input order: the list is sorted on `(rank, index)`,
  since Dart's `List.sort` isn't stable. `networkAddresses()` now returns `AddressScan`, a record of `shown` and
  `dropped` from one read of the interfaces; the ranks are named constants; the Windows order is unchanged.
- `packages/party_host/lib/src/host_service.dart` — `_refreshAddresses` reads the scan and logs `_addressesLine(scan)`
  when the shown list changes: every interface the OS gave, with its address, and which ones were dropped. Line count
  351 → 361 (limit 400).
- `packages/party_host/lib/party_host.dart` — `export 'src/network_addresses.dart' show orderedAddresses;` so the test
  pins the rule (no test in the repo imports a package's `src/` directly).
- `controller_app/lib/src/ui/host_chip.dart` — the menu's address line is a new private `_JoinHint`: the address under
  `hostAddress`, or, with none, "Turn on Wi-Fi so other phones can join" under `hostNoWifi`, in the same style and
  padding as the address. The chip's `build` stays under 60 lines.
- `packages/party_host/test/network_addresses_test.dart` — new, 5 tests for the rule (values below).
- `controller_app/test/host_chip_test.dart` — new, 2 widget tests: the chip menu with no address shows `hostNoWifi` and
  no `hostAddress`; with `en2` listed before `en0` it shows `192.168.50.193` (en0's). The tests put their own
  `HostViewState` behind `hostStateProvider` (`_FixedHostState`), so the addresses don't depend on this PC; the second
  one orders its two addresses through `party.orderedAddresses`, as the host does.
- `docs/briefs/m12/bug-1107b-fix-report.md` — this report.

No existing test was changed: no test in the repo asserted the address order, the chip's address key or the
`Addresses:` log line (checked by grep over the tests and `tools/*.sh`).

## Computed test values

`network_addresses_test.dart` (input → output; ranks computed by the rule):

1. an iPhone lists only its Wi-Fi address, not the cellular one:
   `[10.12.7.4 pdp_ip0 (cellular → dropped), 192.168.50.193 en0 (0)]` → `[192.168.50.193 en0]`. Before the fix both were
   rank 1 and the OS order was kept, so the list was `[10.12.7.4 pdp_ip0, 192.168.50.193 en0]` — the bug.
2. a Windows PC keeps Wi-Fi, then Ethernet, then the virtual adapter:
   `[192.168.1.90 vEthernet (WSL) (2), 10.0.0.9 Ethernet (1), 192.168.1.50 Wi-Fi (0)]` →
   `[Wi-Fi, Ethernet, vEthernet (WSL)]`. Passes before and after, by design.
3. an Android phone lists only its Wi-Fi address, not the cellular one:
   `[10.1.2.3 rmnet_data0 (cellular → dropped), 192.168.1.50 wlan0 (0)]` → `[wlan0]`.
4. the iPhone en0 comes before another en interface the OS listed first:
   `[192.168.0.2 en2 (1), 192.168.50.193 en0 (0)]` → `[192.168.50.193 en0, 192.168.0.2 en2]`. Before the fix both were
   rank 1, so `en2` stayed first — the second half of the bug.
5. two interfaces of one rank keep the order the OS gave them:
   `[192.168.1.70 en3 (1), 192.168.1.50 wlan0 (0), 192.168.1.60 en1 (1)]` → `[wlan0, en3, en1]`: en3 and en1 keep their
   input order.

`host_chip_test.dart`:

- cellular only: `addresses: []` → the menu has `hostNoWifi` with "Turn on Wi-Fi so other phones can join" and no
  `hostAddress`.
- `orderedAddresses([192.168.0.2 en2, 192.168.50.193 en0])` → `[192.168.50.193 en0, 192.168.0.2 en2]`; the chip shows
  `192.168.50.193` and no `hostNoWifi`.

Failing before the fix: both new test files use `orderedAddresses` / `hostNoWifi`, which didn't exist, so they don't
compile against the old code; with the rule alone reverted, cases 1, 3 and 4 fail as shown above. I did not run the old
code to show the red run.

## The log line

Exact text (one line per change of the shown list, prefix kept):

- `Addresses: 192.168.50.193 (en0), 192.168.0.2 (en2); dropped 10.1.2.3 (pdp_ip0)`
- with nothing dropped: `Addresses: 192.168.1.50 (wlan0)`
- with nothing shown: `Addresses: none` (the old code logged a bare `Addresses: `)
- with everything dropped: `Addresses: none; dropped 10.1.2.3 (pdp_ip0)`

A real run on this PC (from the phone widget test's log) printed `[host] Addresses: 192.168.1.124 (Ethernet)`: no
dropped part, because this PC has no cellular interface. Nothing in `tools/*.sh` (smoke.sh included) or in the tests
reads the line; the prefix is kept anyway.

## Checks

- `tools/check.sh format analyze host phone tv` — all PASS: format (1 s), analyze (7 s), host (81 tests), phone
  (331 tests), tv (10 s; `flutter test` in `tv_test_app` reports `+28 ~1`).
- Test counts before → after: host 76 → 81 (+5: the new rule file), phone 329 → 331 (+2: the new chip file), tv 28
  passed and 1 skipped, with no tv test changed.
- `tools/review.sh` — 0 fail, 2 notes: `number controller_app/lib/src/ui/host_chip.dart:94` (the `16` padding the address
  line always had, moved into `_JoinHint`), `size packages/party_host/lib/src/host_service.dart:1` 361 lines (limit 400).
- `tools/review.sh --strings` — 2 removed, 18 added; the new strings are the Wi-Fi hint, the `hostNoWifi` key, the rank
  names and the log text; nothing personal.

## Not sure

1. **Wired and hotspot names have no entry of their own.** Rank 1 is the fallback for every name the Wi-Fi, virtual and
   cellular lists don't match, which is what keeps Windows' order and is what the old code did. Listing `eth`, `bridge`,
   `en`+digit and `ap` explicitly would be dead conditions; I documented which names land there instead. If Claude
   wanted the names written out as a guard for a later re-rank, that is a one-line change.
2. **`AddressScan` is not exported**, only `orderedAddresses` is (`show`), so the package's public surface grows by one
   function. There was no precedent for tests importing `package:.../src/`, so I exported rather than import `src/`.
3. **The log line has no test of its own**: `_addressesLine` is private and only reachable through a real interface read.
   It could move next to the scan in `network_addresses.dart` and be exported if Claude wants it pinned.
4. **`en0` exactly ranks as Wi-Fi even in Personal Hotspot mode**, where iOS may hand `en0` a 172.20.10.x address. That is
   still the reachable one for a phone joining, so I left it.
5. **Three `tv_test_app/windows` generated files show as modified in `git status`** (`generated_plugin_registrant.cc/.h`,
   `generated_plugins.cmake`) after the Flutter tool ran the tv check. I didn't edit them; `git diff --numstat` lists
   nothing for them (line endings only, content identical). Worth a `git diff` before committing; I couldn't clean them
   (git commands that change files are off-limits).
6. **Suggestion, not acted on:** a `host_log_export_test` case with a dropped address, once the log line is testable
   (see 3); and the exported log's header still prints `Addresses:` with the shown list only, as it did — it may deserve
   the dropped ones too.

## Commit message

fix(m12): a hosting phone shows its Wi-Fi address, not cellular

_interfaceRank knew Windows names only, so an iPhone's en0 (Wi-Fi) and
pdp_ip0 (cellular) both fell through to rank 1 and the OS's order won: the
host chip showed the carrier 10.x. orderedAddresses ranks Wi-Fi (en0
exactly) first, then wired and hotspot, then virtual and peer-to-peer, and
drops cellular; equal ranks keep the OS's order. The host logs every
interface with what became of it, and with no address left the chip says
"Turn on Wi-Fi so other phones can join". Windows' order is unchanged.

## Status row

| Bug fix 1107b | G4 done ([bug-1107b-fix-report.md](bug-1107b-fix-report.md)): `orderedAddresses` ranks `en0` as Wi-Fi, drops cellular (`pdp_ip`, `rmnet`, `ccmni`, `wwan`) and sorts stably, so the chip shows the reachable address; the host log names every interface and what was dropped; with none left the chip says "Turn on Wi-Fi so other phones can join". Tests 76→81 (host) and 329→331 (phone); checks pass, review 0 fail. Open: the owner confirms on the next build; Q 1 (the second phone not seeing the iPhone in "Games on this Wi-Fi") is with Claude; the `-65569` discovery error is left alone (Q 3/Q 4) |

## Delete

- none
