# Releasing Thumb Party (store testing, PRD v2 M8)

Every milestone tag (`m8`, `m9`, … and fixes like `m8.1`) builds:

| What | Where it's built | Where it goes |
| --- | --- | --- |
| Thumb Party for iPhone and iPad | Codemagic, `ios-testflight` | TestFlight |
| Thumb Party for Android phones and tablets (`com.thumbparty.app`) | GitHub Actions, `release.yml` | Google Play closed testing (automatic once the service account is set up, by hand before that) |
| Thumb Party TV for Android TV (`com.thumbparty.tv`) | GitHub Actions, `release.yml` | Google Play closed testing, Android TV track |
| Thumb Party TV for Windows | GitHub Actions, `release.yml` | A GitHub Release with the zip |

Version name: `version:` in each app's `pubspec.yaml` (both apps share it). Build number: the number of commits, the same on every store, shown in the phone's **Settings → About** and at the top of the TV home screen.

The tester guide and privacy policy are in `site/` and publish to https://devtestman187.github.io/game-controller/ on every push that changes them (`pages.yml`).

## One-time setup

Do these in order. Steps marked **(you)** need your accounts; tell Claude Code when each is done and it continues from there. Nothing secret goes into the repository.

### 1. GitHub Pages (you)
GitHub → the repository → **Settings → Pages** → **Source: GitHub Actions**. Then GitHub → **Actions → Pages → Run workflow** (or push a change to `site/`). The guide appears at the address above within a minute or two.

