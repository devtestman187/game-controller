# Haiku-driver trial (board-1)

Status: planned Nov 26 (owner picked option A). Source: docs/briefs/m17/STATUS.md, "Driver cost plan", step 2.
Fits docs/design/claude-only-model.md: Sonnet decides, Haiku does the mechanical work. This trial tests whether a Haiku driver can run a whole batch if Sonnet makes only the judgment calls.

## Batch
board-1 = board3a, on branch board-line. It runs after B1, because B1's agent-cost line is the Sonnet baseline.

## Launch
thumb-batch, started with a per-call `model: haiku` override. thumb-batch.md keeps `model: sonnet`; B2-B4 stay on the Sonnet path.

## Sonnet judge
A short Sonnet agent, called on fixed triggers only:
- every brief before the runner starts
- every STOPPED
- every ladder step 3 or later
- every REVIEW finding
- every tracker note

Budget: at most 6 spawns, each with an evidence pack of 30 lines or fewer. The Haiku driver builds the pack and never lets the judge read files. Every spawn counts in the cost.
The judge returns: brief text, repair advice, a finding verdict (real / minor / trivial, with the file:line), or the tracker note text. Nothing else.

## Tracker
The Haiku driver writes the tracker itself with ArtifactData, using `if_version`, from the judge's text. It does not word notes on its own.

## Pass gates (all must hold)
1. thumb-verify returns PASS.
2. No missed design stop (a stop that needed the main session and was not handed back).
3. No extra ladder step against the judge's advice.
4. Total cost (driver, judge, waiters) below the B1 Sonnet baseline, from `bash tools/agent-cost.sh --since <batch start> --line`.
5. The driver's prompt stays under 100k throughout.

## Recorded afterwards (in REPORT.md and the STATUS line)
- the agent-cost line, next to B1's
- the driver's call count and its maximum prompt size
- judge spawns, and what each trigger cost
- any miss: a gate that failed, a judgment the judge had to redo, a note the driver worded itself

If a gate fails, B2 and later stay on Sonnet drivers. If all pass, the owner decides whether Haiku drivers become the default.
