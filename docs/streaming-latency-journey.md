# Streaming the game to a browser: the latency journey (M15, Nov 11-12, 2026)

This is a narrative of what we tried, what each step found and what we got wrong, written from the records in `docs/briefs/m15/`. Anything marked *(inference)* is my reading, not something a record says. Numbers are quoted from the reports and summary files; where the records have none, the text says so.

## 1. Where it stands (Nov 12, 2026)

- The game runs in a Linux container on the home PC (WSL2, RTX 3080), is captured, encoded by the GPU (NVENC H.264) and sent with WebRTC (GStreamer `webrtcsink`) to a browser page. It holds 1080p at about 60 delivered fps, with sound, no loss and no freezes.
- On an iPhone in Safari (second phone run, 09:25 Nov 12): capture to screen **92 ms median / 142 p95**; press to screen **158 / 271 ms**. Gate 1 of the roadmap says **under 80 ms** press to screen. We are about 78 ms over at the median.
- The wire rate was 59.8 delivered fps and a mean of 6.5 Mbit/s in that run's summary file (p95 10.3, max 11.1), against a 10 Mbit/s ceiling. Your quoted 8586 kbit/s is not in any file I could find; the summary says 6510 mean.
- Settings alone are exhausted: dozens of single-setting runs never beat the machine's own run-to-run noise. What is left is structural (section 5).
- The owner approved a seventh fix batch (fix7: three switchable techniques, described below). At the time of writing it is **in progress**: there is no `fix7` folder in the repository yet.

## 2. What we set out to do, and how we measure

The owner decided on Nov 11 to build a custom stack (not Sunshine + Moonlight) to learn how game streaming works and to grow it into a product: lowest latency, several households in separate sessions, server in containers, open-source parts, home PC first. `docs/design/streaming-roadmap.md` sets Gate 1: a family plays on a TV browser and a laptop with phones as controllers, all stages appear in one report, a press reaches the screen in under 80 ms on the home network, and thirty minutes pass with no stall. (The 80 ms gate lives in the roadmap, not in `PRD-v2.md`, whose M15 entry is party content; the PRD only names the stream stage metrics, item S7.)

Latency is recorded per stage by the existing stats framework. Latest phone run (Safari on an iPhone, median ms):

| Stage | What it is | ms |
| --- | --- | --- |
| capture | compositor frame to pipeline | 2 |
| encode | the encoder element in the pipeline | 30 |
| network | wire, same Wi-Fi | 2 |
| jitter buffer | the browser's playout wait | 52 (p95 101) |
| decode | the phone's decoder | 6 |
| display | draw | 0 |
| **capture to screen** | the stages added up | **92** (p95 142) |
| press to screen | a scripted press to the flip seen in the picture | **158** (p95 271) |

Source: `bench-results/20261112-092537/phone2/phone20.json`. Press to screen minus capture to screen is 66 ms, which the owner read as "the host leg" (press reaching the game and the game drawing it). Section 3 explains why that figure did not hold up.

## 3. The journey

**Nov 11: research and probes (what we believed: it might not be possible on this PC).**
Three research reports (48 sources on custom stacks, 50 on Hyper-V GPU sharing, plus a scan of what our code already had) led to a design: game inside `gst-wayland-display` (a Wayland compositor that is a GStreamer source), NVENC, `webrtcsink`, our WebSocket for signalling. Hands-on probes in a locked-down WSL2 distro (`tp-stream`) then found the real constraints. The first probe was blocked because WSL was not installed; after the owner installed it: NVENC works in containers with Docker Engine inside WSL2 (not Docker Desktop), 12 simultaneous encodes at most, `nvh264enc` is broken here (use `nvautogpuh264enc`), and GPU drawing goes through Mesa's D3D12 layer so frames cross system memory. The Flutter TV app builds for Linux and draws 58-60 fps (menu) and about 53 fps (Arena) on the GPU; every X11 route fell back to software at roughly 10 fps. The capture probe settled it: `waylanddisplaysrc` gave 60.0 encoded fps for 42 s with sound through a PulseAudio null sink. Two sessions at once fell to 43-45 fps each.

