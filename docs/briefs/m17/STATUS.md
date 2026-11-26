# M17 status

## Resume here (Nov 26, 2026)
- **Owner go:** "Build, 1A 2A" on Nov 26, using the fast track.
  - 1A = toolchain checks, then the upgrade-only build.
  - 2A = the board line runs alongside M17a in its own copy and with its own review.
  - Standing: "Remember to run questions and recommendations by fable. Stop and ask me in case there is a major change to the plan above".
- **Plans (read these first, in E:\AI\m17-scoping\):**
  - `M17a-batches.md` is the build order: 11 batches B1-B11 (52 jobs) plus the 3-batch board line. Its "Fable review — adopted" and "Home search wait" sections at the end override the table where they differ.
  - `city-rush-plan.md` covers the City Rush rules and the owner's answers. The end of the file has the build stop as a phone shop, one fixed road per district, 6 colours plus badges, and the choices screen in M17a.
  - `M17-dev-plan.md` is the original M17 job list. It has stale parts, listed in M17a-batches.md section 5; job p0b fixes them.
  - The mock-up page is https://claude.ai/artifact/Qesc8AcF6qow8qK9MuP3e1 (panel 3 is the build stop as a phone shop). The review deck is https://claude.ai/artifact/Xtq5f2xLCfe99aUZZnc1H5.
- **Worktrees:**
  - Main line: E:\AI\game-controller-m17, branch m17, from 18a95647 (the m16.6 tip).
  - Side line (to create): E:\AI\game-controller-m17side, branch m17side.
  - Board line: branch board-line.
- **Done before M17a:**
  - Xcode 27.2 is pinned (codemagic.yaml:28). Build 1718 passed and the owner's part-1 device checks passed. Flutter stays 3.47.8.
  - m16.6 holds Pause in the compact game bar and the B-042 mini board (strip/corner, 1.5 mm floor). The owner said "Go for the tag on m16.6", and thumb-release was running when this was written. Check `git tag -l m16.6` and the GitHub/Codemagic runs.
- **Next:** start B1 (m17prep) once the m16.6 release's check has finished; only one full check runs on the machine at a time.
  - B1 now also holds the home search-wait job (owner picked A): show "Looking for a screen…", fix "Search again" and resume, log time-to-first-host, keep 3 s.
- **Owner questions to send at batch start, each with a default:**
  - O1, the champion chain: before B2 ends.
  - O2/O3, choices screen states and the old-phone mapping: at B5 start.
  - O5, Vote defaults: at B7 start.
  - Q5, the kid playtest: needed before B11, so the owner was asked to line up a date.
- **Internal builds BP1 (after B6) and BP2 (after B8)** each need the owner's word.
