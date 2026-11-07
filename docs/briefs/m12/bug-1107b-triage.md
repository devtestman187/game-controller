job: m12 bug triage — a hosting iPhone shows a 10.x address instead of its Wi-Fi 192.168.x address; read-only
stop: after the triage. Change no file but the report; fix nothing.
read: packages/party_host/lib/src/{network_addresses,host_service,host_view_state,advertiser,host_log_export}.dart · controller_app/lib/src/ui/host_chip.dart · controller_app/lib/src/{discovery,local_network}.dart · packages/connection/lib/src/{host_address,controller_client}.dart · packages/party_host/test (tests on addresses) · docs/coding-guidelines.md · the owner's screenshot docs/briefs/m12/bug2-shot.png (read it as an image: iOS Wi-Fi details, IP 192.168.50.193, router 192.168.50.1)

the owner's report:
- did: iPhone, build m12.4 (0.12.0, 187), Wi-Fi on (Wi-Fi 6, 192.168.50.193/24) with mobile data on, Host a game · expected: the host chip shows the phone's Wi-Fi address · happened: "the phone is showing a 10.x.x.x subnet IP for hosting where the phone's actual IP is 192.168.x.x. This prevents me from hosting a game."
- Diagnostics from the same iPhone: a host session of 22 s, one player (its own), `watched: host_phone`; the controller part still points at an old TV 192.168.1.100 (timed out, expected: no TV there); `Discovery: running true, 0 found`; one `Bonsoir … -65569: DefunctConnection` discovery error at 17:38:44, then a restart.
- my guess, check it: `_interfaceRank` knows Windows names only. On iOS Wi-Fi is `en0` and mobile data `pdp_ip0` (a carrier 10.x address); both rank 1, so the OS's order decides and the chip shows `addresses.first`. Android has the same gap (`wlan0` vs `rmnet*`, `ccmni*`); also iOS `utun*`, `ipsec*`, `bridge100` (Personal Hotspot), `awdl0`, `llw0`.

questions:
1 Where does the 10.x address come from and why is it first: confirm or correct the guess with file:line. List every interface name each platform gives (iOS, Android, Windows, macOS if any) and the rank each gets today.
2 What reads the address list: the host chip, the host log, the pairing code / QR, the TV app's panel, anything sent to a joining phone. For each, does the wrong first address stop a join? A phone joining from "Games on this Wi-Fi" resolves the host via mDNS: does the advertiser bind or announce on a chosen interface, or all of them (Bonsoir / NSNetService on iOS)? So which join paths does this bug break: typing the address, the code, tapping the listed game?
3 Is the `-65569 DefunctConnection` discovery error linked to this bug, or separate (iOS mDNSResponder resetting)? Does the restart recover it? Short answer.
4 The fix: how to rank (by name per platform, and/or prefer private 192.168/172.16–31 over 10.x carrier ranges, and/or drop cellular interfaces since a joining phone can't reach them), and whether a cellular address should show at all. The rule must keep Windows' current order. Files, lines, what it could break, and the failing test you'd write first (the ranking is pure, so it's testable with names and addresses).

format (the report, at most 20 lines per question block): `## Q N — <name>` with Cause/Answer, Confidence (sure / likely / guess) and what proves it, Fix, Test, Risk. Mark anything inferred "unsure". No code longer than 5 lines.

allow: docs/briefs/m12/bug-1107b-triage-report.md
check:
report: docs/briefs/m12/bug-1107b-triage-report.md
