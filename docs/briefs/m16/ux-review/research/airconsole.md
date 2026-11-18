# AirConsole — player-flow competitive research digest

**Subject:** AirConsole (N-Dream AG) — phone-as-controller party gaming platform, big screen as host.
**Taxonomy:** `worker-spec.md` §1 — the 13 stages, mapped by number below.
**Purpose:** competitive reference for Thumb Party (phones as controllers, TV as host). AirConsole is the
closest commercial analog, so join and drop/re-entry are treated at greater depth (§A and §B).
**Method:** desk research only. No device was captured, no app was installed, no AirConsole session was
opened. Every claim below is documentation-level and is quoted with its URL. Pixel sizes, contrast ratios
and viewport measurements are **not available** from documentation and are marked `unmeasured` — this file
is not a findings record and does not attempt §2 of the worker spec.

**Evidence classes used**
- `[official-help]` — AirConsole Help Center (Zendesk), customer-facing wording.
- `[official-dev]` — developers.airconsole.com guidelines / `airconsole.github.io` API reference.
- `[official-marketing]` — airconsole.com product copy.
- `[press]` — third-party editorial.
- `[user]` — customer review / forum post; treated as low confidence.

---

## 0. Stage map at a glance

| # | Stage | Verdict | One line |
|---|---|---|---|
| 1 | Launch / first run | **present** | Big screen: a `START PLAYING` button; in-car first launch plays an intro video. Controller: choose Guest or a linked account. |
| 2 | Host setup | **present** | Open airconsole.com (or the TV app), press start, and the big screen shows a connect code plus a QR code. No account needed to host. |
| 3 | Party join | **present, well developed** | Scan the QR (deep-links to the controller) or type the code in the app/web app; many phones, one code. |
| 4 | Player creation / colour & accessory | **partial** | Nickname is prompted once and skipped afterwards; avatar is a profile photo from the account. **Colour and accessory selection: absent.** |
| 5 | Lobby & waiting | **present** | A "Player Lobby" on the phone and a screen-side lobby with the QR at the left; the master controller confirms "Has everyone joined?". |
| 6 | Game selection | **present** | Store renders on the big screen; the master controller is the only device that can pick or change a game. |
| 7 | Round intro / countdown | **absent** at platform level | Per-game. The only platform-owned countdown is the 3-second resume countdown after a pause. |
| 8 | In-round controls | **present as a platform shell** | Controller *views* are per game; the shell (top bar, logo menu, orientation, stay-alive, fullscreen) is the platform's. |
| 9 | Round end | **absent** at platform level | Per-game. |
| 10 | Results / scoreboard | **absent** at platform level | Per-game. The platform offers persistent high scores and profile stats instead of a session scoreboard. |
| 11 | Next round / Play again | **absent** at platform level | Per-game. Platform offers "Change Game" and an optional full-screen multiscreen ad between games. |
| 12 | End of night | **absent** | No session-end screen, summary, or goodbye exists in any source reviewed. The session ends implicitly when the big screen closes or refreshes. |
| 13 | Re-entry after a drop | **present — the most engineered layer** | `device_id` is reserved per device across disconnect and reconnect; platform supplies a pause overlay and a 3-second resume countdown; the game chooses one of 5 documented handling levels. |

---

## A. How a party starts, and how players join (stages 1–3) — deep dive

### A1. Stage 1 — Launch / first run

Big screen, web: `airconsole.com` is the entry surface; the first-run action is a single button. Product copy
lists the sequence as: "Open www.airconsole.com in your browser, open the AirConsole chrome app or AirConsole
on your Android Tv. Then open www.airconsole.com on your phone browser or download the app. **Push the START
button on the big screen.**" — [AirConsole About](http://www.airconsole.com/file/airconsole-info.html)

