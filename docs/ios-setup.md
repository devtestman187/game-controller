# iOS setup (Windows PC, free Apple ID, no Mac)

The controller's iOS build is made in the cloud by **Codemagic** as an **unsigned** `.ipa`. You sign and install it from Windows with **Sideloadly** and a **free Apple ID**. No paid Apple Developer account, App Store Connect, certificates or provisioning profiles are involved.

These are the manual steps only you can do, in order. Steps 1–4 are one-time setup.

---

## 1. Prepare the Windows PC (one time)

1. **Remove Microsoft Store versions** of iTunes and iCloud if you have them (Settings → Apps → Installed apps). Sideloadly needs Apple's own web installers.
2. Install **iTunes** from Apple's site (not the Microsoft Store): https://www.apple.com/itunes/ → "Windows" → download the 64-bit installer.
3. Install **iCloud for Windows** from Apple's site (the non-Store installer linked from https://support.apple.com/HT204283). If only the Store version is offered, follow Sideloadly's FAQ for the web installer link.
4. Install **Sideloadly**: https://sideloadly.io → Download for Windows (64-bit). Run it once.
5. Connect the iPhone by USB, unlock it, and tap **Trust This Computer**. iTunes should show the phone.

## 2. Use a separate Apple ID for sideloading (recommended)

Sideloadly asks for your Apple ID password and 2-factor code. To keep your main account separate, create a new free Apple ID (https://account.apple.com) used **only** for sideloading. It doesn't need to be signed in on the iPhone.

## 3. Turn on Developer Mode on the iPhone (one time)

1. On iOS 16+, apps signed with a development certificate (which free Apple ID signing produces) need Developer Mode.
2. Settings → **Privacy & Security** → **Developer Mode** → On → Restart → confirm "Turn On" after the reboot.
3. If the Developer Mode option is not visible, install the app once with Sideloadly (step 6). The option appears after a development-signed app is on the phone.

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

## 6. Sign and install with Sideloadly

1. iPhone connected by USB and unlocked.
2. Open Sideloadly. Check that your iPhone is selected under **iDevice**.
3. Drag the `.ipa` onto the IPA box.
4. Enter the sideloading **Apple ID** and click **Start**. Enter the password and the 2-factor code when asked.
5. Leave **Advanced options → bundle ID** unchanged. The app ID `com.gamecontrollerdev.controller` is fixed on purpose: a free Apple ID can register only about 10 new app IDs per 7 days.
6. Wait for "Done". The **Controller** app icon appears on the iPhone.

## 7. Trust the developer profile on the iPhone (first install per Apple ID)

Settings → **General** → **VPN & Device Management** → under *Developer App* tap your Apple ID → **Trust "<Apple ID>"** → Trust. Then launch **Controller**.

## 8. Re-sign every 7 days

Apps signed with a free Apple ID **stop launching after 7 days**. To renew, repeat step 6 with the same `.ipa` (or a newer one). The app's data is kept when you re-install over it with the same bundle ID.
- Sideloadly also has an optional **auto-refresh** daemon that re-signs in the background every few days while the PC is on (Sideloadly settings). Check its current docs before relying on it.

## Optional: AltStore (automatic refresh over Wi-Fi)

AltStore can refresh the app automatically, so you don't have to re-sign by hand:
1. Install **AltServer** for Windows from https://altstore.io (also needs the Apple web versions of iTunes and iCloud).
2. In iTunes, enable **Sync with this iPhone over Wi-Fi** for your phone.
3. Use AltServer (tray icon) → **Install AltStore** → your iPhone, signing in with the sideloading Apple ID.
4. Copy the `.ipa` to the phone (for example via Files) and open it in AltStore → **My Apps** → **+**.
5. While AltServer runs on the PC on the **same Wi-Fi** as the iPhone, AltStore refreshes apps in the background before they expire.

Note: AltStore itself uses one of the three app slots.

## Free Apple ID limits (designed around)
| Limit | What it means here |
| --- | --- |
| Apps expire after **7 days** | Re-sign weekly (step 8) or use auto-refresh |
| Only **3** sideloaded apps active at once | The controller uses 1 slot (AltStore uses another if you use it) |
| About **10 new app IDs per week** | The bundle ID is chosen once and never changed |
| No paid-only capabilities | The app uses no push notifications, App Groups, extensions, iCloud or associated domains. Local network and Bonjour (M1) work with a free account. |

## Moving to TestFlight later
Nothing here blocks it. With a paid account you'd add signing in Codemagic (App Store Connect API key + automatic signing) and a TestFlight publish step. The bundle ID and code stay the same. Note that App Store Connect uploads require a recent Xcode, which Codemagic provides.

## Troubleshooting
| Symptom | Fix |
| --- | --- |
| Sideloadly doesn't see the phone | Unlock the phone, re-plug, tap Trust. Make sure the iTunes and iCloud web (non-Store) versions are installed. |
| "Untrusted Developer" on launch | Step 7 |
| App opens then closes immediately after a week | The signature expired. Re-sign (step 8). |
| "Maximum number of apps" error | Remove an older sideloaded app, or wait for one to expire. |
| Codemagic build didn't start | Check the changed paths (docs-only and TV-only changes are skipped on purpose) and the Codemagic webhooks. For an .ipa, push a tag or start `ios-ipa` manually. |
