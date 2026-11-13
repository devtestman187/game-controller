# opt2c report: the keyframe storm of the custom player (Nov 13, 2026)

Commits: 1c7a912 (g1 page diag), 366e6b9 (g2 host diag), 5d6dba1 (g3 storm), b9fa33f (g4 sender), 99ce7a5 (g5 card/marker), plus the bench fetch fix and this report.

## Before and after (headless, wc + tap + separate sound, impairment tool on 127.0.0.2, 60 s run, 30 s impaired)

| Profile | dropped | key requests | freezes |
|---|---|---|---|
| stall, before | 196-205 | 9 | 7-8 (3.2-3.8 s) |
| stall, after | 1 | 0 | 9 (4.7 s; the stalls themselves) |
| all (loss 1 %, 12 Mbit, stalls), before | 180 | 10 | 7 |
| all, after | 1 | 0 | 6 (3.3 s) |

After the stalls the decoder queue peaks at 25-27 and drains; frames are decoded, only the newest is drawn. Tap diagnostics: drops 0, keyreq 0, tunnel outq up to 215 KB, send up to 300 ms (the small buffer shows the stall instead of hiding it). Results: bench-results/20261113-160117 (stall), -160249 (all).

## Clean runs (wc + separate sound, 60 s + 20 s presses)

| Run | card ms | marker ms | dropped | freezes | keys |
|---|---|---|---|---|---|
| 1 | 112 | 112 | 0 | 0 | 0 |
| 2 | 107 | 109 | 0 | 0 | 0 |
| 3 | 101 | 102 | 1 | 0 | 0 |
| marker off | 110 | n/a | 1 | 0 | 0 |

Draw cost: 11-13 ms with the marker, 12 without (noise). Card and marker now agree within 0-2 ms; the cause of the earlier gap is in g5-cardmarker-report.md (card sampled every 8th frame and matched a press to the next flip it saw; the marker matched retroactively).

## Not proven
Safari, a real Wi-Fi stall, hardware decode: only the third sitting shows these. Transport stays WebSocket (no GstWebRTC typelib in the image). Freezes under stalls did not fall: the stall is the freeze; the loss and the storm after it are gone.

## Third sitting: result (iPhone, wc + tap + separate sound)

| Run | press-to-screen ms | freezes (count/ms) | dropped | key requests | recv-to-decode ms | decoder queue max | lag max ms |
|---|---|---|---|---|---|---|---|
| smoke | 203 | 0 | 0 | 0 | 35.9 | 3 | 62 |
| wc3-1 | 186 | 1 / 183 | 0 | 0 | 35.4 | 8 | 1026 |
| wc3-2 | 167 | 2 / 413 | 0 | 0 | 36.4 | 13 | 62 |
| wc3-3 | 159 | 6 / 4727 | 160 | 3 | 40.0 | 40 | 2951 |
| wc3-4 | 105 | 0 | 0 | 0 | 36.0 | 4 | 64 |

Sound played in all runs. wc3-3 had one decoder error ("EncodingError Decoder failure"), one rebuild and a gap of 2348 ms. No "tap diagnostics:" line appeared in the bench output. Results: bench-results/20261113-1741xx to 1749xx; logs opt2/sitting-logs/wc3-*.txt.

- **Outcome:** acceptance rule (all four at 150 ms or less, no more freezes than the current player) NOT met: 3 of 4 runs over 150 ms, freezes in 3 of 4. The custom player is dropped; the current player stays default; the code stays behind default-off switches.
- **Worked:** the keyframe storm is gone on the phone (0 key requests in 4 of 5 runs, 3 in the worst).
- **Did not work:** receive-to-decode rose from about 5 ms to 35-40 ms in every run, about two frames, likely from the new catch-up and newest-frame drawing (not investigated). One run still stalled 2.3 s. The 105-203 ms spread shows the path is not stable.
- Current player the same day: 162/159 and 176/176 ms, 0 freezes.
