# Store listings and forms (PRD v2 M8)

Copy these into Google Play Console and App Store Connect. Graphics are in `assets/branding/` (made by `tools/branding/make-artwork.ps1`) and screenshots in `assets/branding/screenshots/`. Contact for every listing: mrman187@gmail.com. Privacy policy: https://devtestman187.github.io/game-controller/privacy.html

## Thumb Party (phones and tablets)

- **App name**: Thumb Party
- **Package / bundle ID**: `com.thumbparty.app`
- **Category**: Play: Game → Casual. App Store: Games, with Family as the secondary category.
- **Short description** (Play, 80 characters max):
  > Turn your phone into a game controller for the TV. Play together on any screen.
- **Subtitle** (App Store, 30 max): Play together on any screen
- **Full description**:
  > Thumb Party turns your phone or tablet into a game controller. Open Thumb Party TV on an Android TV or a Windows PC, pair your phone with a 4-digit code, and play on the big screen with family and friends.
  >
  > • Three ways to play: a D-pad with A, B, X and Y, gyro steering (tilt your phone), or two analog sticks
  > • Up to four players, each on their own phone
  > • Vibration you can feel for every press and every hit in the game, with strengths you can set
  > • Sized for small hands and big tablets alike
  > • Works on your home Wi-Fi: no accounts, no ads, nothing to sign up for
  >
  > This is a test version. You need the Thumb Party TV app on an Android TV, Google TV or Windows PC on the same Wi-Fi. No TV nearby? Tap "Try without a TV" to try the controls.
- **Screenshots**: `screenshots/phone-*.png` (Play needs at least 2; tablets optional: `screenshots/tablet-*.png`).
- **Play graphics**: icon `play-icon-app-512.png`, feature graphic `play-feature-app-1024x500.png`.

## Thumb Party TV (Android TV and Windows)

