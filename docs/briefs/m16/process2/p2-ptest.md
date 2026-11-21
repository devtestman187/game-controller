job: M16 process2 ptest — self-test for the flash.sh worker extract and allow-list entries
pub: no
stop: after it. flash.sh is protected: do not edit it.
read: docs/briefs/templates/COMMON.md · docs/briefs/m16/process2/script-rules.md · tools/flash.sh (the rules= prompt, the extract lines after it, the allowed array; `--dry-run` prints the command) · docs/worker-extract.md · tools/tests/selftest-test.sh (the test style used here)
decisions (owner, Nov 21): the extract is at most ~60 lines; the full docs stay the source of truth, each carries a note that the extract is updated with it.
tests-first: exempt shell tooling; run your test with bash tools/tests/flash-prompt-test.sh.

do:
1 tools/tests/flash-prompt-test.sh per script-rules.md: `bash tools/flash.sh --dry-run "x"` output contains the extract's heading text and every entry Bash(tools/mine.sh:*) Bash(bash tools/mine.sh:*) Bash(tools/wait-run.sh:*) Bash(bash tools/wait-run.sh:*) Bash(tools/run-stop.sh:*) Bash(bash tools/run-stop.sh:*) Bash(tools/selftest.sh:*) Bash(bash tools/selftest.sh:*) Bash(bash tools/tests/:*) Bash(tools/tests/:*); the extract file has at most 60 lines; FLASH_EXTRACT pointing at a missing file still gives a prompt without the extract; FLASH_EXTRACT at a temp file with spaces in its path is included; both docs carry the note line; `bash tools/run-jobs.sh` is NOT in the allow list.
allow: tools/tests/flash-prompt-test.sh · docs/briefs/m16/process2/p2-ptest-report.md
check: format
report: docs/briefs/m16/process2/p2-ptest-report.md
