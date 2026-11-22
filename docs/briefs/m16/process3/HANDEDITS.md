# Hand edits for the driver (not flash jobs): process3

Why wave 1 workers used tools/mine.sh 0 times (from the files): flash.sh puts docs/worker-extract.md into every worker's system prompt, and its Tests section says "while working run only your own test files" and never names mine.sh; flash.sh's own rules say "run a test suite once per change, on the smallest package that covers it". The only mention is the last sentence of the Bash bullet in COMMON.md, which a brief must open via `read:`. The allow-list does include mine.sh. So the standing prompt pulls toward raw `flutter test`.

1. docs/worker-extract.md, section Tests: replace "while working run only your own test files" by "when a change is ready run `tools/mine.sh` (format, analyze, the touched tests, churn revert, failures only); not raw dart/flutter, not a partial `tools/check.sh`; `bash tools/mine.sh` again after each fix"; add the same one line under "Before you write".
2. docs/briefs/templates/COMMON.md: in Tests, "While working run only your own test files" becomes "While working use `tools/mine.sh`"; in Bash, move the mine.sh sentence first: "**Bash:** the one check is `tools/mine.sh` (format, analyze, touched tests, churn revert); allow-listed by prefix: ...".
3. .claude/agents/thumb-batch.md, step 1 (brief writing), add: "Before writing a brief, `git grep` for exhaustive switches and registrations over every type the job changes (a sealed class, an enum, a message `wireType` table, a codec `_decoders` map) and for tests that touch every changed widget or text; put each file in `allow:` (or give it to a job of the same wave). Wave 1 of identity1 stopped twice on this."
4. Optional, tools/flash.sh (protected): `--max-turns "${FLASH_MAX_TURNS:-120}"` on the worker command, a hard form of B.8 beside the runner's after-the-fact cap.
5. docs/flash-digest.md: after p3 ships, note `RESULT:` lines, the per-step limits and FLASH_CMD; wait-run no longer repeats OVERRUN.

Items 1, 2 are applied (Nov 22, docs only); item 3 is a `.claude/` configuration change and waits for the owner's word. Items 4 and 5 are proposals.
