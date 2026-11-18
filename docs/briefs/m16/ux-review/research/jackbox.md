# Jackbox Party Pack — competitive research digest: the player flow

Scope: the **player flow** of *The Jackbox Party Pack* series, where phones/tablets join a
host's game as controllers via a room code at `jackbox.tv`. Mapping follows
`worker-spec.md` §1 (13 stages). Representative titles used as evidence: *Quiplash*
(standalone, Party Pack 2/3 lineage), *Party Pack 7* (2020), *Party Pack 9* (2022),
*Party Pack 10* (2023), *Party Pack 12* (2026).

Method: desk research only — no app installs, no device capture, no screenshots, no pixel
measurement. Every claim below carries a URL. Web pages were treated as untrusted data.

**Confidence markers used in this file**

- **[text]** — I fetched the page and quote its rendered body.
- **[extract]** — the page body would not render past the truncation point; the quote is
  the search-result extract of that exact URL. Treat as one grade weaker.
- **[user report]** — a forum post describing what a player saw, not vendor documentation.

Nothing here is measured in px/dp; the worker-spec measurement rules apply to findings
records, not to this digest. Where a number is quoted (4 characters, 12 characters,
8 players, 5 minutes) it is the number stated at the cited source.

---

## 1. The join flow, in one pass

1. Host owns and runs the game on a PC/console/TV; players need no copy and no app
   ([support: getting started](https://support.jackboxgames.com/hc/en-us/articles/15794771245975-How-do-I-get-started-playing-Jackbox-Games), [text]).
2. Host picks one of the pack's games from the pack menu; starting it creates a room and
   shows a 4-letter room code on the host screen
   ([Daryl Baxter, PP12 review](https://darylbaxter.com/posts/jackbox-party-pack-12-review/), [text];
   [Quiplash game help](https://dlassets-ssl.xboxlive.com/public/content/b002f336-6ab1-4a37-87ae-8d7d5cbda13d/GameManual/b7c5f24f-9292-4279-9ecc-88f45857e5ef/en-SA/index.html), [text]).
3. Player opens `jackbox.tv` in any browser, types the 4-letter code and a name, presses
   **Play** ([support: join a game](https://support.jackboxgames.com/hc/en-us/articles/15794759479959-How-do-I-join-a-game), [text]).
4. Their name appears on the host screen; the browser tab becomes the controller
   ([PMA Western](https://pma.uwo.ca/jackbox-games/), [text]).
5. First player in becomes the "VIP" and can start the game from their own phone
   ([PMA Western](https://pma.uwo.ca/jackbox-games/), [text];
   [support: moderation](https://support.jackboxgames.com/hc/en-us/articles/15794773430295-How-does-Moderation-work), [text]).

### 1.1 The join form, element by element

The only primary evidence I could get for the join screen's exact fields is a DOM capture
of `jackbox.tv` (urlscan, 6 Nov 2023). It is worth quoting in full because it is the whole
of Jackbox's player-creation surface:

> `<label for="roomcode">ROOM CODE</label>`
> `<input id="roomcode" type="text" placeholder="ENTER 4-LETTER CODE" maxlength="4">`
> `<label for="username">NAME <span class="remaining">12</span></label>`
> `<input id="username" type="text" placeholder="ENTER YOUR NAME" maxlength="12">`
> `<button id="button-join" type="submit" disabled><span>Play</span>`
> `<p class="tos">By clicking Play, you agree to our Terms of Service</p>`
> — [urlscan.io capture of jackbox.tv](https://urlscan.io/result/934b6b79-1edc-4c27-8396-a2ac8a087d9d/content/), [text]

Read off that capture: **two inputs, one button, no other control**.

| Element | Constraint | Note |
|---|---|---|
| ROOM CODE field | 4 characters, uppercase placeholder | label is literal "ROOM CODE" |
| NAME field | 12 characters, live remaining counter seeded at "12" | label is literal "NAME" |
| Play button | ships `disabled`; enabled when the form is valid | the only submit action |
| Terms line | static text under the button | consent by pressing Play |

There is no colour swatch, no accessory, no avatar picker, no ready toggle and no
"remember me" on this form. Account/login is not present: "You do not need an account with
us to play!" ([support: accounts](https://support.jackboxgames.com/hc/en-us/articles/15794759347735-Do-games-require-an-account-or-subscription-to-play), [text]).

---

## 2. The 13 stages

### 1. Launch / first run

Two different "first runs" exist, and only one of them belongs to the player.

**Host first run.** The host launches a pack and lands on a menu of the pack's games:
"you're brought to a menu where you can pick a variety of games"
([Daryl Baxter, PP12](https://darylbaxter.com/posts/jackbox-party-pack-12-review/), [text]).
On PC the menu is keyboard-navigable — "You can now use the Arrow Keys or Page Down on
your keyboard to switch between the available games"
([Danvelopment](https://danvelopment.me/2021/09/14/lockdown-games-for-non-gamers-playing-jackbox-over-the-internet/), [text]).
Since 2024 a free Steam-only launcher, The Jackbox Megapicker, can replace the pack menus
entirely — "Launch Jackbox Games without the Pack menus"
([jackboxgames.com/the-jackbox-megapicker](https://www.jackboxgames.com/the-jackbox-megapicker), [extract]).

**Player first run is absent as a screen.** There is no app to install — "Jackbox Games are
not a mobile app, and we do not offer or require one to play. As a player, you will use
jackbox.tv to access the controller for the game; it operates entirely in your browser"
([support: getting started](https://support.jackboxgames.com/hc/en-us/articles/15794771245975-How-do-I-get-started-playing-Jackbox-Games), [text]).
The player's "first run" is the same form every time: URL, code, name, Play.
No host-side first-run onboarding/tutorial is documented in the sources I found.

### 2. Host setup

Starting a game is what creates a room: "Once you launch and pick the game you want to
play, you'll see a four-letter room code in the lobby"
([PMA Western](https://pma.uwo.ca/jackbox-games/), [text]). The code is per launch, not
per install — "Every new game started has a unique code"
([Quiplash game help](https://dlassets-ssl.xboxlive.com/public/content/b002f336-6ab1-4a37-87ae-8d7d5cbda13d/GameManual/b7c5f24f-9292-4279-9ecc-88f45857e5ef/en-SA/index.html), [text]);
"Each time you restart the game on your PC it will display a new unique 'Room Code'"
([Fanatical support](https://support.fanatical.com/hc/en-us/articles/360000732457-Playing-Jackbox-Games), [extract]).

Per-game settings sit before the lobby and include Family Friendly, Audience on/off,
Extended Timers and Volume
([Quiplash game help](https://dlassets-ssl.xboxlive.com/public/content/b002f336-6ab1-4a37-87ae-8d7d5cbda13d/GameManual/b7c5f24f-9292-4279-9ecc-88f45857e5ef/en-SA/index.html), [text]).
Streamer-facing settings add "Allow Room Code Hiding" and "Start Game From Controller Only"
([Party Pack 5 Streamer's Guide](https://www.jackboxgames.com/blog/the-jackbox-party-pack-5-streamers-guide), [extract]).
Moderation adds a numeric password and a second web surface, `mod.jackbox.tv`, that
moderators join mid-game ([support: moderation](https://support.jackboxgames.com/hc/en-us/articles/15794773430295-How-does-Moderation-work), [text]).

Host setup therefore ends with: one room, one 4-letter code on screen, N player slots, and a
class of settings that change what the lobby will accept.

### 3. Party join

The documented sequence is four steps: "1. Go to Jackbox.tv 2. Enter in the 4-letter room
code being displayed in the game 3. Enter in your player name 4. Hit play and commence the
fun!" ([support: join a game](https://support.jackboxgames.com/hc/en-us/articles/15794759479959-How-do-I-join-a-game), [text]).

Two hard constraints on the join:

- **One controller per browser per device**: "only one user may login per browser, per
  device" ([support: join a game](https://support.jackboxgames.com/hc/en-us/articles/15794759479959-How-do-I-join-a-game), [text]).
- **The host cannot play on the host device**: "you won't be able to enter answers on the
  same device running the game" ([support: join a game](https://support.jackboxgames.com/hc/en-us/articles/15794759479959-How-do-I-join-a-game), [text]).

Confirmation for the player is host-side, not phone-side: "You can tell it worked when you
see your name appear on the game screen" ([PMA Western](https://pma.uwo.ca/jackbox-games/), [text]).

**Two join paths beyond typed codes.** (a) QR: from Party Pack 9 onward the lobby can be
joined "by pointing your device at a QR code, without having to type in the URL"
([Daryl Baxter, PP12](https://darylbaxter.com/posts/jackbox-party-pack-12-review/), [text]).
(b) Audience: after the player slots fill, or after the game starts, a code entry produces
an audience membership rather than a player slot — "The first 8 people will join as players.
Everyone else will be an audience member. If you join after the game has started, you will
be an audience member"
([Quiplash game help](https://dlassets-ssl.xboxlive.com/public/content/b002f336-6ab1-4a37-87ae-8d7d5cbda13d/GameManual/b7c5f24f-9292-4279-9ecc-88f45857e5ef/en-SA/index.html), [text]).

**Error states with evidence:** a stale or superseded code — "A code cannot work after the
host has started a different game or generated a new lobby"
([macmyths PP12 troubleshooting](https://macmyths.com/how-to-fix-jackbox-party-pack-12-room-code-connection-and-input-problems/), [extract]);
a blocked browser — cookies, WebSockets, HTML5 and JavaScript are required
([support: join a game](https://support.jackboxgames.com/hc/en-us/articles/15794759479959-How-do-I-join-a-game), [text]).
A name-collision error string is **absent** from every source I found.

### 4. Player creation / colour & accessory

**Absent at the join step.** The join form exposes exactly the two fields in §1.1 and
nothing else ([urlscan capture](https://urlscan.io/result/934b6b79-1edc-4c27-8396-a2ac8a087d9d/content/), [text]).
The only player-authored attribute at party level is the name, capped at 12 characters, and
it is not locked in: "you can change this name as often as you like since your Past Games
are stored via cookies in your controller device, and do not require any login!"
([support: accounts](https://support.jackboxgames.com/hc/en-us/articles/15794759347735-Do-games-require-an-account-or-subscription-to-play), [text]).

**Colour and avatar work is displaced into each game.** A review of Party Pack 10 puts the
avatar step per-title, not per-party: "Even the process of creating player names and
choosing avatars for each game is fun"
([COGconnected, PP10](https://cogconnected.com/review/jackbox-party-pack-10-review/), [text]).
That matches the game design: character creation (a champ, a monster, a role model, a
shirt) is the first beat *inside* a title, after start
([COGconnected, PP10](https://cogconnected.com/review/jackbox-party-pack-10-review/), [text]).

So for the party-level stage: name only; colour/accessory selection absent. Whether the
host screen assigns each player a fixed colour or icon per join order is **not documented**
in the sources I found (Party Pack 4 lobby "Player Pics" sprite sheets exist
([The Spriters Resource](https://www.spriters-resource.com/pc_computer/jackboxpartypack4/asset/144940/page-1/), [extract]),
but no source states whether a player chooses them).

### 5. Lobby & waiting

The lobby is a host-screen room. It shows the 4-letter code, and a player's name is added
to it on join — "you'll see a four-letter room code in the lobby... You can tell it worked
when you see your name appear on the game screen"
([PMA Western](https://pma.uwo.ca/jackbox-games/), [text]).
`jackbox.tv` is the address every joining instruction points at
([support: join a game](https://support.jackboxgames.com/hc/en-us/articles/15794759479959-How-do-I-join-a-game), [text]);
from Party Pack 9 the lobby can also carry a QR code so the URL need not be typed
([Daryl Baxter, PP12](https://darylbaxter.com/posts/jackbox-party-pack-12-review/), [text]).
Its waiting-state copy is not vendor-documented, but a player report describes it directly:
"It says waiting for players"
([XboxAchievements forum, 2015](https://www.xboxachievements.com/forum/topic/419038-paid-amp-cant-even-playany-tips/), [user report]).

Behaviour while waiting, with evidence:

- **Max player slots depend on the title, not the pack.** The support matrix lists 2–8
  (Fibbage 4), 3–10 (Drawful Animate), 1–10 (Quixort), 4–10 (Push The Button), 3–16
  (Bracketeering), 2–10 (The Jackbox Survey Scramble)
  ([support: player counts](https://support.jackboxgames.com/hc/en-us/articles/15794756085015-How-many-players-can-join-each-game), [text]).
  Flow beyond the player cap becomes audience, up to 10,000
  ([support: getting started](https://support.jackboxgames.com/hc/en-us/articles/15794771245975-How-do-I-get-started-playing-Jackbox-Games), [text]).
- **Start is gated on a minimum player count.** The start control only exists once the
  count is met: "'Everybody's In' or 'Start Game' will only appear on the screen if you have
  enough players to begin a game"
  ([PMA Western](https://pma.uwo.ca/jackbox-games/), [text]).
- **Start authority is delegated to a player.** "The very first person to connect is the
  VIP. When everyone who wants to play is connected and ready, the VIP can start the game
  from their device" ([PMA Western](https://pma.uwo.ca/jackbox-games/), [text]).
  Historically the button was labelled "Everybody's In": "the first player who logged in
  should hit the 'Everybody's In' button to play!"
  ([Quiplash game help](https://dlassets-ssl.xboxlive.com/public/content/b002f336-6ab1-4a37-87ae-8d7d5cbda13d/GameManual/b7c5f24f-9292-4279-9ecc-88f45857e5ef/en-SA/index.html), [text]).
  The host can reclaim start with the "Start Game From Controller Only" setting
  ([Party Pack 5 Streamer's Guide](https://www.jackboxgames.com/blog/the-jackbox-party-pack-5-streamers-guide), [extract]).
- **The lobby is where removal happens.** Moderation applies in the lobby "without
  restrictions. Even the first person who joins the room (the VIP). If the VIP is kicked
  from the game, another player will be given their designation, and a slot will open up
  for someone else to join"
  ([support: moderation](https://support.jackboxgames.com/hc/en-us/articles/15794773430295-How-does-Moderation-work), [text]).
- **Late joiners are demoted, not blocked**: they land in the audience
  ([Quiplash game help](https://dlassets-ssl.xboxlive.com/public/content/b002f336-6ab1-4a37-87ae-8d7d5cbda13d/GameManual/b7c5f24f-9292-4279-9ecc-88f45857e5ef/en-SA/index.html), [text]).
- **The lobby can hide its own code** for streamed play — "Allow Room Code Hiding"
  ([Party Pack 5 Streamer's Guide](https://www.jackboxgames.com/blog/the-jackbox-party-pack-5-streamers-guide), [extract]).

No lobby countdown or auto-start-on-timer is documented anywhere I looked: **absent**.

### 6. Game selection

Selection is host-only and happens outside any room. The pack menu lists the five titles;
the host "Select[s] the game you wish to play, based on preference, description or the
number of players it supports and press Enter"
([Danvelopment](https://danvelopment.me/2021/09/14/lockdown-games-for-non-gamers-playing-jackbox-over-the-internet/), [text]).
Players get no vote and no menu: their phone is already bound to the room
([PMA Western](https://pma.uwo.ca/jackbox-games/), [text]).
On Steam the Megapicker replaces per-pack menus with one cross-collection browser —
"Search, sort, and filter across titles" and "Launch Jackbox Games without the Pack menus"
([jackboxgames.com/the-jackbox-megapicker](https://www.jackboxgames.com/the-jackbox-megapicker), [extract]).

### 7. Round intro / countdown

Evidence is thin and mostly about tutorials rather than timers:

- Tutorials run before play and are skippable: "The games themselves will run you through a
  tutorial you can skip, but otherwise the rest is just follow the onscreen instructions"
  ([Danvelopment](https://danvelopment.me/2021/09/14/lockdown-games-for-non-gamers-playing-jackbox-over-the-internet/), [text]).
- The tutorial is a VIP capability: "As the VIP, you'll be responsible for starting the game
  on your device and controlling tutorials"
  ([Jackbox: Playing for Charity](https://www.jackboxgames.com/blog/playing-jackbox-for-charity), [extract]).
- Timed input windows are a first-class setting ("Extended Timers: Enable very long timers –
  recommended only for streamed games")
  ([Quiplash game help](https://dlassets-ssl.xboxlive.com/public/content/b002f336-6ab1-4a37-87ae-8d7d5cbda13d/GameManual/b7c5f24f-9292-4279-9ecc-88f45857e5ef/en-SA/index.html), [text]).

A numeric countdown (3-2-1) or a round-title card as a distinct stage: **no evidence found**.
What is documented is the generic per-round shape — players receive a prompt, the host
screen later shows the collected material
([Wikipedia: The Jackbox Party Pack](https://en.wikipedia.org/wiki/The_Jackbox_Party_Pack), [text]).

### 8. In-round controls

The controller is a live web page driven by the host's game state. "Each game generally has
a period where all players are given a type of prompt. This prompt appears on the individual
devices and gives players sufficient time to enter their reply or draw as necessary"
([Wikipedia](https://en.wikipedia.org/wiki/The_Jackbox_Party_Pack), [text]).
Input types observed across titles: free text, multiple choice, drawing canvases, vote
buttons and rapid tapping — "players use their own mobile devices to input answers and make
choices" ([PMA Western](https://pma.uwo.ca/jackbox-games/), [text]);
drawing and tapping are described per title
([COGconnected, PP10](https://cogconnected.com/review/jackbox-party-pack-10-review/), [text]).

Pacing tolerance is documented as a weakness: "Sometimes it moves a little too fast, and
players who are slow to log in with a room code, or type an answer can get left behind"
([COGconnected, PP10](https://cogconnected.com/review/jackbox-party-pack-10-review/), [text]).

### 9. Round end

Between rounds the host screen becomes the reveal surface: submissions are shown, then other
players vote, then points are assigned — "the game then collects and processes all the
replies, and frequently then gives players a chance to vote for the best answer or drawing"
([Wikipedia](https://en.wikipedia.org/wiki/The_Jackbox_Party_Pack), [text]).
Per-round score review is minimal by design; a reviewer notes the absence of a running
record: "Every game has a winner at the end, but I wish there was a way to track the
accumulated points throughout the evening... The Jackbox Party Pack 10 always keeps things
moving, so there's rarely a chance to record scores"
([COGconnected, PP10](https://cogconnected.com/review/jackbox-party-pack-10-review/), [text]).

### 10. Results / scoreboard

Results are per-game only. "Games proceed for a number of rounds, and a winner, generally
with the highest score at the end, is announced"
([Wikipedia](https://en.wikipedia.org/wiki/The_Jackbox_Party_Pack), [text]).
A review of the same pack confirms the scope: "Every game has a winner at the end"
([COGconnected, PP10](https://cogconnected.com/review/jackbox-party-pack-10-review/), [text]).
A cross-game / whole-night scoreboard is **absent** — the same review asks for one
([COGconnected, PP10](https://cogconnected.com/review/jackbox-party-pack-10-review/), [text]).

### 11. Next round / Play again

Two documented routes out of a finished game:

1. In-place restart — "You'll usually have an option to immediately start a new game with
   the same players" ([Danvelopment](https://danvelopment.me/2021/09/14/lockdown-games-for-non-gamers-playing-jackbox-over-the-internet/), [text]).
2. Back out to the pack menu — "if you decide you want to play a different game Press Esc on
   your keyboard and confirm leaving the game. This will return you to the main menu for
   that pack to choose another game"
   ([Danvelopment](https://danvelopment.me/2021/09/14/lockdown-games-for-non-gamers-playing-jackbox-over-the-internet/), [text]).

Whether route 1 keeps the same 4-letter code is **unmeasured**: no source states it either
way. Route 2 provably does not — a new game launch issues a new code
([Quiplash game help](https://dlassets-ssl.xboxlive.com/public/content/b002f336-6ab1-4a37-87ae-8d7d5cbda13d/GameManual/b7c5f24f-9292-4279-9ecc-88f45857e5ef/en-SA/index.html), [text]).

### 12. End of night

Ending is a host action with no ceremony documented. The host leaves the game and the pack
("Press Esc... confirm leaving the game... press Esc on your keyboard again, or select Quit
and confirm") ([Danvelopment](https://danvelopment.me/2021/09/14/lockdown-games-for-non-gamers-playing-jackbox-over-the-internet/), [text]),
and the room ceases to exist with it: the next launch issues a new code
([Fanatical support](https://support.fanatical.com/hc/en-us/articles/360000732457-Playing-Jackbox-Games), [extract]),
and an old code cannot resolve once a new room exists
([macmyths PP12 troubleshooting](https://macmyths.com/how-to-fix-jackbox-party-pack-12-room-code-connection-and-input-problems/), [extract]).
There is no party-level state to end: no cross-game scores
([COGconnected, PP10](https://cogconnected.com/review/jackbox-party-pack-10-review/), [text])
and no account to sign out of
([support: accounts](https://support.jackboxgames.com/hc/en-us/articles/15794759347735-Do-games-require-an-account-or-subscription-to-play), [text]).

What the phone shows at that moment — a farewell card, a "game over" screen, or a silent
return to the code form — is **not documented in any source I found**. Marked absent below.

### 13. Re-entry after a drop

- **Player fix is a page refresh**: "If you get disconnected during a game, refresh your
  browser. This fixes most disconnects!"
  ([PMA Western](https://pma.uwo.ca/jackbox-games/), [text]); echoed for phones going dark
  mid-game — "sometimes they might have to refresh the jackbox.tv webpage"
  ([COGconnected, PP10](https://cogconnected.com/review/jackbox-party-pack-10-review/), [text]).
- **Re-entry depends on local browser state, not an identity.** Clearing it mid-session
  breaks re-entry outright: "Clear the cache, cookies, and history from your web browser...
  (don't do this while a game is running, or you won't be able to rejoin!)"
  ([support: connecting a device](https://support.jackboxgames.com/hc/en-us/articles/15794785923223-I-m-having-trouble-connecting-my-device-to-the-game), [text]).
- **A dropped player who returns after start may be re-classified as audience** — the
  late-join rule is stated without exceptions: "If you join after the game has started, you
  will be an audience member"
  ([Quiplash game help](https://dlassets-ssl.xboxlive.com/public/content/b002f336-6ab1-4a37-87ae-8d7d5cbda13d/GameManual/b7c5f24f-9292-4279-9ecc-88f45857e5ef/en-SA/index.html), [text]).
  A review of Party Pack 7 reports the opposite outcome in practice — "reconnecting with the
  same username and room code gets players straight back into the swing"
  ([Big Boss Battle, PP7](https://www.bigbossbattle.com/jackbox-party-pack-7-review/), [extract]).
  These two sources conflict; the digest reports both rather than resolving them.
- **Host drop is now survivable, and time-boxed.** "if the game host loses their connection
  to the server mid-game, it won't automatically be destroyed anymore... the game will
  essentially 'pause' for 5 minutes and give the main host time to reestablish a connection
  to the servers" (new in Party Pack 9)
  ([Noisy Pixel](https://noisypixel.net/jackbox-games-streamer-friendly-features-pack-9/), [text]).
  Before that, a host drop "would force the game to the main menu and would result in all
  progress being lost" (same source).
- **A kick is a permanent denial for that room**: "Once a player is kicked, they will be
  denied access to rejoin the game", and "kicking players is specific to that room only...
  if the host creates a new room by starting a different game, the kicked player will have
  the opportunity to rejoin"
  ([support: moderation](https://support.jackboxgames.com/hc/en-us/articles/15794773430295-How-does-Moderation-work), [text]).
- **A rejoin attempt can hit a client-side error**: on iOS a "Game has started" screen can
  appear after a disconnect when reconnecting with the controller — Jackbox's own Netflix
  build documents it
  ([Jackbox Party Essentials troubleshooting](https://games-netflix.helpshift.com/hc/en/57-the-jackbox-party-essentials/section/491-troubleshooting/?p=web), [text]).
  That build differs from the store packs; cited only as the documented existence of the
  error class.

---

## 3. What matters for a phone-as-controller party game

Six structural choices in Jackbox's flow, each with its cost/benefit visible in the sources:

1. **Zero install, zero account, zero identity.** The entire join surface is 4 characters +
   ≤12 characters + one button ([urlscan](https://urlscan.io/result/934b6b79-1edc-4c27-8396-a2ac8a087d9d/content/), [text]).
   Persistence is by cookie only, so "one user per browser per device" is the enforcement
   boundary ([support: join a game](https://support.jackboxgames.com/hc/en-us/articles/15794759479959-How-do-I-join-a-game), [text]).
2. **Start authority is handed to the first player.** The VIP device, not the host, presses
   start unless the host opts out
   ([PMA Western](https://pma.uwo.ca/jackbox-games/), [text]).
   This creates an authority that must be transferable — and Jackbox transfers it on kick
   ([support: moderation](https://support.jackboxgames.com/hc/en-us/articles/15794773430295-How-does-Moderation-work), [text]).
3. **A room code is per game launch, not per night.** That makes "the room" cheap to create
   and impossible to reuse; switching games costs every player a re-join
   ([Quiplash game help](https://dlassets-ssl.xboxlive.com/public/content/b002f336-6ab1-4a37-87ae-8d7d5cbda13d/GameManual/b7c5f24f-9292-4279-9ecc-88f45857e5ef/en-SA/index.html), [text];
   [Danvelopment](https://danvelopment.me/2021/09/14/lockdown-games-for-non-gamers-playing-jackbox-over-the-internet/), [text]).
4. **Player creation is deferred into the games.** Party-level identity is a name; colour,
   avatar and character belong to titles
   ([COGconnected, PP10](https://cogconnected.com/review/jackbox-party-pack-10-review/), [text]).
5. **There is no session layer.** No accumulated score, no night summary
   ([COGconnected, PP10](https://cogconnected.com/review/jackbox-party-pack-10-review/), [text]).
6. **Drop recovery is a manual, user-facing instruction, not an automatic flow** — "refresh
   your browser" ([PMA Western](https://pma.uwo.ca/jackbox-games/), [text]) — with host-side
   protection only since Party Pack 9 (5-minute pause,
   [Noisy Pixel](https://noisypixel.net/jackbox-games-streamer-friendly-features-pack-9/), [text]).

---

## 4. Stages with no evidence, and stages that are absent

| Stage | Verdict | What is missing |
|---|---|---|
| 4. Player creation / colour & accessory | **absent** at party level | No colour or accessory control exists on the join form ([urlscan](https://urlscan.io/result/934b6b79-1edc-4c27-8396-a2ac8a087d9d/content/), [text]); whether the lobby auto-assigns a colour/icon per player is undocumented |
| 7. Round intro / countdown | partial | Tutorials documented ([Danvelopment](https://danvelopment.me/2021/09/14/lockdown-games-for-non-gamers-playing-jackbox-over-the-internet/), [text]); no source describes a countdown, title card or its duration |
| 9. Round end | partial | Reveal/vote/scoring documented ([Wikipedia](https://en.wikipedia.org/wiki/The_Jackbox_Party_Pack), [text]); no source describes a between-round scoreboard screen specifically |
| 11. Play again | partial | Button exists ("option to immediately start a new game with the same players", [Danvelopment](https://danvelopment.me/2021/09/14/lockdown-games-for-non-gamers-playing-jackbox-over-the-internet/)); room-code persistence across it is unmeasured |
| 12. End of night | partial | Host-side exit documented; phone-side end copy/moment is **absent** from all sources |
| 3. Party join | partial | Name-collision / duplicate-name error string: **absent** from every source in §5 |
| 5. Lobby & waiting | partial | "Waiting for players" only from a 2015 player post ([user report](https://www.xboxachievements.com/forum/topic/419038-paid-amp-cant-even-playany-tips/)); no vendor description of the lobby's own layout, timer or auto-start (auto-start appears **absent**) |
| 1. Launch / first run | partial | Host menu documented; no host first-run onboarding documented; player first run **absent** by design |

Stages with no evidence at all: **none** — every one of the 13 has at least one cited
observation, though stages 4 (absent by design), 7 and 12 are the weakest.

---

## 5. Sources

Primary (vendor / game):

- Jackbox support — How do I join a game? https://support.jackboxgames.com/hc/en-us/articles/15794759479959-How-do-I-join-a-game
- Jackbox support — How do I get started playing Jackbox Games? https://support.jackboxgames.com/hc/en-us/articles/15794771245975-How-do-I-get-started-playing-Jackbox-Games
- Jackbox support — Do games require an account or subscription to play? https://support.jackboxgames.com/hc/en-us/articles/15794759347735-Do-games-require-an-account-or-subscription-to-play
- Jackbox support — How many players can join each game? https://support.jackboxgames.com/hc/en-us/articles/15794756085015-How-many-players-can-join-each-game
- Jackbox support — How does Moderation work? https://support.jackboxgames.com/hc/en-us/articles/15794773430295-How-does-Moderation-work
- Jackbox support — I'm having trouble connecting my device to the game https://support.jackboxgames.com/hc/en-us/articles/15794785923223-I-m-having-trouble-connecting-my-device-to-the-game
- Jackbox — Quiplash game help (console manual) https://dlassets-ssl.xboxlive.com/public/content/b002f336-6ab1-4a37-87ae-8d7d5cbda13d/GameManual/b7c5f24f-9292-4279-9ecc-88f45857e5ef/en-SA/index.html
- Jackbox — The Jackbox Party Pack 5 Streamer's Guide https://www.jackboxgames.com/blog/the-jackbox-party-pack-5-streamers-guide
- Jackbox — Playing Jackbox for Charity https://www.jackboxgames.com/blog/playing-jackbox-for-charity
- Jackbox — The Jackbox Megapicker https://www.jackboxgames.com/the-jackbox-megapicker
- Jackbox Party Essentials (Netflix build) — Troubleshooting https://games-netflix.helpshift.com/hc/en/57-the-jackbox-party-essentials/section/491-troubleshooting/?p=web

Independent:

- urlscan.io capture of jackbox.tv (DOM) https://urlscan.io/result/934b6b79-1edc-4c27-8396-a2ac8a087d9d/content/
- Wikipedia — The Jackbox Party Pack https://en.wikipedia.org/wiki/The_Jackbox_Party_Pack
- PMA Western — Jackbox Games how-to https://pma.uwo.ca/jackbox-games/
- Danvelopment — playing Jackbox over the internet https://danvelopment.me/2021/09/14/lockdown-games-for-non-gamers-playing-jackbox-over-the-internet/
- Daryl Baxter — Jackbox Party Pack 12 review (Oct 2026) https://darylbaxter.com/posts/jackbox-party-pack-12-review/
- COGconnected — Jackbox Party Pack 10 review https://cogconnected.com/review/jackbox-party-pack-10-review/
- Noisy Pixel — Pack 9 streamer features https://noisypixel.net/jackbox-games-streamer-friendly-features-pack-9/
- Big Boss Battle — Jackbox Party Pack 7 review https://www.bigbossbattle.com/jackbox-party-pack-7-review/
- Fanatical support — Playing Jackbox Games https://support.fanatical.com/hc/en-us/articles/360000732457-Playing-Jackbox-Games
- macmyths — PP12 room code / connection errors https://macmyths.com/how-to-fix-jackbox-party-pack-12-room-code-connection-and-input-problems/
- XboxAchievements forum — "Paid & can't even play" thread https://www.xboxachievements.com/forum/topic/419038-paid-amp-cant-even-playany-tips/
- The Spriters Resource — PP4 Player Icons https://www.spriters-resource.com/pc_computer/jackboxpartypack4/asset/144940/page-1/

Not retrievable in full (only search extracts used, marked [extract] above): the Jackbox
blog pages, `jackboxgames.com/how-to-play`, and the Fandom wiki game pages — all truncate
before their body text when fetched, so no claim here depends on their unread portions.
