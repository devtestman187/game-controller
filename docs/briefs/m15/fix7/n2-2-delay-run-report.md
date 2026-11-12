# n2-2 run: `lowdelay=1` in the page — three runs, nothing moved

## Summary

**Headless Chrome, not Safari.** Three 45 s probe runs with `--player-query lowdelay=1`
(n2pl0–n2pl2), 1080p60, one session and one headless Chrome viewer each, judged against n0's
three untouched baselines. Technique 2's host half (the playout-delay RTP header extension) was
blocked in n2-1, so there is no `SESSION_PLAYOUT_DELAY` to run: the page switch is all this
phase could measure.

- **The page switch works and moves nothing beyond noise**: jitter buffer 144 / 102 / 115 ms
  against the baseline's 136 / 96 / 107; stream total 179 / 137 / 150 (171 / 131 / 142); press
  median 242 / 209 / 228 (244 / 205 / 218). Every difference is inside the ±40 ms spread.
- **The host side is untouched**, as a page-only switch should leave it: encode 29 ms (p95 30),
  `pipelineMs` 33.9 / 40.9 / 41.0, encodedFps 57.0 / 56.0 / 55.4, game 17.7 / 18.5 / 18.9 ms/frame.
- **Same bimodal shape as n0**: run 0 sits high (jitter 144, total 179, press 242) and runs 1–2
  low, exactly where n0's run 0 and runs 1–2 sit — so these numbers cannot be told apart from
  the untouched image's.
- **Every run: exactly one viewer row** (`browser/chrome-headless`) with receive data (jitter,
  network and decode stages; 2796 / 2767 / 2781 frames received, 8 / 6 / 7 dropped, no freezes,
  2166 / 2103 / 2053 kbit/s, 1920x1080 H264, relay "no").
- **Read-back not re-taken here**: n2-1 read it back from this same page build (`lowdelay:
  rate=1 drp=on latency=missing video jbt=0 pdh=0, audio jbt=0 pdh=0`). Every run printed
  `switches: player-query lowdelay=1, player-options none`, so the query reached the page.
- One caveat: run 0's press p95 is 323 (max 339), above every baseline p95 (241–275); runs 1–2
  are 239 / 257. One run of three, no fix and no claim.
- **What headless Chrome cannot tell**: whether Safari honours the page hints (the prior-art
  notes say it may ignore `jitterBufferTarget` and `playoutDelayHint`), and nothing here speaks
  to the phone; **the phone decides**. The host extension — the half Safari might honour — does
  not exist yet.

## Method

- Route: `streaming/bench.sh` run directly in `tp-stream` (the earlier run phases' route), not
  `tools/stream.sh`: the wrapper's report needs `dart` on this side, which the sandbox refuses.
- Image rebuilt from this job's checkout first (entrypoint and player are COPY layers near the
  end; the build cache made it quick):

  ```bash
  cd /work/flash-20261112-150253-21094
  timeout 580 docker build -q -f streaming/Dockerfile -t tp-session:latest .
  timeout 590 bash streaming/bench.sh --probe --seconds 45 --label n2pl0 \
    --out /work/stream-bench/n2pl0 --player-query lowdelay=1
  # and the same for n2pl1 and n2pl2
  ```