- **App name**: Thumb Party TV
- **Package**: `com.thumbparty.tv`
- **Devices**: Android TV only (leanback is required, so Play doesn't offer it to phones or tablets). First add the **Android TV** form factor (Test and release → Advanced settings → Form factors); the store listing then shows the TV banner and TV screenshot fields.
- **Category**: Game → Casual
- **Short description**:
  > The big screen for Thumb Party. Phones become controllers on your TV.
- **Full description**:
  > Thumb Party TV is the screen for Thumb Party. Open it on your Android TV or Google TV, and each player pairs a phone or tablet with the code on screen. Then play together on the big screen.
  >
  > • Pair a phone in seconds with a 4-digit code; it reconnects by itself next time
  > • See every controller, its ping and its input live
  > • A quick arena game for up to four players, with sounds and vibration on each phone
  > • No accounts and no ads; everything stays on your home Wi-Fi
  >
  > This is a test version. Each player needs the Thumb Party app on their phone or tablet (Android 12+ or iOS 26+), on the same Wi-Fi as the TV.
- **Graphics**: icon `play-icon-tv-512.png`, feature graphic `play-feature-tv-1024x500.png`, **TV banner** `play-tv-banner-1280x720.png`, TV screenshots `screenshots/tv-*.png` (1280×720).

## Google Play forms (both apps)

| Form | Answer |
| --- | --- |
| Privacy policy | https://devtestman187.github.io/game-controller/privacy.html |
| Ads | No, the app doesn't contain ads |
| Advertising ID | **No**, for both apps. Neither app nor any library in it uses the advertising ID: the release builds have no `AD_ID` permission (checked in the merged manifests, Oct 30, 2026) |
| App access | All functionality is available without special access. (Note for reviewers: it needs a second device to control; the phone app has "Try without a TV".) |
| Content rating | Category: Game. Violence, fear, sexuality, language, controlled substances, gambling: none. Users interact or exchange content: **No** (only devices on your own Wi-Fi). Shares location: no. Digital purchases: no. Expect "Everyone" / PEGI 3. |
| Target audience | **6–8, 9–12, 13–15, 16–17 and 18+** (families with children aged 6 and up; PRD v2 decision, Oct 30, 2026). Not "5 and under". This makes it a mixed-audience app under Google's **Families policy**: no ads (correct), no data collected (correct), store listing suitable for children (it is). If Play asks about ads or SDKs for children: none. |
| News app | No |
| Data safety | Does the app collect or share any of the required user data types? **No.** Is data encrypted in transit? Not applicable (nothing leaves the local network). Account deletion: not applicable (no accounts). |
| Government apps, financial features, health | None |

## App Store Connect (Thumb Party)

| Item | Answer |
| --- | --- |
| App privacy | **Data Not Collected** |
| Age rating | All "None" → **4+**, which lets children of any age use it. **Not** "Made for Kids": that category would need a parental gate in front of every link out of the app (PRD v2 decision). |
| Export compliance | Standard encryption only (`ITSAppUsesNonExemptEncryption` is false in Info.plist, so no question per build) |
| Feedback email | mrman187@gmail.com |
| Marketing / privacy URL | https://devtestman187.github.io/game-controller/ and …/privacy.html |

**TestFlight: Beta App Description**
> Thumb Party turns your iPhone or iPad into a game controller for a TV or PC. Please try all three layouts (D-pad, Gyro and Sticks) and tell us how the controls feel.

**TestFlight: What to Test** (per build; update each milestone)
> Pair with Thumb Party TV, try each layout in Test game, and check the vibration. On iPad, check the controls are easy to reach while holding it.

**Beta App Review: review notes**
> Thumb Party is a game controller: the phone sends input to the Thumb Party TV app on the same Wi-Fi network, which shows the game. To review without a TV, tap "Try without a TV" on the first screen: the controls work and a banner shows what a TV would receive. To try the full setup, run Thumb Party TV on a Windows PC (free download: https://github.com/devtestman187/game-controller/releases/latest), then pick the PC on the phone and type the 4-digit code shown on the PC. No account or sign-in is needed.

## M9: stats (update before the M9 builds go to testers)

From 0.9.0 the TV app can upload anonymous gameplay stats, only after an adult opts in on the TV. The phone records touch counters and sends them to the TV on the local network; each phone can opt out in Settings. The check against the Families policy: [families-check.md](families-check.md).

### Google Play: Data safety (both apps, the same answers)

| Question | Answer |
| --- | --- |
| Does your app collect or share any of the required user data types? | **Yes** |
| Is all of the user data collected by your app encrypted in transit? | **Yes** (HTTPS) |
| Do you provide a way for users to request that their data is deleted? | **Yes**: by email, with the Controller ID from the phone's Diagnostics |
| **App activity → App interactions** | Collected, not shared. Optional (users can choose). Purpose: **Analytics**, **App functionality**. Not processed ephemerally |
| **App info and performance → Diagnostics** | Collected, not shared. Optional. Purpose: **Analytics** (input delay, ping, reconnects, frame drops) |
| **App info and performance → Other app performance data** | Collected, not shared. Optional. Purpose: **Analytics** (the post-game face rating) |
| **Device or other IDs** | Collected, not shared. Optional. Purpose: **Analytics** (a random ID the app makes per install; not the advertising ID or any hardware ID) |
| Everything else (location, personal info, financial, health, messages, photos, audio, files, calendar, contacts, web browsing) | Not collected |

"Shared" means given to a third party: Firestore stores the data for us as a service provider, which Play doesn't count as sharing.

### App Store Connect: App Privacy (Thumb Party)

Change **Data Not Collected** to **Data collected**, then:

| Data type | Linked to the user? | Used for tracking? | Purpose |
| --- | --- | --- | --- |
| **Usage Data → Product Interaction** | No | No | Analytics, App Functionality |
| **Diagnostics → Performance Data** | No | No | Analytics |
| **Diagnostics → Other Diagnostic Data** | No | No | Analytics |

The phone app sends these only to the TV app on the local network; they reach the developer only if an adult allows it on the TV. Not linked to identity, no tracking, still no ads.

### Review notes to add (Play and TestFlight)

> 0.9.0 adds optional anonymous gameplay stats: the TV app asks an adult before sharing any, and each phone can turn them off in Settings → Control stats. No names, accounts, location or advertising IDs.
