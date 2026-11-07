job: m12 bug 1107b fix G4 — a hosting phone shows its Wi-Fi address, never a cellular one
stop: after G4.
read: docs/briefs/m12/bug-1107b-triage-report.md (your triage: Claude approves Q 4's fix with the answers below) · packages/party_host/lib/src/{network_addresses,host_service,host_view_state}.dart · controller_app/lib/src/ui/host_chip.dart · packages/party_host/lib/src/testing/samples.dart · controller_app/test (the host chip's tests)

Claude's answers: Q1 the owner's second phone doesn't see the iPhone in "Games on this Wi-Fi" at all; that is a separate question, not this fix (Claude is getting the host log) · Q2 drop cellular; with no address left, the chip menu says "Turn on Wi-Fi so other phones can join" where the address goes · Q3 two takes: the Diagnostics were copied after hosting stopped · Q4 it came back once more 7 min later, then recovered; leave it.
More from the owner: with mobile data off, the chip showed 192.168.0.2 while Wi-Fi (`en0`) was 192.168.50.193, so another interface also ties with `en0` and wins. Ranking `en0` as Wi-Fi covers it, whatever it is.

do:
1 `network_addresses.dart`: Q 4's rule (0 Wi-Fi incl. `en0` exactly · 1 wired/hotspot · 2 virtual/VPN/peer-to-peer · cellular `pdp_ip`, `rmnet`, `ccmni`, `wwan` dropped), behind a pure `orderedAddresses`. Sort stable (by rank, then input order), since Dart's `List.sort` isn't. Windows' order unchanged.
2 `host_service.dart`: when the list changes, log every interface the OS gave with its address and what became of it, e.g. `Addresses: 192.168.50.193 (en0), 192.168.0.2 (en2); dropped 10.1.2.3 (pdp_ip0)`. Keep the `Addresses:` prefix (tools may read it; check smoke.sh and tests).
3 `host_chip.dart`: no address → the Wi-Fi line from Q2 (key `hostNoWifi`), same style as the address.
tests (failing before 1 and 3):
- `packages/party_host/test/network_addresses_test.dart`: the triage's three cases (iOS `pdp_ip0` first → only `en0`; Windows 0/1/2 order kept; Android `rmnet_data0` dropped), plus iOS `en2` 192.168.0.2 listed before `en0` → `en0` first, and equal ranks keep input order.
- a phone-app widget test: the chip menu with a cellular-only host shows `hostNoWifi` and no `hostAddress`; with `en0` + `en2` shows en0's address.
- existing tests: none should change; list any old → new.
in the report: test counts before and after, the files changed, the log line's exact text.
rules: no lib file over 400 · tools/review.sh: no FAIL on your lines.
allow: docs/briefs/m12/bug-1107b-fix-report.md · packages/party_host/lib · packages/party_host/test · controller_app/lib/src/ui/host_chip.dart · controller_app/test
check: format analyze host phone tv
report: docs/briefs/m12/bug-1107b-fix-report.md