- Image `sha256:2e6feccc…` (n0's was `a19f88a…`); GStreamer 1.24.2, webrtcsink 0.13.6-RELEASE.
  The image id differs from n0's although the commit is the same: the working tree this job was
  cut from carries uncommitted generated plugin registrant files from before the job.
- Labels: two runs were first made with the label `n2pl` (a `$v` in the distro command came
  through empty, so every iteration used the same label and the second overwrote the first), and
  were redone as `n2pl0`-style named runs. Five variant runs in total, inside the brief's six;
  only the three named runs are kept and quoted here.
- Summaries, pipeline snapshots and the switches line fetched with `tools/wsl-fetch.sh` into
  `docs/briefs/m15/fix7/n2-2-delay-run/` (`n2pl00/10/20.json`, `pipeline-n2pl*0.json`,
  `switches.txt`). Containers stopped, scratch files in the distro removed.

## The three runs

| run | jitter | pipelineMs | total | press | encFps | game ms/f | viewer |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `n2pl0` | 144/202 | 33.88 (p95 34.0) | 179/238 (n 11) | 242/323 (91) | 57.01 | 17.7 | 1, chrome |
| `n2pl1` | 102/103 | 40.86 (p95 33.98) | 137/139 (n 4) | 209/239 (90) | 55.96 | 18.5 | 1, chrome |
| `n2pl2` | 115/116 | 40.97 (p95 34.01) | 150/152 (n 10) | 228/257 (83) | 55.43 | 18.9 | 1, chrome |
| baseline | 136/96/107 | 33.7–40.3 | 171/131/142 | 244/205/218 | 55.4–56.6 | 18.4–19.2 | 1, chrome |

Stage rows (median, n2pl0 / n2pl1 / n2pl2): display 0 / 0 / 0, network 1 / 1 / 1, encode 29 / 29 /
29 (p95 30 in all three), capture 2 / 2 / 2, decode 3 / 3 / 3, host tick 14 / 17 / 15, host build
0 / 1 / 1, host raster 4 / 5 / 5. Jitter p95 202 / 103 / 116; total p95 238 / 139 / 152.

Spreads: jitter 102–144 (42), total 137–179 (42), press median 209–242 (33), press p95 239–323
(84). The baseline's spreads are 40, 40, 39 and 34 — the variant is as noisy as the baseline, and
the one outlier (run 0's p95) is on the tight-buffer side of nothing.

## Answers

1. **Host variant: not run.** `streaming/entrypoint.sh` has no `SESSION_PLAYOUT_DELAY` and
   `streaming/player/*.js` has no host-side playout setting; n2-1 proved the extension cannot be
   made with the image's GStreamer (no element, no webrtcsink/webrtcbin hook, no `a=extmap` in
   the SDP). Setting an unknown name would have been a false run.
2. **Player `lowdelay=1`: the browser accepted it and the stream behaves exactly as without it.**
   Jitter buffer and stream total stay inside the baseline's noise (worst case +8 ms), press is
   inside it to the millisecond, and the host's encode/`pipelineMs`/fps are unchanged. Headless
   Chrome's jitter buffer is evidently not moved by `jitterBufferTarget=0` /
   `playoutDelayHint=0` — consistent with the phone's 52/101 ms despite the same hints.
3. **Read-back**: taken once, in n2-1, on this build; not re-taken in these runs (the bench's
   headless shell has no DevTools port, and a kept session plus a second viewer would have cost
   more than it could tell). The overlay line was `lowdelay: rate=1 drp=on latency=missing video
   jbt=0 pdh=0, audio jbt=0 pdh=0`.
4. **What headless Chrome cannot tell**: Safari's handling of the page hints, and any phone
   result. The host extension, if it were built, would be the candidate Safari honours; it is
   not built, so nothing here says whether technique 2 helps the owner's iPhone.

Verdicts, one line each:

- **Player `lowdelay=1`** (n2pl0–n2pl2): accepted by Chrome, no change to the host, no change to
  Chrome's jitter buffer, press or stream total beyond noise — **neutral on the headless viewer;
  the phone decides**.
- **Host `SESSION_PLAYOUT_DELAY=zero`**: **does not exist** (n2-1 blocked it); nothing ran.

The owner's commands (one phone run each; the first with the switch, the second as its pair):

```bash
tools/stream.sh bench --probe --seconds 45 --label phone-ld --player-query lowdelay=1 --viewer external
tools/stream.sh bench --probe --seconds 45 --label phone-ld-off --viewer external
```

There is no owner command for the host half until a webrtcsink change exists.

## Decisions

- Ran only the player variant: the host switch is not implemented (n2-1), so running it was
  impossible rather than skipped.
- Five variant runs, three kept: the two mislabeled runs used exactly the requested settings and
  would have been valid data under wrong names; redoing them kept the folder's names readable and
  stayed inside the six-run cap.
- No read-back was re-taken: same page build, same query, and the read-back is a property of the
  page code, not of a run.
- Nothing outside the report and this folder changed: a run phase adds no behaviour, and the
  switches and their default-off state are as the build job left them.

## Checks

- `tools/check.sh format analyze metrics tv` → `PASS format (2s)`, `PASS analyze (16s)`,
  `PASS metrics (157 tests, 6s)`, `PASS tv (66s)`, "All checks passed (91s)".
- No repository script changed, so no `bash -n` was needed on this side; the one-line loop script
  used in the distro was removed.

## Self-check (docs/review-rules.md part A, items 1–5)

1. **Every host setup**: not affected — no app or page code changed in this job, the image is the
   same commit, and with no query the page runs exactly the code n0's runs used (n2-1 added the
   option behind the switch; the default path is unchanged). Test: n0b0–n0b2 against n2pl0–2.
