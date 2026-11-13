# f8-6 proof runs

Six 45 s runs in `tp-stream` (headless Chrome viewer, `tp-session:latest`), the
checkout `/work/flash-20261112-220045-33184` (`tools/wsl-sync.sh tp-stream`).
Each run left three files here: `<run>.json` is the session summary bench fetched,
`<run>-switches.txt` the bench's own `switches:` line, `<run>.log` the bench's
output (ready line, window length, the report's one summary line).

| Run | Command (in the synced checkout) |
| --- | --- |
| `f8-6-on1` | `bash streaming/bench.sh --probe --seconds 45 --set SESSION_MARKER=on --player-query marker=1 --label f8-6-on1 --out /work/f8-6/on1` |
| `f8-6-on2` | the same with `--label f8-6-on2 --out /work/f8-6/on2` |
| `f8-6-offprobe` | `bash streaming/bench.sh --probe --seconds 45 --label f8-6-offprobe --out /work/f8-6/offprobe` |
| `f8-6-roundon` | `bash streaming/bench.sh --seconds 45 --set SESSION_MARKER=on --player-query marker=1 --label f8-6-roundon --out /work/f8-6/roundon` |
| `f8-6-roundoff` | `bash streaming/bench.sh --seconds 45 --label f8-6-roundoff --out /work/f8-6/roundoff` |
| `f8-6-roundon2` | the `f8-6-roundon` command with `--label f8-6-roundon2 --out /work/f8-6/roundon2` (the repeat) |

The report reads them: [f8-6-proof-run-report.md](../f8-6-proof-run-report.md).
