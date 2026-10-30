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
| App access | All functionality is available without special access. (Note for reviewers: it needs a second device to control; the phone app has "Try without a TV".) |
| Content rating | Category: Game. Violence, fear, sexuality, language, controlled substances, gambling: none. Users interact or exchange content: **No** (only devices on your own Wi-Fi). Shares location: no. Digital purchases: no. Expect "Everyone" / PEGI 3. |
| Target audience | **13–15, 16–17 and 18+** (family audience, children play with adults; PRD v2 decision). "Could the app unintentionally appeal to children?": answer honestly; if Play asks for more, the privacy design already meets the Families policy. |
| News app | No |
| Data safety | Does the app collect or share any of the required user data types? **No.** Is data encrypted in transit? Not applicable (nothing leaves the local network). Account deletion: not applicable (no accounts). |
| Government apps, financial features, health | None |

## App Store Connect (Thumb Party)

| Item | Answer |
| --- | --- |
| App privacy | **Data Not Collected** |
| Age rating | All "None" → **4+**. Not "Made for Kids" (PRD v2 decision: outside the Kids category). |
| Export compliance | Standard encryption only (`ITSAppUsesNonExemptEncryption` is false in Info.plist, so no question per build) |
| Feedback email | mrman187@gmail.com |
| Marketing / privacy URL | https://devtestman187.github.io/game-controller/ and …/privacy.html |

**TestFlight: Beta App Description**
> Thumb Party turns your iPhone or iPad into a game controller for a TV or PC. Please try all three layouts (D-pad, Gyro and Sticks) and tell us how the controls feel.

**TestFlight: What to Test** (per build; update each milestone)
> Pair with Thumb Party TV, try each layout in Test game, and check the vibration. On iPad, check the controls are easy to reach while holding it.

**Beta App Review: review notes**
> Thumb Party is a game controller: the phone sends input to the Thumb Party TV app on the same Wi-Fi network, which shows the game. To review without a TV, tap "Try without a TV" on the first screen: the controls work and a banner shows what a TV would receive. To try the full setup, run Thumb Party TV on a Windows PC (free download: https://github.com/devtestman187/game-controller/releases/latest), then pick the PC on the phone and type the 4-digit code shown on the PC. No account or sign-in is needed.
