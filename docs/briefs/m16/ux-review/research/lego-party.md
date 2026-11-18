# LEGO Party! — player-flow research digest

- **Prepared for:** M16 UX review, research track (maps to worker-spec.md §1, the 13-stage taxonomy)
- **Research date:** 2026-11-17
- **Method:** public web sources only (official FAQ, publisher support articles, patch notes, outlet reviews, store/community posts). No device capture, no screenshots, no code changes.
- **Measurement status:** every UI measurement in this digest is **`unmeasured`** — no pixel positions, dp sizes, contrast ratios, density values or theme tokens were observed. This file is a flow research digest, not a findings record, so worker-spec.md §2/§3 do not apply to it.

---

## 0. Title verification (done first)

A game titled exactly **"LEGO Party!"** exists. It is a 2025 four-player party game developed by SMG Studio and published by Fictions:

- Official FAQ: *"LEGO® Party! is a 1-4-player party game. Compete against your friends in wacky Challenge Zones and 60 hilarious minigames."* ([legoparty.com/faq](https://legoparty.com/faq))
- Announcement: *"The LEGO Group with developer SMG Studios and new publisher Fictions, today announced LEGO® Party! ... available later this year on Steam for PC, Xbox Series X|S, Xbox One, PlayStation®5 (PS5™), PlayStation®4 (PS4™), and Nintendo Switch™."* ([LEGO newsroom, 6 June 2025](https://www.lego.com/ro-ro/aboutus/news/2025/june/lego-party?locale=ro-ro&age-gate=grown_up))
- Platforms per the official FAQ include **Netflix** in addition to PC/console: *"available on Steam for PC, Xbox Series X|S, Xbox One, PlayStation®5 (PS5™), PlayStation®4 (PS4™), Netflix, Nintendo Switch™ 2 and Nintendo Switch™."* ([legoparty.com/faq](https://legoparty.com/faq))

**No substitution was needed.** The title researched is **LEGO Party!** (SMG Studio / Fictions, released 30 September 2025 — [Gematsu](https://www.gematsu.com/2025/08/lego-party-launches-september-30)). A separate **Netflix build of the same title** exists and uses phones as controllers; where its flow differs, it is labelled "Netflix build" below.

### Version note

The flow changed materially after launch. Findings are written against the **1.6.x line (latest documented: 1.6.62, 17 September 2026)** and dated when a behaviour was added later:

| Change | Version | Date | Effect on flow |
|---|---|---|---|
| Rejoin improvements | 1.2.0 | Nov 2025 | Drop/re-entry |
| Easy mode, skip CPU turns, lobby stability | 1.3.0 | Dec 2025 | Controls, pacing, lobby |
| Bonus Bricks (end-of-zone vote) | 1.4.0 | Mar 2026 | End of night |
| Public lobbies, The Lab modes, advanced rules | 1.6.0 | Jul 2026 | Joining, game selection |
| Rejoin-button fix, ping fix, custom-rule flow | 1.6.62 | Sep 2026 | Lobby, re-entry |

Sources: [1.2.0](https://support.fictions.com/hc/en-us/articles/46292824886931--LEGO-Party-Update-1-2-0-Patch-Notes), [1.3.0](https://support.fictions.com/hc/en-us/articles/47304797703827--LEGO-Party-Update-1-3-0-Patch-Notes), [1.4.0](https://store.steampowered.com/news/posts/?feed=steam_community_announcements&enddate=1773878425), [1.6.0](https://support.fictions.com/hc/en-us/articles/53958409766931--LEGO-Party-Update-1-6-0-Patch-Notes), [1.6.62](https://support.fictions.com/hc/en-us/articles/55511035284371--LEGO-Party-Update-1-6-62-Patch-Notes).

---

## 1. The flow spine (as documented)

The documented happy path, with one source per step:

1. **Boot → Main Menu.** Codes are entered here: *"Codes can be input whilst on the Main Menu of LEGO® Party! A pop up will appear on screen if the input is successful."* ([Fictions: input a code](https://support.fictions.com/hc/en-us/articles/44985853617171--LEGO-Party-How-do-I-input-a-code-in-LEGO-Party)). The Main Menu also holds the rejoin prompt and the online panel on the right ([Fictions: re-join](https://support.fictions.com/hc/en-us/articles/44984421250835--LEGO-Party-How-do-I-re-join-a-game-in-progress); [Fictions: username](https://support.fictions.com/hc/en-us/articles/44984529986323--LEGO-Party-How-do-I-change-my-username)).
2. **Play → Host Game or Join Game.** *"In LEGO® Party!, go to Play > Host Game or Join Game. A 5-digit code will be generated, which can be shared to allow up to three additional players to join the lobby."* ([Fictions: play online with friends](https://support.fictions.com/hc/en-us/articles/44983986033171--LEGO-Party-How-do-I-play-online-with-my-friends))
3. **Avatars locked in.** *"Before heading off to tackle the minigames, you'll need to select a minifigure avatar. ... Once players' avatars are locked in, you can choose how to play."* ([BricksFanz review](https://bricksfanz.com/lego-party-game-review/))
4. **Select Game Mode.** *"once you've completed Minifigure character customization, you'll be taken to the Select Game Mode screen. From there, you can choose from several game modes, including Mini Games, Challenge Zones, Mini Game Rush, and Score Chaser."* ([Fictions: specific minigames](https://support.fictions.com/hc/en-us/articles/44984049329171--LEGO-Party-How-do-I-play-specific-Minigames))
5. **Challenge Zone setup.** *"From here you can choose the number of rounds you want to play and then you are into the action."* ([Maxi-Geek review](https://www.maxi-geek.com/con/lego-party-review)). Default is 10 rounds: *"you can set it so that you are playing fewer or more rounds than the usual 10."* ([GameGrin review](https://www.gamegrin.com/reviews/lego-party-review/))
6. **Round loop: minigame first, then board.** *"mini-games ... don't happen at the end of every round. Instead, they initiate the start of every round."* ([SuperPhillip Central review](https://www.superphillipcentral.com/2026/01/lego-party-multi-review.html?m=1)). Placement sets turn order: *"the placements after each mini-game determine your position."* ([Maxi-Geek](https://www.maxi-geek.com/con/lego-party-review)).
7. **Final results in the studio.** *"Once all the rounds are finished, the competitors are all taken back to the studio to see who the winner is."* ([GameGrin](https://www.gamegrin.com/reviews/lego-party-review/)). *"The winner at the end gets a cool trophy."* ([Hey Poor Player review](https://www.heypoorplayer.com/2026/08/17/lego-party-review-switch-2/))
8. **Rewards → Main Menu.** *"Once a game has ended and a winner is crowned, you'll receive experience, increasing both your personal rank and the rank for the board you played on."* ([But Why Tho review](https://butwhytho.net/2025/09/lego-party-review/)).

Two framing facts apply to the whole spine: the game is presented as a TV game show hosted by **Ted Talker and Paige Turner**, with the players as contestants ([GameGrin](https://www.gamegrin.com/reviews/lego-party-review/)); and every session is **four slots** — humans plus CPU — *"with smart AI filling in for any missing human competitors"* ([Hooked Gamers preview](https://hookedgamers.com/pc/lego_party/preview/article-1730.html)).

---

## 2. The seven required questions — direct answers

**How a party starts.** Main Menu → `Play` → `Host Game or Join Game` → 5-digit lobby code → each slot picks a minifigure → `Select Game Mode` → zone + round count → round loop. Local play skips host/join and uses connected controllers; the same avatar and mode steps follow. ([Fictions](https://support.fictions.com/hc/en-us/articles/44983986033171--LEGO-Party-How-do-I-play-online-with-my-friends); [BricksFanz](https://bricksfanz.com/lego-party-game-review/); [Fictions mode article](https://support.fictions.com/hc/en-us/articles/44984049329171--LEGO-Party-How-do-I-play-specific-Minigames))

**How players join.** Three documented routes: (a) type a 5-digit code on the Main Menu, (b) accept/send a platform friend invite through the **Online menu** on the right of the screen, opened with *"press down on the left stick of your controller or press O on your keyboard"*, or (c) from 1.6, pick a **public lobby** from a cross-platform list. There is no matchmaking at launch: the developer's own reply is *"No matchmaking. It's lobby-based online multiplayer for inviting others."* ([Fictions](https://support.fictions.com/hc/en-us/articles/44983986033171--LEGO-Party-How-do-I-play-online-with-my-friends); [Fictions 1.6.0](https://support.fictions.com/hc/en-us/articles/53958409766931--LEGO-Party-Update-1-6-0-Patch-Notes); [Steam thread, developer Sam](https://steamcommunity.com/app/1969370/discussions/0/594035508989085989/))

**How characters/colours are chosen.** Each of the four slots picks a minifigure before mode select; the figure can be a preset or built from parts (head, hair, hat, expression, upper body, lower body). CPU identity and CPU difficulty are chosen on the same step. No separate per-player colour selection is documented: colour arrives as part variants (for example *"All classic Spacemen colours now available"* in the Wardrobe). ([GameGrin](https://www.gamegrin.com/reviews/lego-party-review/); [BricksFanz](https://bricksfanz.com/lego-party-game-review/); [1.4.0 notes](https://store.steampowered.com/news/posts/?feed=steam_community_announcements&enddate=1773878425))

**How the lobby behaves while waiting.** The lobby holds up to four, shows the chosen minifigures, exposes the 5-digit code, and has a **ready state per slot — including CPU slots**. A launch-day player report: *"Why do you need to ready CPU players? Its not like its a big deal, but its odd having to press ready for them specifically."* Public lobbies display ping (fixed in 1.6.62). No timer, kick, text chat or native voice chat is documented. ([Steam thread](https://steamcommunity.com/app/1969370/discussions/0/594035508989085989/); [1.6.62](https://support.fictions.com/hc/en-us/articles/55511035284371--LEGO-Party-Update-1-6-62-Patch-Notes); [voice chat](https://support.fictions.com/hc/en-us/articles/44985923163283--LEGO-Party-Does-LEGO-Party-support-voice-chat))

**How game selection works.** A `Select Game Mode` screen offers `Mini Games`, `Challenge Zones`, `Mini Game Rush` and `Score Chaser` (a `Brick Battles` mode is also named in 1.4 patch notes). Challenge Zone selection adds board (4), round count, optional rules/`The Lab` modifiers, and optional Bonus Bricks. Inside each round, the minigame itself is selected by a **player vote**: three named tiles plus one random tile; *"The tile that has the most players on it after the countdown ends is the mini-game played. In the event of a tie, one of the games chosen by players will be played at random."* ([Fictions mode article](https://support.fictions.com/hc/en-us/articles/44984049329171--LEGO-Party-How-do-I-play-specific-Minigames); [SuperPhillip](https://www.superphillipcentral.com/2026/01/lego-party-multi-review.html?m=1); [1.4.0](https://store.steampowered.com/news/posts/?feed=steam_community_announcements&enddate=1773878425))

**How a night ends.** The last round resolves → all four are returned to the studio set → winner is shown with a trophy → XP/board rank/carrots/minifigures are awarded → Main Menu. There are no random bonus awards at launch (by design), but from 1.4 an optional end-of-zone **Bonus Brick Zone** vote can add Golden Bricks. ([GameGrin](https://www.gamegrin.com/reviews/lego-party-review/); [Hey Poor Player](https://www.heypoorplayer.com/2026/08/17/lego-party-review-switch-2/); [But Why Tho](https://butwhytho.net/2025/09/lego-party-review/); [1.4.0](https://store.steampowered.com/news/posts/?feed=steam_community_announcements&enddate=1773878425))

**How a dropped player is handled.** The dropped player is replaced in-session by a CPU at Normal difficulty; the human can return via a **rejoin pop-up on the Main Menu**, but only while *"your friends are still in the current game and haven't progressed too far without you"*. Rejoin while spectating was explicitly fixed in 1.2.0. There is no documented host migration. ([Fictions: save online games](https://support.fictions.com/hc/en-us/articles/44984020382355--LEGO-Party-Can-I-save-online-games); [Fictions: re-join](https://support.fictions.com/hc/en-us/articles/44984421250835--LEGO-Party-How-do-I-re-join-a-game-in-progress); [1.3.0](https://support.fictions.com/hc/en-us/articles/47304797703827--LEGO-Party-Update-1-3-0-Patch-Notes); [1.2.0](https://support.fictions.com/hc/en-us/articles/46292824886931--LEGO-Party-Update-1-2-0-Patch-Notes))

---

## 3. Stage-by-stage

### Stage 1 — Launch / first run · **present**

**What is documented.** The entry screen is the Main Menu. It contains `Play`, `Load Game` (added to the menu in 1.2.0), a Settings/Controls area, a News panel (added in 1.4.0) and an online panel on the right that shows the player's LEGO Party ID username. A tutorial exists — a reviewer writes *"When you get past the tutorial and start actually playing..."* — but no public source describes its content, length or whether it can be skipped.

**Evidence.**
- Main Menu as code-entry surface: *"Codes can be input whilst on the Main Menu"* ([Fictions](https://support.fictions.com/hc/en-us/articles/44985853617171--LEGO-Party-How-do-I-input-a-code-in-LEGO-Party)).
- Load Game in Main Menu: *"A Load Game option will then be available in the Main Menu"* ([Fictions](https://support.fictions.com/hc/en-us/articles/44984096438163--LEGO-Party-Can-I-save-my-progress-in-a-long-Challenge-Zone)); *"Updated Save Game UI, bringing it to the main menu"* ([1.2.0](https://support.fictions.com/hc/en-us/articles/46292824886931--LEGO-Party-Update-1-2-0-Patch-Notes)).
- News panel: *"Added News Section to display update information in game"* ([1.4.0](https://store.steampowered.com/news/posts/?feed=steam_community_announcements&enddate=1773878425)).
- Username/online panel: *"From the LEGO® Party! Main Menu navigate to the online options menu on the right of the screen > navigate up and click on your user"* ([Fictions](https://support.fictions.com/hc/en-us/articles/44984529986323--LEGO-Party-How-do-I-change-my-username)); *"LEGO® Party ID Usernames are now randomly generated"* ([1.6.0](https://support.fictions.com/hc/en-us/articles/53958409766931--LEGO-Party-Update-1-6-0-Patch-Notes)).
- Tutorial: *"When you get past the tutorial and start actually playing"* ([Hey Poor Player](https://www.heypoorplayer.com/2026/08/17/lego-party-review-switch-2/)).

**Gaps.** No source describes the first-run sequence, any forced sign-in, or the tutorial's screens. `unmeasured`.

---

### Stage 2 — Host setup · **present**

**What is documented.** Online setup begins at `Play > Host Game or Join Game`. Hosting generates a 5-digit code that can be shared with up to three more players. Invites can alternatively be sent from the Online menu. The host controls the session configuration exposed by the mode screen — board, round count, rules — plus the optional 1.6 "advanced game rules" (brick cost/vendor modifiers, brick head starts). Hosting a public lobby is available from 1.6.0.

**Evidence.**
- *"go to Play > Host Game or Join Game. A 5-digit code will be generated, which can be shared to allow up to three additional players to join the lobby."* ([Fictions](https://support.fictions.com/hc/en-us/articles/44983986033171--LEGO-Party-How-do-I-play-online-with-my-friends))
- *"when you host or join a game a 5-digit code will be generated"* ([Fictions](https://support.fictions.com/hc/en-us/articles/46675318267923--LEGO-Party-Play-with-other-players-online))
- Round count is player-set: *"you can adjust how many rounds you'll play"* ([BricksFanz](https://bricksfanz.com/lego-party-game-review/)); *"more rounds means more play time"* ([Maxi-Geek](https://www.maxi-geek.com/con/lego-party-review)).
- Custom rules: *"Brick Head Starts have been moved into this section"*, *"Brick Cost Modifiers"*, *"Brick Vendor Modifiers"* ([1.6.0](https://support.fictions.com/hc/en-us/articles/53958409766931--LEGO-Party-Update-1-6-0-Patch-Notes)); *"Improved flow for applying custom game rules"* ([1.6.62](https://support.fictions.com/hc/en-us/articles/55511035284371--LEGO-Party-Update-1-6-62-Patch-Notes)).
- Public hosting: *"You can now host or join public games"* ([1.6.0](https://support.fictions.com/hc/en-us/articles/53958409766931--LEGO-Party-Update-1-6-0-Patch-Notes)).
- Host has a presentation role online: *"Fixed Host not playing Challenge Zone intros when playing online"* ([1.4.0](https://store.steampowered.com/news/posts/?feed=steam_community_announcements&enddate=1773878425)).

**Gaps.** No source describes host permissions (kick, transfer, close), a host-set lobby timer, or whether non-host players can edit rules. `unmeasured`.

---

### Stage 3 — Party join · **present**

**What is documented.** Joining is code- or invite-based. A player types the 5-digit code on the Main Menu or is invited from the Online menu. From 1.6.0, public lobbies are listed for cross-platform joining. Online play on console requires the platform's subscription service (PS Plus, Game Pass, Nintendo Switch Online). Crossplay is supported across PC/PlayStation/Xbox/Switch. Slots not filled by humans are filled by CPU, so a "party" can be 1–4 humans.

**Evidence.**
- Code/entry: *"A pop up will appear on screen if the input is successful"* ([Fictions](https://support.fictions.com/hc/en-us/articles/44985853617171--LEGO-Party-How-do-I-input-a-code-in-LEGO-Party)).
- Invites: *"you can invite friends through the Online menu, located on the right side of the screen"* ([Fictions](https://support.fictions.com/hc/en-us/articles/44983986033171--LEGO-Party-How-do-I-play-online-with-my-friends)).
- Public lobbies: *"Choose from a list of public Challenge Zone & Minigame Rush lobbies, hosted by other players around the world"* ([1.6.0](https://support.fictions.com/hc/en-us/articles/53958409766931--LEGO-Party-Update-1-6-0-Patch-Notes)).
- No matchmaking at launch (developer): *"No matchmaking. It's lobby-based online multiplayer for inviting others."* ([Steam thread](https://steamcommunity.com/app/1969370/discussions/0/594035508989085989/)).
- Platform subscriptions: *"an active PlayStation Plus subscription is required"* / *"an active Xbox Game Pass subscription is required"* / *"an active Nintendo Switch Online subscription is required"* ([Fictions](https://support.fictions.com/hc/en-us/articles/44983986033171--LEGO-Party-How-do-I-play-online-with-my-friends)).
- Crossplay: *"crossplay will be available"* ([legoparty.com/faq](https://legoparty.com/faq)).
- Four slots with CPU fill: *"All games are designed for four players, with smart AI filling in for any missing human competitors"* ([Hooked Gamers](https://hookedgamers.com/pc/lego_party/preview/article-1730.html)); a player request confirms AI is mandatory: *"Can we please have it so we can only play with two or three friends without adding AI to equal 4."* ([Steam thread](https://steamcommunity.com/app/1969370/discussions/0/594035508989085989/)).
- **Netflix build:** join is per-device QR scan: *"Each player needs their own mobile device. On the main screen, scan the QR code with each device to join the game. The game will show when new controllers are connected. You can add up to four players. If you reach the maximum, the 'Add Controller' option will disappear."* ([Netflix help center](https://games-netflix.helpshift.com/hc/en/44-lego-party/faq/1691-connecting-multiple-controllers-and-devices/))

**Failure state documented.** A host who leaves a lobby while a friend is still in it cannot start a new lobby until that friend leaves: *"you will be met with an error code [0202-0019] and will be unable to start a new lobby until the other people leave the old one. The same applies if you start a lobby, a friend joins, you start the game, and then leave the game."* ([Steam review, Dee](https://steamcommunity.com/id/AgentDee/recommended/1969370))

**Gaps.** No documented queue, password, region filter on join, or "lobby full" screen text. `unmeasured`.

---

### Stage 4 — Player creation / colour & accessory · **present**

**What is documented.** Character choice happens after the party is assembled and before mode selection, for every slot. Players pick a preset minifigure or assemble one from swappable parts: head, hair/hat, expression, upper body, lower body. The roster grows through play (levels, carrots, Wardrobe purchases). No separate per-player colour picker is documented: colour arrives as part variants. CPU characters and CPU difficulty are configured in the same step. The lobby displays the selected minifigure, and a 1.2.0 bug fix ties the lobby preview to the in-game model.

**Evidence.**
- *"Before heading off to tackle the minigames, you'll need to select a minifigure avatar. ... Once players' avatars are locked in, you can choose how to play."* ([BricksFanz](https://bricksfanz.com/lego-party-game-review/))
- Parts list: *"swapping their head, hair, hat, expression, along with the upper body, and lower body"* ([GameGrin](https://www.gamegrin.com/reviews/lego-party-review/)).
- CPU identity/difficulty on the same step: *"Here, you also get to select who the CPU will be and their difficulty level."* ([GameGrin](https://www.gamegrin.com/reviews/lego-party-review/)).
- Roster scale: *"46 figures to choose from to begin with and 300 different characters in total to unlock"* ([GameGrin](https://www.gamegrin.com/reviews/lego-party-review/)); official: *"more than 1 billion minifigure combinations"* ([legoparty.com/faq](https://legoparty.com/faq)).
- Colour as parts: *"15+ new Minifigures to equip and customise in the Wardrobe. All classic Spacemen colours now available"* ([1.4.0](https://store.steampowered.com/news/posts/?feed=steam_community_announcements&enddate=1773878425)).
- Lobby/in-game model link: *"Fix for incorrect Minifigure appearing in game vs what's selected in the lobby"* ([1.2.0](https://support.fictions.com/hc/en-us/articles/46292824886931--LEGO-Party-Update-1-2-0-Patch-Notes)).
- Colour-blind affordance: *"All colors are matched with unique shapes or patterns for colorblind players."* ([Netflix help center](https://games-netflix.helpshift.com/hc/en/44-lego-party/faq/1699-accessibility-features/)) — note: this is the Netflix build's support page.

**Gaps.** No documented separate "player colour" assignment (e.g., P1 red / P2 blue HUD tokens). Whether the same figure can be duplicated across slots is not documented. `unmeasured`.

---

### Stage 5 — Lobby & waiting · **present, thinly documented**

**What is documented.** A four-slot lobby keyed by a 5-digit code. It renders each player's minifigure, supports friend invites from the Online menu, and has a **ready action per slot, including CPU slots**. The host starts the session. A "waiting on slower system/network syncing" prompt exists (fixed in 1.2.0). Public games show ping. There is no native voice chat.

**Evidence.**
- Lobby + code: *"allow up to three additional players to join the lobby"* ([Fictions](https://support.fictions.com/hc/en-us/articles/46675318267923--LEGO-Party-Play-with-other-players-online)).
- Minifigures rendered in lobby: *"Minifigures now load faster in the lobby"* ([1.3.0](https://support.fictions.com/hc/en-us/articles/47304797703827--LEGO-Party-Update-1-3-0-Patch-Notes)).
- Ready per slot: *"Why do you need to ready CPU players? ... its odd having to press ready for them specifically."* ([Steam thread](https://steamcommunity.com/app/1969370/discussions/0/594035508989085989/)).
- Host starts the session: a host describes the sequence *"you start a lobby, a friend joins, you start the game"* ([Steam review, Dee](https://steamcommunity.com/id/AgentDee/recommended/1969370)).
- Waiting/sync prompt: *"Fixed prompt not appearing when waiting on slower system/network syncing"* ([1.2.0](https://support.fictions.com/hc/en-us/articles/46292824886931--LEGO-Party-Update-1-2-0-Patch-Notes)).
- Ping in public games: *"Fixed Ping not displaying correctly in Public Games"* ([1.6.62](https://support.fictions.com/hc/en-us/articles/55511035284371--LEGO-Party-Update-1-6-62-Patch-Notes)).
- No native voice chat: *"LEGO® Party! does not natively support in-game party chat."* ([Fictions](https://support.fictions.com/hc/en-us/articles/44985923163283--LEGO-Party-Does-LEGO-Party-support-voice-chat)).
- **Netflix build:** *"The game will show when new controllers are connected"*, with an `Add Controller` affordance that disappears at four ([Netflix help center](https://games-netflix.helpshift.com/hc/en/44-lego-party/faq/1691-connecting-multiple-controllers-and-devices/)).

**Gaps.** No documented lobby countdown, host "start" button label, kick control, text chat, or what a non-host sees while the host is configuring. The ready gate is evidenced by a player report, not by official documentation. `unmeasured`.

---

### Stage 6 — Game selection · **present**

**What is documented.** Two layers.

*Layer 1 — mode and session setup.* `Select Game Mode` offers `Mini Games`, `Challenge Zones`, `Mini Game Rush` and `Score Chaser`; a `Brick Battles` mode is named in 1.4.0 notes. Challenge Zone adds: board choice (Pirate, NINJAGO, Space, Theme Park), round count (default 10, adjustable), optional rules and `The Lab` modifiers (added 1.6.0), and optional Bonus Bricks (1–10, added 1.4.0). `Mini Game Rush` uses themed playlists, with custom playlists possible. `Minigames` exposes all 60 individually, with a Random option added in 1.3.0 and practice/preview available. `Score Chaser` is a solo high-score mode.

*Layer 2 — the round's minigame vote.* At the start of each round players pick among three named minigames plus one random tile; the tile with the most players wins, ties resolve randomly.

**Evidence.**
- Mode list: ([Fictions](https://support.fictions.com/hc/en-us/articles/44984049329171--LEGO-Party-How-do-I-play-specific-Minigames)).
- Boards and round choice: *"Challenge Zone has four boards, Pirate, Ninjago, Space and Theme Park ... From here you can choose the number of rounds you want to play"* ([Maxi-Geek](https://www.maxi-geek.com/con/lego-party-review)).
- Default 10 rounds: *"fewer or more rounds than the usual 10"* ([GameGrin](https://www.gamegrin.com/reviews/lego-party-review/)).
- `The Lab`: *"Challenge Zone Game Modes (The Lab) — 4 new exciting modes"* ([1.6.0](https://support.fictions.com/hc/en-us/articles/53958409766931--LEGO-Party-Update-1-6-0-Patch-Notes)).
- `Brick Battles`: *"New exciting 2v2 versions of Minigames added to Brick Battles & Minigame Rush!"* ([1.4.0](https://store.steampowered.com/news/posts/?feed=steam_community_announcements&enddate=1773878425)).
- Playlists: *"in the mini-game frenzy mode, where you can choose from existing playlists or create your own"* ([Maxi-Geek](https://www.maxi-geek.com/con/lego-party-review)); *"Added Random option to Minigames game mode"* ([1.3.0](https://support.fictions.com/hc/en-us/articles/47304797703827--LEGO-Party-Update-1-3-0-Patch-Notes)).
- Vote mechanics: ([SuperPhillip](https://www.superphillipcentral.com/2026/01/lego-party-multi-review.html?m=1)); *"The game will offer up three by name and one random"* ([Maxi-Geek](https://www.maxi-geek.com/con/lego-party-review)); *"all the players currently competing vote on the minigame that they want to play from three choices and or random"* ([GameGrin](https://www.gamegrin.com/reviews/lego-party-review/)).

**Gaps.** No documented screen order between mode selection and lobby (whether the lobby is before or after zone/round setup), and no documented "Brick Battles" definition beyond its name in patch notes. `unmeasured`.

---

### Stage 7 — Round intro / countdown · **present**

**What is documented.** Each round opens with the minigame-vote phase and a countdown; when the vote ends the chosen minigame loads. A brief introduction states the goal and controls before play starts. Practice/preview is available before some minigame starts. The host plays Challenge Zone intros online. Round transitions are branded ("Round X" animations). The show framing includes an entrance: *"your character even enters as if called onto the stage."*

**Evidence.**
- Vote + countdown: *"The tile that has the most players on it after the countdown ends is the mini-game played."* ([SuperPhillip](https://www.superphillipcentral.com/2026/01/lego-party-multi-review.html?m=1))
- Minigame intro: *"Each mini-game features a brief, clear introduction to allow players to quickly familiarise themselves with the goal and the controls."* ([Hooked Gamers](https://hookedgamers.com/pc/lego_party/preview/article-1730.html))
- Controls shown before start: *"You can see the required controls before each minigame starts"* ([Netflix help center](https://games-netflix.helpshift.com/hc/en/44-lego-party/faq/1697-minigame-control-schemes/)).
- Practice before play: *"You get to practice the minigame before you play it so you're not thrust straight into it."* ([Steam review, Dee](https://steamcommunity.com/id/AgentDee/recommended/1969370)).
- Host intros: *"Fixed Host not playing Challenge Zone intros when playing online"* ([1.4.0](https://store.steampowered.com/news/posts/?feed=steam_community_announcements&enddate=1773878425)).
- Round branding: *"Fix for Round X animations not displaying correctly in Asian languages"* ([1.2.0](https://support.fictions.com/hc/en-us/articles/46292824886931--LEGO-Party-Update-1-2-0-Patch-Notes)).
- Entrance: ([Maxi-Geek](https://www.maxi-geek.com/con/lego-party-review)).

**Gaps.** No documented countdown length, skip control, or ready gate per round. `unmeasured`.

---

### Stage 8 — In-round controls · **present**

**What is documented.** Minigames use four simplified schemes: joystick only, D-pad only, action button(s) only, or movement + action. Control requirements are shown before the minigame and can be filtered in accessibility settings. The game supports controller and keyboard/mouse, with a Settings → Controls configuration area and rebinding labels (e.g., "Minifigure Movement"). In single-player/CPU sessions, CPU turns in turn-based minigames can be skipped. Colour-blind shapes/patterns and visual sound cues are provided.

**Evidence.**
- Schemes: *"Joystick Only ... D-Pad Only ... Action Button(s) Only ... Movement + Action"*, plus *"filter out control types in the accessibility settings"* ([Netflix help center](https://games-netflix.helpshift.com/hc/en/44-lego-party/faq/1697-minigame-control-schemes/)).
- Simple inputs: *"In most cases, all you need is the left thumbstick and a single button"* ([Hooked Gamers](https://hookedgamers.com/pc/lego_party/preview/article-1730.html)).
- Settings (Controls): ([Fictions](https://support.fictions.com/hc/en-us/articles/44985350853395--LEGO-Party-How-do-I-switch-from-Keyboard-Mouse-to-controller)).
- Rebinding: *"Updated label for 'Minifigure Movement' when rebinding inputs"* ([1.2.0](https://support.fictions.com/hc/en-us/articles/46292824886931--LEGO-Party-Update-1-2-0-Patch-Notes)).
- Skip CPU turns: *"Added ability to skip CPU turns in turn based Minigames"* ([1.3.0](https://support.fictions.com/hc/en-us/articles/47304797703827--LEGO-Party-Update-1-3-0-Patch-Notes)).
- Accessibility: *"All colors are matched with unique shapes or patterns"*, *"Any critical sound cue is also shown visually"* ([Netflix help center](https://games-netflix.helpshift.com/hc/en/44-lego-party/faq/1699-accessibility-features/)).

**Gaps.** A per-minigame control map (which button does what, for all 60) is not published in text. `unmeasured`.

---

### Stage 9 — Round end · **present**

**What is documented.** After the minigame, a **Minigame Results** screen resolves the round: studs are awarded there, host commentary plays, and players can emote/dance/interact (including a slap interaction). Continuing from it was reduced from two presses to one in 1.2.0. Placement then sets the board turn order. The board portion ends after all players have moved, then the next round starts.

**Evidence.**
- Results screen and interactions: *"Players can no longer slap each other out of bounds in Minigame Results"* ([1.3.0](https://support.fictions.com/hc/en-us/articles/47304797703827--LEGO-Party-Update-1-3-0-Patch-Notes)); *"Players no longer end up in the void when slapped in the Minigame results area"* ([1.3.0](https://support.fictions.com/hc/en-us/articles/47304797703827--LEGO-Party-Update-1-3-0-Patch-Notes)).
- Continue: *"Two button presses no longer required to continue from the Minigame Results screen"* ([1.2.0](https://support.fictions.com/hc/en-us/articles/46292824886931--LEGO-Party-Update-1-2-0-Patch-Notes)); *"Studs added to the glove in results screen"* ([1.6.0](https://support.fictions.com/hc/en-us/articles/53958409766931--LEGO-Party-Update-1-6-0-Patch-Notes)).
- Results decoration added in 1.4: *"new dance moves and interactable objects added to the Minigame Results"* ([1.4.0](https://store.steampowered.com/news/posts/?feed=steam_community_announcements&enddate=1773878425)).
- Turn order: *"how you do in the minigame determines the order you move in"* ([Hey Poor Player](https://www.heypoorplayer.com/2026/08/17/lego-party-review-switch-2/)).

**Gaps.** No documented board-side round summary (studs/bricks gained per player at round end). `unmeasured`.

---

### Stage 10 — Results / scoreboard · **present, partial**

**What is documented.** The authoritative end-of-session ranking is Golden Bricks, with studs as tiebreaker: *"Whoever has the most Gold Bricks at the end of the game, with studs used as a tiebreaker, is declared the winner."* The final screen returns the four players to the studio for the reveal. There are no participation/random bonus awards at launch, and a reviewer notes the absence of a stats graph. From 1.4.0, an optional Bonus Brick Zone vote can add bricks at the end of a Challenge Zone.

**Evidence.**
- Win condition: ([But Why Tho](https://butwhytho.net/2025/09/lego-party-review/)); ([BricksFanz](https://bricksfanz.com/lego-party-game-review/)).
- Studio reveal: ([GameGrin](https://www.gamegrin.com/reviews/lego-party-review/)).
- No random awards: *"I am happy that LEGO Party doesn't bother with random participation awards at the end of each board"* ([IGN review, syndicated](https://sea.ign.com/lego-party/233523/review/lego-party-review)) — IGN's body text was only available through the syndicated snippet; treat as supporting, not primary.
- No stats graph: *"I was also sad that I couldn't check out a graph or stats showing the number of bricks collected by everyone throughout all the rounds."* ([GameGrin](https://www.gamegrin.com/reviews/lego-party-review/)).
- Bonus Brick vote: *"Players can vote from a list of random qualifiers, with the winner being awarded the bonus Golden Brick"* ([1.4.0](https://store.steampowered.com/news/posts/?feed=steam_community_announcements&enddate=1773878425)).

**Gaps.** No documented per-round standings screen and no documented in-game scoreboard table beyond the board HUD. `unmeasured`.

---

### Stage 11 — Next round / Play again · **present for "next round"; no evidence for "play again"**

**What is documented.** The session runs until the pre-set round count is reached; the results screen's continue action advances the loop. Quitting mid-session is a deliberate flow: pause → `Quit to Main Menu` → save prompt, then `Load Game` from the Main Menu (local/couch sessions only; online games cannot be saved).

**Evidence.**
- Continue: ([1.2.0](https://support.fictions.com/hc/en-us/articles/46292824886931--LEGO-Party-Update-1-2-0-Patch-Notes)).
- Round count fixed up front: ([But Why Tho](https://butwhytho.net/2025/09/lego-party-review/)); ([GameGrin](https://www.gamegrin.com/reviews/lego-party-review/)).
- Save/quit: *"pausing and choosing to 'Quit to Main Menu' will present you with the option to save your game. A Load Game option will then be available in the Main Menu for your local couch play session/s, of up to four players."* ([Fictions](https://support.fictions.com/hc/en-us/articles/44984096438163--LEGO-Party-Can-I-save-my-progress-in-a-long-Challenge-Zone)).
- Online cannot be saved: *"No"* ([Fictions](https://support.fictions.com/hc/en-us/articles/44984020382355--LEGO-Party-Can-I-save-online-games)).

**Gaps.** **No evidence of a "Play again"/rematch control, or of what the post-rewards screen offers.** One review claims *"each game saves progress after every round"* ([SuperPhillip](https://www.superphillipcentral.com/2026/01/lego-party-multi-review.html?m=1)), which conflicts with the official "No" for online games; treat the review claim as unverified.

---

### Stage 12 — End of night · **present**

**What is documented.** When the last round resolves, the session ends in the studio set: the winner is revealed and receives a trophy; the game then pays out XP (player rank and board rank), carrots and minifigure unlocks, and the session is over. Optional Bonus Bricks (1.4) can be configured before the game and voted on at the end of the Challenge Zone. No end-of-night "keep the party going"/next-session link is documented.

**Evidence.**
- Studio + winner: ([GameGrin](https://www.gamegrin.com/reviews/lego-party-review/)).
- Trophy: *"The winner at the end gets a cool trophy, and you as a player earn points towards unlocking..."* ([Hey Poor Player](https://www.heypoorplayer.com/2026/08/17/lego-party-review-switch-2/)).
- Rewards: *"Once a game has ended and a winner is crowned, you'll receive experience, increasing both your personal rank and the rank for the board you played on. In both cases, you'll receive minifigures and carrots as a reward"* ([But Why Tho](https://butwhytho.net/2025/09/lego-party-review/)).
- Bonus Bricks: ([1.4.0](https://store.steampowered.com/news/posts/?feed=steam_community_announcements&enddate=1773878425)).

**Gaps.** The exact order of winner reveal → XP payout → menu, and whether a "next party" hook exists, are not documented. `unmeasured`.

---

### Stage 13 — Re-entry after a drop · **present**

**What is documented.** Dropped humans are replaced in-session by CPU at Normal difficulty. Re-entry is menu-based: a rejoin pop-up appears on the Main Menu, and the returning player can rejoin an active Mini Game Rush or Challenge Zone — provided the friends are still in the session and have not progressed too far. Rejoin while spectating was fixed in 1.2.0; lobby/rejoin stability was improved in 1.2.0 and 1.3.0; a 1.6.0 fix removed a softlock when disconnecting/reconnecting while viewing the map; 1.6.62 fixed the Rejoin button appearing when it should not. No host migration is documented; a host who leaves cannot start a new lobby while others remain in the old one (error 0202-0019).

**Evidence.**
- *"the game has a rejoin system which will enable you to jump straight back into the game, so long as your friends are still in the current game and haven't progressed too far without you."* ([Fictions](https://support.fictions.com/hc/en-us/articles/44984020382355--LEGO-Party-Can-I-save-online-games)).
- *"You can re-join an online game that you have lost connection with if you are prompted with a rejoin pop-up in the LEGO® Party! Main Menu. Your online friends would still need to either be in an active Mini Game Rush session or a Challenge Zone."* ([Fictions](https://support.fictions.com/hc/en-us/articles/44984421250835--LEGO-Party-How-do-I-re-join-a-game-in-progress)).
- CPU takeover: *"Human replacement CPUs now appear at Normal Difficulty"* ([1.3.0](https://support.fictions.com/hc/en-us/articles/47304797703827--LEGO-Party-Update-1-3-0-Patch-Notes)).
- Spectating: *"Fix for game rejoin not working if spectating a game"* ([1.2.0](https://support.fictions.com/hc/en-us/articles/46292824886931--LEGO-Party-Update-1-2-0-Patch-Notes)).
- Rejoin improvements: *"Improvements to rejoining games in the case of player drop outs"* ([1.2.0](https://support.fictions.com/hc/en-us/articles/46292824886931--LEGO-Party-Update-1-2-0-Patch-Notes)); *"Improved stability of our online lobbies and rejoin functionality"* ([1.3.0](https://support.fictions.com/hc/en-us/articles/47304797703827--LEGO-Party-Update-1-3-0-Patch-Notes)).
- Map softlock: *"Disconnecting and reconnecting whilst viewing the map will no longer softlock the game"* ([1.6.0](https://support.fictions.com/hc/en-us/articles/53958409766931--LEGO-Party-Update-1-6-0-Patch-Notes)).
- Rejoin button: *"Fixed Rejoin button triggering when not displayed in the Main Menu"* ([1.6.62](https://support.fictions.com/hc/en-us/articles/55511035284371--LEGO-Party-Update-1-6-62-Patch-Notes)).
- Host-left failure: ([Steam review, Dee](https://steamcommunity.com/id/AgentDee/recommended/1969370)).
- **Netflix build:** *"You can usually rejoin the game in progress without losing your spot"*, by rescanning the QR code ([Netflix help center](https://games-netflix.helpshift.com/hc/en/44-lego-party/faq/1694-reconnecting-after-controller-disconnection/)).

**Gaps.** No documented rejoin time limit, no documented host migration, no documented state of the CPU-controlled slot when the human returns (whether control is handed back immediately), and no documented "player left" banner. `unmeasured`.

---

## 4. Cross-cutting observations relevant to M16

1. **The session is four slots, not "n players".** The game always runs four contestants; unfilled slots are CPU. A party of two is a party of two humans plus two CPUs ([Hooked Gamers](https://hookedgamers.com/pc/lego_party/preview/article-1730.html); [Steam thread](https://steamcommunity.com/app/1969370/discussions/0/594035508989085989/)).
2. **Identity is the minifigure, not a colour token.** There is no documented P1/P2 colour assignment; colour is a property of parts, and the lobby previews the actual figure ([GameGrin](https://www.gamegrin.com/reviews/lego-party-review/); [1.2.0](https://support.fictions.com/hc/en-us/articles/46292824886931--LEGO-Party-Update-1-2-0-Patch-Notes)).
3. **Joining is code-first.** The 5-digit code is the primary join mechanic; public lobbies were added ten months after launch ([Fictions](https://support.fictions.com/hc/en-us/articles/46675318267923--LEGO-Party-Play-with-other-players-online); [1.6.0](https://support.fictions.com/hc/en-us/articles/53958409766931--LEGO-Party-Update-1-6-0-Patch-Notes)).
4. **Session length is chosen before the party commits.** Default 10 rounds, adjustable; published estimates run 45 minutes to three hours depending on board and rounds ([GameGrin](https://www.gamegrin.com/reviews/lego-party-review/); [Hooked Gamers](https://hookedgamers.com/pc/lego_party/preview/article-1730.html)).
5. **No online resume.** Online sessions cannot be saved; only local/couch sessions can be saved and reloaded ([Fictions](https://support.fictions.com/hc/en-us/articles/44984020382355--LEGO-Party-Can-I-save-online-games); [Fictions](https://support.fictions.com/hc/en-us/articles/44984096438163--LEGO-Party-Can-I-save-my-progress-in-a-long-Challenge-Zone)).
6. **Host authority is real but narrow.** Host generates the code, starts the session, and plays intros; no kick/transfer/migration is documented ([Fictions](https://support.fictions.com/hc/en-us/articles/44983986033171--LEGO-Party-How-do-I-play-online-with-my-friends); [1.4.0](https://store.steampowered.com/news/posts/?feed=steam_community_announcements&enddate=1773878425)).
7. **Re-entry is friends-dependent.** The rejoin prompt only works while the group is still in the session; there is no solo resume of an online party ([Fictions](https://support.fictions.com/hc/en-us/articles/44984421250835--LEGO-Party-How-do-I-re-join-a-game-in-progress)).

---

## 5. Conflicts in the public record

- **Saving online games.** Official support: *"No"* ([Fictions](https://support.fictions.com/hc/en-us/articles/44984020382355--LEGO-Party-Can-I-save-online-games)). A review claims *"each game saves progress after every round"* ([SuperPhillip](https://www.superphillipcentral.com/2026/01/lego-party-multi-review.html?m=1)). Official documentation wins here; the review claim is unverified.
- **When the minigame runs.** Wikipedia's gameplay summary says a minigame begins after a round ([Wikipedia](https://en.wikipedia.org/wiki/Lego_Party)); first-hand reviews and previews say it opens each round ([SuperPhillip](https://www.superphillipcentral.com/2026/01/lego-party-multi-review.html?m=1); [Hey Poor Player](https://www.heypoorplayer.com/2026/08/17/lego-party-review-switch-2/); [Hooked Gamers](https://hookedgamers.com/pc/lego_party/preview/article-1730.html)). The reviews are consistent with each other and are treated as correct.
- **Mode count/naming.** The official support article lists four modes ([Fictions](https://support.fictions.com/hc/en-us/articles/44984049329171--LEGO-Party-How-do-I-play-specific-Minigames)); 1.4.0 patch notes additionally name `Brick Battles` ([1.4.0](https://store.steampowered.com/news/posts/?feed=steam_community_announcements&enddate=1773878425)) without defining it. Treat `Brick Battles` as a named mode with no documented description.
- **Roster totals.** 46 at start / 300 total ([GameGrin](https://www.gamegrin.com/reviews/lego-party-review/)) vs. 168 ([Games.gg guide](https://games.gg/zh-Hant/lego-party/guides/lego-party%E6%8C%87%E5%8D%97%E6%89%80%E6%9C%89%E5%8F%AF%E8%A7%A3%E9%8E%96%E8%A7%92%E8%89%B2%E8%88%87%E4%BA%BA%E5%81%B6/)) — the latter source was read only as a search snippet and is not relied on.
- **Team games.** A review says *"there are no games that require you to team up, except for the odd time someone lands on a Brick Battle square"* ([GameGrin](https://www.gamegrin.com/reviews/lego-party-review/)), but 2v2 minigames exist and were expanded in 1.4.0 ([1.4.0](https://store.steampowered.com/news/posts/?feed=steam_community_announcements&enddate=1773878425)). Both can be true if the review predates the 2v2 expansion; the review is dated October 2025.

---

## 6. Stages / sub-stages with no evidence found

No stage in the 13-stage taxonomy is absent from the product: every stage has at least one documented behaviour no later than 1.6.x. The following **sub-stages produced no evidence** and are flagged rather than filled in:

| # | Stage | Item with no evidence |
|---|---|---|
| 1 | Launch / first run | First-run sequence, tutorial content, any forced sign-in/onboarding screen |
| 5 | Lobby & waiting | Lobby timer/countdown, kick control, text chat, host-only configuration visibility; human ready gate is only inferred from a player report |
| 9 | Round end | Any board-side round summary (per-player gains at end of round) |
| 10 | Results / scoreboard | A per-round standings table or in-session scoreboard screen (only final results and the board HUD are documented) |
| 11 | Next round / Play again | A "Play again"/rematch control, and what the post-rewards screen offers |

Also `unmeasured`: every pixel position, dp size, contrast ratio, density value and theme token; all screen-level layouts in this digest are described from text, not from capture.

---

## 7. Source list

Primary (developer/publisher):

- [legoparty.com FAQ](https://legoparty.com/faq)
- [LEGO newsroom announcement, 6 June 2025](https://www.lego.com/ro-ro/aboutus/news/2025/june/lego-party?locale=ro-ro&age-gate=grown_up)
- Fictions support: [play with other players online](https://support.fictions.com/hc/en-us/articles/46675318267923--LEGO-Party-Play-with-other-players-online) · [how do I play online with my friends](https://support.fictions.com/hc/en-us/articles/44983986033171--LEGO-Party-How-do-I-play-online-with-my-friends) · [input a code](https://support.fictions.com/hc/en-us/articles/44985853617171--LEGO-Party-How-do-I-input-a-code-in-LEGO-Party) · [online menu](https://support.fictions.com/hc/en-us/articles/44985793157651--LEGO-Party-How-do-I-access-the-online-menu) · [re-join a game](https://support.fictions.com/hc/en-us/articles/44984421250835--LEGO-Party-How-do-I-re-join-a-game-in-progress) · [save online games](https://support.fictions.com/hc/en-us/articles/44984020382355--LEGO-Party-Can-I-save-online-games) · [save Challenge Zone progress](https://support.fictions.com/hc/en-us/articles/44984096438163--LEGO-Party-Can-I-save-my-progress-in-a-long-Challenge-Zone) · [specific minigames](https://support.fictions.com/hc/en-us/articles/44984049329171--LEGO-Party-How-do-I-play-specific-Minigames) · [keyboard/mouse to controller](https://support.fictions.com/hc/en-us/articles/44985350853395--LEGO-Party-How-do-I-switch-from-Keyboard-Mouse-to-controller) · [voice chat](https://support.fictions.com/hc/en-us/articles/44985923163283--LEGO-Party-Does-LEGO-Party-support-voice-chat) · [username](https://support.fictions.com/hc/en-us/articles/44984529986323--LEGO-Party-How-do-I-change-my-username) · [progress across platforms](https://support.fictions.com/hc/en-us/articles/44985228031507--LEGO-Party-Does-my-progress-carry-across-platforms) · [cloud saves](https://support.fictions.com/hc/en-us/articles/44985948898195--LEGO-Party-Does-LEGO-Party-support-cloud-saves)
- Patch notes: [1.2.0](https://support.fictions.com/hc/en-us/articles/46292824886931--LEGO-Party-Update-1-2-0-Patch-Notes) · [1.3.0](https://support.fictions.com/hc/en-us/articles/47304797703827--LEGO-Party-Update-1-3-0-Patch-Notes) · [1.4.0 (Steam)](https://store.steampowered.com/news/posts/?feed=steam_community_announcements&enddate=1773878425) · [1.5.0](https://support.fictions.com/hc/en-us/articles/51074632065299--LEGO-Party-Update-1-5-0-Patch-Notes) · [1.6.0](https://support.fictions.com/hc/en-us/articles/53958409766931--LEGO-Party-Update-1-6-0-Patch-Notes) · [1.6.62](https://support.fictions.com/hc/en-us/articles/55511035284371--LEGO-Party-Update-1-6-62-Patch-Notes)
- Netflix build support: [connecting controllers](https://games-netflix.helpshift.com/hc/en/44-lego-party/faq/1691-connecting-multiple-controllers-and-devices/) · [reconnecting after controller disconnection](https://games-netflix.helpshift.com/hc/en/44-lego-party/faq/1694-reconnecting-after-controller-disconnection/) · [manual reconnect](https://games-netflix.helpshift.com/hc/en/44-lego-party/faq/1693-manually-reconnecting-to-the-game-without-a-qr-code/) · [control schemes](https://games-netflix.helpshift.com/hc/en/44-lego-party/faq/1697-minigame-control-schemes/) · [accessibility](https://games-netflix.helpshift.com/hc/en/44-lego-party/faq/1699-accessibility-features/) · [practising minigames](https://games-netflix.helpshift.com/hc/en/44-lego-party/faq/1695-practicing-and-previewing-minigames/)
- Community: [Steam pinned feedback thread (developer replies)](https://steamcommunity.com/app/1969370/discussions/0/594035508989085989/) · [Steam review by Dee](https://steamcommunity.com/id/AgentDee/recommended/1969370)

Secondary (reviews/previews):

- [BricksFanz review, 29 Sep 2025](https://bricksfanz.com/lego-party-game-review/)
- [GameGrin review, Oct 2025](https://www.gamegrin.com/reviews/lego-party-review/)
- [SuperPhillip Central review, 1 Jan 2026](https://www.superphillipcentral.com/2026/01/lego-party-multi-review.html?m=1)
- [But Why Tho review, 30 Sep 2025](https://butwhytho.net/2025/09/lego-party-review/)
- [Maxi-Geek review, 30 Sep 2025](https://www.maxi-geek.com/con/lego-party-review)
- [Hey Poor Player review (Switch 2), 17 Aug 2026](https://www.heypoorplayer.com/2026/08/17/lego-party-review-switch-2/)
- [Hooked Gamers preview, 27 Sep 2025](https://hookedgamers.com/pc/lego_party/preview/article-1730.html)
- [GamesNight review, 24 Nov 2025](https://gamesnight.nz/lego-party-review/)
- [Wikipedia: Lego Party](https://en.wikipedia.org/wiki/Lego_Party) (used only for dates/awards and flagged where it conflicts)
- [IGN syndicated review snippet](https://sea.ign.com/lego-party/233523/review/lego-party-review) (body text not retrievable; used only for the "no random participation awards" point)
