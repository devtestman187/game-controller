job: M15 opt2-7 (wrap-up): README section for the new switches and page option, and an audit of the batch's limits
pub: no
stop: after it.
read: docs/briefs/m15/opt2/PROTOCOL.md · the Summary and Hand-over of every docs/briefs/m15/opt2/opt2-*-report.md that exists · streaming/README.md (the switch tables and the page options section: jbtarget, marker, lowdelay) · streaming/entrypoint.sh (switch names only) · docs/flash-framework.md
@@DEC

No behaviour change in this job: documents only (plus the line-limit audit below).
1. streaming/README.md: add a section "Custom player (WebCodecs), off by default" with: `SESSION_TAP=on` (what it changes: the session pipeline runs in streaming/tap/tap_runner.py with a tee after the encoder, encode shared, leaky tap branch), the tap server and the relay's /tap WebSocket tunnel on the existing player port (no new port, no firewall rule), the message format in two lines (pointing to docs/briefs/m15/opt2/PROTOCOL.md), the page option `?player=wc` (and `wcmode=annexb`), `--player-query "marker=1&player=wc"`, sound in this mode (as the page report says), `SESSION_AUDIO=separate` now meaning sound in its own process (per the sound report), what the bench summary shows (the Custom player table), the image's new apt packages, and the known limits (video only, TCP head-of-line, https needed for Chrome on a phone/other host, headless proof only). Match the README's existing table/paragraph style; use only facts the reports state.
2. Audit (read-only counting, report only): list any file this batch touched that now ends over 380 lines, and any function over 60 lines in the new files (a quick `awk` count is fine). Put the list in the report under Summary; fix only README.
@@REP
@@RULES
allow: docs/briefs/m15/opt2/opt2-7-readme-report.md · docs/briefs/m15/opt2/opt2-7-readme · streaming/README.md
check: format
report: docs/briefs/m15/opt2/opt2-7-readme-report.md
