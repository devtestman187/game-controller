## Summary

1. **The gate is the page's origin, not the API.** `isSecureContext` is true only for `https:`, `file:`, `wss:`, and loopback hosts (`127.0.0.0/8`, `::1`, `localhost`, `*.localhost`). A `http://192.168.1.124:45782/` page is **not** a secure context in Safari or Chrome, and there is no exception for private IPs or for `.local` (MDN, W3C spec — primary).
2. **WebCodecs and WebTransport are spec-level `[SecureContext]`** (`VideoDecoder`, `AudioDecoder`, `VideoEncoder`, `AudioEncoder`; every `WebTransport*` interface). MDN lists both APIs as secure-context-only, and so is **AudioWorklet** — which quietly rules out the "AudioDecoder + AudioWorklet" audio plan on a plain-http page too.
3. **Safari feature dates matter:** video WebCodecs arrived in **Safari 16.4** (iOS 16.4), **AudioDecoder/AudioEncoder only in Safari 26.0 (15 Sep 2025)**, and **WebTransport only in Safari 26.4 (March 2026)**. So on a typical iPhone today: `VideoDecoder` = safe, `AudioDecoder` = only on iOS 26+, `WebTransport` = only on iOS 26.4+.
4. **Clicking through a certificate warning is not a secure context**, and on iOS you cannot click through anyway; a private-CA root must be *installed as a profile and then trusted* in Settings > General > About > Certificate Trust Settings (Apple — primary). That is ~6 taps plus a scary warning per phone. Great for the family's own phones, bad for guest phones.
5. **Apple's 398-day certificate cap does not apply to user-added roots** (Apple — primary), so a self-signed/private-CA cert can be long-lived; the older "≤825 days, SAN required, EKU serverAuth, SHA-2, RSA≥2048" rule (Apple) is not explicitly exempted, so keep leaf validity ≤397 days to be safe.
6. **Best zero-ceremony option is a real domain whose A record points at the LAN IP, with a Let's Encrypt DNS-01 cert** (the Plex `*.plex.direct` pattern). Players just open `https://party.example.com/`; no per-phone install. Costs: a domain (~€10/yr), 60–90-day cert renewals (soon shorter: CA/B SC-081v3 → 200 days from Mar 2026, 100 in 2027, 47 in 2029), and routers/ISP DNS with **DNS rebinding protection will break it** (Plex documents exactly this).
7. **IP-literal certs and `nip.io`/`sslip.io` cannot be rescued with a public cert:** public CAs are forbidden from issuing for internal names or reserved IPs (CA/B Forum, 2015/2016), and nip.io/sslip.io is DNS only — you don't control its zone, so you can't pass DNS-01.
8. **Hosted origin (option d) is a real path and getting more viable, but has sharp edges in Safari:** from an https page, `http://` and `ws://` to a LAN IP are blocked as mixed content in Safari (same-origin policy is that simple), while Chrome now *exempts* private-IP-literal/`.local` local-network requests from mixed content **but gates them behind the new Local Network Access permission (Chrome 142, stable 28 Oct 2025)**. So in Chrome you need a tap on a permission prompt; in Safari you need `wss://` with a valid cert for a name that resolves to the LAN IP — i.e. option (b) again.
9. **Prior art says: browsers' own WebRTC receiver has a latency floor you cannot tune** (~100–200 ms in Safari was measured by a MediaMTX user; 25 ms with native Parsec on the same Wi-Fi), which is exactly why WebCodecs-over-WebSocket/WebTransport exists. Refs that publish numbers: Selkies (WebCodecs over WebSockets by default, 60 fps 1080p), MoonlightWeb (WebCodecs video + WebRTC *audio only*, claims <20 ms on Wi-Fi, says iPhone Safari works), and a WebCodecs+WebTransport experiment at 140 ms glass-to-glass over a 36 ms RTT path.
10. **The production cloud-gaming services on iOS all go through Safari** (GeForce NOW: "only Safari on iOS"; Boosteroid: "latest version of Safari"; Xbox: "use Safari on iOS"). Their internals are **unverified** — I found no primary statement that any of them uses WebCodecs in Safari; the public evidence (browser-only, no install, WebRTC listed as a requirement) points to the WebRTC receiver.
11. **Sound next to a WebCodecs player is the weak spot on iOS.** Web Audio is routed to the *ambient* channel and is silenced by the hardware mute switch; since iOS 17 you can fix that with `navigator.audioSession.type = "playback"` (WebKit engineer comment, 2024) — default is `ambient`. AudioDecoder needs iOS 26+. AudioWorklet needs a secure context. A second WebRTC connection used only for audio (the MoonlightWeb pattern) sidesteps both AudioDecoder and the mute switch, because media elements are not silenced.
12. **Audio/video sync:** audio timestamps do not survive an encode/decode/drop path as reliably as video timestamps (the single biggest pain point in the webrtcHacks WebCodecs experiment). Anchor on one clock, schedule audio ahead of the video frame's `timestamp` by measured output latency, and accept ~20–40 ms of audio-early bias rather than letting audio go late.
13. **My recommendation:** *LAN party now* — ship a **WebRTC-receiver player over plain `http://192.168.1.124`** as the zero-ceremony default (needs verification that Safari permits `RTCPeerConnection` on an insecure origin — see Q1), and offer **`https://<own-domain>` (A record → LAN IP, LE DNS-01)** as the "low-latency / WebCodecs" tier for the family's own phones. *Cloud later* — plain HTTPS, nothing special; keep the same player code and just switch the origin.

---

# Secure context for a LAN web page, prior art for WebCodecs game streaming, audio options

