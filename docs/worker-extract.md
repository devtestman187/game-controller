# Worker extract: the rules every job follows

Short copy of docs/coding-guidelines.md (G) and docs/review-rules.md (R); the full files stay the source of truth.

## Size and shape (G3)

- One responsibility per file, about 300 lines (hard limit 400, tests 500); split a file that would pass it in the same job.
- No lib file you touch ends over 380 lines.
- Functions about 40 lines; a build under 60: extract named widgets, not widget-returning helpers.
- At most 5 parameters; beyond that, a value object. Export only what callers need; one public type per file.

## Style (G2, G4, G7, G10)

- No magic numbers: each tunable is a named constant or settings field with its unit in the name and its reason in the doc comment; only 0, 1, -1, 2 and indices are bare.
- No hard-coded ids, names, addresses, ports or paths; no special case for one caller; no test hooks in lib/.
- No dynamic, no unvalidated as-cast, no ! unless the line before proves it, no late to dodge initialisation order.
- No empty catch and no catch (_): catch at a documented boundary, log through LogSink, return a state the caller handles.
- No TODO, commented-out code, print, unused parameter or dead branch. No new package dependency the task doesn't name.
- Never weaken a check: no skipped, deleted or loosened test, no ignore: for the analyzer, no edited generated file.
- Units in names (Ms, S, Hz, Mm); booleans ask a question; names come from the PRD and the protocol spec.
- Every public type and member has a dartdoc; comments say why, not what.
- 120 columns, dart format; follow the surrounding style and copy an example when the task names one.

## Tests (G9)

- New tests in a NEW file, and they fail on the code as it was; while working run only your own test files.
- Each test name states the rule it checks; no real time (fake clocks, injected nowMs).
- Widget tests run at more than one size when layout matters.
- Await every async side effect before teardown; a pure refactor or docs job says tests-first: exempt <reason>.
- Report every value you computed for an expectation.

## Self-check for the report (R part A): one line each with the test that shows it

1. Every host setup: a TV or PC host, a phone on "Play on this phone", a phone on "Show on this device", a joined phone, a peer one build older.
2. When kept state starts and ends, and what happens when nothing is going on.
3. How a new state combines with the pause menu, the host away, a player away, "Get ready", a dropped link, the results and leaving.
4. Stay in the job's folder and inside allow:.
5. Stop rather than overstep: name the file and say why.
6. Every look: the menu look and the TV look; no fixed pixel height for a look-sized widget.

## Before you write

- Read docs/project-notes.md for the parts that apply to the change.
- Stop at the gate the task names; if a design decision is unclear, stop and say so.
- Write the report once, at the end, with the closing sections the task names.
