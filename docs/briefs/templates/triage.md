job: <milestone> bug triage — <one line: what the owner saw>; read-only
stop: after the triage. Change no file but the report; fix nothing.
read: <the area of code Claude names> · docs/coding-guidelines.md

the owner's report (Claude quotes only what matters):
- did: <…> · expected: <…> · happened: <…>
- log lines: <the few lines that point somewhere, verbatim>
- build: <tag, version, device>

questions (one block per bug):
1 What causes it? file:line, and the path from the owner's action to the symptom.
2 How sure are you (sure / likely / guess), and what would prove it: a test you could write, or a question only the owner can answer?
3 The fix you'd make: files, roughly how many lines, and what it could break.
4 The failing test you'd write first, and why it fails today for the reported reason.

format (the report, at most 20 lines per bug): `## Bug N — <name>` with Cause, Confidence, Fix, Test, Risk. Mark anything inferred rather than read "unsure". No code longer than 5 lines.

check:
report: docs/briefs/<milestone>/bug-<date>-triage.md
