job: M16 process2 prompt — worker doc extract in flash.sh and allow-list entries for the new tools
pub: no
stop: after it. Do not touch any other part of flash.sh.
read: docs/briefs/templates/COMMON.md · tools/flash.sh (the rules= prompt :237-255, the allowed array :257-270) · docs/coding-guidelines.md · docs/review-rules.md
decisions (owner, Nov 21): "put a short extract (at most ~60 lines) of docs/coding-guidelines.md and docs/review-rules.md into flash.sh's standing worker prompt, so workers stop re-reading those files; keep the full files as the source of truth (note in each file that the extract must be updated with it)". Add `Bash(tools/mine.sh:*)`.
tests-first: exempt shell tooling. You cannot run shell tests yet (not allow-listed): check with bash -n; the driver runs your test.

do:
1 Write docs/worker-extract.md: at most 60 lines, the rules a worker breaks most (size limits, style, review-rules part A self-check, test conventions) as terse bullets, each pointing at its source section.
2 flash.sh appends that file's text to $rules when it exists (a missing file: no error). Replace the "Read docs/coding-guidelines.md before every job" sentence with: the extract below is the rules; open the full files only for a question it does not answer.
3 flash.sh allowed list: add Bash(tools/mine.sh:*) Bash(bash tools/mine.sh:*) Bash(tools/wait-run.sh:*) Bash(bash tools/wait-run.sh:*) Bash(tools/run-stop.sh:*) Bash(bash tools/run-stop.sh:*) Bash(tools/selftest.sh:*) Bash(bash tools/selftest.sh:*) Bash(bash tools/tests/:*) Bash(tools/tests/:*). Not bash tools/run-jobs.sh.
4 First lines of coding-guidelines.md and review-rules.md: one note: "docs/worker-extract.md is the short copy workers get in their prompt; update it with this file."
5 tools/tests/flash-prompt-test.sh (follow docs/briefs/m16/process2/script-rules.md as far as it applies): runs `bash tools/flash.sh --dry-run "x"` and asserts the extract text, each new allow entry and the line limit; a missing extract file still works (FLASH_EXTRACT env overrides the path).
allow: tools/flash.sh · docs/worker-extract.md · docs/coding-guidelines.md · docs/review-rules.md · tools/tests/flash-prompt-test.sh · docs/briefs/m16/process2/p2-prompt-report.md
check: format
report: docs/briefs/m16/process2/p2-prompt-report.md
