# Moving the demo-video work to another PC

Plan for moving the Thumb Party demo-video capture setup from the current PC
(Intel i5-8350U, 16 GB) to a faster one. Written Nov 5, 2026.

Source of truth for *how* the capture works is `docs/demo-video-runbook.md`.
This document only covers the move. Per runbook E3 the tool paths change on a
new PC; everything below keeps `WORK` and `REPO` as variables so nothing is
hard-coded.

## 0. Should you move at all?

Not required. On the current PC, M1 take 12 passes every QA rule. A faster PC
helps with: the touch driver reaching only 30-40 Hz instead of 60, phone ping
of 92-188 ms under load, and fewer retakes. Move when you are at a clean
break point (see section 1), not in the middle of a block.

## 1. When to start

Start the move only when **all** are true:

- DeepSeek has ended its session and the final report is in.
- `git status` is clean except the five files that must stay uncommitted
  (`docs/PRD - Copy.md`, `docs/PRD-old.md`, `docs/PRD-old-2.md`,
  `kenney-audio/`, `tools/demo/grpc_touch/`), OR any in-progress edits have been
  committed to a WIP commit on `demo-video` and pushed.
  (As of this writing the tree has uncommitted edits to the M2 scene files and
  the arena brain. Resolve them first: commit if finished and green with
  `tools/check.sh`, otherwise commit as `WIP:` on `demo-video` and push.)
- `$WORK/logs/handoff.md` CURRENT STATE is up to date (exact commit, what is
  done, blocked, next 3 actions).
- Nothing is running: no OBS, ThumbPartyTV, emulator, qemu, touch driver.

## 2. What travels, and how

| Item | How it moves | Notes |
| --- | --- | --- |
| Code (`demo-video` branch) | `git push`, then `git clone` on the new PC | The only thing that must be pushed. |
| `$WORK/logs/handoff.md` and the rest of `$WORK/logs/` | Bundle zip | Handoff is the cold-start document. |
| Accepted footage and its QA files (`footage/`, `qa/`) | Bundle zip, or a USB drive if large | Accepted takes only (see the review sheet). Raw rejected takes can stay behind. |
| `$WORK/backup/` (owner preferences backups) | Bundle zip | Must not contain the OBS password. |
| `$WORK/audio/`, `$WORK/graphics/`, `$WORK/edit/`, `$WORK/sessions/`, `$WORK/charts/` | Bundle zip | Skip `renders/` unless a finished render exists. |
| `kenney-audio/` (untracked in repo) | Bundle zip | Never commit it. |
| `thumb-party-audio/` | Bundle zip | Bubble Pop sounds, `INSTALL.md`, `render.py`. |
| AVD settings: `m7_android12.config.ini`, `m7_android12.ini`, `m8_pixel_tablet.config.ini`, `m8_pixel_tablet.ini` | Bundle zip (`avd/`) | Copy as reference; see section 5 on whether to restore them or recreate. |
| `$WORK/venv` | **Do not copy.** Recreate. | Virtual environments are not portable. |
| Flutter, Android SDK, ffmpeg, OBS, Python, scrcpy | **Do not copy.** Reinstall. | |
| `build/` outputs (TV exe, phone APK) | **Do not copy.** Rebuild. | The new PC builds from HEAD. |
| GitHub login | `gh auth login` on the new PC | Never copy tokens. |

Not needed any more: scrcpy for the emulator (unusable, replaced by OBS window
capture). Install it only if the runbook's version check still asks for it.

## 3. On the old PC: build the bundle

Run in PowerShell, after section 1 is satisfied. Stage into a **fresh** folder
(do not reuse an old one):

