# Script rules (owner, Nov 21): every new shell script in this batch follows them

Style: bash, `set -u`, a header comment with usage, exit codes and env knobs (`sed -n '2,Np'` help via -h). Functions short; file under 300 lines. Works in Git Bash on Windows.

- **Exit codes:** 0 ok · 1 real failure · 2 timeout or stall · 3 bad input or setup (wrong or missing arguments, missing folder/file, not a git worktree). The LAST output line states the result plainly: `RESULT: <ok|FAILED|TIMEOUT|STALLED|OVERRUN|BAD INPUT>: <one sentence>`.
- **Time limit:** the script stops itself past a default limit (an env var overrides it, named in the header) with `TIMEOUT: <what> exceeded <n>s`, exit 2. Every external command that can hang runs under `timeout`.
- **Input checks:** check arguments, the folder, run.log, the worktree up front: a clear one-line message and exit 3. An empty change list, or a package with no tests, prints a plain line saying so; never a silent pass.
- **Edge cases:** paths with spaces (quote everything; `git ... -z` for lists); no changed files; deleted or renamed files in a change list; a test file whose lib file is gone; two copies at once (lock file holding the pid under `.dart_tool/`; refuse with exit 3 when that pid is alive, replace a stale lock); an interrupted run (trap EXIT INT TERM removes the lock and temp files and kills its children).
- **Never destructive:** only `git checkout --` on KNOWN generated paths (tools/churn.sh when it exists); never stage, commit, stash, reset, delete user files, or touch another worktree.
- **Self-test:** `tools/tests/<name>-test.sh` (a throwaway git repo or temp folder; stub `dart`/`flutter`/`flash` through env vars or a PATH stub dir; no network; under 60 s). It prints `PASS <case>` / `FAIL <case>` lines and exits non-zero on any FAIL. It covers every rule above, each with its own case. Run it with `bash tools/tests/<name>-test.sh`.
