job: m12 step9 s9b G4 — the privacy page for M12; the host log's tag
stop: after G4.
read: docs/briefs/m12/s9-report.md ("Item 4": your nine replacements) · site/privacy.html · docs/coding-guidelines.md (writing rules) · packages/party_host/lib/src/host_service.dart (`log.sink('tv')`) and every test or tool that reads that tag (grep `[tv]` and `'tv'` in packages, controller_app, tv_test_app, tools)

do:
1 site/privacy.html: apply your nine replacements exactly as drafted (Claude approved all nine; replacement 6's last clause stands, since s8c adds the Diagnostics session line). Move the "Effective" line to November 7, 2026 and version 0.12.0. Keep the markup and style; nothing else changes.
2 The host's log tag: `LiveHostService` logs under `host` instead of `tv` (the phone host's Diagnostics shows its log). Update every test and tool that matches the old tag (tools/smoke.sh and tools/tv-dev.sh read the TV's log: check their patterns). If a tool's pattern can't change safely, keep `tv` and say why.
tests: existing ones that match the tag, updated (old → new).
in the report: the diff of privacy.html as a list of the changed sentences (old → new, one line each), the files changed for item 2, test counts before and after.
rules: writing rules; no other page changes · tools/review.sh: no FAIL on your lines.
allow: docs/briefs/m12/s9b-report.md · site/privacy.html · packages/party_host · tv_test_app/lib · tv_test_app/test · controller_app/test · tools/smoke.sh · tools/tv-dev.sh
check: format analyze host phone tv
report: docs/briefs/m12/s9b-report.md