**Nov 11: the prototype, four jobs (p1, c1, a2, c2).**
Stats record for streams, the session image and player page, an automation interface (so a session can start and be pressed with no person), and a benchmark that drives a headless Chrome viewer. First end-to-end numbers (headless Chrome on the same PC, 1080p60): capture to screen **126 ms**, press to screen **203 ms** (p95 323), jitter buffer 89 ms, encode 30 ms. The report flagged one oddity it did not explain: the encoder element read 30 ms where the capture probe's whole pipeline read 8 ms.

**Nov 11: review, then tuning one setting at a time (fix1, t1).**
We believed settings could close most of the gap. t1 measured noise first: the same pipeline twice gave 205 and 161 ms (a 44 ms band). Then no setting beat that band: a one-frame VBV buffer, FEC off, 720p, infinite GOP (worse), split tracks (worse), the CUDA encoder (worse). Baseline 183 / press 248 became 161 / 234, which is inside the noise. t1 concluded the floor with this design was about 145-160 ms total and that going lower needs a player with near-zero playout delay and a game drawing at 60 fps, not settings. *Wrong turn:* the review's one "must" said the VBV was being set 1000 times too small; the next batch checked `gst-inspect` and found the property is in kbits, so the code was right and the review was wrong (fix2).

**Nov 11-12: a pinned run that wasn't, and a floor that wasn't (fix2, fix3).**
g1 added `--viewer external` so a real device can be timed, and reported a "pinned viewer" run that improved the jitter buffer 162 to 146 ms. The next review found that the pin option was silently ignored for external viewers, so that run was never pinned; it was withdrawn. h1-2 reran it properly with five round runs: jitter buffer 226, 220 (unpinned), 193, 144 (pinned), and 200 at 720p30. The report first called 190-230 ms "the browser's floor"; the review pointed out its own 144 ms run contradicted that, and the claim was restated: pinning *may* save up to 76 ms but run-to-run spread (49 ms) is too large to say. A real device had to answer. Also found in review: the player's `requestVideoFrameCallback` loop re-armed on every reconnect and was never cancelled (fixed in fix4).

**Nov 12 morning: the owner's first iPhone run, and four measurement bugs.**
Safari reported capture to screen **61 ms median / 91 p95** at 59.3 fps: far better than headless Chrome's 126-260 ms (jitter buffer 22 ms against 90-226). But the same run exposed bugs: three phantom "chrome" viewers were listed beside the real Safari row (host-side stages from the host were counted as viewers); the bench printed 20,992 kbit/s received against a 10,000 ceiling, because the ceiling was the encoder's rate and forward error correction and retransmission multiplied it on the wire (a 30 s check read 20,353 with FEC on and 9,693 with it off); press to screen was empty (no press phase for external viewers); and results landed in an old job's folder. fix5 fixed all four (the encoder now gets a rate derived from the wire ceiling) and three headless runs proved it: one real viewer row, means 6-11 % under the ceiling, press to screen 301 ms median on the headless viewer. A real phone was still untested at that point.

**Nov 12 09:25: second iPhone run, after the fixes.** The table in section 2. Capture to screen was 92 ms against 61 in the first run, and the jitter buffer 52 against 22. These are single runs each; the records do not say how much of that difference is noise. *(inference: given the 36-49 ms noise seen on this PC, it may be mostly noise, but no repeat phone run exists.)* The press gap of 66 ms became fix6's question.

