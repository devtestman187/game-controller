# Scan: is a shader or cartoon-look restyle planned or written down?

Read-only survey (G0), Nov 8, 2026. The owner's words: *"Isn't there new shaders applied to the existing design
to give it a more cartoony look? Check the other .md files in the repository as well."* No file changed but this
report.

## Answer

**Yes, it is planned, but only in notes — not in the PRD, and not in any milestone's contract.** One line names
the plan: [project-notes.md](../project-notes.md) line 72, under "Open items", says a **"Look-and-sound
milestone, planned between M12 and M13"** (owner still thinking, not in the PRD) whose later step is the
**"Toy Box Toon" shader, Arena first**, after "brighter colours, Canvas outlines and shadows", plus 3 extra
sounds with looping and a mute or volume setting. Its source is outside this repository: the DeepSeek
workspace's `game-controller-shaders/DESIGN.md` (and `thumb-party-audio/`); `/e/AI/game-controller` has no
`game-controller-shaders` folder, so that design (the shader itself) was not readable here. Three other docs
treat the milestone as scheduled work to prepare for — [review-rules.md](../review-rules.md) row C1 (shaders,
outlines, music, volume: how things look must be swappable without touching rules), [code-health.md](../code-health.md)
"Look-and-sound" (one palette and one string table, do at its start) and [STATUS.md](STATUS.md) ("at the
look-and-sound milestone's start, one palette and string table") — and [party-ideas.md](../party-ideas.md) line 71
places it after M12, before a party milestone and before M13's outside playtest. **Which milestone: "between M12
and M13", i.e. not M13 itself, and it has no ID — it is in no milestone table; the only `m12.x` names in the docs
are build tags.** The PRD v2 has no such milestone: its M13 is "Fun, content and the first outside playtest",
and the only look-like PRD items are M13's hint glow and the drop-ready highlight. **Nothing is implemented or
specified in code**: no `.frag`, `.glsl` or `.vert` file, no `FragmentProgram`, no `shaders:` section in any
`pubspec.yaml` and no `runtime_effect` import on any branch. The word "shader" appears outside this report only in `project-notes.md` (the plan above and line 93),
`review-rules.md` (row C1) and `dev-tools.md` ("shader notes" among the DeepSeek folders a job may be allowed to
read), plus the emulator's `swiftshader_indirect` flag (`tools/emulator.sh:142`, `project-notes.md:93`,
`STATUS.md:14`), which is unrelated.

## What was searched

Terms (case-insensitive, all of them): shader, fragment, GLSL, FragmentProgram, cartoon, cartoony, toon, cel,
outline, stylized, art style, visual style, look and feel, polish, graphics, restyle, redesign, theme, glow,
gradient, palette.

Refs (`git for-each-ref refs/heads refs/remotes`): `refs/heads/main` (37 `.md`), `refs/heads/m12` (262),
`refs/heads/demo-video` (38), `refs/remotes/origin/main` (254), `refs/remotes/origin/m12` (262),
`refs/remotes/origin/demo-video` (38); `origin/HEAD` is a symref to `origin/main`. Searched with
`git grep -i -n -E '<terms>' <ref> -- '*.md'` on each.

Main checkout `E:\AI\game-controller` (read only, uncommitted docs included): 38 `.md` files, the same set as
`demo-video` (it stays on that branch), searched with `grep -rniE` on the working tree. Its file list matches
the `demo-video` tree exactly (no extra or untracked `.md`), and its hits are `demo-video`'s hits at the same
lines, so nothing new is uncommitted there. Line counts of its `docs/project-notes.md` (102) and
`docs/demo-video-runbook.md` (937) equal the branch's; checksums differ, which is most likely CRLF in the
checkout (not checked further, since nothing there mentions a look restyle).

Note on the refs: local `refs/heads/main` is stale (tip `de2540d`, Nov 5, before `review-rules.md`,
`code-health.md`, `enhancements.md` and `docs/briefs/` existed); `origin/main` (`84443b9`, Nov 8) is one commit
past `m12`'s tip (`3816383`). The hits below say `m12` when they are on `m12` = `origin/m12`, and `origin/main`
where that branch has them too.

## Real hits

### A. The plan itself (the look-and-sound milestone)