```powershell
$stage = "$env:TEMP\demo-bundle-stage-$(Get-Date -Format yyyyMMdd-HHmm)"
New-Item -ItemType Directory $stage | Out-Null
$work = "C:\Users\singh\thumbparty-demo"
$repo = "C:\Users\singh\game-controller"

New-Item -ItemType Directory "$stage\work" | Out-Null
foreach ($d in 'logs','backup','qa','audio','graphics','edit','sessions','charts') {
  if (Test-Path "$work\$d") { Copy-Item "$work\$d" "$stage\work\$d" -Recurse }
}
# Accepted footage only: copy the whole folder, then delete rejected takes by hand
# before zipping if it is large.
Copy-Item "$work\footage" "$stage\work\footage" -Recurse

Copy-Item "$repo\kenney-audio" "$stage\kenney-audio" -Recurse
Copy-Item "C:\Users\singh\Documents\deepseek-harness\default-workspace\thumb-party-audio" "$stage\thumb-party-audio" -Recurse

New-Item -ItemType Directory "$stage\avd" | Out-Null
Copy-Item "C:\Users\singh\.android\avd\m7_android12.avd\config.ini"   "$stage\avd\m7_android12.config.ini"
Copy-Item "C:\Users\singh\.android\avd\m7_android12.ini"              "$stage\avd\m7_android12.ini"
Copy-Item "C:\Users\singh\.android\avd\m8_pixel_tablet.avd\config.ini" "$stage\avd\m8_pixel_tablet.config.ini"
Copy-Item "C:\Users\singh\.android\avd\m8_pixel_tablet.ini"           "$stage\avd\m8_pixel_tablet.ini"

# Record the exact commit the new PC must check out.
git -C $repo rev-parse HEAD | Set-Content "$stage\COMMIT.txt"

Compress-Archive "$stage\*" "$env:USERPROFILE\Desktop\demo-bundle.zip" -Force
```

Check before moving: open the zip, confirm `COMMIT.txt` matches
`git log -1` on `demo-video`, and confirm no OBS password appears in
`work\backup` (search the files for "password").

The previous bundle on the Desktop (`demo-bundle.zip`, Nov 4) is **stale**
(tablet AVD config and handoff changed since). Overwrite it with this one.

Move the zip by USB drive or a cloud-drive folder. If footage makes it too
large, send footage separately.

## 4. On the new PC: set up the toolchain (owner's steps)

Do these yourself; they need admin rights, a reboot, or a login. In order:

1. **Windows**: Windows 11, all updates, **Do Not Disturb on** for the whole
   session (Settings > System > Notifications), display scaling **100%**, a
   single 1920x1080 display if possible (the capture scenes assume it).
2. **Virtualization**: enable it in BIOS/UEFI if off, then in PowerShell
   (admin): `Enable-WindowsOptionalFeature -Online -FeatureName HypervisorPlatform`
   (the emulator uses WHPX). **Reboot.**
3. **Git Bash**: `winget install --id Git.Git -e`
4. **GitHub CLI**: `winget install --id GitHub.cli -e`, then `gh auth login`.
5. **Visual Studio Build Tools** with the **Desktop development with C++**
   workload (needed to build the Windows TV app):
   `winget install --id Microsoft.VisualStudio.2022.BuildTools -e --override "--add Microsoft.VisualStudio.Workload.VCTools --includeRecommended --passive"`
6. **Flutter**: install the same SDK version as the old PC (run `flutter --version`
   on the old PC and match it) at `C:\src\flutter`; put `C:\src\flutter\bin` on PATH.
   Follow `docs/building.md`.
7. **Android SDK**: via Android Studio or command-line tools; install
   platform-tools, the emulator, build-tools and the **API 31 x86_64 "default"
   (non Google Play)** system image so `adb root` works. Accept licenses:
   `flutter doctor --android-licenses`.
8. **Other tools** (PowerShell):
   ```powershell
   winget install --id Gyan.FFmpeg -e
   winget install --id Python.Python.3.12 -e
   winget install --id OBSProject.OBSStudio -e
   winget install --id Microsoft.VisualStudioCode -e
   ```
