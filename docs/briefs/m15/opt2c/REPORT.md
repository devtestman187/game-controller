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