1. **`m12` · `docs/project-notes.md:72`** (also `origin/m12`, `origin/main`; `docs/project-notes.md:40` on
   `demo-video`, `origin/demo-video`, `refs/heads/main`, and in the main checkout's working tree) —
   > - **Look-and-sound milestone, planned between M12 and M13** (owner still thinking; not in the PRD yet): brighter colours, Canvas outlines and shadows, then the "Toy Box Toon" shader (Arena first), the 3 extra sounds with looping, and a mute or volume setting. Source: the DeepSeek workspace's `game-controller-shaders/DESIGN.md` and `thumb-party-audio/`.

2. **`m12` · `docs/review-rules.md:40`** (also `origin/m12`, `origin/main`) — the only other doc that names
   shaders, as a review row:
   > | Look-and-sound milestone (shaders, outlines, music, volume) | Swapping how things look without touching rules | Colours, sizes and styles as literals inside painters instead of a theme or settings; sound names hard-coded in rules |

3. **`m12` · `docs/code-health.md:75`** (also `origin/m12`, `origin/main`) — work to do at its start:
   > | **Look-and-sound** | Colours and card text as literals: the mirror's orange copies `playerColors[1]`; the cards' opacities; "P2 is away" vs "Player 2 is away" already differ. One palette and one string table. (R3 + R2 later) | Low | A re-skin changes one place | **do** at its start |

4. **`m12` · `docs/briefs/m12/STATUS.md:31`** (also `origin/m12`, `origin/main`) — the same item from the M12
   side:
   > - **Open in code-health.md:** before M13, move the round's moments to the shared round flow and one countdown rule; the host's storage writes behind one boundary; at the look-and-sound milestone's start, one palette and string table. Smoke's `disconnect` step (no `disconnected` line on this PC) to triage when `host_connection.dart` is next touched.

5. **All refs, and the main checkout · `docs/party-ideas.md:71`** — where it sits in the order of work:
   > M12 phone hosting, then the look-and-sound milestone (the cat's meow and the award fanfare fit there), then a party milestone, then M13's outside playtest, which would judge the party features. A smaller first step could be points, the party-night scoreboard and the cat.

6. **All refs, and the main checkout · `docs/demo-video.md:357`** — the demo footage waits for it:
   > 5. **When to capture:** after the m11.3 sounds at least. The look-and-sound milestone will change the visuals, but with a scripted pipeline a recapture is one command, so capturing early is cheap.

7. **All refs, and the main checkout · `tools/audio/README.md:5`** — the unused sounds wait for it:
   > The extra cues (lobby, countdown, player_joined) aren't used yet; they wait for the look-and-sound milestone.

8. **`m12` · `docs/project-notes.md:55`** (also `origin/m12`, `origin/main`) — a spacing scale belongs with it:
   > - **UI spacing:** paddings and sizes are bare numbers (most of the script's `number` notes). A small spacing scale for the host and phone apps belongs with the look-and-sound milestone, which restyles the same screens.

9. **`m12` · `docs/dev-tools.md:355`** (`docs/dev-tools.md:234` on `main`, `demo-video`, `origin/demo-video`, and
   the main checkout) — proof that shader notes exist outside the repo:
   > - **Reading outside folders, per job:** `--read <folder>` (repeatable) lets that one job read a folder outside the repository, such as the DeepSeek workspace's sounds or shader notes, instead of pasting excerpts into the brief. …

### B. M12 work that defers a look decision to that milestone (`m12` = `origin/m12`; not on `main`)

10. `docs/briefs/m12/build4-review-r3-report.md:29` — a palette copy to fix before a re-skin:
    > **later** · `packages/puzzle_game/lib/src/view.dart:94` · C row 1 (look and sound) · `_them = 0xFFFFA040` copies `playerColors[1]` (protocol/messages.dart:319) instead of referring to it: a palette change in the look milestone leaves the mirror's frame, dot and "Them n/N" on the old orange while Player 2's badge moves, and nothing ties the two. Costs one reference now, a hunt later.
11. `docs/briefs/m12/fix-f3.md:3` — a brief's reading list names "the look-and-sound row":
    > read: docs/code-health.md N3, N4 and the look-and-sound row · docs/briefs/m12/build4-review-r3-report.md findings 2, 3 and the later · …
12. `docs/briefs/m12/fix-f3-report.md:229` — a palette test that is a guard for it:
    >   look-and-sound milestone, not a bug reproduction.
13. `docs/briefs/m12/s5b-g1-plan.md:572` — a visual question left to "the look-and-sound pass":
    >    the look-and-sound pass decide; hiding the party_host `AppBar`s on the phone would be a party_host change (a
14. `docs/briefs/m12/bug-1107-fix-report.md:107` — a drawing fix left for it:
    >   top at about y −9.4, outside the world the viewer fits to the box. Worth a look in the look-and-sound

### C. Older or partial statements about how it looks (related, not the cartoon restyle)

15. **All refs, and the main checkout · `docs/PRD.md:107`** — v1's line on the Arena's look, still the only PRD
    text about art:
    > | Look | Plain coloured shapes first, replaced later by CC0 art as the assets plan says |
16. **`m12` · `docs/PRD-v2.md:247`** (T15, M13) — a visual effect planned for M13, not a restyle:
    > | Hint glow | When a player has held the same piece for a set time (default 10 seconds), its matching outline glows gently until it is placed or dropped |
    (with `docs/PRD-v2.md:242`, the drop-ready highlight, and `:139`, T15's M13 row.)

## False hits skipped

- `polish`: M6's name ("Polish, settings and latency tooling", `docs/PRD.md:164,351`, `docs/checklists/m6.md:1`)
  — a finished milestone about settings and tooling, not looks; `README.md:39` lists it the same way.
- `theme`: editor and terminal themes in `docs/demo-video-runbook.md:560,566`, `docs/demo-video.md:135,319`; the
  CSS/`styles.xml` names; `theme` meaning Flutter `ThemeData` in `docs/review-rules.md:40` (that one is quoted
  above for its look-and-sound content, not for the word).
- `outline`: the puzzle's shape outline throughout `docs/PRD-v2.md`, `docs/architecture.md`,
  `docs/checklists/m10.md`; `OutlinedButton` in `docs/briefs/m12/s5b-g1-plan.md:246`; "script outline", "screen
  outline" in `docs/demo-video-runbook.md` and `docs/decisions.md:86`; the Phone's faint button outline in
  `docs/protocol.md:172`, `docs/checklists/m10.md:25,44`.
- `graphics`: the demo video's motion graphics and the store graphics (`docs/store-listing.md`,
  `docs/release.md:33`, `docs/demo-video-runbook.md` §5), Play/"TV graphics", "weak graphics" for Roku
  (`docs/PRD-v2.md:349`), the Windows PC's GPU (`docs/demo-video-runbook.md:101`, `docs/project-notes.md:93`).
- `palette`: the player colours (`docs/decisions.md:61`, `docs/briefs/m12/fix-f3-report.md`, `view.dart`'s
  `playerColors`), the audio folder name `palette-b-bubble-pop`, the heatmap's colour palette in the runbook.
- `redesign`/`redesigned`: the m9.2 rating-prompt redesign only (`docs/PRD-v2.md:550`, `docs/checklists/m9.md`).
- `glow`: only the puzzle's hint glow (above).
- `gradient`: captions and the demo edit only (`docs/demo-video-runbook.md:655`, `docs/demo-video.md:317`).
- `cel` (as a whole word), `stylized`, `art style`, `visual style`, `look and feel`, `FragmentProgram`, `GLSL`:
  no hits on any of the three branches. `toon` hits only the `project-notes.md` line above ("Toy Box Toon").
- `cartoon`: one code comment, `tools/audio/render.py:131` (`"""Cartoon water-drop / bloop: rising sine chirp."""`)
  — a sound, not the look.

## Code check (all branches, briefly)

- No `.frag`, `.glsl`, `.vert` or `.shader` file on any of the three branches (`git grep -l '' <ref> -- <paths>`),
  and `git grep` for `runtime_effect`, `flutter/runtime` and `uniform vec` finds nothing, so there is no shader
  source on any branch.
- No `FragmentProgram` and no `flutter_shaders`/`fragment_shader` dependency: `git grep` over every `pubspec.yaml`
  on the three branches finds neither, and no `shaders:` section in any of them.
- No test or widget mentions a shader either; the only `shader` strings on any branch are the docs in the answer
  above and the emulator's `swiftshader_indirect` flag.

## Not checked / unsure

1. The shader design itself (`game-controller-shaders/DESIGN.md`) is outside the folders I may read; the plan's
   only trace in the repository is the one `project-notes.md` line. Whether it describes a real fragment shader
   or only a look is not knowable from here.
2. The main checkout's file contents are equal to `demo-video` by line count, not by checksum (checksums differ,
   probably CRLF); I did not find any uncommitted look document there, but I could not run `git status` in that
   checkout (it is outside the job's sandbox rules).
3. Local `refs/heads/main` (`de2540d`, Nov 5) is 129 commits behind `origin/main`; the report says `m12`/
   `origin/*` where a line is only there, so a reader on the stale local `main` will see fewer hits.

## Self-check (review-rules.md part A)

1. **Every host setup.** Not affected: no code and no screen changed; the scan only produced this report.
2. **When kept state starts and ends.** Not affected: nothing is held, timed or cached by this job.
3. **How a new state combines with the others.** Not affected: no state added; the scan adds no pause, wait or
   hide.
4. **Stay in the job's folder.** Wrote one file, `docs/briefs/m12/scan-shader-look-report.md`, inside
   `docs/briefs/m12/`; `git status` shows no other change from this job (the modified `tv_test_app/windows/...`
   files were there before it).
5. **Stop rather than overstep.** Nothing in the brief asked for a file outside `allow:`. I could not run git in
   the main checkout (a command that changes directory is refused by the sandbox there); I read its files
   directly instead, which the brief allows, and said above what that cost (no `git status` there).

## Commit message

```
docs(scan): a cartoon restyle is planned, but only in project notes

One line in project-notes.md (line 72) says a "look-and-sound
milestone, planned between M12 and M13" ends with a "Toy Box Toon"
shader, Arena first, after brighter colours and Canvas outlines. It is
not in the PRD, has no number, and its design lives outside the repo
(the DeepSeek workspace's game-controller-shaders/DESIGN.md).

Three other docs treat it as scheduled: the review rules' C1 row,
code-health's palette note and M12's STATUS. No shader code exists on
any branch: no .frag file, FragmentProgram or shaders: in a pubspec.
```

## Status row

| Look scan (Nov 8) | **Done (read-only)**: a shader/cartoon restyle is written down only as an unnumbered "look-and-sound milestone, planned between M12 and M13" (`project-notes.md:72`, `review-rules.md:40`, `code-health.md:75`, `STATUS.md:31`); it is not in the PRD and no shader code exists on any branch. **Open:** whether it becomes a numbered PRD v2 milestone (and when), and what its `DESIGN.md` outside the repo contains. |

## Delete

- none
