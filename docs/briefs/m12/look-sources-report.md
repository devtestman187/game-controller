# Look sources: what survives of the "Toy Box Toon" design

Read-only survey (G0), Nov 8, 2026. No file changed but this report.

**Answer in one paragraph.** The design itself is gone from this PC: no `game-controller-shaders` folder exists in
either readable outside folder, the DeepSeek workspace holds only the audio package and the demo-video handoff, and
no colour, width, band, light, texture, shadow, motion or per-screen shader detail is written down anywhere I could
read. What survives is the plan's **order of five steps** (`docs/project-notes.md:72`, recorded by Claude from the
owner, "owner still thinking"), the **constraints** a restyle must meet (one palette and one string table, look
swappable without touching rules), the **owner's own words** of Nov 8, and **the whole audio package**, which is
intact and precise.

## (a) The Toy Box Toon design, as far as it can be rebuilt

### The plan (the only design text that exists in the repository)

Source: `docs/project-notes.md:72`, under "Open items". *Recorded by Claude in the owner's stead — the owner's plan,
not an AI's proposal; the parenthesis "(owner still thinking; not in the PRD yet)" is Claude's.*

> - **Look-and-sound milestone, planned between M12 and M13** (owner still thinking; not in the PRD yet): brighter
>   colours, Canvas outlines and shadows, then the "Toy Box Toon" shader (Arena first), the 3 extra sounds with
>   looping, and a mute or volume setting. Source: the DeepSeek workspace's `game-controller-shaders/DESIGN.md` and
>   `thumb-party-audio/`.

That yields, in order:

| # | Step | Concrete detail in the text | Owner's or AI's |
| --- | --- | --- | --- |
| 1 | Brighter colours | "brighter colours" — no values, no palette, no screen list | Owner's plan (via Claude's note) |
| 2 | Canvas outlines and shadows | "Canvas outlines and shadows" — implies drawn in a `CustomPainter`, no width, colour, offset or blur | Owner's plan (via Claude's note) |
| 3 | "Toy Box Toon" shader | **"Arena first"** — the Arena (`packages/test_game/lib/src/arena_painter.dart`, `arena_view.dart`) is the first shader target; "toon" suggests a cel/toon fragment shader, but no term beyond the name is written | Owner's plan (via Claude's note) |
| 4 | The 3 extra sounds, looping | `lobby`, `countdown`, `player_joined`; see (c) for every fact | Owner's plan + full audio docs |
| 5 | Mute or volume setting | "a mute or volume setting" — no control type, step count or where it lives | Owner's plan (via Claude's note) |

**Nothing else exists.** No outline width, shading-band count, light direction, rim light, texture, halftone,
shadow colour/offset, wobble/squash, frame-rate or per-screen rule is written in any file I could read. The words
"toon", "cel shad", "cartoon" and "look-and-sound" were searched case-insensitively across the repository's `docs/`,
both outside folders and the demo workspace's `.md`/`.txt`/`.html`; the only hits are the ones quoted in this report.

### Constraints the design must meet (written down, so they bind the design)

- `docs/code-health.md:75` — **do first, at the milestone's start** (the project's audit row, not the owner's words):
  > | **Look-and-sound** | Colours and card text as literals: the mirror's orange copies `playerColors[1]`; the cards' opacities; "P2 is away" vs "Player 2 is away" already differ. One palette and one string table. (R3 + R2 later) | Low | A re-skin changes one place | **do** at its start |
- `docs/review-rules.md:40` — the review test a re-skin is held to (the project's rule, not the owner's words):
  > | Look-and-sound milestone (shaders, outlines, music, volume) | Swapping how things look without touching rules | Colours, sizes and styles as literals inside painters instead of a theme or settings; sound names hard-coded in rules |
- `docs/briefs/m12/STATUS.md:31` — the same item from M12's side: "at the look-and-sound milestone's start, one
  palette and string table".
- `docs/project-notes.md:55` — "A small spacing scale for the host and phone apps belongs with the look-and-sound
  milestone, which restyles the same screens."
- `docs/briefs/m12/s5b-g1-plan.md:572` — an open UI question handed to it: "Two bars on a 393-high screen … keep
  both for G3/G4 and let the look-and-sound pass decide; hiding the party_host `AppBar`s on the phone would be a
  party_host change".
