# M12 bug triage — 1107b: a hosting iPhone shows a 10.x address instead of its Wi-Fi 192.168.x one

Read-only triage; no fix, no file changed but this report. Read: `network_addresses.dart`, `host_service.dart`,
`host_view_state.dart`, `advertiser.dart`, `host_log_export.dart`, `host_chip.dart`, `discovery.dart`,
`local_network.dart`, `host_address.dart`, `controller_client.dart`, `phone_host.dart`, `hosting.dart`,
`web_socket_listener.dart`, `pairing_panel.dart`, the `party_host` tests (none covers the address list) and
`coding-guidelines.md`. No check run: the brief's only `check:` is this report, and no test on this PC can produce an
iPhone's interface list.

The screenshot (`bug2-shot.png`, read as an image): iOS Wi-Fi details for "Beybesbabes" (the iPhone's own name at the
top), "Use Connectivity Assist" **on**, Wi-Fi 6 (802.11ax), IPv4 192.168.50.193 / 255.255.255.0, router 192.168.50.1,
IPv6 fe80::4f0:5cb9:8870:93ac. The status bar shows cellular bars **and** Wi-Fi, so the phone's cellular interface is
up while Wi-Fi carries the home LAN.

## Q 1 — where the 10.x comes from, and why it is first

**Cause** the guess holds. `_interfaceRank` (`network_addresses.dart:27-41`) is a substring match on Windows names:
Wi-Fi-like → 0 (`:38`), `eth` → 1 (`:39`), **everything else also 1** (`:40`; `:39` is a no-op), virtual/VPN → 2
(`:29-37`). `en0` and `pdp_ip0` match nothing, both 1. The comparator (`:18`) compares ranks only, so equal entries keep
`NetworkInterface.list`'s order — the OS's — and `host_chip.dart:40` shows `addresses.firstOrNull?.address`: the
cellular 10.x on the owner's iPhone.

| platform | names and today's rank |
| --- | --- |
| iOS | en0 Wi-Fi **1** · pdp_ip0/1 cellular **1** · ipsec0 **1** · bridge100 hotspot **1** · en1/en2, anpi0/1 **1** · utun0-4 **2** · awdl0/llw0 **1** (link-local, dropped at `:17`) |
| Android | wlan0 **0** · eth0, rmnet_data0/rmnet0, ccmni0, p2p0, ap0, dummy0, wg0 (WireGuard) **1** · tun0 **2** |
| Windows | Wi-Fi / Wi-Fi 2 **0** · Ethernet / Ethernet 2, Local Area Connection* 1 **1** · vEthernet (WSL/Hyper-V), Tailscale, OpenVPN Wintun **2** |
| macOS (no host ships) | en0 **1** (Wi-Fi on a MacBook, so it would misrank too) · en1-en6, bridge0, awdl0 **1** · utun* **2** |

Correction: Android is **not** misordered — `wlan0` is rank 0 and beats `rmnet*` at 1; its gap is only that a cellular
address is listed (and shown alone with Wi-Fi off).
**Confidence** sure for the ranks and the tie; likely that `pdp_ip0` came first (getifaddrs order; Dart's `List.sort`
is unstable, but for two or three entries it keeps equal keys). "unsure": that iPhone's getifaddrs order, and whether
`pdp_ip1` had an IPv4 too. Proves it: the Wi-Fi IPv4 is 192.168.50.193, so the 10.x cannot be `en0`. Fix: Q 4.

## Q 2 — what reads the list, and which join paths break

| reader | where | what it shows | does the wrong first address hurt? |
| --- | --- | --- | --- |
| host chip menu | `host_chip.dart:40`, `:57-61` | the first address only, beside the code | **yes**: it is the number the host reads out, and it is unreachable from the LAN |
| host log, exported log | `host_service.dart:334`, `host_log_export.dart:22` | every address with its interface name | no: both are there, labelled `en0`/`pdp_ip0` |
| TV app pairing panel | `pairing_panel.dart:93-107` | up to 3, each with its interface | no: a TV/PC host never has a cellular entry |
| pairing code | `host_chip.dart:41`, `:53` | the code; **no address in it** | no |
| anything sent to a joining phone | protocol messages (`packages/protocol/lib/src/messages.dart`) carry no address; no QR in the repo | — | no |
| the joining phone's target | `discovery.dart:184` (mDNS `hostAddresses`), `host_address.dart:114-130` (IPv4 first) | what mDNS resolved | no |

The advertiser picks no interface: `BonsoirBroadcast` gets only the service (`advertiser.dart:81-83`), so Bonjour
publishes on every active interface and mDNSResponder answers per interface — a phone on the home Wi-Fi resolves
`en0`'s 192.168.50.193. The server binds `anyIPv6`/`anyIPv4` (`web_socket_listener.dart:48-56`), and the host's own
player is in-process (`phone_host.dart:103`), so hosting itself is not broken.
**Answer** the bug breaks exactly one join path: **typing the address** (and with it "type the address and the code",
which is the chip's whole purpose, `host_chip.dart:9-12`). **The code** and **tapping the listed game** still work —
until mDNS is down, and then manual entry is the only fallback and it is the broken one.
**Confidence** sure for the readers and the bind (code); likely for Bonjour's per-interface answer (plugin behaviour,
not testable here). "unsure": whether the owner's second phone tried the list, the typed address, or neither.

## Q 3 — is the `-65569` DefunctConnection discovery error this bug?

