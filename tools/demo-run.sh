#!/usr/bin/env bash
# A worked example of the automation interface (M15 a2, docs/automation.md):
# starts a Bumper Round with two simulated players, lets it run a moment and
# takes a screenshot. Run it against a host started with automation on:
#
#   tools/tv-dev.sh start --automation      # then, in another shell:
#   tools/demo-run.sh
#
# A phone hosting can be reached too: pass the token the host was started
# with in THUMBPARTY_AUTOMATION_TOKEN, and --url (or
# THUMBPARTY_AUTOMATION_URL) when it isn't on this PC's loopback.
# The screenshot goes to automation-demo.png in the folder this ran from.
set -u

cd "$(dirname "$0")/.." || exit 2
auto=(dart tools/automation.dart)

"${auto[@]}" status || exit 1
"${auto[@]}" players --nickname Ann || exit 1
"${auto[@]}" players --nickname Bo || exit 1
"${auto[@]}" start --game arena --mode bumper || exit 1
sleep 3
"${auto[@]}" state || exit 1
"${auto[@]}" screenshot --out automation-demo.png || exit 1
"${auto[@]}" session || exit 1
"${auto[@]}" stop || exit 1
echo "Done: automation-demo.png, and the session summary above."
