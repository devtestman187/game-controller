# M16 UX review — worker spec (shared reference)

Read this file first. It is the single source of truth for the flow taxonomy, the
findings record shape, the measurement rules, and the adb capture protocol. Your own
brief names your scope (which screens, which sizes, which game); this file says *how*.

This is a research and design task. You change no application code, no test, no
protocol, no map, no dependency. You produce documents and evidence only.

## 1. Flow taxonomy (the 13 stages)

1. Launch / first run
2. Host setup
3. Party join
4. Player creation / colour & accessory
5. Lobby & waiting
6. Game selection
7. Round intro / countdown
8. In-round controls
9. Round end
10. Results / scoreboard
11. Next round / Play again
12. End of night
13. Re-entry after a drop

Every findings record and every research digest maps its content to these stages by
number. If a screen or a game covers no stage, say so explicitly.

## 2. Findings record shape (exactly this)

For every screen, return ONE record in this order:

```
screen / form factor / theme / viewport px
elements in reading order, with pixel size and position
primary action: label, size in dp, contrast ratio
secondary actions
text that wraps or truncates at this size, and how
states covered, and states missing (empty, error, waiting, dropped link)
cross-screen inconsistencies versus the other screens
```

## 3. Measurement rules (no adjectives — a number or a named token)

- **Positions and sizes**: give `x,y` top-left and `w x h`, in physical px, and the
  dp value next to it. State the density you divided by (`dp = px / (density/160)`).
- **Viewport**: report the physical px and the logical dp, and the `wm size` /
  `wm density` output you observed. State orientation (landscape/portrait).
- **Contrast ratio**: sample the actual text foreground and its background fill from
  the screenshot, compute WCAG 2.x contrast, and name the token pair from
  `docs/design/look-and-sound.md` section 3 they correspond to. If the observed pair
  is not in the token table, write `unmeasured`.
- **Theme**: infer Sunny vs Night from the background colour and cross-check
  look-and-sound.md section 3 (`background`). Report the sampled value that decides it.
- **No adjectives anywhere.** "cramped", "clean", "nice" are forbidden. State a
  measured number (a size, a ratio, a gap) instead. If you cannot measure it, write
  `unmeasured`.
- **Do not invent.** If a state or element is absent, say "absent", do not describe a
  hypothetical.

## 4. adb capture protocol (read before touching a device)

- adb: `C:\Users\mrman\AppData\Local\Android\Sdk\platform-tools\adb.exe`
- Run it with the `&` call operator in pwsh, and `-s <serial>` on every call.
- **Never** use PowerShell `>` redirection on `adb exec-out screencap -p` (it corrupts
  PNG bytes). Capture in two steps:
  - `& adb -s <serial> shell screencap -p /sdcard/<name>.png`
  - `& adb -s <serial> pull /sdcard/<name>.png "<local path>"`
- Read the pulled PNG with the `read_image` tool.
- Write screenshots only under `C:\Users\mrman\AppData\Local\Temp\ux-pilot\`. Never
  into the repo, except that your findings text file goes under
  `E:\AI\game-controller-m16\docs\briefs\m16\ux-review\findings\`.

### Devices

| Device | adb serial | App | Launch | Native display |
|---|---|---|---|---|
| Pixel Tablet (controller) | `adb-3817105H80BRQP-cAkbcX._adb-tls-connect._tcp` | `com.thumbparty.app` | `com.thumbparty.app/.MainActivity` | 1600x2560 @ 320 (override density 354); landscape viewport 2560x1600 |
| Sony BRAVIA TV (host) | `192.168.1.100:5555` | `com.thumbparty.tv` | `com.thumbparty.tv/.MainActivity` | 3840x2160 panel, override 1920x1080 @ 320 (960x540 dp) |

### Size-matrix override (tablet only, when your brief says so)

To simulate a target logical size, set the override BEFORE launching the app, then
force-stop and relaunch so the app lays out fresh:

```
& adb -s <tablet> shell wm size <W>x<H>      # target LOGICAL px, landscape WxH
& adb -s <tablet> shell wm density 160        # 1 dp = 1 px, so px == dp
& adb -s <tablet> shell am force-stop com.thumbparty.app
& adb -s <tablet> shell am start -n com.thumbparty.app/.MainActivity
```

Restore afterwards, every time:

```
& adb -s <tablet> shell wm size reset
& adb -s <tablet> shell wm density reset
```

## 5. Theme

The Look setting is Auto (Sunny 07:00–19:00, else Night). Current time is afternoon,
so a fresh app shows **Sunny**. Capture in Sunny; record `theme: Sunny`. The Night
palette differs in colour only (look-and-sound.md D1: every size, shape and outline is
the same), so layout facts carry across; Night contrast is already asserted by the
`toy_look` test. Do not flip Look unless your brief tells you to.

## 6. Output

- Findings text: one file per worker under
  `E:\AI\game-controller-m16\docs\briefs\m16\ux-review\findings\<name>.md`, named as
  your brief says.
- Research: one digest per game under
  `E:\AI\game-controller-m16\docs\briefs\m16\ux-review\research\<game>.md`.
- End your reply with: the file you wrote, the screens/sizes you actually captured,
  and any `unmeasured` items.

## 7. Hard rules

- Do NOT run `git add` / `commit` / `push` / `stash`, or `tools/check.sh`.
- Do NOT modify any file under `lib/`, `test/`, `packages/*/lib`, `packages/*/test`.
- Do NOT change device settings except: `wm size` / `wm density` (and reset them),
  and Look/theme inside the app only when your brief says to.
- Do NOT uninstall, and do not touch the other device unless your brief assigns it.
- If the app shows a crash/error screen or the screenshot is blank, STOP and report
  that instead of guessing.
