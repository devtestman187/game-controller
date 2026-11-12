# M15 h1-2 run review

## Summary

Verdict: **small fixes**. Counts: **1 must, 3 should, 4 could**.

- The report's answer (:23) calls the browser's floor 190–230 ms and the rig's share "at most ~25 ms", but its own
  p2 is 144 ms of jitter and 181 ms of total, 46 ms under that floor, and nothing derives the 25 ms.
- Two Summary sentences (:26, :27) state facts the fetched files contradict: the buffer is not 85–88 % of the
  total in p2 (80 %) or l1 (92 %), and l1's encode (15 ms) and decode (2 ms) are not the 1080p60 stages.
- The Summary is 21 non-blank lines against the brief's 15, with seven table rows and two paragraphs where the
  brief asks for five runs and one answer sentence.

## Findings

- **must** docs/briefs/m15/fix3/h1-2-run-report.md:23 (and :42) calls the buffer's floor "190–230 ms" and any rig share "at most ~25 ms" while its own p2 is 144 ms of jitter and 181 ms of total (`h1-2/p2/h1p20.json`), 46 ms under that floor, and nothing in the report derives 25 ms → restate the floor as the lowest observed run (144 ms, or "not measurable") and either derive the rig share from it (220 − 144 = 76 ms) or drop the number.
- **should** docs/briefs/m15/fix3/h1-2-run-report.md:26 "85–88 % of stream_total in every round" is contradicted by the same table: p2 is 144/181 = 80 %, l1 is 200/218 = 92 % and p1 is 193/229 = 84 % → give the measured range (80–92 %) or the ratio per run.
- **should** docs/briefs/m15/fix3/h1-2-run-report.md:27 "the other stages are stable across all runs (encode 29 … decode 4 …)" is false for l1, whose encode median is 15 and decode 2 (`h1-2/l1/h1l10.json`), as Decision 4 on :104 itself says → say the stages held at 1080p60 and that l1's encode and decode fell with the lower load.
- **should** docs/briefs/m15/fix3/h1-2-run-report.md:3 the Summary runs from :3 to :28 (21 non-blank lines, seven table rows and two paragraphs of analysis) against the brief's "at most 15 lines: the five runs in one table, and one sentence answering" → keep the five run rows with the probe pair as a footnote and one answer sentence, and move the rest to "The question, read out".
- **could** docs/briefs/m15/fix3/h1-2-run-report.md:43 "g1's own pair (162 → 146) is the same size as the noise measured here" — this job's own spread is 49 ms (p1/p2) and 32 ms (q1/q2), so 16 ms is inside the noise rather than the same size → say "inside the noise".
- **could** docs/briefs/m15/fix3/h1-2-run-report.md:14 p2's total (181 / 287) rests on n = 4 samples where the other runs have 8–21 (`h1-2/p2/h1p20.json`), and the table shows no n → add n per cell, or mark the cells whose p95 is over four samples.
- **could** docs/briefs/m15/fix3/h1-2-run-report.md:87 the proof says "the others really are not [pinned]", but b1 has no docker-inspect line (`h1-2/evidence.txt:14` records the wrong container name), so only its 0-15 Chrome affinity is shown → say that b1's cpuset line is missing and why.
- **could** docs/briefs/m15/fix3/h1-2-run-report.md:111 the report has no Self-check section, which review-rules part A and guidelines §11 ask of every job, so A4 (folder) and A5 (stop) are unstated → add the five one-line answers.

## Decisions to confirm

- **Decision 1 (probe pair instead of press in the rounds):** the press figures come from runs with no game loop (q1/q2 have no `gameFps`, delivered 54.4/56.8), so the press and round numbers are not one sample — confirm the probe pair is the press answer wanted.
- **Decision 2 (bench.sh run directly from `/work/flash-20261112-000014-3492`):** the copy's revision is never recorded and the wrapper's fresh sync was skipped; the only change to `streaming/bench.sh` since is the `--viewer-cpus`/`--viewer external` guard, which these runs don't use — confirm the numbers stand without one run through `tools/stream.sh bench`.
- **The answer and the withdrawal of g1's 16 ms:** confirm before the number is quoted anywhere, because :23's floor is contradicted by p2 (the must above).
- **The h1x 20 s diagnostic run (Observation 1):** it is billed only in Decision 6's label list, not as a decision, and its `ss` output was not fetched — confirm the four-viewer observation should stay.

## Could not check

- `docs/briefs/m15/fix3/run-findings.md` does not exist, so there were no per-run entries to weigh.
- Whether the containers were stopped and `/work/stream-bench` emptied (Decision 6): no access to the distro from this sandbox (`wsl -d tp-stream` was refused).
- Which revision `/work/flash-20261112-000014-3492` holds, and whether the fetched JSONs are byte-identical to the ones the bench wrote: neither is recorded and neither can be read from here.
- The h1x run's `ss` output behind Observation 1 was not fetched, so "the extra registrations come from the page itself" cannot be checked.
- I compared the table's jitter, total, press, delivered fps, game fps and both CPU columns against the seven JSONs and the evidence file's median lines, but I did not recompute the viewer CPU medians from the samples.

## Commit message

M15 h1-2 review: the floor claim and two Summary figures are wrong

Adds the review of the h1-2 pinned-viewer run in docs/briefs/m15/fix3. The
seven table rows match the fetched summaries, but the report's answer calls a
190-230 ms browser floor that its own p2 (144 ms) undercuts, and its two
Summary sentences about the buffer's share of the total and the stable stages
are false for p2 and l1. Docs only; no code, results or fetched file changed.

## Status row

- **h1-2 run reviewed (fix3):** verdict small fixes — 1 must, 3 should, 4 could; the run's measured cells check out against the seven summaries, the report's floor and stage claims do not; **open:** the 190–230 ms floor and the ~25 ms rig share, the 85–88 % ratio, the false "stages stable" line, and the 21-line Summary.

## Delete

- none