9. **Reboot** once more, then open **new** Git Bash and PowerShell windows so PATH
   is current.
10. **Sign in once** to anything the capture needs interactively (GitHub in
    the browser for the browser shots).

## 5. On the new PC: restore the work

```powershell
mkdir C:\Users\singh\thumbparty-demo        # or any path; keep it in $WORK below
git clone https://github.com/<owner>/game-controller.git C:\Users\singh\game-controller
cd C:\Users\singh\game-controller
git checkout demo-video
git log -1                                   # must match COMMIT.txt in the bundle
Expand-Archive $env:USERPROFILE\Desktop\demo-bundle.zip -DestinationPath $env:TEMP\demo-bundle
```

Then copy `work\*` into `$WORK`, `kenney-audio` into the repo root,
`thumb-party-audio` to where the runbook's E1 expects it, and run:

```bash
export PATH="/c/Users/$USER/AppData/Local/Microsoft/WinGet/Links:$PATH"
export WORK=/c/Users/<you>/thumbparty-demo
export REPO=/c/Users/<you>/game-controller
mkdir -p $WORK/{footage,logs,sessions,charts,graphics,audio,edit,renders,qa,backup}
cd $WORK && py -3.12 -m venv venv
./venv/Scripts/python.exe -m pip install --upgrade pip
./venv/Scripts/python.exe -m pip install numpy==2.* pillow==11.* matplotlib==3.*
```

**AVDs**: create `m7_android12` in Android Studio Device Manager (phone, API 31
x86_64 default image, accelerometer and gyroscope on), then compare its
`config.ini` against the saved one and align the settings that matter (panel
2400x1080, density, sensors, `hw.gpu`). Likewise `m8_pixel_tablet`. Do not
paste the old `config.ini` blindly over a fresh AVD; a different SDK version can
reject fields. After that, `tools/emulator.sh capture-size on|off` handles the
capture sizes (phone 1800x810@315, tablet 1920x1200@240).

## 6. Validate the new PC with a fresh DeepSeek session

Nothing counts as moved until a **fresh** DeepSeek session passes this
checklist. Paste the prompt below into the new session (it contains the
fresh-session preamble).

````
FRESH SESSION ON A NEW PC. You have no memory of earlier sessions, and the
computer is different from the one the runbook describes. Read, in order:
1. <REPO>\docs\demo-pc-move.md (this plan)
2. <REPO>\docs\demo-video-runbook.md: sections 0, E1-E4, 2.3-2.8, 3.1-3.2.
3. <WORK>\logs\handoff.md: CURRENT STATE.
4. `git log --oneline -20` on branch demo-video; HEAD must equal the commit in the bundle's COMMIT.txt.