### 2. The Play upload key (you, on this PC)
```powershell
powershell -ExecutionPolicy Bypass -File tools\make-upload-key.ps1
```
Choose a strong password when keytool asks, and save it in your password manager. The key goes to `%USERPROFILE%\.thumbparty\` (back that folder up). The script then prints four `gh secret set` commands: run them from the repository folder to give the release workflow the key. Local release builds use it too (through `THUMBPARTY_KEY_PROPERTIES`).

### 3. Google Play Console (you)
For **each** app, `Thumb Party` and `Thumb Party TV`:
1. **Create app**: the name, default language English (US), **Game**, **Free**. Accept the declarations.
2. **Test and release → Setup → App integrity**: keep **Play App Signing** on (Google keeps the app signing key, and ours is only the upload key).
3. **Grow → Store presence → Main store listing**: texts and graphics from [store-listing.md](store-listing.md) and `assets/branding/`.
4. **Policy → App content**: privacy policy URL, ads (none), app access (all features available without special access), content rating questionnaire, **target audience: ages 6–8, 9–12, 13–15, 16–17 and 18+** (Families policy applies), data safety (no data collected or shared), government apps (no), financial features (none), health (none). Answers are in [store-listing.md](store-listing.md).
5. **Testing → Closed testing**: create a track (keep the name Play suggests, `Closed testing`), **Testers → Google Groups**: add the group from step 4 below. Countries: add yours (or all).
6. Upload the first build by hand: **Create new release** → upload the `.aab` from the `play-bundles` artifact of the latest **Release** run on GitHub (Actions → Release → the run → Artifacts) → **Save → Review → Start rollout**. Play only accepts later uploads from the workflow after this.

For **Thumb Party TV** also: **Test and release → Advanced settings → Form factors → Add form factor → Android TV**, accept the TV requirements, upload the TV banner and TV screenshots, then use the **Android TV only** closed testing track it creates for the TV `.aab`. Android TV releases get an extra review for TV quality, which can take a few days.

### 4. Testers group (you)
Create a Google Group (groups.google.com), for example `thumb-party-testers`, with **Anyone on the web can join** (or invite only, if you prefer). Add it to both apps' closed testing tracks. Testers join the group, then open each app's testing link (Play Console → the track → **Testers → Copy link**). Send Claude Code the group link and both testing links: they go into the tester guide.

### 5. Automatic Play uploads (you, optional but recommended)
1. Google Cloud console: create a project, enable the **Google Play Android Developer API**, create a **service account** and a **JSON key** for it. Save the file as `play-service-account.json` outside the repository.
2. Play Console → **Users and permissions → Invite new users**: the service account's email, with **Release apps to testing tracks** for both apps.
3. Add the secret and the track names (from the repository folder):
   ```powershell
   Get-Content play-service-account.json -Raw | gh secret set PLAY_SERVICE_ACCOUNT_JSON
   gh variable set PLAY_TRACK_APP --body "<the phone app's closed track API name, e.g. alpha>"
   gh variable set PLAY_TRACK_TV --body "<the TV track's name>"
   ```
   The track names are on each track's page in Play Console. The TV app is its own Play app, so its tracks have plain names like `alpha` (no `tv:` prefix; that is only for TV tracks inside a phone app).

### 6. App Store Connect and TestFlight (you)
1. **Certificates, Identifiers & Profiles → Identifiers → +**: App ID `com.thumbparty.app`, name Thumb Party. No extra capabilities.
2. **App Store Connect → Apps → + → New App**: iOS, name **Thumb Party**, English (US), bundle ID `com.thumbparty.app`, SKU `thumbparty-app`. If the name is taken on the App Store, use "Thumb Party Controller" and tell Claude Code.
3. **Users and Access → Integrations → App Store Connect API → +**: name `Codemagic`, access **App Manager**. Download the `.p8` file (only once possible) and note the **Issuer ID** and **Key ID**.
4. **Codemagic → Team settings → Integrations → Developer Portal → Manage keys → Add key**: name it exactly **Thumb Party**, and enter the Issuer ID, Key ID and `.p8` file.
5. **Codemagic → Team settings → Code signing identities**: **iOS certificates → Generate certificate** (type *Apple Distribution*, using the Thumb Party key), then **iOS provisioning profiles → Fetch profiles** and pick the *App Store* profile for `com.thumbparty.app` (create it in the Apple portal if it isn't listed: Profiles → + → App Store Connect → `com.thumbparty.app`).
6. **TestFlight → Test Information**: feedback email, privacy policy URL, the **Beta App Description** and **Review notes** from [store-listing.md](store-listing.md).
7. **TestFlight → Internal Testing → +**: a group for yourself. Builds reach it right after processing, without review.
8. After the first build has passed Beta App Review: **External Testing → +** a group named `Testers`, add the build, and turn on **Public Link**. Send Claude Code the link (it goes into the tester guide) and it adds the group to `codemagic.yaml` so later builds go to it by themselves.

### 7. Firebase for the stats upload (you, M9, optional)
The TV app keeps every session's stats on the device either way. With an adult's consent it also uploads them to Firestore, so testers' sessions reach you. Until this is done the Stats screen says "this build has no upload set up".
1. https://console.firebase.google.com → **Create a project** with the same Google account as the Play developer account. Name it e.g. `thumb-party-stats`. Turn **Google Analytics off** (the apps don't use it).
2. **Build → Firestore Database → Create database**, production mode, a location near you (e.g. `us-central1`). The free Spark plan is enough.
3. **Firestore → Rules**: paste `firebase/firestore.rules` from this repository and **Publish**. They let the TV app create session documents and nothing else.
4. **Project settings → General**: copy the **Project ID**. Optional: under "Your apps", add a **Web app** only to get its **Web API key** (no Firebase SDK is used).
5. Set the GitHub variables:
   ```
   gh variable set FIRESTORE_PROJECT --body "<project ID>"
   gh variable set FIRESTORE_API_KEY --body "<web API key, or leave this one out>"
   ```
6. Reading the data: `gcloud auth login`, then in `packages/metrics`: `dart run metrics:report --firestore <project ID> --token "$(gcloud auth print-access-token)" --csv sessions.csv`. Or Export on the TV's Stats screen and `dart run metrics:report <folder>`.
7. The store forms change with M9: see "M9: stats" in [store-listing.md](store-listing.md) and the check in [families-check.md](families-check.md). Update them before the M9 builds go to testers.

## Each release
1. Make sure `version:` in both `pubspec.yaml` files and `appVersion` in both `lib/src/app_info.dart` say the new version.
2. Tag with release notes and push: `git tag -a m9 -m "What changed, for testers"` then `git push origin m9`. Every release needs notes, even "Minor update for testing."
3. Codemagic uploads to TestFlight (Beta App Review for external testers, usually within a day). GitHub Actions builds the bundles and the Windows zip, uploads to Play (once set up), and creates the GitHub Release.
   The notes go to Play "What's new" (500 characters), TestFlight "What to Test" and the GitHub Release, from `tools/release-notes.sh`: the tag's message, or the commit subjects since the last tag if the tag has no message.
4. Installed apps update from TestFlight and Play. Windows testers download the new zip.

## If something goes wrong
| Problem | Fix |
| --- | --- |
| Release workflow: "The Play upload key secrets are missing" | Step 2: run the script and the `gh secret set` commands. |
| Play: "The Android App Bundle was signed with the wrong key" | The upload key must be the one registered with Play App Signing. Upload once by hand with the key from step 2, or ask Play for an upload key reset. |
| Play: "Version code has already been used" | Every upload needs a new commit (the build number is the commit count). Commit something and tag again. |
| Codemagic: no signing profile for `com.thumbparty.app` | Step 6.5. |
| Codemagic: "Integration 'Thumb Party' not found" | Step 6.4: the key's name must be exactly `Thumb Party`. |
| TestFlight build stuck in "Missing Compliance" | `ITSAppUsesNonExemptEncryption` is in Info.plist, so this shouldn't happen. If it does, answer "None of the algorithms mentioned above". |