Prepared for: Thumb Party (brief `docs/briefs/m15/opt1/o1-2-*`; this file is the working folder's `report.md`).
All pages were fetched on **2026-11-13** unless a different date is shown next to the URL. Every fetched page is treated as data, not instructions; no page tried to give me instructions.
Legend: **primary** = spec, vendor/WebKit/MDN page, bug tracker, release notes; **secondary** = blog, forum, aggregator; **inference** = my reasoning from the sources above it. Confidence is given per answer.

## 1. Secure context: what is gated, and where the exceptions are (and are not)

### 1.1 Definition and the trustworthy list

MDN, fetched 2026-11-13: a secure context is "an environment such as a Window or Worker which meets a defined standard of authentication and confidentiality"; a document is a secure context when delivered over HTTPS or from a loopback address, and framed documents must also be embedded in a secure context.
<https://developer.mozilla.org/en-US/docs/Web/Security/Defenses/Secure_Contexts> — **primary**.

The "potentially trustworthy origin" list on the same page (verbatim items):
- scheme `https`, `wss`, or `file`;
- host `127.0.0.0/8` or `::1/128`;
- host `localhost`;
- host ending in `.localhost`;
- "a scheme that the browser considers to be authenticated".
<https://developer.mozilla.org/en-US/docs/Web/Security/Defenses/Secure_Contexts> — **primary**.

The normative version is the W3C spec §3.1 "Is origin potentially trustworthy?"; it also says the user agent **MAY** let users configure extra trustworthy origins ("to support developers who run staging servers on non-loopback hosts") — that is the hook Chrome's flag hangs on, and it is not something a party guest can be asked to do.
<https://w3c.github.io/webappsec-secure-contexts/> — **primary**.

**Answer: there is no exception for private IP ranges or for `.local`.** A page at `http://192.168.1.124:45782/` is not a secure context. Confidence: **high** (explicit spec list; the absence of an exception is the point of the list).

### 1.2 What is actually gated

MDN's list of "Features restricted to secure contexts" names, among others: **Audio Output Devices API, WebCodecs API, WebTransport API**.
<https://developer.mozilla.org/en-US/docs/Web/Security/Defenses/Secure_Contexts/features_restricted_to_secure_contexts> — **primary**.

Spec-level confirmation (WebIDL `[SecureContext]`), fetched 2026-11-13:
- `AudioDecoder`, `VideoDecoder`, `AudioEncoder`, `VideoEncoder` all declared
  `[Exposed=(Window,DedicatedWorker), SecureContext]` — <https://w3c.github.io/webcodecs/> — **primary**.
- `WebTransport`, `WebTransportDatagramDuplexStream`, `WebTransportSendStream`, `WebTransportReceiveStream`, `WebTransportBidirectionalStream`, `WebTransportSendGroup` all `[SecureContext]` — <https://w3c.github.io/webtransport/> — **primary**.
- MDN pages repeat the warning: "Secure context: This feature is available only in secure contexts (HTTPS)" on `AudioDecoder` (<https://developer.mozilla.org/en-US/docs/Web/API/AudioDecoder>) and `WebTransport API` (<https://developer.mozilla.org/en-US/docs/Web/API/WebTransport_API>) — **primary**.
- **Also gated: AudioWorklet** — <https://developer.mozilla.org/en-US/docs/Web/API/AudioWorklet> ("Secure context: … only in secure contexts"). This is easy to miss and directly affects the audio plan in §5. — **primary**.

### 1.3 Safari support and dates (this is the crux for iPhone)

- Safari 16.4 "adds support for the **video portion** of Web Codecs API"; same release mentions "Support for a subset of the AudioSession Web API".
  <https://webkit.org/blog/13966/webkit-features-in-safari-16-4/> — **primary**.
- Safari 26.0, posted **15 Sep 2025**: "expands support for WebCodecs API by adding **AudioEncoder** and **AudioDecoder**".
  <https://webkit.org/blog/17333/webkit-features-in-safari-26-0/> — **primary**.
- caniuse "WebCodecs API": Chrome 94+, Firefox 130+, **Safari 16.4–18.7 partial (video only), 26.0+ full**, 92.27 % global usage.
  <https://caniuse.com/webcodecs> — **secondary (aggregator)**.
- **WebTransport: Safari 26.4+ only**; caniuse lists Safari/Safari-iOS "3.1–26.3 Not supported, 26.4+ Supported", Chrome 97+.
  <https://caniuse.com/webtransport> — **secondary**; corroborated by the WebKit post "WebKit Features for Safari 26.4" (March 2026, 44 features incl. WebTransport) <https://webkit.org/blog/17862/webkit-features-for-safari-26-4/> — **primary**.
- MDN still labels `AudioDecoder` "Limited availability — not Baseline". <https://developer.mozilla.org/en-US/docs/Web/API/AudioDecoder> — **primary**.

So, for a phone at a party in Nov 2026: `VideoDecoder` works on iOS 16.4+; `AudioDecoder` needs iOS 26+; `WebTransport` needs iOS 26.4+. **WebSocket + VideoDecoder is the portable combination.** Confidence: **high**.

I could not test Safari hands-on (no device in this environment). The claim "Safari exposes these only in secure contexts" is therefore spec + MDN + WebKit's `[SecureContext]` conformance, not a device test. Confidence **high**, but see Q2.

### 1.4 The desktop-only escape hatches

- Chrome: `--unsafely-treat-insecure-origin-as-secure` / the `chrome://flags` "Insecure origins treated as secure" list, and an enterprise policy of the same name: "Setting a list of URLs in this policy has the same effect as setting the command-line flag".
  <https://chromeenterprise.google/policies/unsafely-treat-insecure-origin-as-secure/> — **primary (vendor policy doc)**; the flags UI is described on Stack Overflow <https://stackoverflow.com/questions/40696280/unsafely-treat-insecure-origin-as-secure-flag-is-not-working-on-chrome> — **secondary**.
- **None of this exists on iOS.** You cannot pass flags to Safari, and every iOS browser is WebKit underneath. Confidence: **high** (inference from the iOS app model; no vendor page states it because nobody would document an impossibility).

### 1.5 Chrome's new Local Network Access permission (matters for option d and for any "hosted page" plan)

Chrome's post, published 2025-06-09, updated **2025-09-29**: "The Local Network Access permission prompt is launching in **Chrome 142**".
<https://developer.chrome.com/blog/local-network-access> — **primary (vendor)**. Chrome 142 stable date: **28 October 2025** <https://developer.chrome.com/release-notes/142> — **primary**.

Facts from that post that matter here:
- "The ability to request this permission is **restricted to secure contexts**."
- A local network request is defined as public→private/loopback; private = RFC1918 (e.g. `192.168.0.0/16`), 169.254/16, `fc00::/7`, `fe80::/10`, and IPv4-mapped forms.
- **Mixed-content exemption** for permission-gated local requests, when Chrome can tell before resolving: host is a **private IP literal**, host ends in **`.local`**, or `fetch(..., { targetAddressSpace: "local" })`. A *public domain* that merely resolves to a LAN address is **not** exempt (example 3 in the post).
- Known limitations as of that update: "**WebSockets, WebTransport, and WebRTC connections to the local network are not yet gated** on the LNA permission" (crbug 421156866 / 421216834 / 421223919).
- Chrome 138 was opt-in testing via `chrome://flags#local-network-access-check`.

**Consequence:** an https page hosted publicly, opening `ws://192.168.1.124` or `http://192.168.1.124`, is blocked as mixed content in Safari, and in Chrome is blocked **unless** the host is the IP literal (or `.local`) *and* the user grants the LNA prompt. Confidence: **high** for Chrome (vendor text); **medium-high** for Safari (see next).

### 1.6 Safari and mixed content

MDN: browsers "auto-upgrade image, video, and audio mixed content … and **block** insecure requests for all other resource types"; and "Mixed content requests that would otherwise be upgraded are blocked if the URL's host is an **IP address** rather than a domain name". Blockable types include `fetch()`, XHR, `<script>`, `<iframe>`, CSS URLs, `sendBeacon`.
<https://developer.mozilla.org/en-US/docs/Web/Security/Mixed_content> — **primary**.

For `ws://` specifically I could not fetch the exact normative step (the WHATWG WebSockets standard page at <https://websockets.spec.whatwg.org/> doesn't carry the mixed-content sentence; the HTML spec page fetch failed). Practical statement found: "browsers block `ws://` on HTTPS pages" <https://websocket.org/reference/wss-vs-ws/> — **secondary**. Confidence: **high** that this is true in Safari and Chrome, but **unverified at the spec sentence level** — flagging it honestly.

Note the mixed-content spec's "upgrade" algorithm early-returns for IP-address hosts, i.e. it does not upgrade them; per MDN they are then blocked rather than upgraded. <https://w3c.github.io/webappsec-mixed-content/> — **primary**.

### 1.7 iOS local network permission

Apple: "In iOS 14 or later … any app that wants to interact with devices on your network must ask for permission the first time that it tries to browse your local network"; revocable at Settings > Privacy & Security > Local Network. Published 2026-04-07.
<https://support.apple.com/en-us/102229> — **primary (vendor)**.

Whether **Safari** itself shows this prompt when a page hits `http://192.168.x.x` is only **secondary** corroboration ("Safari refuses a local IP address? Grant Local Network access on your iPhone or iPad") <https://browserhow.com/allow-safari-to-load-local-ip-addresses-without-https-on-ios/> — **secondary**. In practice it is one extra "Allow" tap on first join. Confidence: **medium** (prompt exists almost certainly; exact trigger conditions unverified).

---

## 2. The options, from the point of view of a party

Cost/expiry numbers are current at 2026-11-13. "Ceremony" = what an ordinary guest must do on their own phone.

### (a) Self-signed / private-CA certificate on the LAN IP

**How it works.** Generate a root + leaf with `iPAddress` SAN `192.168.1.124`, serve TLS from the host, install the root on each phone.

**Guest must:** download a `.mobileconfig` (or the `.crt`) from the host over plain http, then Settings → "Profile Downloaded" → Install (passcode), then **Settings > General > About > Certificate Trust Settings → "Enable full trust for root certificates" → toggle on**. Apple documents this path verbatim, and notes trust is *not* automatic for profiles installed by hand (it *is* automatic for Configurator/MDM).
<https://support.apple.com/en-us/102390> (published 2025-03-26) — **primary**.
On Android the equivalent is Settings → Security → Encryption & credentials → Install a certificate → CA certificate (vendor-specific; **unverified** in this research — I did not fetch an Android doc).

**Host owner must:** create the CA, keep it (a leaked root signs anything for that phone forever), rotate if the LAN IP changes (new SAN), serve the profile file, and re-issue when the LAN IP changes.

**Certificate lifetime rules (primary):**
- "TLS server certificates issued on or after September 1, 2020 … must not have a validity period greater than **398 days**" — but "This change **will not affect certificates issued from user-added or administrator-added Root CAs**". <https://support.apple.com/en-us/102028> (published 2023-08-21) — **primary**.
- The older iOS 13 / macOS 10.15 rules do **not** state an exemption: RSA ≥ 2048, SHA-2 signature, **DNS name in SAN** (CN alone untrusted), and for certs with NotBefore after 2019-07-01 an **EKU with id-kp-serverAuth** and validity **≤ 825 days**. <https://support.apple.com/en-us/103769> (published 2023-11-06) — **primary**.
- Reading: use an IP-address SAN, EKU serverAuth, SHA-256, and keep the leaf ≤ 397 days so you satisfy every stated rule even if the 825-day rule is applied to user roots. That the 825-day rule *does* apply to user roots is **unverified**; the conservative choice sidesteps it.

**Does Safari then treat the https page as a secure context and allow WebCodecs?** Per the spec's definition (trusted TLS ⇒ potentially trustworthy), yes. **Inference**, confidence **high**, but I found no Safari-specific test report — treat as must-test (Q2). Important corollary: **a certificate warning that you "proceed past" is not an authenticated origin**, so it does not give you a secure context; on iOS you can't proceed past it anyway. **Inference**, confidence **high**.

**Cost:** zero. **Expiry:** none if you set 397 days and re-issue yearly; the root can be long-lived. **Maintenance:** the real cost is per-device trust and the profile-install ritual, every time a new phone arrives.

**Verdict for a party:** fine for *your own family's* phones (install once, never again), **hostile for guests** — profile install + a scary CA-trust warning is exactly the ceremony the brief wants to avoid. Android and iOS also use different install flows, and a guest who has never done it will get stuck.

### (b) A real certificate for a real domain that resolves to a private IP

**How it works.** Own a domain (say `thumbparty.example`), put an `A party.thumbparty.example → 192.168.1.124` record in its DNS, get a cert via **Let's Encrypt DNS-01** (no HTTP reachability needed), serve TLS from the host.

- DNS-01 is documented: prove control of DNS with a TXT record at `_acme-challenge.<domain>`; "it can work in scenarios that HTTP-01 can't"; requires a DNS provider with an API for automation <https://letsencrypt.org/docs/challenge-types/> — **primary**.
- Rate limits: "Up to **50 certificates** … per registered domain … every **7 days**", refilling "1 certificate every 202 minutes"; plus per-account failed-validation limits <https://letsencrypt.org/docs/rate-limits/> — **primary**.
- The pattern is exactly Plex's: Plex issues LE certs for `*.plex.direct` names that encode your server, and tells users to connect by name rather than by IP; the same page documents the failure mode: **routers/ISPs with DNS rebinding protection** block a public name that answers with a private address, with fixes given for dnsmasq (`rebind-domain-ok=/plex.direct/`) and pfSense (`private-domain: "plex.direct"`).
  <https://support.plex.tv/articles/206225077-how-to-use-secure-server-connections/> — **primary (vendor)**.
- Historical write-up of the design: Filippo Valsorda, "How Plex is doing HTTPS for all its users" <https://blog.filippo.io/how-plex-is-doing-https-for-all-its-users/> — **secondary** (linked from the Plex page; I did not re-fetch it).
- Public CAs **cannot** issue for internal names or reserved (private) IPs: "on November 11, 2015, the issuance of certificates with a reserved IP address or internal server name is prohibited. On October 1, 2016, all publicly trusted SSL/TLS certificates with an internal name or reserved IP address will be revoked and/or blocked".
  <https://cabforum.org/working-groups/server/internal-names/> — **primary (CA/Browser Forum)**.
  Therefore **`nip.io`/`sslip.io` cannot give you a trusted name either**: nip.io/sslip.io is a DNS responder only ("when queried with a hostname with an embedded IP address, returns that IP address"; examples include `www.192.168.0.1.nip.io`), and you don't control its zone, so you cannot pass DNS-01 for `<ip>.nip.io`. <https://sslip.io/ (redirects to https://nip.io)> — **primary (service page)**.
- **Certificate lifetime is shrinking:** CA/B ballot SC-081v3 reduces public TLS validity from 398 days to **200 days (15 Mar 2026), 100 days (15 Mar 2027), 47 days (15 Mar 2029)**, and cuts data-reuse periods too. <https://cabforum.org/2025/04/11/ballot-sc081v3-introduce-schedule-of-reducing-validity-and-data-reuse-periods/> — **primary**; the 200/100/47 dates are spelled out by third parties <https://duokey.com/en/resources/tls-certificate-lifetime-47-days-timeline-2026> — **secondary**.

**Guest must:** nothing. Open the URL. (One-time: the phone may show the iOS local-network prompt.)

**Host owner must:** buy a domain, keep an A record pointed at the *current* LAN IP, run an ACME client with a DNS API token on the host, and handle renewals — now every 60–90 days, eventually every few weeks. The private key lives on the LAN host, which is fine here but is why you should use a scoped DNS API token ("putting your full DNS API credentials on your web server significantly increases the impact if that web server is hacked" — Let's Encrypt).

**Pitfalls:** (i) DNS rebinding protection on the router or ISP DNS breaks it silently (Plex, above); (ii) DHCP changes `192.168.1.124` → A record goes stale → wrong-cert/mixed failures; pin a DHCP reservation; (iii) if a guest is on cellular, the name resolves to a private IP and simply fails; (iv) `wss://` to the same name is then fine, and **WebTransport/QUIC to it is also possible** because the origin is a real name with a real cert.

**Cost:** domain ~€8–15/year; certs free. **Expiry:** 60–90 days today, shortening on the schedule above. **Maintenance:** automation, but automation must actually exist.

**Verdict:** **best UX by a wide margin** (zero guest ceremony), and the only option that also unlocks WebCodecs *and* WebTransport at full speed. Fails hard if the router does rebinding protection and you can't change it.

### (c) mDNS `.local` names

- `.local` is reserved for multicast DNS, so **no public CA will issue for it** (CA/B internal-name prohibition, above) — **primary** for the cert side.
- iOS/macOS resolve `.local` natively via Bonjour; Android resolves `.local` from **Android 12** onward per a Stack Overflow answer ("Starting with Android 12, Android for the first time actually resolves .local domains correctly") <https://stackoverflow.com/questions/71426016/why-do-android-12-12l-13-preview-devices-dont-resolve-local-dns-anymore> — **secondary**, and Chrome on Android has open mDNS issues <https://issues.chromium.org/issues/379030058> (**secondary**, not read in detail).
- mDNS does not cross subnets/VLANs — irrelevant for one-party-one-Wi-Fi, relevant if the host is on a different SSID/VLAN; the "why it stops at the subnet" claim is from a blog <https://www.dnsium.com/blog/mdns-local-domain-explained-fix> — **secondary**.

**Verdict:** nice for finding the host (`http://host.local:45782/`) but **does not solve the secure-context problem** — `.local` over http is still insecure, and `.local` over https needs option (a)'s private CA. It is *Chrome's* mixed-content exemption includes "the request hostname is a .local domain", which is the only place `.local` helps (Chrome, hosted-origin case). Confidence: **high**.

### (d) A hosted origin: page from a public https site, media from the LAN host

Two sub-cases, and they behave very differently:

**d1. Plain http/ws to the LAN IP from an https page.** Blocked as mixed content in Safari (MDN §1.6 above); in Chrome allowed *only* for private-IP-literal or `.local` hosts and only after the user grants the **Local Network Access** permission (Chrome 142+), and even then WebSocket/WebTransport are, per the Sept-2025 update, **not yet gated** by LNA — which cuts both ways: today they may work without the prompt, but they are explicitly on the roadmap to be gated ("We plan to ship Local Network Access for WebSockets, WebTransport, and WebRTC connections soon"). <https://developer.chrome.com/blog/local-network-access> — **primary**.
Also expect iOS's local-network prompt (Apple §1.7).

**d2. `wss://` (or WebTransport) to a name that resolves to the LAN IP, using a real cert.** This is mixed-content-legal everywhere (it's `wss:`), but it collapses back into option (b): you need a real cert for a real name whose DNS answer is `192.168.x.x`, plus the same DNS-rebinding hazard. There is no way to get a public cert for the bare IP.
And `WebTransport`'s `serverCertificateHashes` escape hatch does **not** save you: the spec requires the cert to be ECDSA P-256 (RSA forbidden) with a **total validity ≤ two weeks**, and it can't be combined with `allowPooling` — so it is a 14-day-rotation mechanism for a dedicated QUIC connection, not a way to join a party. <https://w3c.github.io/webtransport/> §6.9 — **primary**.

**Verdict:** d1 is a trap in Safari (will simply not work) and a permission-prompt-plus-future-breakage in Chrome. d2 is (b) with extra steps. Confidence: **high** for Chrome/Safari mixed-content behaviour; **medium** for how LNA treats WebSocket/WebTransport by the time you ship (moving target).

### (e) A cloud relay

Page and media both come from a public https origin; the LAN host holds an outbound `wss://` connection to the relay and the phones talk to the relay. No secure-context problem at all, no per-phone ceremony, works off-LAN too. Costs: your bandwidth for every player's video, one more hop of latency (typically +RTT to the relay, i.e. +10–60 ms in-region), a server, and a privacy story (all video transits someone's box, even if it's yours). Certificate/expiry handled by the host platform.
I did not fetch a vendor page for this; it is **inference** from the mixed-content and secure-context rules above plus the general WebRTC/TURN architecture in <https://quic.video/blog/replacing-webrtc/> (**secondary**, author is a streaming engineer). Confidence: **high** that it works; the cost/latency numbers are **inference**.

### (f) PWA or native wrapper

- **PWA alone does not help.** "Add to Home Screen" does not change the origin; a home-screen app for `http://192.168.1.124` is still an insecure context, and it cannot register a service worker ("Only secure contexts are allowed to register service workers, so service workers are always secure contexts" — MDN secure contexts §Workers). Confidence: **high** (**inference** from the origin rule; no vendor doc says "http PWAs are insecure" because it follows from the definition).
- **WKWebView wrapper:** the app embeds WebKit, so WebCodecs availability should track the iOS version (VideoDecoder on iOS 16.4+, AudioDecoder on iOS 26+) — but **is WebCodecs exposed in WKWebView? I could not verify this**; caniwebview's WebCodecs page renders its tables via script and gave me no data <https://caniwebview.com/features/web-feature-webcodecs/> (**unverified**), and I found no Apple doc. Mark as **unverified, must test on device** (Q3).
- **Custom URL schemes (`app://`) and `file://` in WKWebView:** `file:` is potentially trustworthy per spec/MDN (so a bundled-file approach is a secure context), but custom schemes handled by `WKURLSchemeHandler` are **not** covered by any doc I could find — **unverified**. Apple's API page only describes registering the handler <https://developer.apple.com/documentation/webkit/wkwebviewconfiguration/seturlschemehandler(_:forurlscheme:)> — **primary**, silent on origin trust.
- **The reliable trick, if you go native:** run a tiny HTTP server *inside the app* on `127.0.0.1` and load `http://127.0.0.1:PORT/`. Loopback is on the trustworthy list (MDN §1.1), so you get a secure context, WebCodecs, AudioWorklet and service workers without any certificate. Cost: an app in the App Store (or TestFlight/Enterprise), review latency, and the whole "install nothing" promise dies.
- Note also that a wrapper does not remove the local-network permission prompt (Apple §1.7).

**Verdict:** high effort, high per-player cost (app install), and still carries an unverified WebCodecs-in-WKWebView risk. Not for a party; plausible later if you need a locked-down kiosk/TV mode.

### (g) QR-code join flow

Nothing about QR changes secure context — it only removes typing. iOS Camera and Android Camera/Lens open `http(s)` links in the default browser; a `https://` link to a name with an untrusted cert lands the guest on a full-page warning (**bad**), while an `http://` link lands them on a working page that simply lacks WebCodecs. Note: iOS may hand off `https` links to Safari rather than an in-app browser — that is the behaviour you want, and it is also what Xbox documents ("For the best results on iOS devices, make sure you're using the Safari browser") <https://support.xbox.com/en-IS/help/games-apps/cloud-gaming/setup-cloud-gaming-apple> — **primary (vendor)**, fetched as a snippet; full page did not render for me. Confidence: **medium-high**.

QR is orthogonal and should be used in every option: encode the final URL, one code per LAN IP change (or encode the name from option (b), which never changes).

### Option comparison (party UX first)

| Option | Guest ceremony | Host work | Money | Expiry / renewal | Breaks when | Verdict |
|---|---|---|---|---|---|---|
| (a) private CA on IP | profile install + trust toggle (~6 taps, 2 OSes) | CA + leaf, re-issue on IP change | 0 | leaf ≤397 d (root long) | LAN IP changes; new guest phone | own phones only |
| (b) own domain → LAN IP, LE DNS-01 | none | DNS API token, ACME, DHCP reservation | ~€10/yr | 60–90 d now → 47 d by 2029 | router/ISP DNS rebinding protection; IP change | **best UX** |
| (c) `.local` | none | mDNS announcement | 0 | n/a | Android <12; needs (a) for TLS anyway | naming only |
| (d1) hosted page + http/ws to IP | 1 tap (Chrome prompt) or impossible (Safari) | none | 0 | n/a | Safari always; Chrome LNA roadmap | no |
| (d2) hosted page + wss to name | none | same as (b) | as (b) | as (b) | as (b) | = (b) |
| (e) cloud relay | none | outbound client, server | server + egress | platform | internet down | fallback / later |
| (f) app wrapper | App Store install | app build + review | dev account | OS updates | WKWebView WebCodecs **unverified** | later |
| (g) QR | just a scan | print a code | 0 | URL changes | stale URL | use in all |

## 3. Recommendation

**"LAN party now".** Two tiers, decided by the host's router, not by taste:

1. **Default tier — zero ceremony, no certs: WebRTC-receiver player over `http://192.168.1.124:45782/`.** A `<video>` element fed by an `RTCPeerConnection` (Opus + H.264/VP8) needs no secure context, no install, and no permission on Safari. This is the tier that always works. Expect the browser's receiver latency: a MediaMTX user measured **100–200 ms** streaming to Safari vs **25 ms** with the native Parsec client on the same Wi-Fi, and the maintainer's answer was that this is "an intrinsic limitation of the video streaming stack you want to use (browser-based WebRTC)" because "latency is introduced by browsers … they choose the latency value autonomously", with a WebCodecs transport on the roadmap <https://github.com/bluenviron/mediamtx/issues/4063> — **primary (project maintainer)**. For a party quiz/board game that is fine; for a twitch game it is not.
   *Caveat to verify before committing:* Selkies' FAQ warns that on plain HTTP to a non-localhost host, "Many browsers do not support WebRTC or relevant features including pointer and keyboard lock" <https://docs.selkies.io/latest/faq/> — **primary (project doc)**, and it contradicts my expectation that `RTCPeerConnection` is not secure-context gated. See Q1. This is the single fact that could invalidate the default tier.
2. **Low-latency tier — WebCodecs over WebSocket, served from an https origin reached by a real name:** own domain + `A` record → LAN IP + LE DNS-01, per Plex. Guests just open the URL; `VideoDecoder` works on iOS 16.4+, `AudioDecoder`/AudioWorklet only on iOS 26+ (have a media-element or WebRTC-audio fallback), `WebTransport` only on iOS 26.4+. Keep the plain-http player as the fallback under the same URL set, because the rebinding-protection failure mode is invisible from the inside.

Do **not** build the private-CA path as the default (option a); keep it as the documented escape hatch for the family's own phones when (b) is impossible.

**"Cloud product later".** The origin is https, so `isSecureContext` is true and every option in the brief collapses to "just build it". Keep the player transport-agnostic (WebSocket/WebTransport) and keep the LAN player as a *variant*, not a fork: the only thing that changes is the origin and the endpoint discovery. Chrome's LNA permission and Safari's mixed-content rules stop mattering the moment the media comes from the same origin as the page.

## 4. Prior art: WebCodecs video streaming to browsers, and what latency people report

### 4.1 Open-source remote-desktop / cloud-gaming web clients

- **Selkies** — "By default it delivers the stream over plain WebSockets to a **WebCodecs-based** web client; WebRTC is available as an opt-in transport"; claims 60 fps at 1080p, "latency-eliminating techniques utilized in web-based WebRTC game streaming platforms". <https://docs.selkies.io/latest/design/> — **primary (project doc)**.
  Web client details: "decodes the video with WebCodecs over WebSockets and through the browser's own receiver over WebRTC"; "runs on Chromium, Firefox, and Safari"; and the Safari-specific workaround: "where it has no WebCodecs audio (**Safari before 26**, Firefox before 130 …) Opus is decoded … by libopus compiled to WebAssembly". <https://docs.selkies.io/latest/components/web-client/> — **primary**. This independently confirms the AudioDecoder-lands-in-Safari-26 date and shows the practical fallback.
- **Neko** — self-hosted virtual browser over **WebRTC** (no WebCodecs path documented) <https://github.com/m1k1o/neko> — **primary (project README)**. Useful as the "WebRTC-only" baseline, not as a latency data point.
- **MediaMTX** — WebRTC (WHEP) reading in browsers; the maintainer states browser WebRTC has a latency floor and that "In the future we will definitely add … an additional transport based on **WebCodecs**, which does not have this limitation". <https://github.com/bluenviron/mediamtx/issues/4063> (opened 2024-12-21) — **primary (maintainer)**.
- **MoonlightWeb** (`linckosz/moonlight-web`, GPL-3.0) — the closest architectural match to the brief: "The browser decodes with **WebCodecs + WebGPU/canvas** and plays audio through its own **WebRTC** player (an AudioWorklet on the WSS fallback)"; vendor FAQ claims "Under 20 ms over Wi-Fi", "up to 120 fps", iPhone/iPad Safari supported with no install. <https://github.com/linckosz/moonlight-web> and <https://moonlightweb.top/faq.html> — **secondary (vendor's own marketing docs)**; treat the 20 ms and 120 fps as claims, not measurements.
- **HelixPlay** (`HelixDevelopment/HelixPlay`) — Go monorepo cloud-gaming platform; README advertises "≤30ms LAN / ≤50ms WAN p999", streaming via "WebRTC Pion v4, QUIC/quic-go, custom UDP", clients "Angular+WASM", decode "WebCodecs/native". <https://github.com/HelixDevelopment/HelixPlay> — **secondary (vendor README)**; no methodology published, so **unverified**.
- **moonlight-web-stream** (`MrCreativ3001/moonlight-web-stream`) — "hosts a Web Server which will forward Sunshine traffic to a Browser using the **WebRTC** Api" <https://github.com/MrCreativ3001/moonlight-web-stream> — **primary (project README)**; the WebRTC-only sibling of the above.

### 4.2 Measured numbers I could actually find

- **WebCodecs + WebTransport, glass-to-glass: 140 ms** at ~36 ms RTT, at low resolution/bitrate; **380 ms** after raising resolution and bitrate; **~700 ms** at 500 kbit/s over a 167 ms RTT path (no send-order/scheduling tricks). Source: webrtcHacks Q&A with the implementer (Jordi), 18 Jul 2023 <https://webrtchacks.com/webcodecs-webtransport-and-webrtc/> — **secondary (expert interview, with the implementer's own clock-in-frame measurement, described by him as "not super accurate")**.
- **WebRTC receiver in Safari: 100–200 ms**, native Parsec 25 ms on the same Wi-Fi (mediaMTX issue, above) — **primary (user report + maintainer explanation)**.
- **WebRTC on a LAN: 40 ms** glass-to-glass (MediaMTX), vs 772 ms LL-HLS on the same setup <https://computingforgeeks.com/low-latency-live-streaming-webrtc-ll-hls-rtmp/> — **secondary**; a useful "what the receiver can do on a quiet LAN" anchor.
- **Direct "video element vs canvas" A/B:** I did **not** find a rigorous published head-to-head with the same encoder and the same measurement method. The closest material is the MediaMTX maintainer's explanation (browser-chosen buffering is the difference, not the codec) and the WebCodecs+WebTransport experiment above. **Answer to the brief's "what gain is reported": roughly 1.5–4× lower glass-to-glass latency when you can bypass the receiver's jitter buffer, i.e. ~40–140 ms versus ~100–300 ms — my synthesis (inference, medium confidence)**, not a single citable measurement.

### 4.3 What production cloud-gaming services do in iOS Safari

- **GeForce NOW:** "At this time, GeForce NOW **only supports Safari** on iOS and iPadOS." (page "Updated 09/29/2021") <https://nvidia.custhelp.com/app/answers/detail/a_id/5132> — **primary (vendor)**, though old. Related: "On iOS, iPadOS and Android, only games that support full or partial gamepad are playable … because Safari and Chrome do not support pointer-lock mouse functionality while streaming" <https://nvidia.custhelp.com/app/answers/detail/a_id/5109> — **primary**, and directly relevant to your input design.
- **Xbox Cloud Gaming:** recommends Safari on iOS ("For the best results on iOS devices, make sure you're using the Safari browser") <https://support.xbox.com/en-IS/help/games-apps/cloud-gaming/setup-cloud-gaming-apple> — **primary (vendor)**, via search snippet.
- **Boosteroid:** iPhone requires "iPhone 7 or higher, The latest version of Safari"; the Windows requirements list "h.264 hardware decoding" and "WebRTC (support)", and note a software-decoder fallback with "high CPU load". <https://help.boosteroid.com/en/content/general-requirements-for-your-digital-environment> — **primary (vendor)**.
- **Amazon Luna:** the support page exists and covers "Web browsers on PC, Mac, Chromebook, iPhone, iPad" but did not render for me → **unverified** <https://www.amazon.com/gp/help/customer/display.html?nodeId=T6cH7LTpXR93ldlzi9>.
- **Do any of them use WebCodecs in Safari?** **Unverified.** I found no vendor statement, and the "latest Safari + hardware H.264 decode + WebRTC" requirements read like the WebRTC receiver path. Treat "they are all on WebRTC in Safari" as **inference, medium confidence** — the honest position is "unknown, and it does not change your plan, because the WebRTC path is the one that works without ceremony".
- **Third-party evidence that Safari's streaming path is limited:** the Better xCloud wiki tells users on macOS to prefer Chrome/Edge because "you won't be able to use the high-quality codec in Safari", and lists Safari-only limitations <https://github.com/redphx/better-xcloud/wiki/Using-with-Safari> (last edited 2023-10-16) — **secondary**.

### 4.4 WebKit/W3C issues on WebCodecs latency

- **w3c/webcodecs#899 "Delayed H264 decoding on browsers when using VideoDecoder"** (macOS, opened 2025-07-23, closed as not planned): H.264 streams with sparse frames stall 2–3 s with the hardware decoder unless enough packets are queued, fixed by `hardwareAcceleration: 'prefer-software'`; a Chrome contributor replied that this follows from the bitstream configuration, not the API. <https://github.com/w3c/webcodecs/issues/899> — **primary (issue thread)**. Directly relevant: **do not trust the hardware decoder path for a desk-like game screen with few changed frames**; either keep the encoder emitting frames (repeat/IDR) or be ready to force software.
- **WebKit bug 221334 "Audio passed through WebAudio is delayed and glitchy on Safari"** (still **NEW**, reported 2021): on iOS "the audio sometimes stutters and has tiny gaps of silence … which widen the longer the video is played", and the reporter's conclusion was to "warn our users to not use Safari for now". <https://bugs.webkit.org/show_bug.cgi?id=221334> — **primary**. This is the strongest single argument for the "separate WebRTC audio-only track" design in §5.
- I did not find a WebKit bug specifically about `VideoDecoder` output latency in Safari (searched bugzilla quicksearch; nothing on point) → **unverified that none exists**.

## 5. Sound next to a WebCodecs video player on iOS

### 5.1 The three shapes

1. **`AudioDecoder` (Opus/AAC) + AudioWorklet or scheduled `AudioBufferSourceNode`s.** Lowest possible latency and it shares the video clock. Costs: `AudioDecoder` needs **iOS 26+** (WebKit, §1.3); `AudioWorklet` needs a secure context (MDN, §1.2); and the worklet path is exactly what bug 221334's reporters found glitchy on iOS. Selkies ships a **libopus-wasm** fallback for exactly this gap <https://docs.selkies.io/latest/components/web-client/> — **primary** — which is a real option if you must have one code path.
2. **A second, audio-only WebRTC connection, played in a hidden `<audio>`/`<video>` element.** Media elements are **not** silenced by the mute switch, are not secure-context gated, and get an adaptive jitter buffer for free. MoonlightWeb's published design is precisely this ("WebCodecs decodes, WebGL2 or WebGPU renders, and the browser's WebRTC player plays the Opus audio") <https://moonlightweb.top/faq.html> — **secondary (vendor)**. You lose exact sample-level sync control (you get `RTCRtpReceiver`'s jitter buffer behaviour) but you gain robustness.
3. **WebSocket PCM (or 16-bit PCM in a data channel) → `AudioContext` + `AudioBufferSourceNode` scheduled ahead.** Full control, no AudioDecoder dependency, works on every iOS version — but you pay bandwidth (48 kHz stereo 16-bit ≈ 1.5 Mbit/s) and you must do your own jitter buffering.

**Recommendation:** shape 2 for the LAN-party tier (it works on every iOS, and the mute switch is not an issue), shape 1 for the https/WebCodecs tier when `"AudioDecoder" in window`, shape 3 as the "no WebCodecs audio" fallback if you dislike WebRTC. Confidence: **medium-high** (architectural inference from the sources above).

### 5.2 Autoplay, gesture, and the mute switch (all primary)

- Autoplay: "you can assume that media will be allowed to autoplay only if at least one of the following is true: the audio is muted or its volume is set to 0; the user has interacted with the site"; and for Web Audio, "a website … can start playing audio using the start() method on a source node linked to the AudioContext. Doing so outside the context of handling a user input event is subject to autoplay rules." <https://developer.mozilla.org/en-US/docs/Web/Media/Guides/Autoplay> — **primary**.
- WebKit's iOS policy is stricter than the general rule for *audible* media: `<video autoplay>` autoplays only if it has **no audio track**, or is **muted**, and it pauses if it gains audio or is un-muted without a gesture; `play()` returns a promise that rejects otherwise. <https://webkit.org/blog/6784/new-video-policies-for-ios/> (iOS 10 era, still the canonical statement) — **primary**.
- **Design consequence:** the join tap (a "Tap to play" button, which a QR-code page needs anyway) is a user gesture — create/resume the `AudioContext` and call `play()` there, synchronously in the handler. Do not resume from `canplaythrough` or a timer.
- **Silent switch:** Web Audio is routed to the **ambient/ringer** channel and is muted by the hardware mute switch, while media elements are not. WebKit bug 237322 documents this ("webaudio seems to be on the default/ringer channel of iOS") and the accepted fix in **Comment 6, 2024-09-25**: "Since **iOS 17**, you can set the audio session type to `playback` … `navigator.audioSession.type = "playback"` and audio will not be suspended. By default the type is `ambient` and so audio will be muted if the phone is muted." <https://bugs.webkit.org/show_bug.cgi?id=237322> — **primary**. Bug status RESOLVED/**CONFIGURATION CHANGED** (i.e. fixed by the new API, not by changing the default).
- The API: `navigator.audioSession.type` with values `"auto"`, `"playback"`, `"transient"`, `"transient-solo"`, `"ambient"`, `"play-and-record"`; `state` is `"active" | "interrupted" | "inactive"` with a `statechange` event. MDN marks it **experimental**. <https://developer.mozilla.org/en-US/docs/Web/API/AudioSession> — **primary**.
- Safari 16.4 already shipped "a subset of the AudioSession Web API" <https://webkit.org/blog/13966/webkit-features-in-safari-16-4/> — **primary**; feature-detect (`if ("audioSession" in navigator)`).
- **Resume after interruption:** interruptions (call, Siri, another app taking audio) move the context out of `running`; listen for `statechange` on `navigator.audioSession` (and/or the context's own state) and call `resume()` on the next user gesture. MDN's AudioSession page states audible media is auto-paused/resumed by interruptions while "state monitoring allows the configuration of behavior that is not automatically controlled" — **primary**. The classic WebKit-only failure ("AudioContext stays `interrupted` and never recovers") is widely reported but I did not fetch a primary record of it → **unverified detail**, keep the "resume on next tap" defensive path.

### 5.3 Output latency numbers on iOS Safari

- **`baseLatency`** = buffer size ÷ sample rate. WebKit's implementation is literally `framesPerBuffer / sampleRate` <https://raw.githubusercontent.com/WebKit/WebKit/main/Source/WebCore/Modules/webaudio/AudioContext.cpp> — **primary (source)**. On Apple platforms the CoreAudio I/O buffer is commonly 128 frames, i.e. **~2.7 ms at 48 kHz / ~2.9 ms at 44.1 kHz**. That the buffer is 128 frames on iOS Safari specifically is **inference** (I could not confirm it in the platform audio code) — **medium confidence**.
- **`outputLatency`** = platform-reported value; WebKit returns `0` when the context is not playing, `512 / sampleRate` when "noise injection policies" are on, else `destination()->outputLatency()` — same source, **primary**. Support: Safari on iOS **18.4+** (caniuse: "Safari on iOS 3.2–18.3: Not supported; 18.4–26.6: Supported") <https://caniuse.com/mdn-api_audiocontext_outputlatency> — **secondary**. Before 18.4 you get `undefined`, which is why the Stack Overflow complaint "outputLatency not supported in Safari: how do audiovisual apps handle sync?" exists <https://stackoverflow.com/questions/78004345/audiocontext-outputlatency-not-supported-in-safari-how-do-audiovisual-apps-hand> — **secondary**.
- **I could not find a published, measured iOS-Safari `baseLatency`/`outputLatency` number.** Apple's native equivalent documents that `AVAudioSession.outputLatency` exists and warns "Using an AirPlay-enabled device … can result in a 2-second delay" <https://developer.apple.com/documentation/avfaudio/avaudiosession/outputlatency> — **primary**, but that is the native API, not Web Audio. Realistic planning number for phone speaker output: **tens of milliseconds (order 10–40 ms)**, with Bluetooth (AirPods/AAC) adding **150–250 ms** — **inference, low-medium confidence**; measure on the actual phones (Q4).

### 5.4 Lip-sync when video is drawn on arrival and audio is scheduled

What the WebCodecs experimenters found (primary-ish, expert interview, 18 Jul 2023): "video timestamps survive the encoding and decoding stages, but **not audio timestamps** … if [audio] drops something, you need to know exactly how much dropped … to align them. So, this is one of the main challenges … I would love for the audio timestamps to be the same as video timestamps" — and separately, `AudioData` frames are not transferable, at ~21 ms of audio per frame, which is "a big performance hit … a lot of copies". <https://webrtchacks.com/webcodecs-webtransport-and-webrtc/> — **secondary**.

Practical anchoring recipe (all **inference**, flagged as such):
1. Put a **host monotonic timestamp** (µs, same clock) in every video and audio packet. Do not rely on encoder/decoder PTS surviving; carry your own field in the framing.
2. Keep one **`performance.now()`-based playout clock** in the player; map host time → local time at handshake with a ping/pong minimum-RTT estimate and re-map slowly (drift-correct, do not jump).
3. Schedule audio **ahead** with `AudioBufferSourceNode.start(when)` where `when = audioContext.currentTime + lead`, `lead` ≈ 2× observed jitter + `outputLatency || 0.02`. Never schedule in the past (it starts immediately and you lose the anchor).
4. Draw the video frame whose timestamp is the **newest one ≤ (now − lead_audio_bias)**; if you have to choose, make **audio early, video late** — human tolerance for audio-leading-video is much larger than the reverse. The commonly quoted acceptable window is audio ≤ 45 ms early / 125 ms late (ITU-R BT.1359); **I did not fetch that recommendation** → **unverified**, but it matches the "audio early is safer" rule you'll implement anyway.
5. If you took shape 2 (WebRTC audio), you lose the sample anchor: measure the element's playout with an occasional click/marker and nudge the video draw time by that offset. Expect to need a **manual "A/V offset" slider** (±200 ms) in the dev settings — every project in §4 that published on this ended up with one (**inference**).

## 6. What I could not confirm (explicit "unverified" list)

- **U1** Safari, on a device, refusing `VideoDecoder`/`AudioDecoder`/`AudioWorklet` on `http://192.168.x.x` (no device available; spec+MDN only).
- **U2** That `RTCPeerConnection` works on an insecure origin in **Safari** (Selkies' FAQ says many features don't outside localhost — see Q1). This decides the default tier.
- **U3** WebCodecs availability inside **WKWebView** (caniwebview tables unreadable; no Apple doc).
- **U4** Secure-context status of WKWebView **custom URL schemes**.
- **U5** Whether Apple's **825-day** rule applies to **user-installed roots** (the 398-day rule explicitly does not).
- **U6** Android's CA-install flow and Android Chrome's `.local` behaviour (only Stack Overflow-grade sources).
- **U7** Internals of GeForce NOW / Xbox / Luna / Boosteroid web clients (WebRTC vs WebCodecs) — no vendor statement found.
- **U8** Published measured iOS-Safari `baseLatency`/`outputLatency` values.
- **U9** Any rigorous published "video element vs WebCodecs canvas" A/B with matched encoders.
- **U10** Normative spec sentence for "`ws://` blocked from https page" (HTML spec page did not fetch; WHATWG WebSockets standard doesn't carry it).
- **U11** Parsec's web-client browser requirements (support page 404/empty when fetched).
- **U12** The ITU-R BT.1359 lip-sync window (quoted from memory, not fetched).
- **U13** Amazon Luna's exact browser matrix (page didn't render).

## 7. Things worth knowing that the brief did not ask about

- **WebTransport's `serverCertificateHashes` is not an escape hatch for LAN parties**: ECDSA P-256 only, ≤ 2 weeks validity, no `allowPooling` (spec §6.9). It solves "I don't want a CA for my own QUIC server", not "guests must join easily".
- **`AudioWorklet` being secure-context-gated** (§1.2) means the audio plan and the video plan share the same gate — there is no "keep audio on the old path over http" design unless you use media elements/WebRTC.
- **Chrome's LNA permission is a moving target**: WebSockets/WebTransport/WebRTC to the LAN are ungated today but announced to be gated "soon". Any option that depends on them staying ungated has a shelf life.
- **Local-network permission on iOS is a first-join tap for every guest** in every option, once per site (Apple §1.7) — budget it in the join flow copy.
- **Pointer lock is unavailable in Safari and Chrome on iOS** (NVIDIA's own support page), which is why GFN requires a gamepad there. If Thumb Party ever needs a mouse-driven game on a phone, the phone-as-controller design already avoids this.

## 8. Questions for Claude (which I would answer first, given the brief or a device)

1. **Q1 (blocking):** Does `RTCPeerConnection` (receive-only, `<video>` sink) work in Safari on `http://192.168.x.x`? If yes, the zero-ceremony tier stands with no certs at all. Selkies' FAQ suggests it may not; the spec says it is not `[SecureContext]`. A one-line test page on a phone settles it and should be the very first experiment.
2. **Q2:** Do you need `AudioDecoder` (iOS 26+) at all, or is the WebRTC-audio-only shape acceptable permanently? That answer decides whether the https tier is "nice" or "required".
3. **Q3:** Is a native wrapper even on the table? WKWebView's WebCodecs behaviour is the biggest unknown in option (f), and the loopback-server trick makes it work if you go there.
4. **Q4:** Can someone measure `AudioContext.baseLatency` / `outputLatency` and a lip-sync offset on a real iPhone (iOS 26.x, speaker and AirPods)? I found no published numbers for iOS Safari.
5. **Q5:** Does the household's router (or ISP DNS) do DNS rebinding protection? If it does, option (b) dies and the ranking changes to (a)-for-family + WebRTC-for-guests.
6. **Q6:** How stable is `192.168.1.124`? Every option except the loopback one breaks on a DHCP change; a DHCP reservation is a prerequisite, not a detail.
7. **Q7:** Should the report's "cloud later" design assume WebTransport is available (Safari 26.4+, i.e. very recent) or stay on WebSocket? My read: WebSocket for the next year, WebTransport behind a capability flag.
