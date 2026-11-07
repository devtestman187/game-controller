# M12 step 3: the host-side measurement on the PC

Nov 7, 2026, by Claude. The step 3 exit check ([m12-sessions.md](../../design/m12-sessions.md) §6): the development TV app on this Windows PC hosts each game, started with `tools/tv-dev.sh start --game <game> --hz <rate>`, and `sim_controller --view --stream` watches it for 45 s over loopback, streaming input 60 times a second. Measured after s3d's correction (every acknowledged input is a sample; late = 1.5 frame intervals).

| Game, frames/s | Touch-to-frame median / p95 | Jitter median / p95 | Drawn, gaps, late | Frame size mean / max |
| --- | --- | --- | --- | --- |
| Arena, 60 | 31 / 37 ms | 2 / 5 ms | 2644, 5, 120 | 490 / 518 B |
| Arena, 30 | 37 / 64 ms | 2 / 15 ms | 1342, 0, 41 | 491 / 521 B |
| Arena, 20 | 47 / 77 ms | 1 / 4 ms | 897, 0, 16 | 492 / 521 B |
| Shape Race, 60 | 31 / 44 ms | 1 / 5 ms | 2641, 17, 128 | 250 / 252 B |
| Shape Race, 30 | 36 / 55 ms | 1 / 3 ms | 1345, 0, 15 | 264 / 266 B |

**What it shows:** at 60 frames a second the delay from input to drawn frame is about 31 ms median, inside the 50 ms target, and it grows as the rate drops (47 ms median and 77 ms p95 at 20). That supports D2 (60 by default). Frames are about 0.5 KB, so 60 a second is about 30 KB/s per viewer.

**What it doesn't show:** this is one PC talking to itself, so there's no Wi-Fi in it, and the simulated viewer's 60 Hz timer is Windows' coarse one (most of the late draws at 60 Hz). Real phones and Wi-Fi come in step 6's measurement (one phone hosts, one joins).

**First run, before s3d:** touch-to-frame was 31 ms median at every rate and almost every draw counted late at 30 and 20 Hz. Both came from the contract's rules, which s3d corrected.

**Found on the way:**
- `tv-dev.sh` and `smoke.sh` couldn't read the TV log once the flutter tool's crash wrote a NUL byte into it; fixed with `grep -a` (`f675fbc`).
- In this sandbox the TV app loads 0 of 10 sounds (the temp-folder block, as in step 1). Sounds are a device check.
- The full `tools/smoke.sh` couldn't run its `frames` step here: running with the sandbox off was refused, and inside it the restarted app can't write its temp folder. The other 9 steps passed. The measurement above is the same check by hand.
- Once, the first TV app of a run refused the code from its own log ("Wrong pairing code"). The host picks a new code after several wrong codes in a row; what sent them is unknown (the log had gone quiet). Fresh starts paired every time.

Screenshots: the Arena with the simulated player (`tv-arena-30.png`) and Shape Race solo (`tv-shape_race-60.png`), sent to the owner.