**Nov 12: fix6, four jobs on where the time goes (k1-1 to k1-4, each 23-30 minutes).**
- *Measure the host leg (k1-1).* New stages and frame-timing gauges. In the probe run the host leg read 42 ms, not 66 (press to game tick 17, tick to build 0, build to raster 5, and a 20 ms remainder). The game paced at 20.4 ms/frame (about 48 fps) while the encoder delivered 57-60.
- *Why 48 fps (k1-2).* The app's own work was about 11.5 ms of a 16.7 ms slot; about 9 ms per frame was spent waiting for the compositor's frame callback, and roughly one frame in five missed its slot. Switching Impeller to Skia (`THUMB_PARTY_IMPELLER=0`) halved raster time (about 4.6 vs 9.9 ms) and gave 55.3 and 52.1 fps against baselines of 48.5 and 51.9 fps, but the baselines themselves differ by 3.4 fps, so the gain is at the edge of noise. The switch exists; the default did not change. The tracer and a multi-threaded converter were ruled out as causes.
- *Where the host leg goes (k1-3).* The game answers a press in about one frame (19-25 ms: the press is serviced in the idle gap and its frame starts one interval later); it cannot go lower and is not a busy renderer. The remainder cell that gave 20 ms in k1-1 read 11, 48, 48 and 51 ms across four identical runs: it is a subtraction of two independent end-to-end numbers, not a measurement. Two capture-side queues were tried and both made things worse. The best estimate of the host leg to the encoder's input is 20-45 ms, and nothing in the records accounts for 66 ms. A scripted press now asks for the frame that can show it.
- *What the 30 ms encode stage is (k1-4).* In a micro-bench with nothing downstream, the same encoder with the session's settings holds a frame 9.2-11.3 ms across nine settings (a 2 ms spread, smaller than the 4.8 ms between two baseline runs). In the session it reads 29-34 ms. A queue after the encoder dropped the stage to 3 ms while the whole pipeline stayed at 33 ms and `webrtcsink`'s own queue went from 18 to 27 ms. So the stage's name is misleading: the encoder is waiting for `webrtcsink` to take its output. A queue renames the wait; it shortens nothing. No setting became a default.

**Nov 12 midday: prior art.** A research note ranked six techniques (section 5) from public sources and the owner's three papers. None of the three papers measured our four problem areas or Safari, so they changed no ranking. The papers cite 100 ms for fast genres and 150 ms for others as tolerable, and about 50 ms as acceptable (claimed); for party games that bears directly on whether 80 ms is the right target.

**Now: fix7 (in progress).** Its goal is three switchable techniques to try on the phone: audio sent apart from video, a zero playout delay request, and sender-side switches. I did not find a brief or report for it; this description is from your task text.

## 4. What we learned

1. **A stage's label can hide a downstream wait.** "Encode 30 ms" is an element's time including whatever its push waits for. The hardware encoder alone takes about 10 ms.
2. **Headless Chromium is not Safari.** Its jitter buffer read 90-260 ms; Safari's read 22 and 52 ms. Tuning the rig against Chrome would have chased the wrong buffer.
3. **Measure the noise first.** On this shared PC the same run moves 36-49 ms. Every single-setting experiment fell inside that band, so none was adopted. A derived number made by subtracting two independent measurements (the 66 ms, the 20 ms remainder) can be worse than noise.
4. **Settings are exhausted.** Encoder properties, VBV, FEC, GOP, resolution, CPU pinning, renderer, capture queues: none helped beyond noise.
5. **Several of our own measurements were wrong:** phantom viewers, a bitrate "ceiling" that was not the wire rate, an empty press phase, a re-arming frame loop, a pinning flag that did nothing, and a "floor" claim contradicted by its own data. Reviews by a second worker caught most of them; one review finding (the VBV unit) was itself wrong, and checking the tool settled it.
6. **The game answers a press in one frame; the 48 fps is a frame-clock wait,** not a busy game.
7. **How the work was done:** Claude designs, decides and reads only each batch's review summary; Sonnet agents run batches (per the task description); cheap flash-worker jobs implement; a runner commits and has a second worker review. Jobs were short and phased (13-30 minutes, 100-315 turns each) (the reason for the short phases is not stated in the records I read).

## 5. Open questions and options

The research ranks these; gains are inferences or claims from other projects, not our measurements:

1. **Audio apart from video** (fix7): Chromium raises video delay when audio and video share a stream; separate streams removed it in one engineer's report. Safari: one claim only. Possible gain up to the whole 50-100 ms *if* sync is the cause.
2. **Zero playout delay** (min=max=0 header from the sender): cheap; Safari support unconfirmed; earlier client-side hints did nothing on Safari.
3. **Sender switches** (fix7): remove the wait inside `webrtcsink` (congestion control off, FEC off, fixed bitrate) or bypass it with plain `webrtcbin`. Up to about 25 ms (inference). Host side, so Safari is unaffected.
4. **Fixed frame clock** instead of the compositor's callback: back to 60 fps, a few ms (inference); the residue of dropped frames after Skia is unexplained.
5. **A custom WebCodecs player** over WebSocket or WebTransport: the only route that guarantees no browser jitter buffer (one source: 20-30 ms lower than WebRTC). Biggest rewrite, loses WebRTC congestion control.
6. **Hide latency with instant feedback on the controller:** vibration, highlight and sound at press time on the phone. Cheapest, but needs the owner's judgement and a test; no paper measured it.
7. **Is 80 ms the right target?** Published cloud-gaming figures are 56-98 ms click to draw natively; no figure was found for press to screen on iPhone Safari. 80 ms looks plausible in Chrome and on Safari only if the jitter buffer is bypassed. With a 100-150 ms tolerance for casual games, 158 ms is close and 80 ms may be stricter than the games need *(inference)*. The roadmap itself says that if feel is wrong even at low delay, the snapshot path becomes the product.

Still unknown: the true run-to-run noise on the phone (one run each so far), and what the remaining ~66 ms of press-to-screen over capture-to-screen is.

## 6. Source index