- `docs/briefs/m12/bug-1107-fix-report.md:107` — a drawing bug handed to it: "A carried full-size piece is clipped at
  the world's top … Worth a look in the look-and-sound milestone (a carried piece drawn at `trayScale` until it
  leaves the tray, or the world given a top band), not now."
- `docs/demo-video.md:357` — the demo footage may be recaptured afterwards: "The look-and-sound milestone will change
  the visuals, but with a scripted pipeline a recapture is one command, so capturing early is cheap."
- `docs/party-ideas.md:71` — where it sits: "M12 phone hosting, then the look-and-sound milestone (the cat's meow and
  the award fanfare fit there), then a party milestone, then M13's outside playtest".

### Older look statements that a restyle inherits (PRD, so the owner's spec)

- `docs/PRD.md:107` (v1, the only PRD text about art): "| Look | Plain coloured shapes first, replaced later by CC0 art
  as the assets plan says |".
- `docs/PRD-v2.md:247` (T15, M13): "When a player has held the same piece for a set time (default 10 seconds), its
  matching outline glows gently until it is placed or dropped" — the hint glow; `:242` is the drop-ready highlight
  ("the outline brightens and the phone gives a light tick"), `:245` the last 15 seconds ("the clock turns red").
- `docs/PRD-v2.md:235`: "Easy outlines are coloured to match their pieces. Medium and Hard outlines are grey, so only
  the shape helps".
- `docs/PRD-v2.md:302`: "right and wrong also show a ✓ or ✗, so colour-blind players can play" — a restyle must keep
  shape and symbol readable, not colour alone.
- `docs/decisions.md:61`: the shared colour palette lives in the protocol package (`playerColors`), one per player.
- `docs/decisions.md:86` (owner decision): "**Artwork drawn in code** (`tools/branding/make-artwork.ps1`) … User chose
  generated artwork. Every size … comes from one script, so it can be redrawn at any time." — the icon is the one
  shaded, glossy thing the project owns; see (d).

Current background, for reference: `0xFF14181F` (`puzzle_game/lib/src/view.dart:99`, `arena_painter.dart:22`).

### AI suggestions about the look (not owner's)

From `thumb-party-audio/PROPOSAL.md` (written by an AI in the DeepSeek workspace, about how the *sound* sits with the
art — the author is not named in it):
- `:48` — "the game is family, ages 6+, flat bright shapes on `#14181F`, and the audio is laser-and-explosion
  language."
- `:89` — "if the branding is more 'cartoon sugar rush' than 'wooden toy', B beats it."
- `:143` — A. Toy Box "also sits well against flat vector shapes on a near-black background — acoustic warmth reads as
  human without competing with the art."
- `:181` — "the PRD already plans a music toggle for M13" (a claim about the PRD, not a look fact).

## (b) The owner's wishes about the look, quoted

1. **Owner's words, Nov 8, 2026** (quoted in `docs/briefs/m12/scan-shader-look.md:5`, which produced the earlier scan):
   > "Isn't there new shaders applied to the existing design to give it a more cartoony look? Check the other .md
   > files in the repository as well."
2. **Owner's plan, recorded in `docs/project-notes.md:72`** (the five steps in (a)), marked "owner still thinking; not
   in the PRD yet".
3. **Owner's decision, `docs/decisions.md:86`**: "User chose generated artwork" for all branding and store graphics —
   so a look can be redrawn by script rather than commissioned.
