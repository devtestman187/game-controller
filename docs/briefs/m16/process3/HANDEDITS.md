# Hand edits for the driver (not flash jobs): process3

Why wave 1 workers used tools/mine.sh 0 times (from the files): flash.sh puts docs/worker-extract.md into every worker's system prompt, and its Tests section says "while working run only your own test files" and never names mine.sh; flash.sh's own rules say "run a test suite once per change, on the smallest package that covers it". The only mention is the last sentence of the Bash bullet in COMMON.md, which a brief must open via `read:`. The allow-list does include mine.sh. So the standing prompt pulls toward raw `flutter test`.

1. docs/worker-extract.md, section Tests: replace "while working run only your own test files" by "when a change is ready run `tools/mine.sh` (format, analyze, the touched tests, churn revert, failures only); not raw dart/flutter, not a partial `tools/check.sh`; `bash tools/mine.sh` again after each fix"; add the same one line under "Before you write".
2. docs/briefs/templates/COMMON.md: in Tests, "While working run only your own test files" becomes "While working use `tools/mine.sh`"; in Bash, move the mine.sh sentence first: "**Bash:** the one check is `tools/mine.sh` (format, analyze, touched tests, churn revert); allow-listed by prefix: ...".
3. .claude/agents/thumb-batch.md, step 1 (brief writing), add: "Before writing a brief, `git grep` for exhaustive switches and registrations over every type the job changes (a sealed class, an enum, a message `wireType` table, a codec `_decoders` map) and for tests that touch every changed widget or text; put each file in `allow:` (or give it to a job of the same wave). Wave 1 of identity1 stopped twice on this."
4. Optional, tools/flash.sh (protected): `--max-turns "${FLASH_MAX_TURNS:-120}"` on the worker command, a hard form of B.8 beside the runner's after-the-fact cap.
5. docs/flash-digest.md: after p3 ships, note `RESULT:` lines, the per-step limits and FLASH_CMD; wait-run no longer repeats OVERRUN.

Items 1, 2, 3 are applied (Nov 22; item 3 on the owner's approval of the process3 plan, plus the wave-independence line). Item 4 approved by the main session with default 150 (hard backstop; sizing target stays 120). Item 5 after p3 ships.

Item 4 applied Nov 22 with the default 150: tools/flash.sh passes `--max-turns "${FLASH_MAX_TURNS:-150}"` (the flag was already used by the preflight there; flash-prompt-test passes).