- Status and plan: `docs/briefs/m15/STATUS.md` (written Nov 11, now stale on "next steps"), `docs/design/streaming-custom.md`, `docs/design/streaming-roadmap.md` (Gate 1), `docs/PRD-v2.md` (S7)
- Research: `docs/briefs/m15/research-custom-stack-report.md`, `research-hyperv-gpu-report.md`, `scan-stream-touchpoints-report.md`, `research/latency-prior-art.md`
- Probes: `docs/briefs/m15/wsl2-probe-report.md`, `linux-game-probe-report.md`, `capture-probe-report.md`
- Prototype: `docs/briefs/m15/p1-stream-metrics-report.md`, `c1-session-image-report.md`, `a2-automation-report.md`, `c2-stream-stats-report.md`, `REVIEW.md`
- fix1 / t1: `docs/briefs/m15/fix1/t1-latency-tuning-report.md`, `fix1/REVIEW.md`
- fix2 / g1: `docs/briefs/m15/fix2/g1-fixes-and-real-viewer-report.md`, `fix2/REVIEW.md`
- fix3 / h1: `docs/briefs/m15/fix3/h1-2-run-report.md`, `fix3/REVIEW.md`
- fix4: `docs/briefs/m15/fix4/i1-fix-report.md`
- fix5: `docs/briefs/m15/fix5/j1-1-fix-report.md`, `fix5/j1-2-run-report.md`, `fix5/j1-1-fix.md` (first iPhone numbers, in its Background)
- Phone runs: `docs/briefs/m15/c2/results/bench/bench0.json` (first iPhone run, row v3), `docs/briefs/m15/bench-results/20261112-092537/phone2/phone20.json`
- fix6: `docs/briefs/m15/fix6/k1-1-measure-report.md`, `k1-2-fps-report.md`, `k1-3-hostleg-report.md`, `k1-4-encoder-report.md`, `k1-1-measure.md` (the owner's 66 ms reading)
- Job timings: `docs/briefs/m15/run.log` and `fix1`-`fix6/run.log`; process: `docs/flash-framework.md`; debt: `docs/code-health.md` ("M15 streaming")
- fix7: no files yet.

## Running notes

Short dated notes of key data, decisions and challenges, appended as the work goes on, so the story can be rewritten from them later. Newest last.

- **Nov 12, 2026, decision.** After fix6 found nothing faster than the noise, the owner asked for research into prior art before more measuring, and supplied three papers. None of the three changed the ranking; the web research produced six ranked techniques (docs/briefs/m15/research/latency-prior-art.md).
- **Nov 12, 2026, challenge.** The three papers could not be read at first: one site refused the request and the PDF reader was not installed. An already-installed text extractor (pdftotext) solved it without installing anything.
- **Nov 12, 2026, data.** Thresholds cited in the Penn State dissertation: 150 ms tolerable, 100 ms for fast games. Our phone run: 158 ms median. The 80 ms gate may be stricter than casual party games need; not decided.
- **Nov 12, 2026, decision.** The owner chose to try the three cheapest techniques first, each behind a switch, default off: audio apart from video, zero playout delay, sender switches (batch fix7, nine short jobs, started 12:55). Phone runs decide; headless Chromium is not Safari.
- **Nov 12, 2026, correction.** Two figures quoted to the owner were not backed by the records: 8586 kbit/s (the record reads a mean of 6510) and a 66 ms host leg (a subtraction; measured 42 ms, later 20-45 ms and called unreliable).
- **Nov 12, 2026, way of working.** The main session was close to its weekly limit, so Sonnet agents now write briefs, run batches, do research and write documents; flash-worker implements; the main session decides and checks reports.
- **Nov 12, 2026, data (fix7, headless Chrome, not Safari).** Baselines: jitter buffer 96-136 ms, host time per frame (pipelineMs) 33.7-40.3, press-to-screen 205-244 ms (noise 39 ms). Sound on its own connection (`SESSION_AUDIO=separate`): jitter 13-14, press 143-146, host unchanged. No sound (`SESSION_AUDIO=off`): jitter 14-28, pipelineMs 7.7, press 128-136. Page option `lowdelay=1`, FEC off, retransmission off, congestion control on: all inside noise. Source: docs/briefs/m15/fix7/n4-matrix-report.md.
- **Nov 12, 2026, finding.** The browser's large buffer was mostly lip-sync: the video was held back to match the sound. Splitting them removed about 100 ms of buffer in Chrome.
- **Nov 12, 2026, challenge.** The zero-playout-delay RTP extension could not be sent: the installed GStreamer has no element or hook for it; it would need an install or a build.
- **Nov 12, 2026, open (inference).** With no sound the host time per frame fell from about 33 ms to 7.7 ms, and the sound encoder shows 20 ms. So the "wait inside webrtcsink" is probably the video waiting for the pipeline-wide latency that the sound branch sets. Not yet tested: sound in its own pipeline, so the video is not delayed by it.
- **Nov 12, 2026, challenge.** One job (audio build) ran 387 turns against a 150 target and broke another package's test; repaired by hand by the Sonnet agent. The other eight jobs ran 51-171 turns.
- **Nov 12, 2026, data (iPhone Safari, four 60 s runs, one each, results under docs/briefs/m15/bench-results/20261112-18*).** Median/p95 in ms. Baseline: buffer 30/69, stream total 69/111, press-to-screen 185/281. Sound on its own connection: buffer 59/104, total 98/145, press 192/239. No sound: host encode stage 3 (pipeline 7.5 against 34-38), buffer 65/91, total 77/106, press 181/256. Page option lowdelay=1: buffer 31/57, total 70/98, press 167/341.
- **Nov 12, 2026, finding.** What worked in headless Chrome did not carry to Safari: none of the switches moved press-to-screen beyond what looks like run-to-run variation (167-192). With no sound the host got about 27 ms faster and Safari's buffer grew by about as much.
- **Nov 12, 2026, finding (inference).** The measured stream chain is only about 70 ms; press-to-screen is 167-192. Host legs before capture are about 25-30 ms, which leaves 70-85 ms that no stage measures (the table's derived column; "display" reads 0). On headless Chrome that remainder was 11-51 ms. The largest piece of the phone's latency is therefore not yet located; candidates are Safari's time from decoded frame to glass and the way the probe detects the press on screen.
- **Nov 12, 2026, challenge.** The phone baseline moved between runs with nothing changed (buffer 52 in the morning, 30 in the evening); phone noise is still not measured. Reconnect counts (16, 46, 68) and first-frame times grew from run to run, which looks like a counting error carried by the phone's page across sessions, not real reconnects; unverified.
- **Nov 12, 2026, caveat.** The owner reported that Safari was left running through all four evening phone runs (the page was not opened fresh for each). The growing reconnect counts and first-frame times fit that, and the four runs' comparison is weakened: a rerun with a fresh page per run is needed before drawing conclusions. Work paused on the owner's word.
- **Nov 12, 2026, challenge.** The player page reconnects on its own when a new session appears, so a tab left open from one run joined the next run before the owner did and spoiled it (explains the earlier reconnect counts). New routine: the owner closes every stream tab and says ready; only then is the run started. The page also gives no sign that a stream has ended, although the session does stop.
- **Nov 12, 2026, data (iPhone Safari, clean reruns, fresh tab each, one run each; median/p95 ms).** Baseline (20261112-191250): encode stage 30, buffer 79/112, stream total 118/154, press-to-screen 179/239, two freezes reported (9.3 s, not noticed by the owner). Sound on its own connection (…-191539 or the phone-audio-sep folder of that evening): buffer 22/52, total 61/94, press 187/321. No sound (20261112-193438): encode stage 3, buffer 18/45, total 30/60, press 169/370. Page option lowdelay=1 (20261112-200543): buffer 89/128, total 130/173, press 223/317. Spoiled or unhealthy no-sound attempts, kept for the record: 20261112-191818 (stale tab joined first) and the following attempt (four freezes, 19 s, 12049 kbit/s received, no press figure; the owner could not reopen the tab).
- **Nov 12, 2026, finding.** On Safari the sound is what holds the video back, on the host and in the browser: with no sound the measured stream chain was 30 ms, with sound on its own connection 61 ms, against 118-130 ms with sound in the same stream. The page's lowdelay option does nothing on Safari.
- **Nov 12, 2026, finding (the open problem).** Press-to-screen did not follow the stream chain: 179, 187, 169 and 223 ms while the chain read 118, 61, 30 and 130 ms. The gap between them ranged from 61 to 139 ms. So either the press timing or the chain timing is not measuring what we think on the phone, or a real delay sits outside both. Until that is settled, no press-to-screen figure from the phone can be trusted to judge a change. Next: check the measurement with an independent method.
- **Nov 12, 2026, decision.** Batch fix8 (six jobs) builds an independent check of the phone's press-to-screen: a coded marker row drawn in the top-left of the picture (frame counter, host clock, a press-flip cell), read back from the video element by the page, with an NTP-style clock offset and every requestVideoFrameCallback field the browser gives. Marker and page option are off by default (SESSION_MARKER=on, page query marker=1); two page fixes (the page says the stream has ended and never rejoins by itself; the bench ignores a page loaded before the session). Spec: docs/streaming-marker.md.
- **Nov 12, 2026, finding (audit, docs/briefs/m15/fix8/f8-1-audit-report.md).** No single definite fault explains the 61-139 ms gap. The chain's `display` stage is max(0, presentationTime - expectedDisplayTime), so it ends at the plan and cannot see decoded-to-glass (it reads 0 in all four runs); the chain total is a sum of six stage medians; after the host legs 36, 104, 117 and 73 ms stay unexplained. Best fit (inference): Safari's jitter-buffer figure is only part of the playout wait, the rest sits in WebKit's renderer queue, compositing and the panel, which no field covers. Smaller press-side faults: the patch is read every 8th frame when idle, a press can match a flip up to 499 ms later, presses are polled every 200 ms.
- **Nov 12, 2026, data (headless Chrome, not Safari).** The marker is readable in every frame (10,000+ frames, 0 unreadable), clock offset uncertainty about 9 ms, and it costs 0.2 ms build and 0.5 ms raster a frame on the host. But the independent press-to-screen disagreed with the card probe in one of two identical runs: 369 against 241 ms (jitter buffer 259) and 236 against 213 (jitter 109). The marker's press figure follows the jitter buffer, the card's much less. Headless Chrome cannot say which is right; the phone decides.
- **Nov 12, 2026, challenge.** Job 2 stopped on generated plugin files outside its list and job 4 on a CRLF fixture comparison on Windows; both repaired by hand (ordinary stops). Jobs ran 70-199 turns; two (199, 186) over the 150 target.
