job: milestone-end review part rv1 of 3 (read-only): controller_app home, launch, host and coach marks
pub: no
model: sonnet
turns: 45
expected-min: 20
stop: after it.
read: docs/review-rules.md · docs/coding-guidelines.md · docs/briefs/m16/close/REVIEW-VERDICTS.md (findings already verdicted: skip them) · docs/briefs/m16/plan789/PLAN.md:60-100 · the change: `git diff fb2f6a5e..6300f506c86c033ace7362e33616fafe97340a52 -- controller_app/lib/src/home controller_app/lib/src/host controller_app/lib/src/local_network.dart controller_app/lib/src/discovery.dart controller_app/lib/src/app_info.dart controller_app/test` (and read the touched files around the hunks)
decide: never stop for a question. You change no code and no document except your report. If something cannot be judged from what you can read, say so under "Could not check".

You do the milestone-end review of the m16 work (range fb2f6a5e..6300f506c86c033ace7362e33616fafe97340a52) for the part named above. Rules: review-rules part A (A1 every host setup; A2 kept state start/end; A3 combinations: pause menu, host away, "Get ready", dropped link, results, leaving; A4 stay in the job's folder; A5 stop rather than overstep; A6 every look: Sunny, Night, TV, with test sizes 320x640, 568x320 and an iPad window, large text) plus guidelines. The wire protocol must not change: flag any change to packages/protocol or a message shape as a must. Known and decided, do not report: pad top bar overflow 12 px at 568x320 in the TV look (owner question), 48 dp phone-host controls, TV chip label, "Round N of M" on split/phone, reconnect, Show tips row placement.
Report (docs/review-rules.md part D), at most 100 lines: ## Summary (verdict, counts must/should/later, the top three) · ## Findings (`- **must|should|later** file:line rule: failure -> fix`) · ## Combination table (A3, tested by / not tested) · ## Could not check. Every finding names a file and line you have read; a new test that passes on old code is a must.
rules: change nothing but your report - no praise - install nothing - leave no scratch file behind
allow: docs/briefs/m16/close/rv1-report.md
report: docs/briefs/m16/close/rv1-report.md