4. **Owner's wishes it must respect** (PRD, so the owner's): ages 6 and up (`docs/decisions.md`, 2026-10-30 — "I want
   younger children to be able to play"); colour-blind safe (PRD-v2:302); plain coloured shapes until CC0 art
   (PRD.md:107).

No owner quote about specific colours, an art style by name, a reference game, or a mock-up of a restyled screen
exists anywhere I could read. The only owner-chosen mock-ups in the docs are M12's layout sketches
(`docs/design/m12-*.png/.svg`), which are UI layout, not style.

## (c) The audio facts

Package: `C:\Users\mrman\Documents\deepseek-harness\default-workspace\thumb-party-audio\` — `README.md`,
`INSTALL.md`, `PROPOSAL.md`, `ARCHIVE.md`, `render.py`, `audition.html`; deliverables in
`final/palette-b-bubble-pop/` (13 Ogg) and WAV masters in `final/palette-b-bubble-pop-wav/`.

### The three extras (all documented in `README.md` §"The three extras" and `INSTALL.md` §5)

| Cue | Length | What it is | Intended use (INSTALL.md §5 "Where to fire them") | Looping |
| --- | --- | --- | --- | --- |
| `lobby.ogg` | 19.20 s (846,720 samples at 44.1 kHz: 19.2 × 44,100) | "19.2 s lobby loop: 100 BPM, C–Am–F–G twice, plucks + bells + shaker" | Start on the TV home screen, stop when a game opens; "the one cue that needs a volume/mute control" | **Yes** — rendered with 2 s spare tail folded back over the start, "no fade at either edge"; seam step 0.008 vs 0.002 median sample step, "i.e. no click" |
| `countdown.ogg` | 4.42 s | "three rising beeps on the second, then a C major 'go'" | Start when a countdown begins; "the beeps land on 0 s, 1 s, 2 s and the 'go' chord on 3 s" | No |
| `player_joined.ogg` | 1.02 s | "bright C6–E6–G6 bell rise", "deliberately higher and longer than `help` (which rises G5→C6 and repeats every 3 s), so the two do not get confused" | On the host's player-paired/connected event, "so it fires once per phone, not once per frame" | No |

File sizes in `final/palette-b-bubble-pop/`: `lobby.ogg` 175,759 B (172 KB), `countdown.ogg` 31,903 B (31 KB),
`player_joined.ogg` 13,979 B (14 KB). Levels: extras at −18 dBFS RMS (countdown, player joined) and −20 (lobby,
"since music should not compete with effects"); "Every file peaks below −3 dBFS".

### What the code needs (INSTALL.md §5, still true today)

- `SoundKey` has no values for them; add `lobby`, `countdown`, `playerJoined('player_joined')` in
  `assets/lib/asset_manifest.dart`. `providers.dart` loads every `SoundKey` at startup, so no other wiring is needed
  once the values exist.
- Looping: `SoLoudSoundPlayer.play()` "stops and restarts the previous voice of the same key; it does not loop"; the
  proposal is `playLoop(name)` / `stopLoop()` using `flutter_soloud`'s `setLooping`, which "loops the whole file, which
  is what the sample-exact 19.2 s render assumes".
- `countdown` needs a small new phase: "Arena has a 2.0 s round break (`roundBreakS`) but no countdown state yet".
- Credits rows for the three files are written out in INSTALL.md §5 (project-generated, CC0 1.0, `render.py`).

### State in the repository today

- `assets/audio/` holds the **ten** Bubble Pop cues only (`error`, `help`, `hit`, `pickup`, `rumble`, `snap`,
  `success`, `tick`, `time_up`, `wrong`) — no `lobby`, `countdown` or `player_joined`.
- `tools/audio/README.md:5`: "The extra cues (lobby, countdown, player_joined) aren't used yet; they wait for the
  look-and-sound milestone."
- The demo reel used all three without shipping them (`E:\AI\thumbparty-demo\edit\sound_map.md`: "Not shipped by the
  game yet (owner's decision …)"), with the lobby bed at "−20 dB under gameplay, −14 dB under the cards" — a
  ready-made mixing reference.

### Name coincidence worth knowing

The runner-up **sound** palette is called "A. Toy Box" — "warm mallets … The sound of a nice wooden toy"
(`PROPOSAL.md:75-89`, kept in `archive/palette-a-toy-box/`). It is not the shader; the shared name tells Claude where
the phrase "Toy Box" likely came from. The chosen sound palette is B. Bubble Pop ("Saturday-morning cartoon").

## (d) `E:\AI\thumbparty-demo\graphics`

| File | What it is |
| --- | --- |
| `title.png` (52,960 B) | The reel's title card: the app icon on the dark reel background, "Thumb Party", "Your phone is the controller.", the disclosure line "Recorded from the real apps. Every player is a script." |
| `title_fade.mp4` (79,744 B) | The same card as a video (the fade-in used in the edit) |
| `end.png` (75,652 B) | The end card: icon, "Thumb Party", the Pages and GitHub addresses, "Google Play · TestFlight · Windows", "Built by Manveer Wasson.", "Music and join/countdown sounds: upcoming Thumb Party audio" |
| `end_fade.mp4` (75,717 B) | The end card as a video (the fade-out) |

**Nothing here shows a planned in-game look.** All four are the demo video's own title/end cards, from the reel's
Phase 5 graphics (`docs/demo-video-runbook.md:654,663`: `title.py`, `cards.py`), in the reel's style ("background
`#12161C`; text `#FFFFFF` and `#AAB2BD`; player colours from `packages/protocol`; Segoe UI"). The icon in them is the
shipped app icon (`assets/branding/play-icon-app-512.png`): flat dots with a glossy highlight ellipse each on navy —
the only shaded artwork the project owns, and branding rather than a game look. No Arena or Shape Race frame, no
mock-up of a restyled screen, is in this folder.

## (e) What is missing

1. **`game-controller-shaders/DESIGN.md` itself** — not on this PC in either readable folder or the repository; per the
   brief it lives on the other PC under `C:\Users\singh\...`. Everything below is unknowable without it: which shader
   technique (fragment program, `runtime_effect`, image filter), band count and thresholds, outline width in world
   units or pixels, light direction and colour, shadow style, palette values, textures, motion, and which Arena
   elements (dot, goal, hazards, walls, numbers) it covers.
2. **The sound of "Toy Box Toon"** — whether the look was meant to match sound palette A (Toy Box, warm mallets) or B
   (Bubble Pop), which already shipped. Only A shares the name.
3. **What "brighter colours" means against `#14181F`** — a lighter background, brighter player colours, or both; no
   file says.
4. **Where the mute/volume control lives** (TV settings, phone host sheet, both) and its shape; `PROPOSAL.md:178-181`
   argues for it but is a suggestion.
5. **Whether it becomes a numbered PRD v2 milestone**, and whether its name is "Toy Box Toon" or only the shader's.
6. **Mock-ups or reference games** — none anywhere. The nearest thing to a style reference is the AI phrase "cartoon
   sugar rush" vs "wooden toy" (PROPOSAL.md:89), which is about sound.
7. **History check not repeated:** this job's environment refused `git` commands, so I did not re-run the branch-wide
   search; the earlier scan (`docs/briefs/m12/scan-shader-look-report.md` §"Code check") already found no `.frag`,
   `FragmentProgram`, `shaders:` section or shader dependency on any of the three branches, and no `.frag`/`.glsl`/
   `DESIGN.md` file exists in the working tree now (checked with `find`).

What was searched: every `.md`/`.dart`/`.yaml`/`.txt` in the repository for `toy box toon`, `game-controller-shaders`,
`cel shad`, `look-and-sound`, `cartoon`, `toon`, `cartoony`, `brighter`; both outside folders for the same terms plus
`shader`, `palette`, `colour`, `outline` (the demo folder's `.md`/`.txt`/`.json`/`.ps1`, its `logs/` included;
`venv/` is a Python install and was searched only as a side effect of the recursive grep); `handoff_history.md`
(27 KB, demo-video work only — no look content); the inbox (`README.md`, `charter.md`,
`status/bridge.json` = `{"state":"stopped"}`, empty `to-claude`/`to-deepseek`/`archive`/`running`).

## Self-check (review-rules.md part A)

1. **Every host setup.** Not affected: no code, screen or host path changed; one report file written.
2. **When kept state starts and ends.** Not affected: nothing is held, timed or cached.
3. **How a new state combines with the others.** Not affected: no state added.
4. **Your folder only.** Wrote only `docs/briefs/m12/look-sources-report.md`; everything else was read.
5. **Stop rather than overstep.** Read-only job, stopped after the report. I did not try to fetch the missing
   `DESIGN.md` from anywhere but the two allowed folders.

## Commit message

```
docs(look): gather what survives of the Toy Box Toon design

The shader design (game-controller-shaders/DESIGN.md) is not on this
PC: neither outside folder nor the repo holds a colour, width, band,
light or screen list. Only the plan survives in project-notes.md:72,
with the constraints in code-health.md and review-rules.md.

The audio package is intact: lobby 19.20 s sample-exact loop, countdown
4.42 s and player_joined 1.02 s, with their firing points and the
looping and SoundKey work they need.
```

## Status row

| Look sources (Nov 8) | **Done (read-only)**: searched both outside folders, the inbox, the handoff and the repo docs; the Toy Box Toon design itself is missing from this PC and only its five-step plan, its constraints and the owner's Nov 8 words survive; the three extra sounds are fully documented (lobby 19.20 s loop, countdown 4.42 s, player_joined 1.02 s, all unshipped, looping needs new code); `thumbparty-demo/graphics` holds only the reel's title/end cards. **Open:** the `DESIGN.md` from the other PC, the palette values, and whether the milestone gets a PRD number. |

## Delete

- none
