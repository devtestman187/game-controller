# Review: sentry1 stats-optb

## Summary

needs Claude — no must; 3 should, 5 could; every suite passes at the reviewed commit (7eed4bda).

Counts: must 0 · should 3 · could 5.

- The yes answer is lost for the rest of the evening after a host pause/resume: `LiveStats.resume` starts a new session for phones that stay paired and never resend (`live_stats.dart:279`).
- The phone host's own player ("Play on this phone", `inProcess` but not `local`) never shares, so its data is dropped from every upload even when the host said yes (`session_player.dart:102`).
- The new §8c says the uploaded session has "no names or device IDs", but `uploadableSummary` keeps `install` (the persisted controller ID) and `device` for each sharing player (`docs/protocol.md:207`).

Checks I ran: `tools/check.sh protocol` 120, `metrics` 166, `connection` 303, `host` 539 — all PASS. The report's host count (515) is not this commit's count; see the last finding.

## Findings

- **should** packages/party_host/lib/src/live_stats.dart:279 a host pause ends the session and `resume` starts a new one for still-paired phones that never re-pair, so a player who said yes counts as not sharing for the rest of the evening → keep each controller's answer in `SessionRecorder` and apply it when that player joins a later session (the report's question 1).
- **should** packages/metrics/lib/src/session_player.dart:102 only `local` players are marked as sharing, so the phone host's own player, joined over the in-process link (`inProcess: true`, `local: false`), is left out of every upload even though the host's consent is what allows the upload → treat `inProcess` players like local ones, or send `setStatsShare` for the in-process client from the host's own consent.
- **should** docs/protocol.md:207 the paragraph promises the uploaded session has "no names or device IDs", while `uploadableSummary` passes each sharing player's `install` ID and `device` block through unchanged → reword the sentence to what the upload holds, or strip those fields in `uploadableSummary`.
- **could** packages/metrics/lib/src/uploadable.dart:37 a team win filtered down to one sharing member leaves `winners: [n]` (or drops `winners` while `winner` stays), which `report_rounds.dart:218` prints as a solo win of that player → drop `winners` when fewer than two members remain and keep only `winner` (the report's question 3).
- **could** packages/metrics/lib/src/uploadable.dart:13 any player entry without a `share` key is dropped, so every session saved before this build and still in the upload queue goes up with no players at all → say so once in the doc, or keep the old player list for a summary whose players all predate the field.
- **could** packages/party_host/test/live_stats_share_test.dart:96 the job's host test was committed in the parent commit 8c621c8, which cannot compile it (`setStatsShare` and `uploadableSummary` do not exist there), so the reviewed commit is not self-contained and 8c621c8 does not build its own test suite → commit a job's test with the code it tests.
- **could** docs/briefs/m14/sentry1/stats-optb-report.md:15 the reported host count (515) is not the suite's count at this commit, which the runner measures as 539 tests, all passing → re-measure before quoting the number.
- **could** packages/connection/test/stats_share_test.dart:55 the reconnect test waits for the pairing answer on a second subscription opened after `ClientStatus.connected`, so it can miss that answer and sit until its 5 s timeout → take the first answer from the `answers` list the test already collects from before `connect`.

## Decisions to confirm

- **No capability for `stats_share`:** it conflicts with coding-guidelines §8 and the review checklist's "capability-gated", and is safe only because an older host's `MessageCodec.decode` returns null for an unknown type (`codec.dart:70`); the brief and design doc say no capability, so this is consistent, but it is a standing exception.
- **Sharing players still upload `install` and `device`:** the owner's sentence ("no names or device IDs") is not met by the payload, and the report does not list this as a decision.
- **The in-process player is not treated as local (report decision 8):** it makes "Play on this phone" players invisible in uploads; the design doc's "local players of the host itself" arguably covers it.
- **Sessions saved before this build upload with no players:** the first upload after the update drops old per-player data; safe direction, never stated as a decision.
- **`winners` may keep one member (report decision 6 / question 3):** the CSV printer prefers `winners`, so the shape decides what the report shows; the alternative is one line.
- **The Stats screen's export still holds non-sharing players (per the brief):** whoever hands that folder over sends everything, no filter applied.

## Could not check

- What the upload endpoint or the server-side report does with `install` IDs, a one-member `winners`, or a round without `player` data: neither is in this repository.
- Device behaviour (the report says none needs a device check; nothing in the diff is UI or timing, which matches).

## Commit message

sentry1 stats-optb review: three should findings, no must

- read the 7eed4bda diff against the guidelines, the review rules and the brief
- ran protocol, metrics, connection and host at the reviewed commit: all pass, host is 539 not 515
- findings: the answer is lost after a host pause, the in-process player never shares, §8c's "no device IDs" claim

## Status row

sentry1 stats-optb reviewed: no must, nothing blocks the commit; open: the pause/resume answer gap, the in-process player's sharing, §8c's wording, the `winners` shape and the report's host count.

## Delete

- none