**Answer** separate. `-65569` is `kDNSServiceErr_DefunctConnection`: the app's socket to mDNSResponder was reset —
usual on a network transition (Wi-Fi ↔ cellular handoff with Connectivity Assist on, or the app being suspended). The
address ranking never touches Bonsoir, and the error came from the *controller* side (`discovery.dart:112-118`), not
the advertiser. **Does the restart recover it**: yes — `restart()` (`discovery.dart:146-150`) calls `stop()` (which
cancels the subscription and clears `_discovery`) and then `start()`, which re-initialises the plugin; a bare `start()`
would have been a no-op (`discovery.dart:107`). Also expected: `0 found` while hosting, since hosting stops discovery
(`hosting.dart:34`), and starting again on stop (`:57`).
**Confidence** likely (the code path is sure; that the daemon reset was a one-off is not). Proves it: one occurrence,
then a restart, then normal `running` state.

## Q 4 — the fix

**Rule** rank by interface name per platform, and drop cellular addresses. Name first: an address rule would reorder a
Windows laptop on a 10.0.0.0/8 home LAN, and the brief needs Windows' order kept.
- **0 Wi-Fi**: `wi-fi`, `wifi`, `wlan`, `en0` (exactly; iPhone/iPad Wi-Fi) — Windows and Android unchanged.
- **1 wired / hotspot**: `eth`, `local area connection`, `bridge`, `en` + digit, `ap`.
- **2 virtual / VPN / peer-to-peer**: today's (`:29-37`) plus `ipsec`, `wg`, `p2p`, `awdl`, `llw`, `anpi`.
- **3 cellular, dropped from the list**: `pdp_ip`, `rmnet`, `ccmni`, `wwan`; no phone can reach a carrier NAT address.
**Files / lines** `network_addresses.dart:12-41` only: split a pure `orderedAddresses(Iterable<LocalAddress>)` out of
`networkAddresses()`, so names and addresses are testable without the OS. `host_chip.dart` and `pairing_panel.dart` stay
as they are, except that `state.addresses` can be empty on a cellular-only host (the chip then draws no address,
`:57`; the TV panel already says "No network connection", `pairing_panel.dart:94`).
**Test** first in a new `packages/party_host/test/network_addresses_test.dart` (none exists; no test touches the list):
`orderedAddresses([LocalAddress('10.12.7.4','pdp_ip0'), LocalAddress('192.168.50.193','en0')])`: both rank 1 today,
so input order is kept and `first.address == '10.12.7.4'`; after the fix `['192.168.50.193']`. Pin Windows too,
`[vEthernet (WSL) 192.168.1.90, Ethernet 10.0.0.9, Wi-Fi 192.168.1.50]` → `['Wi-Fi', 'Ethernet', 'vEthernet (WSL)']`
(0/1/2, passes before and after), and Android `[rmnet_data0 10.1.2.3, wlan0 192.168.1.50]` → `['wlan0']`.
**Risk** a phone hosting on mobile data loses its only address and the chip shows none, with no explanation: either add
"Turn on Wi-Fi so other phones can join", or keep cellular listed last (a design call, Q 2). Nothing in `lib/` assumes
a first address; the TV sample has one.

## Files changed

- `docs/briefs/m12/bug-1107b-triage-report.md` — new: this triage.

## Checks

- None run: the brief's only `check:` is this report, and the finding is a device interface list that this PC can't
  produce. The triage is read-only; no test or app was run.

## Questions

1. How did the second phone try to join — tapped the listed game, or typed the address and code? It decides whether
   the owner was blocked by this or by something else (tapping should have worked).
2. Cellular-only hosting: should the host chip say "Turn on Wi-Fi so other phones can join" when no address is left
   after dropping cellular, or keep the 10.x address last as a hint that hosting won't work?
3. The diagnostics mix a 22 s host session with "Discovery: running true" and an old TV target 192.168.1.100 — was
   that report captured before "Host a game" (hosting stops discovery, `hosting.dart:34`), or in two takes?
4. Did the same `DefunctConnection` error come back after the restart? One occurrence suggests a network transition;
   a repeat suggests something on this phone.

## Suggestions (not acted on)

- Log both lists while sorting is in question: the shown addresses and every dropped one, so the next report's log
  names the interface the phone actually has (the exported log already prints interfaces, not the dropped ones).
- A phone-app widget test over the chip with a two-address sample (`pdp_ip0` first), so the app side of the rule is
  pinned too; today's `samples.dart:45` has one address.
- No macOS host ships, so `en0`-as-Wi-Fi is safe for now; if a Mac host is ever added, Apple's `NWPathMonitor` (or
  `SCNetworkInterface`) is the honest source instead of names.

## Commit message

```
docs(m12): triage the hosting iPhone's 10.x address

_interfaceRank (network_addresses.dart:27-41) knows Windows names only, so
en0 and pdp_ip0 both fall through to rank 1 and the list keeps the OS order;
the host chip shows addresses.first, the carrier 10.x. The server binds every
interface and mDNS answers per interface, so hosting and tapping the game
work — only typing the address breaks. Fix: rank en0 as Wi-Fi, drop cellular
addresses, with a pure orderedAddresses test (en0 first, Windows unchanged).
Open: what a cellular-only host should say.
```

## Status row

| Bug triage 1107b | G0 survey done ([bug-1107b-triage-report.md](bug-1107b-triage-report.md)): `_interfaceRank` (`network_addresses.dart:27-41`) matches only Windows names, so iOS `en0` (Wi-Fi) and `pdp_ip0` (cellular 10.x) tie at rank 1 and the chip (`host_chip.dart:40`) shows the OS's first — the cellular one; Android already ranks `wlan0` first. Hosting, the mDNS list and the code still work; only typing the address breaks, and the `-65569` discovery error is separate and recovers on restart. Fix proposed: name-based ranks (en0 = Wi-Fi, cellular dropped, Windows order kept) behind a pure `orderedAddresses` with a failing test. Open: how the second phone tried to join, and whether a cellular-only host shows a hint |

## Delete

- none
