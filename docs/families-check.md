# Families policy check for the M9 stats (PRD v2 M9)

The apps target ages 6 and up, so Google Play's Families policy applies (a mixed-audience app: children and older players). M9 adds anonymous gameplay statistics. This page checks them against the policy before the M9 builds go to testers. Policy read on Oct 31, 2026: https://support.google.com/googleplay/android-developer/answer/9893335. It isn't legal advice; the policy itself suggests counsel for anything unclear.

## What is collected, and where it goes

| Data | Where it's made | Where it goes |
| --- | --- | --- |
| Touch counters per input mode: presses and how long they're held, empty taps (counts on a 6 by 3 grid), near misses, slide-offs, rapid taps, stick and tilt times, recalibrations | Phone | To the TV app on the home Wi-Fi only. The phone itself sends nothing to the internet |
| The settings in effect (button size, sensitivity, haptics on or off, …) | Phone | TV |
| Device class: phone or tablet, screen size in mm, model (e.g. "Google Pixel 8"), OS version, whether it can vibrate | Phone | TV |
| A random install ID per phone (made by the app, not the Android ID or any hardware ID) | Phone | TV |
| Input delay, ping, reconnects, frame drops | TV | Stays on the TV |
| Arena results (rounds, wins, wall hits) and the face rating with its tags | TV | Stays on the TV |
| **The session summary of all the above** | TV | **Only with an adult's opt-in on the TV**: one document per session to Firestore over HTTPS. Otherwise it stays on the TV |

Never recorded or sent: names or nicknames (the phone's label such as "iPhone 3F1C" stays on the TV screen), contacts, photos, location, email, accounts, advertising IDs, Wi-Fi details (SSID, BSSID, IP or MAC addresses), touch traces. The TV keeps only known counters from a phone and drops anything else, and drops device strings that don't look like a model or version (`sanitizeSegmentData`, `SessionCollector`). Tests check that an exported session has no names or addresses.

## Against the policy

| Requirement | M9 | OK? |
| --- | --- | --- |
| Don't transmit AAID, SIM serial, Build serial, BSSID, MAC, SSID, IMEI or IMSI from children or users of unknown age | None of them is read or sent. The install ID is a random value the app makes | Yes |
| No location permission or precise location for child-directed apps | No location permission in either app | Yes |
| Only Families Self-Certified **Ads** SDKs may show ads to children | No ads, no ad SDK | Yes |
| Non-ad SDKs must be approved for child-directed services, or not collect children's data | No SDK at all: the upload is a plain HTTPS request to the Firestore REST API (no Firebase SDK, no Google Analytics) | Yes |
| No AD_ID permission (for apps aimed solely at children on API 33+) | Not requested (checked in the M8 merged manifests) | Yes |
| Disclose personal and sensitive data collected from children, including device data | Disclosed in the privacy policy and the Data safety form (below). Device model and OS count as device data | Do the forms |
| Consent | Upload is off until an adult opts in on the TV (the prompt says it's for the adult in charge). Each phone shows that stats are recorded and can opt out in Settings. Choice changeable any time on the TV's Stats screen | Yes |

COPPA note: the data is anonymous and used only to improve the controls (internal operations), with an adult's opt-in, and never sold or shared.

## What you change in the consoles before the M9 builds reach testers

1. **Play Console → both apps → App content → Data safety**: answers in [store-listing.md](store-listing.md), "M9: stats". The phone app collects nothing over the internet itself, but its counters reach us through the TV app, so both apps declare the same data, to be safe.
2. **App Store Connect → Thumb Party → App Privacy**: change "Data Not Collected" to the M9 answers in store-listing.md.
3. Privacy policy: updated on the site with the M9 changes (site/privacy.html).
4. Firebase: the project under the Play developer account, with the rules in `firebase/firestore.rules` (release.md step 7).

## Risks left

- Anyone who finds the project ID could create junk session documents (the rules check the shape and size, not who sent it). The free plan's daily write limit caps the damage, and the report tool can filter by app version. App Check could be added later.
- Deletion: sessions aren't linked to a person. If someone asks for their data to be deleted, they can send the install ID (the "Controller ID" in the phone's Diagnostics) and every session with it is deleted by hand.
