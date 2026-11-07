job: <milestone> step<N> G0 — survey for <topic>; read-only
stop: after the survey. Change no file but the report; don't plan or design.
read: <design section the step builds> · docs/coding-guidelines.md

questions (what Claude needs to know before writing the contract):
1 <e.g. every type the step changes: file, public members, who constructs it>
2 <e.g. every call site of X, file:line>
3 <e.g. which tests pin the behaviour the step changes>

do: answer each question with facts from the code, each with file:line. No proposals; mark anything you inferred rather than read "unsure". Then fill the sections below.

format (the report, at most 100 lines; tables or one line per fact):
## Answers — per question, numbered
## Sizes — every file the step will likely touch, with its line count; flag any over 300
## Constraints — exported API, platform code, persisted formats, wire messages, tests that pin behaviour
## Conflicts — where the design section doesn't fit the code as it is
## Questions — what you couldn't find out

check:
report: docs/briefs/<milestone>/s<N>-g0-survey.md
