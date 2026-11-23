# M16 identity1-clean ct: report

## Files changed

- `tools/tests/claude-worker-test.sh`: after the web-brief case, two cases in the same style. (1) A brief with `turns: 50` gives `max-turns: 50` (exit 0). (2) A brief with `turns: 20` still gives `max-turns: 35` (exit 0). Both run `--brief <file> --dry-run` with the stub `claude` on PATH.
- `tools/selftest.sh`: `FLASH_WORKER` added to the `unset` list on line 29, after `RUN_CHECK_SKIP`; the comment above it now names `FLASH_WORKER` too, so a combined run by `tools/run-jobs.sh` cannot pass the worker kind down into the tests.

## Checks

- `bash tools/tests/claude-worker-test.sh`: `RESULT: ok: 17 case(s) passed` (all 17 PASS, including the two new ones).
- `tools/check.sh format`: PASS (`All checks passed (14s)`).

## Computed values for the expectations

- Brief `turns: 50`, claude worker default cap 35: `50 > 35`, so maxturns becomes 50; the dry-run line must contain `max-turns: 50`.
- Brief `turns: 20`: `20 > 35` is false, so maxturns stays 35; the dry-run line must contain `max-turns: 35`.

## Tests-first note

Exempt, as the brief says: the code (flash.sh:244) already exists. The new case was not run against a copy without that line (that would mean editing `tools/flash.sh`, which is out of scope). By reading the code: with the turns line removed, `maxturns` stays at the default 35, so the `max-turns: 50` assertion fails. Not run, reasoned from the code.

## Questions / suggestions

1. The "fails if the turns line is removed" property was argued from the code, not run. A one-off check with the line removed in a scratch copy would confirm it.
2. The selftest comment edit goes slightly beyond the brief's one-line change; it was made to keep the comment accurate, as the brief asked. Easy to revert if preferred.
3. The new brief files are written under `$tmp`, so no repo files are created.

## Commit message — a draft

Pin the brief turns line in the claude worker test

Add two claude-worker cases: a brief `turns: 50` raises --max-turns to 50,
and `turns: 20` leaves the 35 default (the line only raises).
selftest.sh also unsets FLASH_WORKER so a combined run cannot pass the
worker kind down into the tests.

## Status row

M16 identity1-clean ct: done: claude-worker-test pins the brief turns line (50 raises, 20 keeps 35) and selftest unsets FLASH_WORKER; 17/17 PASS, format PASS. Open: confirm the new case fails with the turns line removed (argued from code, not run).

## Delete

- none
