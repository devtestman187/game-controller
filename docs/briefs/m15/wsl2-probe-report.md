# WSL2 + Docker Engine + NVENC probe report

## 1. Verdict

| Test | Result |
|---|---|
| A native NVENC in WSL | NOT RUN - WSL is not installed |
| B NVENC in container | NOT RUN |
| C-a GPU rendering in WSL | NOT RUN |
| C-b GPU rendering in container | NOT RUN |
| C-c render+encode headless 1080p60 | NOT RUN |
| D session cap | NOT RUN |
| Stretch (weston) | NOT RUN |

Summary: The probe stopped at step 0/1 as the hard limits require. This PC has no WSL at all (`wsl --version` and `wsl -l -v` both answer "The Windows Subsystem for Linux is not installed. You can install by running 'wsl.exe --install'."). Creating the `tp-stream` distro needs `wsl --install`, which enables Windows features (VirtualMachinePlatform / WSL) and normally a reboot. That is forbidden for the probe, so nothing could be tested. The question (NVENC + GPU render in WSL2 containers) remains open.

## 2. Environment (Windows side, read-only)
- Windows 11 Pro, `Microsoft Windows [Version 10.0.26300.9974]` (OS Version 10.0.26300 Build 26300)
- GPU: NVIDIA GeForce RTX 3080, 10240 MiB, WDDM; `NVIDIA-SMI 610.88  KMD Version: 610.88  CUDA UMD Version: 13.3`
- Docker Desktop: not installed (no `C:\Program Files\Docker\Docker`, no docker process)
- WSL services (WslService/LxssManager) and vmms: none found by Get-Service
- WSL: not installed (no wsl --version, no distros)
- Not checked: optional-feature state (needs elevation).

## 3. Step by step
- Step 0: `wsl --version`, `wsl -l -v`, `wsl --status` -> all "The Windows Subsystem for Linux is not installed." (exit 50). `cmd /c ver`, `systeminfo`, `nvidia-smi` as above.
- Steps 1-7: not run (blocked).
- Step 8: nothing created, nothing to tidy.

## 4. Working recipe
None yet. What the owner must do first (needs admin and a likely reboot, which I may not do):
1. In an elevated shell: `wsl --install --no-distribution`, then reboot.
2. `wsl --update`, `wsl --version` (need a version supporting `--name`).
3. `wsl --install -d Ubuntu-24.04 --name tp-stream --no-launch`
4. Re-run this probe (steps 2-8 of the brief).

## 5. What failed or is unproven
Everything beyond inventory is unproven. Reason: WSL not installed; installing it requires enabling Windows features and a reboot, which the brief forbids.

## 6. How to remove everything
Nothing was created. (After a future probe: `wsl --unregister tp-stream`.)