Owner decisions (don't revisit): OBS both-sides capture; floors TV 59 fps /
phone 45 fps; arena phone half judged by delivery; DND on; phone 1800x810@315,
tablet 1920x1200@240; untracked files (PRD copies, kenney-audio/,
tools/demo/grpc_touch/) are never committed; no tags or releases.
Hard rules: never edit a QA gate to make a take pass; 3-attempt cap per
failure mode; all TV app changes behind DEMO_DIRECTOR; status notes max 5 lines.

GOAL: prove this PC can reproduce the old PC's results. NO new shots in this block.

Step 1: environment check. Report versions: Flutter/Dart, adb, emulator, ffmpeg,
Python, OBS, gh. Report CPU, RAM, GPU, display resolution and scaling. Confirm
WHPX is available. Update runbook E1/E2 paths and the Hardware line for this PC
and commit.
Step 2: tools/check.sh must be green.
Step 3: build both apps from HEAD (2.5) and write $WORK/edit/build.txt.
Step 4: start the m7_android12 emulator; run `tools/emulator.sh capture-size on`;
confirm the screen is 1800x810@315 and pointer-location works.
Step 5: layouts. For each phone layout (sticks, dpad, gyro) tap three control
points through the touch driver and confirm the app reads them. Do not
re-measure unless a point misses; if it does, say which and by how much.
Step 6: gyro dry run (calibrate first, 2.4 Step D) and four held tilt intents:
the TV dot must move in the matching direction each time.
Step 7: ONE M1 smoke take (--tv-screen arena), graded with the current 2.8
rules. Report fps, exact-duplicate runs, delivery, and the touch driver's
achieved rate (should now be close to 60 Hz) and phone ping.
Step 8: compare to old PC numbers: M1 take 12 (TV 60.0 fps, 0 duplicate runs,
phone delivery 59.9 fps, driver 30-40 Hz, ping 92-188 ms). Report each metric
side by side.

If something fails, fix the environment (not a gate) within the 3-attempt cap,
else stop and report. Finish with the ground-rule-9 cleanup, update handoff.md
for a cold start, and print a NEXT SESSION paragraph of 5 lines or fewer
(preceded by the fresh-session preamble).
````

## 7. After validation

- The old PC stays untouched until the new PC has produced **one accepted take**.
  That is the rollback.
- Footage from both PCs may be mixed in the final edit if resolution, frame
  rate and scene are identical; the QA gates apply the same way on both.
- Re-run the remaining shots on the new PC in the planned order: P1, M2, M3, M4,
  P2, P3 (cursor hidden), then R1, R2, G1, and the G2 first race take (STOP
  gate for the owner). Known state at the time of the move (Nov 5): only M1
  take 12 is accepted; M3 was blocked by host load on the old PC (the arena,
  OBS 3840x1080 capture and the emulator starve each other and the phone is
  dropped after the 4 s heartbeat timeout); M2, M4, P1-P3 were fixed in code
  but never shot because the session locked.
- **Re-shoot M1 once** on the new PC with the pointer hidden
  (`tools/demo/cursor.ps1`, called by the showrunner). Take 12 passed QA but the
  Windows pointer is visible in it (`qa/cursorzoom/m1_zoom.png`), because OBS's
  `capture_cursor=false` did not hide it and the `tvCursor` gate missed it.
- **Start `tools/demo/awake.ps1` before the first take** of every block and stay
  signed in. A locked session records black frames that pass every 2.8 rule.
  On the new PC also set Settings > System > Power: screen/sleep = Never while
  plugged in, and turn off lock-on-idle.
- Tablet emulator: after a cold boot wait about 90 s before `capture-size`,
  `install` and launch, or "System UI isn't responding" appears.
- Update `project-notes.md` / memory notes with the new machine and the date
  of the move.

## 8. Known differences to expect

- Frame rates should be easier to hit; do not tighten the gates because of it.
- Layout coordinates depend on the capture size, not the CPU; they should
  carry over. Re-measure only if a verification tap misses.
- Emulator sensor axes: the AVD panel is landscape, and the driver sends
  the inverse turn. This is emulator-side and unchanged by the move.
- Different GPU drivers can change window-capture behaviour in OBS. If OBS
  binds the wrong window or shows black, check `tools/demo/obs.dart` window
  matching (`Android Emulator -`) and the OBS capture method before touching
  anything else.
- Windows' DND state check (`SHQueryUserNotificationState`) may report 5 even
  when DND is off; the owner's confirmation overrides it.

## 9. Owner checklist (one page)

1. [ ] DeepSeek session ended, report received, tree clean/pushed.
2. [ ] Bundle built (section 3), COMMIT.txt matches `demo-video` HEAD.
3. [ ] Bundle copied to the new PC.
4. [ ] Section 4 steps done, rebooted twice, DND on.
5. [ ] Repo cloned, bundle restored, venv created (section 5).
6. [ ] AVDs created and aligned.
7. [ ] Fresh DeepSeek session run with the section 6 prompt; results compared.
8. [ ] One accepted take on the new PC, then retire the old setup.
