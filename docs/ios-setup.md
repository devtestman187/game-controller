# iOS setup (Windows PC, free Apple ID, no Mac)

The controller's iOS build is made in the cloud by **Codemagic** as an **unsigned** `.ipa`. You import it into **iLoader** on Windows, which signs it with a **free Apple ID** and installs it on the iPhone. No paid Apple Developer account, App Store Connect, certificates or provisioning profiles are involved.

Why iLoader: on October 24, 2026 it signed in and installed when Sideloadly and Impactor could not (Apple had blocked the sign-in method they use). See the PRD decisions.

These are the manual steps only you can do, in order. Steps 1–4 are one-time setup.

---

## 1. Prepare the Windows PC (one time)

1. **Remove the Microsoft Store version** of iTunes if you have it (Settings → Apps → Installed apps).
2. Install **iTunes** from Apple's site (not the Microsoft Store): https://www.apple.com/itunes/ → "Windows" → download the 64-bit installer. iLoader uses the Apple Mobile Device service that comes with it to talk to the phone over USB. iCloud is not needed.
3. Install **iLoader** only from its official sources: the releases page at https://github.com/nab138/iloader/releases or https://iloader.app (WinGet: `winget install nabdev.iloader`). Other download sites are not official.
4. **Keep a copy of the installer that worked** (for example in a `tools` folder outside the repo). If a newer release breaks sign-in, reinstall that one.
5. Connect the iPhone by USB, unlock it, and tap **Trust This Computer**. iTunes should show the phone.

## 2. Use a separate Apple ID for sideloading (recommended)

iLoader asks for your Apple ID password and 2-factor code. To keep your main account separate, create a new free Apple ID (https://account.apple.com) used **only** for sideloading. It doesn't need to be signed in on the iPhone.

## 3. Turn on Developer Mode on the iPhone (one time)

1. On iOS 16+, apps signed with a development certificate (which free Apple ID signing produces) need Developer Mode.
2. Settings → **Privacy & Security** → **Developer Mode** → On → Restart → confirm "Turn On" after the reboot.
3. If the Developer Mode option is not visible, install the app once with iLoader (step 6). The option appears after a development-signed app is on the phone.

## 4. Connect the repo to Codemagic (one time)

1. Sign up at https://codemagic.io with your **GitHub** account (the free personal plan gives about 500 macOS M2 build minutes per month as of Oct 2026. Check the current limits on the pricing page).
2. **Add application** → GitHub → pick the `game-controller` repository → project type **Flutter App (via codemagic.yaml)**.
3. Codemagic reads `codemagic.yaml` from the repo root. There's nothing to configure for code signing. Leave iOS signing empty.
4. Check that webhooks were created (Codemagic app → Webhooks tab). That's what triggers builds on push, pull request and tag.

What runs automatically:
| Event | Workflow | Result |
| --- | --- | --- |
| Push to `main` touching `controller_app/` or `packages/protocol/` | `ios-check-main` | Analyze, tests, unsigned build. No download. |
| Pull request into `main` touching those paths | `ios-check-pr` | Same |
| Any **tag** (e.g. `m0`, `m1`) | `ios-ipa` | Builds and publishes `controller-unsigned-<tag>.ipa` |
| **Start new build** in the Codemagic UI → workflow `ios-ipa` | `ios-ipa` | Same, named `controller-unsigned-manual-<n>.ipa` |

Docs-only and TV-only changes don't start an iOS build. Builds stop after 30 minutes, and a newer commit cancels an older running build.

## 5. Download the .ipa

1. Codemagic → your app → **Builds** → the finished `ios-ipa` build (green).
2. Under **Artifacts**, download `controller-unsigned-<tag>.ipa` to the PC.

## 6. Import, sign and install with iLoader

1. iPhone connected by USB and unlocked.
2. Open iLoader and sign in with the sideloading **Apple ID**. Enter the password and the 2-factor code when asked.
3. Check that your iPhone is the selected device.
4. Choose iLoader's option to **import an IPA** (not "Install SideStore") and pick the downloaded `controller-unsigned-<tag>.ipa`.
5. Don't change the bundle ID if iLoader offers to. The app ID `com.gamecontrollerdev.controller` is fixed on purpose: a free Apple ID can register only about 10 new app IDs per 7 days.
6. Wait for it to finish. The **Controller** app icon appears on the iPhone.

If something fails, open iLoader's **View Logs** (set the log level to Debug if it's empty). Full logs are in `%APPDATA%\me.nabdev.iloader\logs`.

## 7. Trust the developer profile on the iPhone (first install per Apple ID)

Settings → **General** → **VPN & Device Management** → under *Developer App* tap your Apple ID → **Trust "<Apple ID>"** → Trust. Then launch **Controller**.

## 8. Re-install every 7 days

Apps signed with a free Apple ID **stop launching after 7 days**. To renew, repeat step 6 with the same `.ipa` (or a newer one). The app's data is kept when you re-install over it with the same bundle ID.

Automatic refresh with SideStore (which iLoader can install) is an open question in the PRD. Its sign-in still needed workarounds in October 2026, so weekly re-installs by hand are the default for now.

## Free Apple ID limits (designed around)
| Limit | What it means here |
| --- | --- |
| Apps expire after **7 days** | Re-install weekly (step 8) |
| Only **3** sideloaded apps active at once | The controller uses 1 slot (SideStore would use another) |
| About **10 new app IDs per week** | The bundle ID is chosen once and never changed |
| No paid-only capabilities | The app uses no push notifications, App Groups, extensions, iCloud or associated domains. Local network and Bonjour (M1) work with a free account. |

iLoader can also show and revoke the Apple ID's development certificates and app IDs, which helps if you hit a certificate or app ID limit.

## If Apple blocks sideloading sign-in again
Fall back to a paid Apple Developer account and TestFlight (see below). This is the PRD's mitigation.

## Moving to TestFlight later
Nothing here blocks it. With a paid account you'd add signing in Codemagic (App Store Connect API key + automatic signing) and a TestFlight publish step. The bundle ID and code stay the same. Note that App Store Connect uploads require a recent Xcode, which Codemagic provides.

## Troubleshooting
| Symptom | Fix |
| --- | --- |
| iLoader doesn't see the phone | Unlock the phone, re-plug, tap Trust. Make sure Apple's iTunes (not the Store version) is installed, so the Apple Mobile Device service is running. |
| Apple ID sign-in fails | Check the 2-factor code and the logs. If a new iLoader release broke sign-in, reinstall the saved installer (step 1.4). |
| "Untrusted Developer" on launch | Step 7 |
| App opens then closes immediately after a week | The signature expired. Re-install (step 8). |
| "Maximum number of apps" error | Remove an older sideloaded app, or wait for one to expire. |
| Certificate or app ID limit error | Revoke old development certificates or app IDs in iLoader. |
| Codemagic build didn't start | Check the changed paths (docs-only and TV-only changes are skipped on purpose) and the Codemagic webhooks. For an .ipa, push a tag or start `ios-ipa` manually. |
