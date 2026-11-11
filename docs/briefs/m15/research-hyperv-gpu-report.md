# Hyper-V, GPU partitioning and NVENC on a Windows 11 PC (RTX 3080)

Research for the game-streaming server: Linux containers running GPU-rendered apps and encoding with
NVENC (`nvh264enc`) through the NVIDIA Container Toolkit.
All pages fetched **2026-11-11**. Facts I could not fetch are marked **unverified**.

## The plain answer

**Not officially — and on a Linux guest, not reliably.** Microsoft's own troubleshooting documentation
states plainly that "DDA and GPU-P aren't supported on desktop-class hardware or client operating
systems such as Windows 10 or 11 Pro", and that a GPU-P host must run Windows Server 2025 or newer
([learn.microsoft.com, updated 2026-02-12](https://learn.microsoft.com/en-us/troubleshoot/windows-server/virtualization/troubleshoot-hyper-v-gpu-assignment-partitioning-passthrough-issues)).
The `Add-VMGpuPartitionAdapter` / `Get-VMHostPartitionableGpu` cmdlets and the "GPU-PV" mechanism do
exist on Windows 11 Pro and community tools use them, but the technology is undocumented on the client
and the supported-GPU list is enterprise-only (A2/A10/A16/A40/L2/L4/L40/L40S/RTX Pro 6000 Blackwell
Server Edition — no GeForce) ([GPU partitioning, updated 2025-07-24](https://learn.microsoft.com/en-us/windows-server/virtualization/hyper-v/gpu-partitioning)).
In a *Windows* GPU-P guest NVENC demonstrably works (Easy-GPU-PV, Sunshine/Parsec streaming VMs), because
the guest gets a paravirtual display/render driver. In a *Linux* GPU-P guest you get `/dev/dxg` and a
copied copy of the WSL driver bundle: CUDA, NVML and the NVENC API work, but there is **no NVIDIA DRM
node**, so zero-copy display→encode paths fail; only one report exists and it is from a Sunshine user,
not from Microsoft or NVIDIA. DDA (whole-GPU passthrough) is blocked on client Windows at `Start-VM`
(`0xC035001E`). The one path that is both documented by Microsoft/NVIDIA and known to expose NVENC to
Linux containers on this exact PC is **WSL2 with Docker Engine installed inside the distro** (not
Docker Desktop, whose WSL2 backend strips the NVENC/NVDEC libraries — docker/desktop-feedback#467, still
open).

## Table for point 7 (recommendation, ranked by effort × risk)

| Rank | Option (goal: Linux containers + NVENC on the RTX 3080) | Verdict | Effort | Main risk / caveat | Evidence |
|---|---|---|---|---|---|
| 1 | **Plain WSL2 Ubuntu + Docker Engine inside the distro + NVIDIA Container Toolkit** | works with caveats | low (≈1–2 h) | containers need the `video` driver capability and possibly `/usr/lib/wsl/lib` bind-mounted; no DRM node, so GL/Vulkan comes from Mesa d3d12/Dozen and any EGL↔NVENC zero-copy must go through system memory | [MS: Docker engine in WSL + toolkit](https://learn.microsoft.com/en-us/windows/wsl/tutorials/gpu-compute); [NVIDIA CUDA-on-WSL guide, updated 2026-11-02](https://docs.nvidia.com/cuda/wsl-user-guide/index.html); [Jellyfin NVIDIA docs](https://jellyfin.org/docs/general/post-install/transcoding/hardware-acceleration/nvidia/); [WSL#6357 (fixed)](https://github.com/microsoft/WSL/issues/6357) |
| 2 | **Linux host (dual boot, or a second/repurposed PC)** | works | medium (2–4 h + OS install) | loses always-on Windows; needs a separate disk or repartition | [NVIDIA container toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html); [Jellyfin Linux section](https://jellyfin.org/docs/general/post-install/transcoding/hardware-acceleration/nvidia/) |
| 3 | **Rented cloud GPU with NVENC** (L4/T4/A10-class) | works | low (minutes to start), cost ongoing | per-hour cost, upload latency, no local 3080 use; L4 has unrestricted NVENC sessions, GeForce is capped at 12 | [NVIDIA encode/decode support matrix](https://developer.nvidia.com/video-encode-and-decode-gpu-support-matrix-new) |
| 4 | **Hyper-V GPU-P with a Linux (Ubuntu) guest** | works with caveats / unsupported by MS | high (day+, scripting, DKMS) | inofficial on client; guest driver files copied by hand and re-copied on every host driver update; **no DRM node** (breaks zero-copy capture/EGL interop); container toolkit unproven there | [staralt/dxgkrnl-dkms](https://github.com/staralt/dxgkrnl-dkms); [dxgkrnl v4 DKMS](https://github.com/meandmyboiclaude/dxgkrnl-v4-dkms); [Sunshine#5598](https://github.com/LizardByte/Sunshine/issues/5598); [MS troubleshooting doc](https://learn.microsoft.com/en-us/troubleshoot/windows-server/virtualization/troubleshoot-hyper-v-gpu-assignment-partitioning-passthrough-issues) |
| 5 | **Hyper-V DDA (whole GPU to the VM)** | does not work on Windows 11 client | — | DDA is Server-only; on Windows 11 Pro the assignments succeed but `Start-VM` fails with `0xC035001E`; and with one GPU the host would lose its display adapter | [MS DDA plan doc](https://learn.microsoft.com/en-us/windows-server/virtualization/hyper-v/plan/plan-for-deploying-devices-using-discrete-device-assignment); [WSL#40842, Oct 2026](https://github.com/microsoft/WSL/issues/40842) |
| 6 | **VMware Workstation / VirtualBox on the same host** | does not work | — | both only offer an emulated SVGA/VMSVGA 3D device; no PCI passthrough, no CUDA/NVENC | [Broadcom Workstation 25H2 docs](https://techdocs.broadcom.com/us/en/vmware-cis/desktop-hypervisors/workstation-pro/25H2/using-vmware-workstation-pro/configuring-and-managing-virtual-machines/configure-display-settings-for-a-virtual-machine/prepare-the-host-system-to-use-accelerated-3d-graphics.html); [VirtualBox manual ch.14](https://www.virtualbox.org/manual/ch14.html) |

Short setup notes: (1) install Ubuntu from the Microsoft Store, `curl https://get.docker.com | sh`,
install `nvidia-container-toolkit`, run containers with `--gpus all -e NVIDIA_DRIVER_CAPABILITIES=all`
(see §5). (2) install any distro, `nvidia-driver-<latest>`, `libnvidia-encode`, `nvidia-container-toolkit`.
(3) rent an L4/T4 instance, install the same toolkit. (4) create a Gen-2 Ubuntu VM, add a GPU-P adapter
with the PowerShell in [staralt/dxgkrnl-dkms](https://github.com/staralt/dxgkrnl-dkms), copy
`C:\Windows\System32\lxss\lib` + `C:\Program Files\WSL\lib` + the DriverStore `*.so` files into
`/usr/lib/wsl/lib`, build dxgkrnl as a DKMS module, `ldconfig`, reboot.

---

## 1. GPU partitioning (GPU-P / GPU-PV) on Windows 11 client Hyper-V

**What Microsoft supports.** GPU partitioning is documented only for **Windows Server 2025** (live
migration requires Datacenter). Host prerequisites: Windows Server 2025, Hyper-V role, SR-IOV and
VT-d/IOMMU enabled in firmware, IOMMU DMA bit-tracking CPU, NVIDIA **vGPU** driver, and a *licence* that
supports GPU-P. One partition per VM, partitions auto-assigned, and a GPU cannot be both DDA and
partitionable ([GPU partitioning, updated 2025-07-24](https://learn.microsoft.com/en-us/windows-server/virtualization/hyper-v/gpu-partitioning);
[Partition and assign GPUs, Server 2025](https://learn.microsoft.com/en-us/windows-server/virtualization/hyper-v/partition-assign-vm-gpu)).

**Windows 11 vs Windows Server 2025.** Microsoft's troubleshooting article is explicit: "DDA and GPU-P
aren't supported on desktop-class hardware or client operating systems such as Windows 10 or 11 Pro",
and "If you want to use GPU-P, the host computer has to run Windows Server 2025 or a newer version"
([updated 2026-02-12](https://learn.microsoft.com/en-us/troubleshoot/windows-server/virtualization/troubleshoot-hyper-v-gpu-assignment-partitioning-passthrough-issues)).
Supported GPU-P adapters on the Server side are A2, A10, A16, A40, L2, L4, L40, L40S, RTX Pro 6000
Blackwell Server Edition, plus AMD Radeon PRO V710
([same page, 2025-07-24](https://learn.microsoft.com/en-us/windows-server/virtualization/hyper-v/gpu-partitioning)).

**What is nonetheless possible on Windows 11.** The `Hyper-V` PowerShell module on Windows 11 Pro
contains `Get-VMHostPartitionableGpu`, `Add-VMGpuPartitionAdapter` (with `-Min/Max/OptimalPartitionVRAM`,
`…Encode`, `…Decode`, `…Compute` knobs), `Set-VMGpuPartitionAdapter` and `Remove-VMGpuPartitionAdapter`
([cmdlet reference, Server 2025 view](https://learn.microsoft.com/en-us/powershell/module/hyper-v/add-vmgpupartitionadapter?view=windowsserver2025-ps)).
A Windows 11 Pro host does list its GPUs as partitionable — a Nov-2026 report shows
`Get-VMHostPartitionableGpu` listing even an NPU on Windows 11 Pro 26200
([microsoft/WSL#40842, 2026-10-19](https://github.com/microsoft/WSL/issues/40842)). Community tooling
therefore treats client Windows as a valid host: Easy-GPU-PV required "Windows 10 20H1+ Pro, Enterprise
or Education OR Windows 11 Pro, Enterprise or Education" and a GPU that supports NVENC/QSV/AMF; it was
archived on 2026-06-01 and replaced by App Sandbox
([repo](https://github.com/jamesstringer90/Easy-GPU-PV), [README](https://raw.githubusercontent.com/jamesstringer90/Easy-GPU-PV/main/README.md)).
ExHyperV, an actively developed GPU-P GUI, lists supported hosts as Windows 10 17134+, **Windows 11**,
Server 2019/2022/2025
([ExHyperV README](https://github.com/Justsenger/ExHyperV)).
Windows Server 2022 (build 20348, WDDM 2.9) is where Microsoft's paravirtual GPU stack gained Linux-VM
and WSL2 support; Windows 11 is WDDM 3.x, so it is newer than that bar
([ExHyperV WDDM table](https://github.com/Justsenger/ExHyperV)).
Editions: Hyper-V itself cannot be installed on Windows 10/11 **Home**
([MS: enable Hyper-V](https://learn.microsoft.com/en-us/virtualization/hyper-v-on-windows/quick-start/enable-hyper-v));
WSL2, however, works on Home.

**RTX 3080 + current drivers.** There is no Microsoft or NVIDIA statement that a GeForce RTX 3080 is
partitionable. Empirically GPU-PV works on GeForce cards: ExHyperV's tested list includes RTX 4090,
4080 Super, 2080 Super, GTX 1050 and a Tesla P100, all with DirectX 12, OpenGL, Vulkan, "Codec" and
CUDA/OpenCL ticked; RTX 3080 is not in that table but the same Ampere/Ada drivers are
([ExHyperV compatibility list](https://github.com/Justsenger/ExHyperV)). One 2026 project reports a
GPU-P Linux VM on an **RTX 3080 10 GB** with CUDA 13.2 and OpenGL 4.6
([dxgkrnl-v4-dkms](https://github.com/meandmyboiclaude/dxgkrnl-v4-dkms)). The catch that bites owners:
the guest uses *copies* of the host's driver files, so every host GPU driver update must be re-copied
(`Update-VMGpuPartitionDriver.ps1`, [Easy-GPU-PV README](https://raw.githubusercontent.com/jamesstringer90/Easy-GPU-PV/main/README.md));
on recent drivers (≈596.49+) a GPU-PV bug made Windows guests lose `nvEncoderAPI64.dll`, which silently
dropped Moonlight to software encoding until the driver folder was made read-only
([ExHyperV#254, 2026-07-24…28](https://github.com/Justsenger/ExHyperV/issues/254)). Also note that
`Set-VMGpuPartitionAdapter` limits reportedly have no effect on client, i.e. the partition is not really
capped ([ExHyperV README](https://github.com/Justsenger/ExHyperV), citing Easy-GPU-PV issue #298 —
**unverified**, I could not load that issue).

## 2. GPU-P with a Windows guest: does NVENC work?

Yes, in practice — this is the mainstream use of GPU-PV (game-streaming VMs).

- Easy-GPU-P/PV's prerequisites *require* a GPU with hardware video encoding ("NVIDIA NVENC, Intel
  QuickSync or AMD AMF") and tell you to install a GPU-accelerated remote-desktop/streaming app plus a
  virtual display driver in the guest
  ([README](https://raw.githubusercontent.com/jamesstringer90/Easy-GPU-PV/main/README.md)).
- ExHyperV ships a "Sunshine + GPU-PV" recipe (virtual display driver + Sunshine in the VM, stream with
  Moonlight), and its compatibility table ticks the codec column for the tested NVIDIA cards
  ([README](https://github.com/Justsenger/ExHyperV)).
- Issue #254 above is only understandable if NVENC is the expected encode path in a GPU-P Windows guest
  (encoding fell back to software when an NVENC DLL went missing)
  ([ExHyperV#254](https://github.com/Justsenger/ExHyperV/issues/254)).
- A long-running Level1Techs thread on "2 gamers 1 GPU" states NVENC (and CUDA) can be enabled in the
  guest, with caveats tied to driver versions — **secondary/community evidence, 2021-era**
  ([forum.level1techs.com](https://forum.level1techs.com/t/2-gamers-1-gpu-with-hyper-v-gpu-p-gpu-partitioning-finally-made-possible-with-hyperv/172234)).

Known limits, all community-sourced: no vGPU licence exists for GeForce (Microsoft's flow assumes one —
[MS troubleshooting doc](https://learn.microsoft.com/en-us/troubleshoot/windows-server/virtualization/troubleshoot-hyper-v-gpu-assignment-partitioning-passthrough-issues));
driver updates must be re-copied into the guest; **checkpoints are unsupported** with a GPU-PV adapter and
Startup RAM must equal minimum RAM (no dynamic memory)
([ExHyperV](https://github.com/Justsenger/ExHyperV)); there are reports of a GPU memory leak on older
builds (ExHyperV recommends host ≥ 26100.4946, citing Easy-GPU-PV#446 — **unverified**); host and guest
Windows versions should match (Easy-GPU-PV README); a physical display or HDMI dummy plug is needed for
screen capture on the host (Easy-GPU-PV README); and Vulkan is "unavailable, GL games may or may not
work" in Windows guests (Easy-GPU-PV README).

## 3. GPU-P with a Linux (Ubuntu) guest

**Official status.** Microsoft lists Ubuntu 18.04/20.04/22.04 as *supported GPU-P guests* — but only on a
Windows Server 2025 host with a supported (enterprise) GPU and the NVIDIA vGPU driver
([GPU partitioning, 2025-07-24](https://learn.microsoft.com/en-us/windows-server/virtualization/hyper-v/gpu-partitioning);
[MS troubleshooting doc](https://learn.microsoft.com/en-us/troubleshoot/windows-server/virtualization/troubleshoot-hyper-v-gpu-assignment-partitioning-passthrough-issues)).
That combination does not exist for a GeForce RTX 3080.

**The mechanism: `dxgkrnl`.** The Linux side of WSL2's GPU support is `dxgkrnl`, which creates `/dev/dxg`
and forwards D3D12/CUDA calls to the Windows host over VMBus. It is **not in mainline Linux**: the v4
patch series went to LKML on 2026-03-19, four years after v3, "without much excitement for getting it
into the mainline Linux kernel"
([Phoronix, 2026-03-19](https://www.phoronix.com/news/Microsoft-DXGKRNL-Linux-v4));
the cover letter describes "virtual compute devices (vGPUs) paravirtualized by a Windows Hyper-V host",
primary use case WSL2 ([LKML v4 00/55](https://lkml.iu.edu/2603.2/09609.html)).
It ships only in Microsoft's WSL2 kernel tree
(`drivers/hv/dxgkrnl`, [microsoft/WSL2-Linux-Kernel](https://github.com/microsoft/WSL2-Linux-Kernel/tree/linux-msft-wsl-6.6.y/drivers/hv/dxgkrnl)),
so a normal Hyper-V Linux VM needs it built out-of-tree.

**Can a normal Hyper-V Linux VM use it?** Yes, unofficially, two current projects:

- `staralt/dxgkrnl-dkms` — DKMS build of the WSL kernel module for Ubuntu 22.04/24.04/26.04, Debian 13,
  TrueNAS; requires a Windows 10 21H2+/Windows 11 host, a Gen-2 VM, and the Windows driver files copied
  into `/usr/lib/wsl/lib`; `nvidia-smi` shows the GPU. Its README's own "Problems" section says:
  *"It doesn't seem to support GPU acceleration. (But CUDA is working.)"*
  ([repo](https://github.com/staralt/dxgkrnl-dkms)).
- `dxgkrnl-v4-dkms` — packages the official LKML v4 patches for standalone Hyper-V VMs; tested on
  **Fedora 44 / RTX 3080 10 GB**, reporting CUDA 13.2 and OpenGL 4.6 through Mesa's d3d12 driver
  (`GALLIUM_DRIVER=d3d12`, `glxinfo` → "Device: D3D12 (NVIDIA GeForce RTX 3080)"); Vulkan via Dozen
  (`VK_ICD_FILENAMES=…/dzn_icd.x86_64.json`); also warns that `/dev/dxg` is world-writable by default
  ([repo](https://github.com/meandmyboiclaude/dxgkrnl-v4-dkms)).
- The older community write-up (Ubuntu-on-Hyper-V GPU acceleration gist) is referenced by both; still
  getting comments in 2026 from users running Docker workloads this way
  ([krzys-h gist](https://gist.github.com/krzys-h/e2def49966aa42bbd3316dfb794f4d6a)) — **secondary**.

**Is NVENC available there?** Yes at the API level, per one detailed report — and it comes with a large
asterisk. Sunshine issue #5598 (opened 2026-09-02, retested 2026-11-06) documents a Windows 11
Hyper-V host with an **RTX 4050** passed to a Gen-2 Arch Linux guest via GPU-P (`/dev/dxg`, host driver
596.08, later 610.60). In the guest: "/dev/dxg: PASS, NVML: PASS, CUDA: PASS, NVDEC: PASS, Direct NVENC
API: PASS", including a stress test of 12,000 frames at 1080p (~251–349 fps). What failed was Sunshine's
*zero-copy* path: it maps the CUDA device to a DRM node, and the guest has only `hyperv_drm`
(`/dev/dri/card1`) — no NVIDIA render node — so it aborted with "Unable to find DRM device with PCI bus
ID". With wlr capture the maintainers' RAM-bridge fallback fixed it (pre-release
2026.1103.235308 finds `h264_nvenc`, `hevc_nvenc`, `av1_nvenc`); KMS capture still fails
([Sunshine#5598](https://github.com/LizardByte/Sunshine/issues/5598)).

So: **the encoder works; the capture/interop around it does not.** I found **no report of the NVIDIA
Container Toolkit, and none of `nvh264enc`, running inside a GPU-P Linux VM** (see "not confirmed").
Practical reading: `nvh264enc` accepts plain `video/x-raw` system memory
([GStreamer nvh264enc docs](https://gstreamer.freedesktop.org/documentation/nvcodec/nvh264enc.html)),
so a CPU upload into NVENC should be possible even without a DRM node, but the toolkit expects
`/dev/nvidia*` devices and `/proc/driver/nvidia`, which do not exist here (**inference, unverified**).

## 4. Discrete Device Assignment (DDA)

**Server only.** DDA is documented for Windows Server 2016/2019/2022/2025 and Azure Local; guests may be
Windows 10+ / Server 2016+ or supported Linux — "DDA can also provide GPU acceleration to Linux VMs,
subject to support" and "virtualized workloads run on the native driver and typically have full access to
the GPU's functionality"
([MS plan-for-GPU-acceleration, Server 2016–2025](https://learn.microsoft.com/en-us/windows-server/virtualization/hyper-v/plan/plan-for-gpu-acceleration-in-windows-server);
[DDA planning doc](https://learn.microsoft.com/en-us/windows-server/virtualization/hyper-v/plan/plan-for-deploying-devices-using-discrete-device-assignment)).
Microsoft's troubleshooting article says DDA "isn't supported on desktop-class hardware or client
operating systems such as Windows 10 or 11 Pro"
([updated 2026-02-12](https://learn.microsoft.com/en-us/troubleshoot/windows-server/virtualization/troubleshoot-hyper-v-gpu-assignment-partitioning-passthrough-issues)).

**On Windows 11 Pro it fails at the last step.** A 2026 report on Windows 11 Pro 26200: DDA of a device
"gets through `Dismount-VMHostAssignableDevice` and `Add-VMAssignableDevice` on Windows 11 Pro but
`Start-VM` fails with 0xC035001E ('A hypervisor feature is not available to the user'), so a VM
workaround is not available on client SKUs either"
([microsoft/WSL#40842, 2026-10-19](https://github.com/microsoft/WSL/issues/40842)). That example is an
NPU, not a GPU; no GPU-specific success report on client Windows was found, so treat "DDA on Windows 11"
as **not possible** (high confidence, single primary-ish source for the error code).

**Requirements and consequences.** Server-class hardware with OS control of the PCIe fabric and ACS on
the root complex; MMIO space must be raised (`Set-VM -LowMemoryMappedIoSpace 3Gb -HighMemoryMappedIoSpace 33280Mb`
is the doc's own GPU example) because a 3080 needs GB of BAR space; the host **loses the device** while
dismounted; VM save/restore, live migration, dynamic memory and HA clustering are unavailable with a
device attached ([DDA planning doc](https://learn.microsoft.com/en-us/windows-server/virtualization/hyper-v/plan/plan-for-deploying-devices-using-discrete-device-assignment)).
With a single GPU the host would have no display adapter — you would need integrated graphics or a
second card. Whether *this* PC has an iGPU is unknown (see Decisions).

**If you had a Server host:** a Linux guest with DDA loads the ordinary NVIDIA driver, so NVENC, NVDEC and
the NVIDIA Container Toolkit work exactly as on bare metal — DDA passes the "entire PCIe device" and the
vendor driver installs normally in the guest
([DDA planning doc](https://learn.microsoft.com/en-us/windows-server/virtualization/hyper-v/plan/plan-for-deploying-devices-using-discrete-device-assignment);
[container toolkit install guide](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html)).
That is a statement about the mechanism; I found no DDA+Linux+NVENC writeup to cite (**unverified as a
specific report**).

## 5. WSL2 without Docker Desktop

**NVENC in a plain WSL2 distro: yes.** `/usr/lib/wsl/lib` contains `libnvidia-encode.so.1` and
`libnvcuvid.so.1` (the Docker issue lists `libnvcuvid.so.1` at 27 MB) —
[docker/desktop-feedback#467, 2026-06-17](https://github.com/docker/desktop-feedback/issues/467). The
long-running WSL issue asking for NVENC/NVDEC was **closed as fixed in insider builds**: posters confirm
"nvidia new driver support nvenc in wsl2 now… I got obs working when choosing nvenc encoder in wslg",
with `libnvidia-encode.so.1` appearing in `System32\lxss\lib` from driver 27.21.14.7025 (≈470.25)
([microsoft/WSL#6357](https://github.com/microsoft/WSL/issues/6357)). Jellyfin's official docs state it
flatly: "NVIDIA Windows driver provides access to the NVENC/NVDEC and CUDA in Windows WSL2 and Docker"
([jellyfin.org](https://jellyfin.org/docs/general/post-install/transcoding/hardware-acceleration/nvidia/)).
NVIDIA's own CUDA-on-WSL guide (v13.5, updated **2026-11-02**) does **not** mention video encode at all:
it documents CUDA, the loss of OpenGL-CUDA interop ("Applications relying on OpenGL will not work"),
`--gpus all` as the only toolkit mode, and that acceleration requires GeForce/RTX cards in **WDDM**
mode ([docs.nvidia.com](https://docs.nvidia.com/cuda/wsl-user-guide/index.html)) — so NVENC there is
supported-by-behaviour, not by an NVIDIA statement.

**Docker Engine inside the distro.** Microsoft documents exactly this path: "install the Docker engine
directly in WSL", then install the NVIDIA Container Toolkit, then `docker run --gpus all …`, and it
recommends `MESA_D3D12_DEFAULT_ADAPTER_NAME` to pick a GPU
([MS: GPU acceleration for ML in WSL](https://learn.microsoft.com/en-us/windows/wsl/tutorials/gpu-compute)).
NVIDIA's guide lists "Docker support: Supported with the latest NVIDIA Container Toolkit, using Docker CLI
or Docker Desktop" ([NVIDIA](https://docs.nvidia.com/cuda/wsl-user-guide/index.html)).

**The trap is the encode library, not CUDA.** The toolkit only injects `libnvidia-encode.so` when the
`video` driver capability is requested — the resolution of the classic report is
`-e NVIDIA_DRIVER_CAPABILITIES=compute,utility,video`
([nvidia-docker#1530, closed 2021-08-03](https://github.com/NVIDIA/nvidia-docker/issues/1530)). Docker
**Desktop**'s WSL2 backend forwards only the CUDA/management set and never mounts `/usr/lib/wsl/lib`, so
NVENC/NVDEC fail inside its containers even though `nvidia-smi` works; the issue was opened 2026-06-17
and on 2026-11-11 is still **open** with only label triage and no maintainer reply
([#467](https://github.com/docker/desktop-feedback/issues/467)). Whether the *same* limitation applies to
Docker Engine inside a WSL distro is not settled in writing: the toolkit enumerates libraries through the
distro's ldconfig, and the WSL bundle sits on the library path, so it *should* inject; the usual
workaround is to bind-mount `/usr/lib/wsl/lib` into the container and set
`LD_LIBRARY_PATH=/usr/lib/wsl/lib` (**community practice, unverified by a primary source**; the
NVIDIA forum answer about WSL encode libs only says the libraries must be the host-mounted ones
([forums.developer.nvidia.com](https://forums.developer.nvidia.com/t/building-ffmpeg-with-nvenc-inside-docker-container-in-wsl-2-linux-distro/155102))).

**GPU-rendered app + NVENC at the same time.** In WSL2 there is no NVIDIA DRM node; GL/Vulkan come from
Mesa's D3D12/Dozen layers on top of `/dev/dxg`. Microsoft's DirectX blog announced the D3D12-backed
Mesa path and, in Feb 2023, **VA-API video acceleration over D3D12** (H.264 decode and
`VAEntrypointEncSlice` encode, Mesa ≥ 22.2) for ffmpeg/GStreamer in WSLg
([devblogs.microsoft.com, 2023-02-13](https://devblogs.microsoft.com/commandline/d3d12-gpu-video-acceleration-in-the-windows-subsystem-for-linux-now-available/)).
`VK_ICD_FILENAMES=…/dzn_icd…json` and `GALLIUM_DRIVER=d3d12` are the documented-by-community switches
([dxgkrnl-v4-dkms](https://github.com/meandmyboiclaude/dxgkrnl-v4-dkms);
[paulbatum gist](https://gist.github.com/paulbatum/0a75c927948afb9341cca8bd8ff00e07) — AI-written, treat
as secondary). Containers do not automatically get `/dev/dxg`, so a containerised GL/Vulkan app needs
`--device /dev/dxg` plus the Mesa/D3D12 user-mode libraries — workable, but I found no primary
documentation (**unverified**).

## 6. Other hypervisors on a Windows 11 host (one line each)

- **VMware Workstation (25H2):** no GPU passthrough — "VMware Workstation does not support GPU
  passthrough", only a virtual SVGA 3D device (guest OpenGL 4.3; Vulkan renderer only when the *host* is
  Linux) ([Broadcom techdocs](https://techdocs.broadcom.com/us/en/vmware-cis/desktop-hypervisors/workstation-pro/25H2/using-vmware-workstation-pro/configuring-and-managing-virtual-machines/configure-display-settings-for-a-virtual-machine/prepare-the-host-system-to-use-accelerated-3d-graphics.html);
  [Broadcom community answer](https://community.broadcom.com/vmware-cloud-foundation/discussion/vmware-workstation-17-pro-supports-use-of-host-gpu)) — no NVENC.
- **VirtualBox 7.x:** 3D acceleration is still listed as an *experimental* feature and there is no PCI
  passthrough; no CUDA/NVENC in guests
  ([VirtualBox manual ch.14](https://www.virtualbox.org/manual/ch14.html)).
- **Linux as the host (KVM/QEMU):** the best technical fit — the NVIDIA driver, NVENC and the container
  toolkit run natively for the containers, and Windows only needs VFIO passthrough (second GPU or
  single-GPU tricks) if you still want a Windows guest
  ([toolkit install guide](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html)).

## 7. Recommendation

See the table at the top. Concretely for this PC, in order:

1. **Prove the encoder on WSL2 today** (cheap, reversible): Ubuntu in WSL2 → Docker Engine → NVIDIA
   Container Toolkit → `docker run --gpus all -e NVIDIA_DRIVER_CAPABILITIES=all … ffmpeg -f lavfi -i testsrc -c:v h264_nvenc out.mp4`,
   then repeat with a GStreamer image running `nvh264enc`. If `/usr/lib/wsl/lib` is not mounted into the
   container, bind-mount it. This is the only option whose GPU stack Microsoft/NVIDIA both document.
2. **Accept the rendering caveat**: in WSL2 the app's GL/Vulkan comes from Mesa d3d12/Dozen, which is
   slower than native and for which NVIDIA explicitly says OpenGL-CUDA interop is unsupported; encoding
   from system memory with `nvh264enc` avoids needing DRM/CUDA interop.
3. **If rendering performance or container cleanliness matters, dual-boot Linux** (or put Linux on a
   spare machine). That is the only arrangement where containers, `/dev/dri`, NVENC and zero-copy all
   behave like the docs say.
4. **Do not build on Hyper-V GPU-P for Linux.** It is undocumented on client Windows, requires copied
   driver files, breaks on driver updates, exposes no DRM node (which is what broke Sunshine in #5598),
   and nobody has published a container-toolkit + NVENC result.
5. **DDA is closed** on Windows 11 Pro (`0xC035001E`), and with a single GPU it would leave the host
   without a display adapter anyway.
6. **Cloud GPU** is the fastest way to validate an NVENC pipeline end-to-end before committing to local
   hardware; pick an L4-class instance (unrestricted NVENC sessions) rather than a GeForce.

## What I could not confirm

- No Microsoft or NVIDIA document says GPU-P is supported on Windows 11 **client**; the only explicit
  statements are the opposite. Community tools work, but "supported" is not a thing here.
- No report of the **NVIDIA Container Toolkit** working inside a GPU-P **Linux** VM (no `/dev/nvidia*`,
  no `/proc/driver/nvidia`, only `/dev/dxg`). Unverified either way.
- No report of **`nvh264enc` / GStreamer nvcodec** specifically running in WSL2 or in a GPU-P Linux VM.
  The NVENC evidence is API-level (Sunshine's 12,000-frame test) and ffmpeg/OBS-level; GStreamer nvcodec
  is my inference from the plugin's acceptance of system memory.
- Whether the `video` driver capability is sufficient in a WSL **Docker Engine** container (versus
  Docker Desktop, which is broken per #467) — no primary source; NVIDIA's guide is silent.
- Whether GPU-P `Set-VMGpuPartitionAdapter` limits are truly ignored (ExHyperV says yes; the linked
  Easy-GPU-PV issue #298 would not load for me) and whether the GPU-memory leak (Easy-GPU-PV#446) is
  fixed.
- DDA of a **GPU** on Windows 11 Pro: only an NPU example of the `0xC035001E` failure exists.
- Whether this PC's CPU has integrated graphics (needed for DDA, and for keeping a display while a GPU is
  dismounted).
- Cloud pricing/instance availability, and whether any provider blocks NVENC on consumer-style images.
- I did not read NVIDIA's vGPU licensing terms; the "no vGPU licence for GeForce" line is inference from
  the supported-GPU lists.
- Nothing I fetched contained instructions aimed at me; one page (a gist) is explicitly labelled as
  AI-written and is used only as secondary evidence.

## Decisions (assumptions I made)

- Windows 11 **Pro** assumed (Hyper-V exists); Home cannot install Hyper-V at all, WSL2 is unaffected.
- One GPU, no second card; iGPU unknown — flagged wherever it matters (DDA).
- "NVENC" means H.264/HEVC encode. The RTX 3080 is Ampere/7th-gen NVENC with **no AV1 encode**, 1 NVENC
  engine and a driver cap of **12 concurrent sessions**
  ([NVIDIA support matrix, fetched 2026-11-11](https://developer.nvidia.com/video-encode-and-decode-gpu-support-matrix-new)).
  L4, by contrast, is "Unrestricted" (same page).
- I treated Docker Desktop #467 as still open: fetched 2026-11-11, state "Open", last activity a label
  added 2026-07-16.
- The report is written to `report.md` in this job folder, as the job instructions ask (the brief names
  `docs/briefs/m15/research-hyperv-gpu-report.md`, which I cannot write from here).