Big screen, TV: a store install, then open. "**TV:** Open the AirConsole TV App (see [Play on TV](https://airconsole.zendesk.com/hc/en-us/articles/4405279964946-Play-on-TV)
for supported TVs), or connect a PC to your TV via HDMI and go to airconsole.com."
— [How to Connect](https://airconsole.zendesk.com/hc/en-us/articles/360014511400-How-to-Connect). Store listings for the TV apps are on
[About the AirConsole Apps](https://airconsole.zendesk.com/hc/en-us/articles/360015064779-About-the-AirConsole-Apps).
(The older help-centre slug `360014511400-Connect-Code-QR-Code` is the *same article id* as How to Connect — a
rename, not a second page, so it is cited once here.)

Big screen, car (the only surface with a documented first-run *video*): "If you're launching the app for the
first time, an intro video will play. After that, or on subsequent launches, you'll see a connect screen with
a connect code and a QR code." — [Play in Audi](https://airconsole.zendesk.com/hc/en-us/articles/29648195287708-Play-in-Audi)

Controller, first run: there is no onboarding tour. The first-run decision is *identity*, made before the code
is entered: "Open the AirConsole App (recommended) or go to airconsole.com in your phone's browser. **Choose
how you want to continue, as Guest, or linked to Google / iOS / Facebook / email.** We recommend linking an
account so your game progress doesn't get lost. Then enter the code shown on the Big Screen."
— [How to Connect](https://airconsole.zendesk.com/hc/en-us/articles/360014511400-How-to-Connect)

Read-across: the platform's first run is split across two devices with different first-run content (a button on
the screen, an identity choice on the phone, a video only in cars). Thumb Party's stage 1 is a single-device
app, so this split does not transfer directly — but the *ordering* does: AirConsole asks for identity **before**
asking for the code (see A2), so the code screen is the last step of joining, not the first.

### A2. Stage 2 — Host setup

The host does nothing but start. "Whatever you use, your Big Screen will now show a **connect code** and a
**QR code**." — [How to Connect](https://airconsole.zendesk.com/hc/en-us/articles/360014511400-How-to-Connect)

There is no host account, no host name, no room name, and no host configuration step documented anywhere
reviewed. The session is identified only by its code. The code is generated by the platform and handed to the
game on ready: `onReady(code)` — "Gets called when the game console is ready… `code` | string | The AirConsole
join code." — [AirConsole Connectivity API](https://airconsole.github.io/airconsole-api/AirConsole-Connectivity.html)

Read-across: hosting is zero-configuration. The tradeoff AirConsole accepts is that the room has no name and no
persistent identity — a new session is a new code, and there is no way to re-open last night's room.

### A3. Stage 3 — Party join (code / QR flow)

Two documented paths, and the QR path is a deep link into the controller, not a code to retype:

> "You have two options: **1. Scan the QR code** shown on the Big Screen with your phone's camera. This will
> take you straight to the AirConsole Controller. **2. Enter the connect code manually.** Open the AirConsole
> App (recommended) or go to airconsole.com in your phone's browser…" — [How to Connect](https://airconsole.zendesk.com/hc/en-us/articles/360014511400-How-to-Connect)

The in-car article states the same two paths and names the redirect target: "Use your phone's camera to scan
the QR code. You will be redirected to the AirConsole Controller Web App (or the AirConsole Controller app, if
you have it installed)." — [Play in Audi](https://airconsole.zendesk.com/hc/en-us/articles/29648195287708-Play-in-Audi)

Codepoints of the flow:

1. **The screen shows the code.** "your Big Screen will now show a connect code" — [How to Connect](https://airconsole.zendesk.com/hc/en-us/articles/360014511400-How-to-Connect).
2. **The phone opens the controller surface.** Two surfaces are supported: the native app (iOS / Android /
   Amazon) and the mobile web app. App store links: [About the AirConsole Apps](https://airconsole.zendesk.com/hc/en-us/articles/360015064779-About-the-AirConsole-Apps).
3. **Identity choice** (Guest or linked account) — [How to Connect](https://airconsole.zendesk.com/hc/en-us/articles/360014511400-How-to-Connect).
4. **Code entry or QR scan** — [How to Connect](https://airconsole.zendesk.com/hc/en-us/articles/360014511400-How-to-Connect).
5. **Nickname prompt, once** — see stage 4.
6. **Landing in the lobby** — "Once connected, you'll land in the **Player Lobby**." — [How to Connect](https://airconsole.zendesk.com/hc/en-us/articles/360014511400-How-to-Connect).

**Many phones, one code.** "Multiple people can join the same session with the same connect code and their own
phone." — [How to Connect](https://airconsole.zendesk.com/hc/en-us/articles/360014511400-How-to-Connect).
"The number of players is not limited to 2… Additional players can easily join the same session, needing
nothing except a smartphone and an internet connection, making AirConsole ideal for spontaneous play sessions
at parties" — [AirConsole About](http://www.airconsole.com/file/airconsole-info.html).

**The controller follows the screen.** Controllers are attached to the *session*, not to a game, and are
re-targeted when the screen navigates: "Browse the AirConsole Store on the Big Screen, pick a game, and **your
phone automatically becomes the right kind of controller for that game**." — [How to Connect](https://airconsole.zendesk.com/hc/en-us/articles/360014511400-How-to-Connect).
The platform moves all devices together: `navigateTo(url, parameters)` — "Request that all devices load a game
by url or game id."; `navigateHome()` — "Request that all devices return to the AirConsole store."
— [Navigation API](https://airconsole.github.io/airconsole-api/AirConsole-Navigation.html)

**Player cap.** There is no platform-wide cap; the cap is per game and configured by the developer, and the
platform expects the *game* to render the overflow state. AirConsole staff answer: "There is no limit by
default. The number of players that will be considered depends on what your screen defines when you call
`setActivePlayers(numberOfPlayers)`… For the game in the store: You configure that on airconsole.com/developers
in your game." — [Stack Overflow, answer citing AirConsole configuration](https://stackoverflow.com/questions/77410095/maximum-number-of-players).
The developer guideline is explicit that the overflow case must be designed: "**If the game is full, the player
above the maximum should has a message indicating it.**" [sic] — [UX design for connect/disconnect events](https://developers.airconsole.com/ux-design-for-connectdisconnect-events).
An independent review reports per-game counts of "some support 4, others up to 8" and confirms "I couldn't
find a documented platform-wide cap" — [GeekExtreme review](https://www.geekextreme.com/airconsole-review-free-games-worth/).

**Network assumption is contradicted across official pages.** Marketing: "You do not have to be connected to
the same WiFi to be able to play together." — [AirConsole About](http://www.airconsole.com/file/airconsole-info.html).
Help Center tip: "All devices (Big Screen and phones) should be on the **same WiFi network**." — [How to Connect](https://airconsole.zendesk.com/hc/en-us/articles/360014511400-How-to-Connect).
The troubleshooting article repeats the same-WiFi advice as the first fix: "**Use the same WiFi**: Please make
sure all players are connected to the same Wifi as your AirConsole console device" — [Disconnects](https://airconsole.zendesk.com/hc/en-us/articles/360014580319-Disconnects).
Recorded here as a documented inconsistency, not resolved by the sources.

**Gaps in the join flow (marked, not filled).**
- The **code length** is not stated in any official page reviewed. Secondary press consistently reports six
  digits: "you will see a six-digit code" — [PC Tech Magazine, 2016](https://pctechmag.com/2016/12/party-gaming-with-airconsole/);
  "den sechsstelligen Code" — [CHIP, 2025](https://www.chip.de/downloads/webapp-AirConsole-Multiplayer-Spiele-fuer-Freunde_164034286.html).
  Treated as **reported, not confirmed**; exact length `unmeasured`.
- Whether the QR **pre-fills the code** or only opens the controller is not documented. `unmeasured`.
- No documented **invalid/expired-code error state**. `unmeasured` (an absence of documentation, not proof of
  an absent screen).

---

## B. Stage 4 — Player creation / colour & accessory

AirConsole separates *account profile* from *session identity*, and the session asks for very little.

**What is prompted:** a nickname, once. "A screen will appear prompting you to enter your nickname. **If you've
used the app before and already set a nickname, this step will be skipped.** Otherwise, enter your nickname and
press **'Continue'**." — [Play in Audi](https://airconsole.zendesk.com/hc/en-us/articles/29648195287708-Play-in-Audi)

**Where the avatar comes from:** the account profile, not a picker. Profile contents are listed as "Your
nickname and avatar photo" — [Profile](https://airconsole.zendesk.com/hc/en-us/articles/4405557079698-Profile).
Editing is a settings action, not a lobby action: "Open AirConsole, press the three stripes on the top right to
open the Menu and select 'Profile'. There you can select the Pen icon that is next to your profile picture to
edit your profile." — [Profile](https://airconsole.zendesk.com/hc/en-us/articles/4405557079698-Profile).
The API exposes both fields to games: `getNickname(device_id)`, `getProfilePicture(device_id_or_uid, size)` —
"Returns the url to a profile picture of the user", with `size` defaulting to **64 px**
— [Profile API](https://airconsole.github.io/airconsole-api/AirConsole-Profile.html). Games can also force the
editor: `editProfile()` — "Lets the user change his nickname, profile picture and email address. If you need a
real nickname of the user, use this function." — [Profile API](https://airconsole.github.io/airconsole-api/AirConsole-Profile.html).

**Colour: absent at platform level.** No source reviewed shows a colour picker, a colour wheel, or an
auto-assigned player colour in the join or lobby flow. Colour appears only as something a *game* may store:
"If a player chooses to be the color blue, he sets his custom device state with
`airconsole.setCustomDeviceStateProperty("my_color", "blue")`" — [Device Ids and state](https://developers.airconsole.com/device-ids-and-state),
and as a design suggestion to games: "This can be used for something as simple as displaying the player color"
— [Smartphones as Controllers](https://developers.airconsole.com/smartphones-as-controllers).

**Accessory: absent.** No accessory, hat, emote or any customisation object appears in any source reviewed.

**Read-across:** this is the clearest structural difference from Thumb Party. AirConsole's session identity is
*(nickname, photo)* and nothing else; the phone is told apart by avatar, not by a colour the player chose.
Colour is pushed down into each game, which means a player's colour is not stable across a night. Any
Thumb Party design that assigns colour in stage 4 is adding a stage AirConsole does not have.

---

## C. Stage 5 — Lobby & waiting

Two lobbies exist and the sources describe both, from different angles.

**Phone side — "Player Lobby":** "Once connected, you'll land in the **Player Lobby**. The main controller (Host)
will then be able to start the session." — [How to Connect](https://airconsole.zendesk.com/hc/en-us/articles/360014511400-How-to-Connect).
It is also the place where a waiting player is parked while a round runs: with player silencing enabled, "New
players will be informed that they need to wait for the game round to finish on their controller."
— [Handling players connecting](https://developers.airconsole.com/handling-players-connecting)

**Screen side — lobby with the join affordance:** "You've now entered the **Lobby**. Wait for other players to
connect. They can do so by scanning the **QR code shown on the left side of the Lobby screen**."
— [Play in Audi](https://airconsole.zendesk.com/hc/en-us/articles/29648195287708-Play-in-Audi)
The QR stays visible in the lobby, so joining remains possible while others wait.

**The host's start gate is a confirmation, not a countdown:** "The **first player** to connect becomes the
**Main Controller** and will choose the games. Once everyone has joined, confirm by pressing **'Yes'** on the
Main Controller ('Has everyone joined?')." — [Play in Audi](https://airconsole.zendesk.com/hc/en-us/articles/29648195287708-Play-in-Audi)
There is no documented timer, no auto-start, and no "ready" state per player. The gate is one human asking the
room a question and answering it on their own phone.

**Who is in the room is shown by avatars in a top bar:** the disconnect article describes the two states as
changes to "your profile image in the top bar" — a pulsating red overlay for a bad connection, disappearance
for a disconnect (see §J2). — [Disconnects](https://airconsole.zendesk.com/hc/en-us/articles/360014580319-Disconnects)
The article does not say whether "the top bar" is on the big screen or the controller, so the surface is
`unmeasured`.

**Late arrival while a round is live** is a designed state, not an error. Player silencing exists precisely for
it: "It ensures that newly joined players are not known to the game until the game round is finished." —
[Handling players connecting](https://developers.airconsole.com/handling-players-connecting). It is **off by
default**: "Player Silencing is by default not enabled!" — same URL. The platform also defines lobby
promotion after a drop: "If players disconnect from the session then a player that was ''waiting to connect''
should automatically be placed in the lobby." — [UX design for connect/disconnect events](https://developers.airconsole.com/ux-design-for-connectdisconnect-events)

**Read-across:** the lobby does three jobs — show the QR, show who is present (avatars), and hand start
authority to exactly one device. The "Has everyone joined?" confirmation is worth noting as a pattern: it puts
the readiness check on the host's phone rather than on the TV, where the host would have to walk to the screen.

---

## D. Stage 6 — Game selection

**The store is a screen surface; the choosing is done on one phone.** The two facts are split across pages and
must be read together:

- "Browse the AirConsole Store on the Big Screen, pick a game, and your phone automatically becomes the right
  kind of controller for that game." — [How to Connect](https://airconsole.zendesk.com/hc/en-us/articles/360014511400-How-to-Connect)
- "The **first player** to connect becomes the **Main Controller** and will choose the games."
  — [Play in Audi](https://airconsole.zendesk.com/hc/en-us/articles/29648195287708-Play-in-Audi)
- "**Use your controller to select and start a game.**" — [Play in Audi](https://airconsole.zendesk.com/hc/en-us/articles/29648195287708-Play-in-Audi)
- Marketing's step 5 of the whole product: "Navigate through the library using your new gamepad"
  — [AirConsole About](http://www.airconsole.com/file/airconsole-info.html)

So: the library renders on the TV, and the master controller's phone is the input device that moves through it.
There is no per-player vote, no queue, no "everyone pick one" screen in any source reviewed.

**Authorisation is enforced at product level, not just UI:** "Only one player, the 'Master' controller, is able
to change the game." — [How can I change a game?](https://airconsole.zendesk.com/hc/en-us/articles/360015054759-How-can-I-change-a-game)

**Who is master.** Normally the first to connect, but not strictly: `getMasterControllerDeviceId()` —
"Returns the device ID of the master controller. **Premium devices are prioritzed.**" [sic]
— [Connectivity API](https://airconsole.github.io/airconsole-api/AirConsole-Connectivity.html). A paying
player can therefore outrank the first joiner for control of the room. This is a monetisation rule embedded in
the flow, and it is not disclosed anywhere in the help centre.

**Changing game mid-night** is a controller-menu action: "To open the menu tap the AirConsole logo on top. The
menu will pop up and you can now select **'Change Game'**." — [How can I change a game?](https://airconsole.zendesk.com/hc/en-us/articles/360015054759-How-can-I-change-a-game).
The same menu is documented for exiting a game: "To get out of the game you can just hit the AirConsole logo on
the controller which will take you back to the store." — [Product Hunt, AirConsole team answer](https://www.producthunt.com/p/airconsole/airconsole)
(2015; corroborates the logo-as-menu affordance).

**Documented label inconsistency:** the help-centre FAQ calls the menu item **"Change Game"** ([URL above](https://airconsole.zendesk.com/hc/en-us/articles/360015054759-How-can-I-change-a-game)),
while the in-car walkthrough calls it **"New game"**: "tap the AirConsole logo at the top of your controller
screen and choose '**New game**'" — [Play in Audi](https://airconsole.zendesk.com/hc/en-us/articles/29648195287708-Play-in-Audi).
Same control, two names, across two official pages. Flagged for Thumb Party's copy review.

---

## E. Stage 7 — Round intro / countdown

**Absent at platform level.** No source reviewed describes the platform drawing a round intro, a "get ready",
or a round-start countdown. Games own that surface; the guidelines only tell developers to manage *controller
views* for their own phases — "Views are different controller layouts for different ingame situations" —
[Smartphones as Controllers](https://developers.airconsole.com/smartphones-as-controllers) — and describe
per-game states such as "the player has died and is waiting for respawn" — same URL.

The one countdown the platform does own is a **resume** countdown, not a round intro: "AirConsole will show a
countdown overlay for **3 seconds** before onResume event is called."
— [Handling unstable connections](https://developers.airconsole.com/handling-unstable-connections). Numbers
used: 3 seconds.

---

## F. Stage 8 — In-round controls

**Present, but as a shell around per-game views.**

What the platform provides for every game, without game code: "AirConsole already handles a bunch of issues for
you like full-screen mode, device-orientation or stay-alive" — [Developers home](https://developers.airconsole.com/).
Orientation is settable by the game: `setOrientation(...)` — [User Interface API](https://airconsole.github.io/airconsole-api/AirConsole-User_Interface.html).
The controller top bar persists in-game and carries the AirConsole logo (the menu affordance, stage 6) and the
player's profile image (the connection indicator, §J2) — [Disconnects](https://airconsole.zendesk.com/hc/en-us/articles/360014580319-Disconnects).

What the game provides: the whole control surface, as one of several *views*. The platform's own design rules
for that surface are unusually prescriptive and are the most quotable part of the developer docs:

- "Use different controller views / layouts for different situations"
- "Label buttons / interactive areas with their actual function"
- "Make all buttons / interactive areas as big as possible"
- "**Do not use d-pads and virtual joysticks**"
- "Make use of personalized controllers for individual players"

— all from [Smartphones as Controllers](https://developers.airconsole.com/smartphones-as-controllers). The same
page explains the reason for the size rule: "A player's finger may slip over the screen while they are not
looking down… To combat this, interactive areas / buttons on AirConsole controllers should be made as big as
possible" — same URL. It also states the constraint plainly: virtual joysticks "will _**always**_ feel subpar on
a smartphone controller" — same URL.

State transport during play is the platform's, and is lossless-by-design: "The AirConsole API makes sure that no
messages and updates from the Screen and the Controllers are lost. A message or update sent by a device is
guaranteed to arrive at some point in the right order even if the internet connection was disrupted, but the
latency can be high." — [Handling unstable connections](https://developers.airconsole.com/handling-unstable-connections)

---

## G. Stage 9 / 10 — Round end and results

**Stage 9 (round end): absent at platform level.** No platform-owned round-end screen, no "round over"
interstitial, no transition owned by AirConsole. The only documented transitions are the game's own state
change and the platform's pause/resume overlay (see §J3).

**Stage 10 (results / scoreboard): absent at platform level, with a persistent substitute.** No source
reviewed shows a session scoreboard or an end-of-round ranking drawn by the platform. What the platform does
provide is *asynchronous, per-account* scoring, exposed to games as an API:

- `storeHighScore(...)`, `requestHighScores()`, `onHighScores(...)`, `onHighScoreStored(...)`
  — [High Scores API](https://airconsole.github.io/airconsole-api/AirConsole-High_Scores.html)
- The scored object is **not a room**: `requestHighScores()` returns ranks of `"world"`, `"country"`,
  `"region"`, `"city"`, `"friends"`, `"partner"` (default `["world"]`), with `total` default **8** and `top`
  default **5** per rank type — [High Scores API](https://airconsole.github.io/airconsole-api/AirConsole-High_Scores.html).
  That is a global leaderboard surface, not a "who won the last round" surface.
- The API is explicitly not an authority: "High Scores are public, not secure and anyone can request and tamper
  with them. Do not store sensitive data." — [High Scores API](https://airconsole.github.io/airconsole-api/AirConsole-High_Scores.html)
- The player-visible version lives in the profile: "Your highscores", "Stats: Amount of games played, amount of
  hours played, biggest group size, total sessions" — [Profile](https://airconsole.zendesk.com/hc/en-us/articles/4405557079698-Profile)

Important caveat on that substitute: "**Profile data is stored locally on your device.** If you reinstall the
app or switch devices, your stats may not carry over and can't always be recovered."
— [Profile](https://airconsole.zendesk.com/hc/en-us/articles/4405557079698-Profile). (The same page says game
progress is server-side: "The game progress is stored on our servers and is linked to the users profile name,
email and unique device identification number." — same URL.) So scores survive on the server while the
stats that make them legible to the player may not survive a device change.

---

## H. Stage 11 — Next round / Play again

**Absent as a platform concept.** There is no "play again" affordance owned by AirConsole, no rematch button,
no automatic round loop. Going again is one of two game-level actions: the game restarts itself, or the master
controller re-enters the store via the logo menu and picks again — "Change Game" ([URL](https://airconsole.zendesk.com/hc/en-us/articles/360015054759-How-can-I-change-a-game)) /
"New game" ([URL](https://airconsole.zendesk.com/hc/en-us/articles/29648195287708-Play-in-Audi)). Either way,
`navigateHome()` is what moves *all* devices at once: "Request that all devices return to the AirConsole store."
— [Navigation API](https://airconsole.github.io/airconsole-api/AirConsole-Navigation.html)

The one platform-owned thing that can sit between rounds is **an ad**, and it is synchronised across devices by
design: `showAd()` — "Requests that AirConsole shows a multiscreen advertisment. Can only be called by the
AirConsole.SCREEN. `onAdShow` is called on all connected devices if an advertisement is shown (in this event
please mute all sounds). `onAdComplete` is called on all connected devices when the advertisement is complete or
no advertisement was shown." — [Ads API](https://airconsole.github.io/airconsole-api/AirConsole-Ads.html).
`onAdShow` is described as "a fullscreen advertisement… shown on this screen"
— [Ads API](https://airconsole.github.io/airconsole-api/AirConsole-Ads.html). A user review claims this
interstitial runs after each game on the free tier — "after each game you have to sit through 30 seconds of
adverts" — [Amazon customer review](https://www.cdn.amazon.in/product-reviews/B085H7Z1XC/ref=acr_dp_hist_2?ie=UTF8&filterByStar=two_star&reviewerType=all_reviews)
`[user]`, low confidence, duration unverified.

---

## I. Stage 12 — End of night

**Absent.** No source reviewed — marketing, help centre (Getting Started, FAQ, Troubleshooting, Account
sections), developer guidelines, or API reference — contains an end-of-session screen, a night summary, a
"final standings", a "thanks for playing", or an explicit "leave session" control.

What exists instead is an **always-open console model** with exactly two navigation states, *store* and *game*:
`navigateHome()` ("Request that all devices return to the AirConsole store.") and `navigateTo(url, parameters)`
("Request that all devices load a game by url or game id.") — [Navigation API](https://airconsole.github.io/airconsole-api/AirConsole-Navigation.html).
No third destination is defined. Play continues until the humans stop; the store is the resting state.

The session therefore ends **implicitly and without acknowledgement**, by the big screen being closed or
reloaded: "If nothing helps, refresh your console by refreshing the browser window, restarting the AirConsole
App." — [Disconnects](https://airconsole.zendesk.com/hc/en-us/articles/360014580319-Disconnects). Every
controller link dies with it, and the code becomes void. The nearest thing to a record of a night is the
profile counters ("biggest group size", "total sessions") — [Profile](https://airconsole.zendesk.com/hc/en-us/articles/4405557079698-Profile) —
which are aggregate and device-local, not a summary of the night just played.

**Read-across:** this is the largest hole in the 13-stage coverage of the closest commercial analog. A party
platform with no end-of-night moment means the last memory of a session is whichever game screen happened to be
up when someone closed the laptop. Thumb Party has no commercial precedent here to copy — which makes stage 12
a differentiation opportunity rather than a catch-up item.

---

## J. Stage 13 — Re-entry after a drop — deep dive

This is where AirConsole is most engineered, and where it diverges most from a naive design. The mechanics come
in four layers.

### J1. Identity is reserved per device, not per connection

The core rule, stated three separate times across the docs, and the single most transferable fact in this
digest:

> "Within an AirConsole session, **devices keep the same `device_id` when they disconnect and reconnect**.
> Different controllers will never get the same `device_id` in a session. **Every `device_id` remains reserved
> for the device that originally got it.**" — [Device Ids and state](https://developers.airconsole.com/device-ids-and-state)

Same text repeated in the API reference: "Within an AirConsole session, devices keep the same device_id when
they disconnect and reconnect… Every device_id remains reserved for the device that originally got it."
— [Connectivity API](https://airconsole.github.io/airconsole-api/AirConsole-Connectivity.html)

Consequence: a dropped player who comes back **is the same player**, with the same `device_id`, and therefore
keeps their slot, colour, score and custom state. There is no re-joining ceremony documented, no re-picking a
name, and no duplicate-identity problem. Player numbers are derived, not stored: `setActivePlayers()` "takes
all currently connected controllers and assigns them a player number. The assigned player numbers always start
with 0 and are consecutive" — [Device Ids and state](https://developers.airconsole.com/device-ids-and-state).

The platform also tells games that a session's device set can be sparse and out of order: "When you're game is
loaded, maybe only controller device_ids [3, 7, 12] are still present and NOT [1, 2, 3]" — same URL. Games are
forbidden from assuming `1, 2, 3`.

State survives the gap explicitly: "`onCustomDeviceStateChange(device_id, custom_data)` will be called on all
other devices, when data is set for a device — **even if a device joins at a later point** and was not
connected when the data was set." — [Device Ids and state](https://developers.airconsole.com/device-ids-and-state).
A late or returning phone is therefore re-hydrated by the platform rather than by game code.

### J2. The platform owns the "link is bad" and "link is gone" visuals

Two distinct states are documented, and the distinction matters for design:

> "1. ***Bad connection:*** a pulsating red overlay is being shown over your profile image in the top bar
> 2. ***Disconnect:*** your profile image (avatar) disappears"
> — [Disconnects](https://airconsole.zendesk.com/hc/en-us/articles/360014580319-Disconnects)

So *degraded* and *gone* are different pixels in the same slot: an overlay versus an absence. Which surface
carries that top bar (big screen player list, or the phone's own bar) is not stated in the article; `unmeasured`.
The article's stated cause is environmental — "mostly it is because the console device and controller lose
internet connection" — and it names the most common self-inflicted cause, which is a real UX hazard for a
phone-as-controller product: "**Don't switch Apps:** While playing or waiting until a game is loaded you might
want to check on other apps or notifications you receive. Switching apps can cause a disconnect."
— [Disconnects](https://airconsole.zendesk.com/hc/en-us/articles/360014580319-Disconnects)

### J3. The pause overlay and the 3-second resume countdown are platform-drawn

> "When AirConsole detects a very high latency or temporary disconnect from the internet, the `onPause()` method
> will be called, and you should immediately pause the game and all audio. **You don't need to inform the user
> about pausing the game since AirConsole will provide a pause overlay on the screen and all controllers.**"
> — [Handling unstable connections](https://developers.airconsole.com/handling-unstable-connections)

> "Once the internet connection conditions are back to normal, AirConsole will call `onResume()`… **AirConsole
> will show a countdown overlay for 3 seconds before `onResume` event is called.**"
> — [Handling unstable connections](https://developers.airconsole.com/handling-unstable-connections)

Three details worth stealing for Thumb Party:

1. **The pause is not the game's job, and games are told not to duplicate it:** "Please, do not create any
   informative screens about pausing the game. AirConsole will provide pause overlay on Screen and all
   Controllers." — same URL. One owner for the reconnect UI.
2. **The overlay may be late, and that is accepted:** "Sometimes, there may be a delay in displaying the pause
   overlay on Controllers. This happens when the connection between the Controllers and the screen is completely
   lost, but as soon as the connection is re-established, the pause overlay will appear." — same URL.
3. **Resume is announced before it happens** (3 s countdown) rather than snapping back — the same URL.

### J4. What the *game* does about the missing player is a ranked choice

AirConsole does not prescribe one drop policy. It publishes a ladder from best to worst and asks developers to
place their game on it:

> "**Level 1:** Game allows players to seamlessly drop in & drop out with no effect on players or gameplay.
> Game examples: *PinWorld, RopeRaid, Trivia Crack.*
> **Level 2:** AI replaces dropped players or new players replace AI players. Game examples: *GoKartGo, Ludo.*
> **Level 3:** Game prompt asking how to manage a connect/disconnect issue (**wait for reconnect, continue game,
> go back to main menu**), adding bots if needed. Game examples: *Starlit Kart Racing, Overcooked.*
> **Level 4:** No game prompt & game continues; **disconnected player has a 'wait' message on controller
> device**. Game examples: *8bit Fiesta.*
> **Level 5:** No game prompt & game goes back to the main menu for all players. Game examples: *Snowboard
> Buddies, Smoots Summer Games.*"
> — [UX design for connect/disconnect events](https://developers.airconsole.com/ux-design-for-connectdisconnect-events)

Level 3 is the only level at which the *room* is asked to decide, and its three options are the canonical
reconnect dialogue: wait / continue / abandon. Levels 4 and 5 differ only in blast radius: one player waits, or
everyone is ejected to the menu.

Two further rules on the same page: overflow players must be told they are over the cap ("If the game is full,
the player above the maximum should has a message indicating it."), and a waiter is promoted when a seat frees
("If players disconnect from the session then a player that was ''waiting to connect'' should automatically be
placed in the lobby."). — [UX design for connect/disconnect events](https://developers.airconsole.com/ux-design-for-connectdisconnect-events)

### J5. Silence for mid-round joiners (a drop-adjacent state)

A phone that arrives mid-round is not the same as a phone that returns, and the platform treats it separately.
Player silencing is off by default; when on, "New players will be informed that they need to wait for the game
round to finish on their controller. Your screen and controller will only invoke `onConnect` after the game round
is no longer active, which is controlled by your screen calling `setActivePlayers(0)`."
— [Handling players connecting](https://developers.airconsole.com/handling-players-connecting)

The lifecycle is spelled out: "Once the active game round is no longer active, all waiting `onConnect` events
will be executed, **unless the device has disconnected already**." — same URL. With silencing *off*, the burden
moves to the game: "New players will be added to your game as soon as they connect to the game, invoking
`onConnect` and requiring your game to manually handle and ignore messages as well as visualizing the correct
state on the game controller." — same URL. The documented game states are `LOBBY` (`setActivePlayers(0)`) and
`GAME` (`setActivePlayers(2)` in the pong example) — same URL.

### J6. Re-entry: what is documented, and what is not

Documented: the device keeps its `device_id`; the platform draws a pause overlay and a 3 s resume countdown;
messages are queued and delivered in order after the disruption ("guaranteed to arrive at some point in the
right order even if the internet connection was disrupted"); the game chooses a Level 1–5 policy; a mid-round
joiner can be parked with a wait message.

**Not documented, and therefore `unmeasured`:** the actual re-entry *screen* and its copy. No source reviewed
says whether a dropped controller auto-rejoins the session on reconnect, or must re-open the app and re-enter
the code, or shows a "reconnecting…" state of its own. The reservation of `device_id` implies re-entry is
possible without re-identifying; it does not describe the pixels. Likewise `unmeasured`: what happens to the
*master* role when the master controller drops (whether authority transfers, and to whom), and whether a
session code expires.

**Read-across for Thumb Party:** the model to copy is *reserve identity at the transport layer, decide policy at
the game layer, own the overlay at the platform layer*. That split is why AirConsole can support five different
drop policies without five different reconnect UIs. The model to improve on is the re-entry screen itself: the
platform has no documented re-entry surface, so a dropped Thumb Party player currently has a better-defined
path than an AirConsole player does.

---

## K. Cross-cutting inconsistencies found (all official pages)

| # | Inconsistency | Source A | Source B |
|---|---|---|---|
| 1 | Same-WiFi required? **No** vs **Yes** | "You do not have to be connected to the same WiFi to be able to play together." — [About](http://www.airconsole.com/file/airconsole-info.html) | "All devices (Big Screen and phones) should be on the **same WiFi network**." — [How to Connect](https://airconsole.zendesk.com/hc/en-us/articles/360014511400-How-to-Connect); [Disconnects](https://airconsole.zendesk.com/hc/en-us/articles/360014580319-Disconnects) |
| 2 | Menu item name: **"Change Game"** vs **"New game"** | [How can I change a game?](https://airconsole.zendesk.com/hc/en-us/articles/360015054759-How-can-I-change-a-game) | [Play in Audi](https://airconsole.zendesk.com/hc/en-us/articles/29648195287708-Play-in-Audi) |
| 3 | Who may pick a game: **the host** vs **the master controller, premium-prioritised** | "The main controller (Host) will then be able to start the session" — [How to Connect](https://airconsole.zendesk.com/hc/en-us/articles/360014511400-How-to-Connect) | "Returns the device ID of the master controller. Premium devices are prioritzed." [sic] — [Connectivity API](https://airconsole.github.io/airconsole-api/AirConsole-Connectivity.html) |
| 4 | Game pick location: **on the big screen** vs **on the controller** | "Browse the AirConsole Store on the Big Screen" — [How to Connect](https://airconsole.zendesk.com/hc/en-us/articles/360014511400-How-to-Connect) | "Use your controller to select and start a game." — [Play in Audi](https://airconsole.zendesk.com/hc/en-us/articles/29648195287708-Play-in-Audi) — reconcilable as *render on screen, input on phone*, but never written as one sentence |

---

## L. Evidence table

| Source | Class | Supports |
|---|---|---|
| [AirConsole About](http://www.airconsole.com/file/airconsole-info.html) | official-marketing | stage 1 start button, 6-step product loop, profile nickname/photo, unlimited additional players, same-WiFi claim |
| [How to Connect](https://airconsole.zendesk.com/hc/en-us/articles/360014511400-How-to-Connect) | official-help | stages 1–6: code + QR, guest/account choice, Player Lobby, store on screen, controller follows game, same-WiFi tip |
| [Play in Audi](https://airconsole.zendesk.com/hc/en-us/articles/29648195287708-Play-in-Audi) | official-help | stages 1, 3, 4, 5, 6, 11: first-run video, QR redirect, nickname once + Continue, Lobby + QR left, first player = Main Controller, "Has everyone joined?" + Yes, "New game" menu |
| [Play on TV](https://airconsole.zendesk.com/hc/en-us/articles/4405279964946-Play-on-TV) | official-help | stage 2: TV platforms (Android TV, Google TV, Fire TV, newer Chromecast); linked from How to Connect, not independently quoted here |
| [How can I change a game?](https://airconsole.zendesk.com/hc/en-us/articles/360015054759-How-can-I-change-a-game) | official-help | stage 6/11: logo → menu → "Change Game", master-only authority |
| [Disconnects](https://airconsole.zendesk.com/hc/en-us/articles/360014580319-Disconnects) | official-help | stage 13: pulsating red overlay, avatar disappears, app-switching as cause, refresh ends the session |
| [Profile](https://airconsole.zendesk.com/hc/en-us/articles/4405557079698-Profile) | official-help | stage 4/10/12: nickname + avatar photo, edit path, stats incl. biggest group size / total sessions, local storage caveat |
| [About the AirConsole Apps](https://airconsole.zendesk.com/hc/en-us/articles/360015064779-About-the-AirConsole-Apps) | official-help | stage 1/3: controller apps (iOS/Android/Amazon), TV apps |
| [Device Ids and state](https://developers.airconsole.com/device-ids-and-state) | official-dev | stage 13 core: device_id reserved across reconnect, sparse id sets, setActivePlayers, custom state re-hydration; stage 4 colour example |
| [UX design for connect/disconnect events](https://developers.airconsole.com/ux-design-for-connectdisconnect-events) | official-dev | stage 13 policy ladder L1–L5, full-game message, waiter promoted to lobby |
| [Handling players connecting](https://developers.airconsole.com/handling-players-connecting) | official-dev | stage 5/13: player silencing, wait message, LOBBY/GAME states |
| [Handling unstable connections](https://developers.airconsole.com/handling-unstable-connections) | official-dev | stage 7/13: pause overlay, 3 s resume countdown, ordered lossless delivery, late overlay |
| [Smartphones as Controllers](https://developers.airconsole.com/smartphones-as-controllers) | official-dev | stage 8: views, button sizing rules, no d-pads, personalised controllers |
| [Developers home](https://developers.airconsole.com/) | official-dev | stage 8: fullscreen/orientation/stay-alive handled by platform |
| [Navigation API](https://airconsole.github.io/airconsole-api/AirConsole-Navigation.html) | official-dev | stages 6/11/12: only two destinations, navigateTo/navigateHome for all devices |
| [Connectivity API](https://airconsole.github.io/airconsole-api/AirConsole-Connectivity.html) | official-dev | stage 2 join code, stage 6 master + premium priority, stage 13 onDisconnect/device_id |
| [Profile API](https://airconsole.github.io/airconsole-api/AirConsole-Profile.html) | official-dev | stage 4 nickname/avatar, 64 px default picture size, editProfile |
| [Ads API](https://airconsole.github.io/airconsole-api/AirConsole-Ads.html) | official-dev | stage 11: fullscreen multiscreen ad between games |
| [High Scores API](https://airconsole.github.io/airconsole-api/AirConsole-High_Scores.html) | official-dev | stage 10 substitute for a scoreboard: world/country/region/city/friends ranks, total 8 / top 5, "public, not secure" |
| [User Interface API](https://airconsole.github.io/airconsole-api/AirConsole-User_Interface.html) | official-dev | stage 8: `setOrientation(portrait\|landscape)` |
| [Stack Overflow: maximum number of players](https://stackoverflow.com/questions/77410095/maximum-number-of-players) | official-dev (staff answer) | stage 3/5: no default cap, per-game config, overflow handling is the game's job |
| [Product Hunt — AirConsole](https://www.producthunt.com/p/airconsole/airconsole) | official (team answer) | stage 6/11: logo returns to store |
| [PC Tech Magazine](https://pctechmag.com/2016/12/party-gaming-with-airconsole/) | press | six-digit code (reported) |
| [CHIP](https://www.chip.de/downloads/webapp-AirConsole-Multiplayer-Spiele-fuer-Freunde_164034286.html) | press | six-digit code (reported, DE) |
| [GeekExtreme review](https://www.geekextreme.com/airconsole-review-free-games-worth/) | press | no documented platform cap; per-game 4–8 players; QR-or-type join; no offline |
| [Amazon customer review](https://www.cdn.amazon.in/product-reviews/B085H7Z1XC/ref=acr_dp_hist_2?ie=UTF8&filterByStar=two_star&reviewerType=all_reviews) | user (low confidence) | ad between games claim (unverified) |

---

## M. Stages with no evidence / absent, and unmeasured items

**Absent as designed stages (no source reviewed describes them at platform level):**
- **Stage 7 — round intro / countdown.** Per-game. Only platform countdown is the 3 s resume overlay.
- **Stage 9 — round end.** Per-game.
- **Stage 10 — results / scoreboard.** Per-game; platform substitutes persistent high scores + profile stats.
- **Stage 11 — next round / play again.** Per-game; platform offers "Change Game" and an optional ad.
- **Stage 12 — end of night.** Absent entirely: no summary, no final standings, no leave control.
- **Stage 4 — colour & accessory selection.** Absent; only nickname + account avatar exist.

**`unmeasured` (sources are silent, not contradictory):**
- Connect-code length and character set (reported six digits by press, not confirmed officially).
- Whether the QR pre-fills the code or only launches the controller.
- Invalid / expired / already-full code error screens.
- Which device carries "the top bar" in the disconnect article.
- The re-entry screen itself: auto-rejoin vs. re-enter code vs. "reconnecting…" copy.
- Master-role transfer when the master controller drops.
- Whether a session code expires, and after how long.
- All pixel sizes, positions, dp values, contrast ratios and viewport measurements — no device was captured.
- Ad duration between games.

---

## N. Headline takeaways for Thumb Party

1. **Join is two channels, and the QR is a deep link** — the code is the fallback, not the primary path.
   ([How to Connect](https://airconsole.zendesk.com/hc/en-us/articles/360014511400-How-to-Connect))
2. **Identity is asked once, before the code, and skipped on return visits** — nickname only; no colour, no
   accessory, avatar from the account. ([Play in Audi](https://airconsole.zendesk.com/hc/en-us/articles/29648195287708-Play-in-Audi), [Profile](https://airconsole.zendesk.com/hc/en-us/articles/4405557079698-Profile))
3. **One device is authorised, and the room is told which** — first joiner = master, premium outranks, and only
   the master can change game. ([Connectivity API](https://airconsole.github.io/airconsole-api/AirConsole-Connectivity.html), [How can I change a game?](https://airconsole.zendesk.com/hc/en-us/articles/360015054759-How-can-I-change-a-game))
4. **The start gate is a human confirmation on the host's phone**, not a timer on the TV. ([Play in Audi](https://airconsole.zendesk.com/hc/en-us/articles/29648195287708-Play-in-Audi))
5. **Drops preserve identity at the transport layer and defer policy to the game** — five documented policies,
   one platform-owned overlay. ([Device Ids and state](https://developers.airconsole.com/device-ids-and-state), [UX design for connect/disconnect events](https://developers.airconsole.com/ux-design-for-connectdisconnect-events))
6. **Stages 7, 9, 10, 11 and 12 are all outsourced to games or missing** — the platform is a lobby, a store, a
   pipe and a connection manager. Everything a party actually remembers is per-game or absent.