2. **Kept state**: the option's only kept state is the page's one-second put-back timer, which
   starts when a page with the query loads and ends when the page closes (n2-1's code, unchanged
   here); this job added no state. Test: n2-1's `streaming/player/relay_test.py`, untouched this
   job and not run by it.
3. **How a new state combines**: nothing new — the option neither pauses, hides, waits nor blocks
   input, and does not touch the round, the pause menu or the host's states.
4. **Job folder only**: wrote this report and `docs/briefs/m15/fix7/n2-2-delay-run/` (three
   summaries, three pipeline snapshots, `switches.txt`).
5. **Stop rather than overstep**: the host half is blocked, so its runs were not faked; the
   report says so plainly instead of substituting a run.

## Questions and suggestions

1. Run 0's press p95 (323) is the highest tail seen in fix7 so far; is a longer probe (60 s) or
   more presses per run worth it before the phone comparison, or is the noise band wide enough?
2. n2pl1's `stream_total` has only 4 samples (n2pl2 10); should the bench's total combine more
   sampling ticks, so a three-run comparison does not hinge on one run's four samples?
3. Same question as n2-1's: drop technique 2's host half from the batch's phone comparison until
   a webrtcsink change exists, or keep the page switch alone as the variant?

## Hand-over

- Exists now: three 45 s headless-Chrome runs of the page switch (`n2pl0`–`n2pl2`, summaries and
  pipeline snapshots in `docs/briefs/m15/fix7/n2-2-delay-run/`), judged against n0's baselines.
- Numbers (headless Chrome, not Safari): jitter 144 / 102 / 115 ms (baseline 136 / 96 / 107),
  stream total 179 / 137 / 150 (171 / 131 / 142), press 242 / 209 / 228 (244 / 205 / 218), encode
  29 ms, `pipelineMs` 33.9 / 40.9 / 41.0, encodedFps 57.0 / 56.0 / 55.4, one viewer row each with
  receive data. All inside the ~40 ms noise, with n0's bimodal shape.
- Commands that worked (in `tp-stream`, from `/work/flash-20261112-150253-21094`):

      docker build -f streaming/Dockerfile -t tp-session:latest .
      bash streaming/bench.sh --probe --seconds 45 --label n2pl0 --out /work/stream-bench/n2pl0 --player-query lowdelay=1

- Do not redo: these three runs, the image build, n2-1's page read-back, the host-half survey.
- Open: the phone runs decide technique 2; the host extension still does not exist; run 0's press
  tail (p95 323) is unexplained but inside one run of the band.

## Commit message

docs: three fix7 runs of the page's zero-delay switch

Three 45 s probe runs with `lowdelay=1` on the viewer's URL (headless Chrome, 1080p60): jitter
buffer 144/102/115 ms against the baseline's 136/96/107, stream total 179/137/150, press
242/209/228, encode 29 ms, encodedFps 55.4-57.0, one viewer row each. Every difference is inside
the ~40 ms noise and the runs repeat n0's bimodal shape, so the switch moves nothing a headless
viewer can see; the host half of technique 2 is still blocked (n2-1) and was not run. Summaries
in fix7/n2-2-delay-run/; no code changed.

## Status row

fix7 n2 technique 2 (run): page `lowdelay=1` measured three times in headless Chrome — jitter 144/102/115, total 179/137/150, press 242/209/228, all inside n0's noise — so the page hint is neutral on Chrome; the host playout-delay extension is still blocked (n2-1) and was not run — open: the paired phone runs (Safari may ignore both hints) and the webrtcsink extension.

## Delete

- none
