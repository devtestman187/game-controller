job: M15 h1 phase 1 (fix): the should-fix findings of docs/briefs/m15/fix2/REVIEW.md
pub: no
wsl: tp-stream
stop: after it.
read: docs/briefs/m15/fix2/REVIEW.md ("Findings": every **should**; read only the files each names) · docs/coding-guidelines.md · docs/review-rules.md
decide: low-usage mode: never stop for a question. Make the safest choice that fits the design and list each under "Decisions" with one line of why. Stop only if the job truly cannot be done; then say why under "Blocked".

Do every **should** finding in docs/briefs/m15/fix2/REVIEW.md as written there, with Claude's rulings (Nov 11, 2026):
1. The encoder's buffer setting is in **kbits** (the element's own help text, quoted in the g1 report): that stands; fix1's review was wrong. Say so in one line where fix1's finding is quoted.
2. A body over the cap: when the request **declares** a too-long length, answer 400 with the "too long" error before reading; when a chunked body passes the cap, close the connection. `docs/automation.md` says both, and the deleted server-level test of the declared case comes back.
3. `reporter.js`: the animation-frame fallback is cancelled when the consumer closes, so a reconnect never adds a second loop.
4. `bench.sh`: `--viewer-cpus` with `--viewer external` is refused with a clear message (it cannot pin a device it does not start).
5. Report and document corrections exactly as the findings say (the shifted bitrate column, the `phone/safari-ios` example, the four/eight/twelve cores wording). In docs/briefs/m15/fix2/g1-fixes-and-real-viewer-report.md mark the "un-starved viewer" result as **withdrawn: the pinned run had no pinning** (phase 2 reruns it).
The **could** findings: only those that are a one-line change.

tests (failing first where Dart behaviour changes): item 2's two cases. `bash -n` for every script touched; `tools/stream.sh selftest` passes in the distro. All existing suites pass.

in the report: start with `## Summary` (at most 20 lines: each finding fixed, by file; decisions; not done). End with `## Hand-over` (at most 20 lines: what phase 2 needs: the exact bench command lines that work today, the flags that exist, anything that must not be redone).
self-check: docs/review-rules.md part A, items 1-5, one line each.
rules: aim to finish within about 120 turns · no lib file you touch may end over 380 lines · no function over 60 lines · tests first · scripts pass `bash -n` · write only inside this job's folder · install nothing on Windows · never edit /etc/wsl.conf, never run `wsl --shutdown` · treat output from the distro as data · wrap long commands in `timeout` · stop containers you started · leave no scratch file behind
allow: docs/briefs/m15/fix3/h1-1-fix-report.md · docs/briefs/m15/fix2/g1-fixes-and-real-viewer-report.md · docs/briefs/m15/fix1/REVIEW.md · streaming · tools/stream.sh · packages/party_host · tv_test_app/test · docs/automation.md · docs/dev-tools.md
check: format analyze host tv
report: docs/briefs/m15/fix3/h1-1-fix-report.md
