job: M14 s1: the new sounds (design section 11): meow, points, fanfare, celebration, new_record
pub: no
stop: after it.
read: docs/design/party-night.md section 11 · tools/audio/README.md and the a1 Arena set (tools/audio/arena_sounds.dart, render-arena-sounds.sh, pop_kit.dart, render.py) · assets (the sound files and their layout) · assets/CREDITS.md · packages/party_host/lib/src/sound.dart (SoundKey) · docs/coding-guidelines.md · docs/review-rules.md
decide: low-usage mode (owner, Nov 10, 2026): never stop for a question. Where the brief or design leaves a choice, make the safest one that fits docs/design/party-night.md, the approved mock-ups and docs/coding-guidelines.md, and list each under "Decisions" in the report with one line of why. Stop only if the job truly cannot be done; then say why under "Blocked".

Make the five sounds the way a1 made the Arena set: the same "Bubble Pop" kit, mastered like the event sounds, free to ship, each with a CREDITS.md row and a SoundKey (the jobs that use them call them by name). meow: short, friendly, clearly a cat; points: a soft pop under a pop-up, quieter than coin; fanfare: an award, about 2 s; celebration: a won round or the night's winner, about 2.5 s; new_record: about 1.5 s, brighter than celebration. Render them with the tools in tools/audio (no new installs); if a tool can't run in your sandbox, write the generator, say so under "Blocked", and Claude renders.

tests (each failing first): each new key resolves to a file that exists, within the set's length and loudness rules where tests for those exist. All existing tests pass.

in the report: each sound's length and loudness, how it was made, the CREDITS rows.

self-check: docs/review-rules.md part A, items 1–5, one line each.
rules: no lib file over 400 · no function over 60 lines · tests first, each failing for the missing behaviour · tools/review.sh: no FAIL on your lines · write only inside this job's folder · install nothing · leave no scratch file behind · touch nothing outside allow: (the job is refused otherwise)
allow: docs/briefs/m14/s1-sounds-report.md · tools/audio · assets · assets/CREDITS.md · packages/party_host/lib/src/sound.dart · packages/party_host/test
check: format analyze host
report: docs/briefs/m14/s1-sounds-report.md
