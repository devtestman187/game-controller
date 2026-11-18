# Super Mario Party Jamboree — player-flow research digest

Scope: *Super Mario Party Jamboree*, Nintendo Switch, released 2024-10-17 (worldwide)
([Super Mario Wiki](https://www.mariowiki.com/Super_Mario_Party_Jamboree)). Notes on the
2025 Switch 2 Edition (+ Jamboree TV) are marked where they change the flow. All stages
are numbered per `worker-spec.md` section 1. No device capture was performed for this
digest; every claim below is a quotation or close paraphrase of a cited public page, and
screen geometry is **not** measured here (`unmeasured`).

Method note: official Nintendo support pages were preferred for step order and button
labels; press reviews for what the screens contain; community wiki/forum posts only where
no official page covers the behaviour, and labelled as such.

---

## 1. Launch / first run

Evidence:

- Start from the HOME Menu, then a Joy-Con strap notice appears before the title screen:
  "If you are using Joy-Con 2 or Joy-Con controllers to play, read the notice that
  appears, attach the straps, and then close the notice."
- The title screen is gated on a two-button press: "Press the **L Button** and **R Button**
  together on the title screen."
- Online features require an update and a Nintendo Switch Online membership: "The game
  must be updated to the latest version to play online"; "A Nintendo Switch Online
  membership and a copy of the *Super Mario Party Jamboree* game is required on each
  system to play online."
- First-run progression gate: "Once you've completed your first board, you unlock Pro
  Rules" (Console Creatures).
- Controller-dependent prompt reported by a player: with a Pro Controller the game "m'a
  demandé si je voulais desactivé les mini jeux dynamiques ou alors je devais utiliser un
  joy con" — i.e. it offers to disable motion minigames instead of requiring Joy-Con
  ([jeuxvideo.com forum, page 5](https://m.jeuxvideo.com/forums/42-3007199-74441581-5-0-1-0-officiel-super-mario-party-jamboree.htm), community report).

Sources: [Nintendo Support KA 66549](https://en-americas-support.nintendo.com/app/answers/detail/a_id/66549),
[Console Creatures review](https://www.consolecreatures.com/review-super-mario-party-jamboree/).

Flow: HOME Menu → strap notice (modal, dismiss with OK) → title screen (L+R) → player-count
screen. There is no account sign-in wall and no forced tutorial on this path; the
single-player story mode *Party-Planner Trek* is a separate island, not a first-run
tutorial ([Super Mario Wiki](https://www.mariowiki.com/Super_Mario_Party_Jamboree)).

---

## 2. Host setup

Local (the console owner is the implicit host; there is no host role in local play):

1. "Select the number of players that will be playing on this system (between one and
   four)."
2. "If you have more than one player, you can link a User Account or change the name for
   any guest player."
3. "Select a character for each player, then press the **A Button** when everyone is ready."
4. "When Toad asks if you want to climb aboard the Hot-Air Balloon, select **Set Off!**"
   (or **Stay in Plaza** to go online).

Online friend rooms invert this: the room creator is the host and "The room host will have
control over selecting the game mode and other settings." Room controls while hosting:
"press the **X Button** to view the room info, the **Y Button** to invite friends, or the
**B Button** to end the session and close the room"; "press and hold the **Y Button** to
show the passcode."

Rule parameters are set before the board: "Configure the difficulty of CPU players, toggle
the number of Stars each player starts with, enable or disable Motion Minigames, and more"
([Nintendo, official product page](https://www.nintendo.com/en-za/Games/Nintendo-Switch-games/Super-Mario-Party-Jamboree-2591147.html)).
Turn count is a Party Rules setting: "the number of turns (10 turns are usually 90 minutes,
but you can crank that up to 30 turns)" (Console Creatures). A per-mode Player Settings
screen also sets CPU vs human per character: "There you can change whether a character is
CPU controlled of player controlled"
([n-europe forum](https://forum.n-europe.com/topic/40016-super-mario-party-jamboree-17th-october-2024/page/2/), community report).

Sources: [Nintendo Support KA 66549](https://en-americas-support.nintendo.com/app/answers/detail/a_id/66549).

---

## 3. Party join

- **Local.** No in-game "join" screen exists. Controllers are added at the player-count
  step (1–4) and characters are assigned per player on the next screen. With more than one
  local player, online is disabled: "Select this mode with multiple players connected and
  you'll get the option to play with people nearby, that's the people currently using a
  Joy-con, and you'll also find that the online option is now unavailable"
  ([Nintendo Life](https://www.nintendolife.com/guides/super-mario-party-jamboree-multiplayer-requirements-local-and-online-guide)).
- **Online with specific people.** "Press the **Y Button** to connect online, then select
  **Connect**"; alternatively "walk to the antenna and pressing the **A Button**." Then
  either "Select **Create Room**" (4-Player Room for Mario Party/Minigame Bay, 8-Player
  Room for Bowser Kaboom Squad/Koopathlon), set "Yes to set a four-digit passcode … or **No**
  to skip", or "Select **Join a Room**" → pick from "the room list" / "press the **Y
  Button** to search by Room ID" → "If the room has a passcode set, enter the passcode."
  Joining brings you "to a selection of rooms split into 4 and 8-player listings"
  (Nintendo Life).
- **Online with anyone.** "Select **Worldwide** to connect to the Internet"; supported for
  "Mario Party, Bowser Kaboom Squad, Koopathlon, and Minigame Bay (certain activities
  only)."
- 8-Player Room "can only be selected while you are in single player mode (only one player
  is playing on your system)."

Sources: [Nintendo Support KA 66549](https://en-americas-support.nintendo.com/app/answers/detail/a_id/66549),
[Nintendo Life](https://www.nintendolife.com/guides/super-mario-party-jamboree-multiplayer-requirements-local-and-online-guide).

Absent: no join-in-progress for a player who was not in the match (see stage 13); no
local-wireless "nearby" join for Mario Party mode on the 2024 Switch version (the Switch 2
Edition adds GameShare, "People Nearby", `a_id/68617`).

---

## 4. Player creation / colour & accessory

- Creation is **character selection only**: "Select a character for each player, then press
  the **A Button** when everyone is ready." The roster is 22 characters, of which "two of
  these characters, **Pauline and Ninji**, are initially locked off from use"; they are
  found by zooming the hot-air balloon view ("the small sandy island right to the left of
  Minigame Bay"; "the hills to the right and directly behind" Rhythm Kitchen)
  ([Nintendo Life](https://www.nintendolife.com/guides/super-mario-party-jamboree-how-to-unlock-pauline-and-ninji)).
- Identity is per-player slot: guest players can be renamed or have a User Account linked
  at the player-count step (KA 66549).
- **Colour choice: absent.** No source describes picking a colour or a palette for a
  character; each character is visually fixed and distinct, so colour is implied by the
  character rather than chosen.
- **Accessory/outfit choice: absent at setup.** Cosmetic customisation exists only as
  unlockable meta-rewards bought with Party Points: "you can also unlock additional stages
  and other items like stickers, reactions, and other minor collectibles"
  ([Dot Esports](https://dotesports.com/mario/news/all-rewards-in-super-mario-party-jamboree)).
  Those are plaza purchases, not character-loadout options on the character-select screen.

---

## 5. Lobby & waiting

- The lobby is the online room, not a separate screen. After creating a room the host can
  inspect it (X), invite (Y), or close it (B); the passcode is shown by holding Y. The
  party does not leave for the board until everyone is in: "Once all players have joined
  the room, walk to the Hot-Air Balloon and press the **A Button** to go to Party Plaza."
- The host, not the guests, drives progression: "The room host will have control over
  selecting the game mode and other settings."
- Before/around the room, players exist as their character in Party Plaza, and a Toad NPC
  edits setup: "You can also talk to the Toad in the Party Plaza to change character and
  the number of players, as well as the message speed"
  ([n-europe forum](https://forum.n-europe.com/topic/40016-super-mario-party-jamboree-17th-october-2024/page/2/), community report).
- Waiting can be filled by bots: online, "you may select to play against human players but
  get paired against AI if a match is not available; when this happens, the game lies to
  you and gives these bots account names"
  ([Niche Gamer](https://nichegamer.com/reviews/super-mario-party-jamboree-review/)).
  A French player reports the same for 4-player online: "le jeu ne trouve pas de joueurs et
  nous match avec des ordis dès le début"
  ([jeuxvideo.com, page 9](https://www.jeuxvideo.com/forums/42-3007199-74441581-9-0-1-0-officiel-super-mario-party-jamboree.htm), community report).

Sources: [Nintendo Support KA 66549](https://en-americas-support.nintendo.com/app/answers/detail/a_id/66549).

Absent/unverified: no documented ready-check, countdown, host migration, kick/vote, or
in-lobby minigame practice; no official statement of what a joined guest can do besides
wait. Those sub-behaviours are `unverified`, not described here.

---

## 6. Game selection

- Mode selection happens on a map of islands in Party Plaza: "Select the mode you'd like to
  play. You can either switch between modes using the **L Button** and **R Button**, locate
  the island for that mode using the **Left Stick**, or press the **Y Button** to open the
  map, then select the island using the **A Button**." Modes present: Mario Party, Minigame
  Bay, Motion Island (Paratroopa Flight School, Toad's Item Factory, Rhythm Kitchen), Bowser
  Challenges (Koopathlon, Bowser Kaboom Squad), Party-Planner Trek
  ([Super Mario Wiki](https://www.mariowiki.com/Super_Mario_Party_Jamboree)).
- Inside Mario Party, the order is opponent type → rule type → map: "Before you even select
  a map, you will have to decide if you want to play against local players or CPUs, or play
  online. Once that is decided, you will have to choose which rule type you want to play"
  (Niche Gamer).
- Board select: "There are a total of seven boards to play on. Four boards are unlocked and
  available from the get-go, and a further three are made available as you progress"; the
  locked three come from "achievements … and make your way through the rankings towards the
  maximum level of 50" (Nintendo Life). The board-select screen also carries help: "check
  out a few further tips and tricks in the in-game menu as you select which board you want
  to play" (Nintendo Life).
- Rules: **Party Rules** is adjustable (turns 10–30, bonus-star switch, assists, CPU
  difficulty, Star handicap, motion minigames); **Pro Rules** is a locked ruleset — "the
  only option that the player can have before starting a game is the ability to turn off
  mini-games help (unavailable in matchmaking) and motion-controlled minigames. The ruleset
  includes the game lasting for 12 turns only, one Bonus Star that is announced at the start
  of the game, and minigame selection being set to vote"
  ([Super Mario Wiki](https://www.mariowiki.com/Super_Mario_Party_Jamboree)).

Absent: no free per-minigame picker inside a board game (minigames are drawn per round;
"vote" is the Pro Rules mechanism). A Party Rules minigame-selection option exists but its
values are not documented in the sources read → `unverified`.

---

## 7. Round intro / countdown

- Turn order is decided by an opening dice roll, not by a menu: "the blocks are also used to
  determine the turn order of the game before it starts: Each player hits a Dice Block, and
  whoever rolls the highest number goes first, while the player who rolls the lowest number
  goes last" ([Super Mario Wiki — Dice Block](https://www.mariowiki.com/Dice_Block)).
  A fan guide describes the same beat: "Let the game establish turn order with its opening
  roll" ([studboards](https://www.studboards.com/play/guides/play-super-mario-party-jamboree/)).
- Board arrival carries an introduction before play: "Read the board introduction together"
  (studboards).
- The minigame is announced and explained after the last player's turn: "After each player
  has had a turn, everyone will clash in one of over 110 minigames"
  ([Nintendo, official product page](https://www.nintendo.com/en-za/Games/Nintendo-Switch-games/Super-Mario-Party-Jamboree-2591147.html)).
- Each minigame has an instruction phase plus a rehearsal: "The embedded practice mode in
  the UI provides the chance to test-run a minigame before diving in"
  ([Cogconnected](https://cogconnected.com/review/super-mario-party-jamboree-review/));
  "each mini-game has a quick practice round before the main event"
  ([K-Zone](https://www.kzone.com.au/article/playing-now-super-mario-party-jamboree-613107)).

Absent: no source read states a numeric 3-2-1 countdown on the minigame intro or a skippable
vs. non-skippable rules card. The practice round can be disabled indirectly through the
"minigames help" setting (Pro Rules description above), but the Party Rules control for it is
`unverified`.

---

## 8. In-round controls

- Dice: "To roll a Dice Block, the player needs to press **A**"; "Holding down **A** in
  *Super Mario Party* and *Super Mario Party Jamboree* causes the Dice Block to spin faster"
  (Super Mario Wiki — Dice Block). A guide describes the stop action and junction choice:
  "Choose the Dice Block, stop it with the prompted button, then move the distance the game
  assigns; select a direction when a junction asks you to" (studboards).
- Map and items are on the player's turn UI: "open the map using the displayed control";
  "If the item menu offers an item you hold, read its effect and decide whether to use it
  before rolling" (studboards).
- Turn HUD: "the number of spaces you were to the star appearing in the top left of the
  screen, that the turn order was a scrolling bar"
  ([TechRaptor](https://techraptor.net/gaming/reviews/super-mario-party-jamboree-whole-party-and-then-some)).
- Online time pressure: "In online games with random players, each player's turn has a
  30-second time limit" (Super Mario Wiki); a reviewer confirms "the Party mode …
  fortunately has a 30-second timer"
  ([TheNerdStash](https://thenerdstash.com/super-mario-party-jamboree-review-new-levels-of-fun/)).
- Motion minigames can be removed from the pool: "the ability to turn off motion-controlled
  minigames (you wouldn't be missing out on too much by doing so as there are only 15 of
  them)" ([My Nintendo News](https://mynintendonews.com/2024/10/15/review-super-mario-party-jamboree/)).
- A Jamboree Buddy on the board forces a special minigame: "When a player passes by an
  unaffiliated Jamboree Buddy on the board, all players participate in a Showdown minigame"
  (Super Mario Wiki).

---

## 9. Round end

- The round terminates in a minigame payout, not a board scoreboard: "When all four players
  have made their turn, they all play a minigame, at the end of which the winner gets a
  sizeable amount of coins, while the three others get way less"
  ([Backloggd review](https://backloggd.com/u/Funzo/review/3743625/)). Nintendo states the
  same rule: "The better you do, the more coins you'll get."
- Bonus minigames double the payout: "the occurrence of Bonus Minigames, where the coins won
  are doubled" (Super Mario Wiki).
- Control then returns to the board and the next turn; there is no inter-round menu
  documented.

Absent: no evidence of a distinct per-round scoreboard screen between the minigame result and
the next turn; the paying screen is described as part of the minigame result.

---

## 10. Results / scoreboard

- Board ranking is by Stars, with coins as the tiebreak in Jamboree: "The player with the
  most Stars ranks first; coins break a tied Star total" (studboards). Note a source conflict:
  the series-level wiki says "At the end of the game, if there is a tie at any position, a
  Dice Block roll is used to break the tie" (Super Mario Wiki — Dice Block). The Jamboree
  tiebreak is therefore `unverified`; both sources are cited rather than reconciled.
- Final ceremony: after the last turn, Toad announces the standings and the bonus stars, then
  the player can inspect "a graph of when and how many stars were earned, the final results,
  and the detailed results" (translated from
  [namu.wiki](https://namu.wiki/w/%EC%8A%88%ED%8D%BC%20%EB%A7%88%EB%A6%AC%EC%98%A4%20%ED%8C%8C%ED%8B%B0), Korean community wiki).
- Bonus Star count is turn-count dependent: "it was once again changed to two, but three
  Bonus Stars are given if the game lasts … 30 turns in … *Super Mario Party Jamboree*"; the
  "classic" three-star option is retained "but it restricts the Minigame Bonus to 30-turn
  games"; with Pro Rules, "Games are always 12 turns with one Bonus Star, and the chosen
  Bonus Star is announced at the beginning of the game"
  ([Super Mario Wiki — Bonus Star](https://www.mariowiki.com/Bonus_Star)).
- The winner takes a title, not just a rank: "Whoever gets the most stars wins the game and
  earns the title of Super Star!" (Nintendo, official product page).

---

## 11. Next round / Play again

- Within a board there is no per-round gate: after the minigame result the next turn starts
  (see stage 9), so "next round" is automatic.
- After the final results, leaving the results screen ends the session rather than offering a
  rematch: leaving the final-results screen awards Party Points and "then you return to Party
  Plaza" (namu.wiki, translated).
- "Play Again" is documented only for Free Play, not for Mario Party mode: "Fixed a bug where
  players are sometimes unable to progress the game when 'Play Again' is selected after
  playing Rhythm Kitchen in Free Play"
  ([GoNintendo, Ver. 2.1.0 patch notes](https://gonintendo.com/contents/50819-super-mario-party-jamboree-updated-to-ver-2-1-0)).

Absent: no documented "rematch with same settings" control at the end of a Mario Party board.
Whether an online room survives the end of a board so the host can start another game is
`unverified`.

---

## 12. End of night

- The night ends on the results ceremony (standings → bonus stars → star graph → final results
  → detailed results), then Party Points, then Party Plaza (namu.wiki, translated). Nintendo
  frames the outcome as a title: "earns the title of Super Star!".
- Meta-progression is paid out at that point: Party Points are earned from games and spent in
  Plaza shops; rewards add "stickers, reactions, and other minor collectibles" (Dot Esports);
  achievements/ranks unlock boards (Nintendo Life) and the first completed board unlocks Pro
  Rules (Console Creatures).

Absent: no session-level "end of night" summary across several boards; each board terminates
independently back to Party Plaza. No save/confirm prompt is documented at exit →
`unverified`.

---

## 13. Re-entry after a drop

- A dropped player's seat is taken over by a CPU and the board continues. Player report: "si
  le seul joueur de la partie quitte, il est remplacer par une I.A" — if the only human
  leaves, an AI replaces them
  ([jeuxvideo.com, page 9](https://www.jeuxvideo.com/forums/42-3007199-74441581-9-0-1-0-officiel-super-mario-party-jamboree.htm), community report; original spelling kept).
- The same player can re-enter the running match. Reviewer: "Fortunately, you can reconnect to
  the same match fast, so it doesn't affect the turns too much" (TheNerdStash). Player review:
  "If you disconnect from a game (which you inevitably will at some point), the game will
  allow you to jump back in at any time"
  ([Backloggd](https://backloggd.com/u/ZonnerTheZoner/review/2037683)); and "The ability to
  reconnect to a friend's game if you get disconnected is a phenomenal feature"
  ([Metacritic user reviews](https://www.metacritic.com/game/super-mario-party-jamboree/user-reviews/)).
- Drops are a routine path, not an edge case: "I played without problems for about 30 minutes,
  but then the game started to have a 'Connection Error.'" (TheNerdStash).
- The host controls the room's lifetime: "press the **B Button** to end the session and close
  the room" (KA 66549) — a host leaving intentionally is a different path from a drop.

Absent/unverified: no documented join-in-progress for a player who was never in the match; no
documented rejoin window or timeout; no documented control over the difficulty of the CPU that
replaces a dropped player; no documented host migration on host drop.

---

## Cross-stage observations

- The flow is **host-driven, not lobby-driven**: there is no ready-check or vote at the party
  level, and only Pro Rules introduces voting (for minigames). Everything before the board is
  a sequence of single-actor confirmations (player count → characters → balloon → island →
  board → rules → start).
- **Two different "join" models** share one UI surface: local play joins at the player-count
  screen and disables online; online play joins via Room ID/passcode/listings and is limited
  to one local player per system.
- **Failure is absorbed rather than surfaced**: matchmaking pads empty seats with
  human-named CPUs and a dropped human is replaced by a CPU, so the board never blocks on a
  missing player. Re-entry exists for the player who dropped, not for a new player.

---

## Sources

1. Nintendo Support, "How to Start a Multiplayer Game (Super Mario Party Jamboree)", KA 66549 — https://en-americas-support.nintendo.com/app/answers/detail/a_id/66549
2. Nintendo Support, "How to Start a Multiplayer Game (… Switch 2 Edition + Jamboree TV)", KA 68617 — https://en-americas-support.nintendo.com/app/answers/detail/a_id/68617
3. Nintendo, official product page (en-za) — https://www.nintendo.com/en-za/Games/Nintendo-Switch-games/Super-Mario-Party-Jamboree-2591147.html
4. Super Mario Wiki, "Super Mario Party Jamboree" — https://www.mariowiki.com/Super_Mario_Party_Jamboree
5. Super Mario Wiki, "Dice Block" — https://www.mariowiki.com/Dice_Block
6. Super Mario Wiki, "Bonus Star" — https://www.mariowiki.com/Bonus_Star
7. Nintendo Life, "Multiplayer Requirements — Local And Online Guide" — https://www.nintendolife.com/guides/super-mario-party-jamboree-multiplayer-requirements-local-and-online-guide
8. Nintendo Life, "All Boards List And How To Unlock" — https://www.nintendolife.com/guides/super-mario-party-jamboree-all-boards-list-and-how-to-unlock
9. Nintendo Life, "How To Unlock Pauline And Ninji" — https://www.nintendolife.com/guides/super-mario-party-jamboree-how-to-unlock-pauline-and-ninji
10. Console Creatures, review — https://www.consolecreatures.com/review-super-mario-party-jamboree/
11. Niche Gamer, review — https://nichegamer.com/reviews/super-mario-party-jamboree-review/
12. TheNerdStash, review — https://thenerdstash.com/super-mario-party-jamboree-review-new-levels-of-fun/
13. TechRaptor, review — https://techraptor.net/gaming/reviews/super-mario-party-jamboree-whole-party-and-then-some
14. Cogconnected, review — https://cogconnected.com/review/super-mario-party-jamboree-review/
15. K-Zone, "Playing Now" — https://www.kzone.com.au/article/playing-now-super-mario-party-jamboree-613107
16. My Nintendo News, review — https://mynintendonews.com/2024/10/15/review-super-mario-party-jamboree/
17. Dot Esports, "All rewards" — https://dotesports.com/mario/news/all-rewards-in-super-mario-party-jamboree
18. Dot Esports, "What are Party Points" — https://dotesports.com/mario/news/what-are-party-points-in-super-mario-party-jamboree-and-what-can-you-do-with-them
19. studboards, play guide — https://www.studboards.com/play/guides/play-super-mario-party-jamboree/
20. GoNintendo, Ver. 2.1.0 patch notes — https://gonintendo.com/contents/50819-super-mario-party-jamboree-updated-to-ver-2-1-0
21. Backloggd, user reviews (Funzo; ZonnerTheZoner) — https://backloggd.com/u/Funzo/review/3743625/ ; https://backloggd.com/u/ZonnerTheZoner/review/2037683
22. Metacritic, user reviews — https://www.metacritic.com/game/super-mario-party-jamboree/user-reviews/
23. namu.wiki, 슈퍼 마리오 파티 (Jamboree section) — https://namu.wiki/w/%EC%8A%88%ED%8D%BC%20%EB%A7%88%EB%A6%AC%EC%98%A4%20%ED%8C%8C%ED%8B%B0
24. jeuxvideo.com forum, "[Officiel] Super Mario Party Jamboree" — https://www.jeuxvideo.com/forums/42-3007199-74441581-8-0-1-0-officiel-super-mario-party-jamboree.htm and https://m.jeuxvideo.com/forums/42-3007199-74441581-9-0-1-0-officiel-super-mario-party-jamboree.htm
25. n-europe forum thread — https://forum.n-europe.com/topic/40016-super-mario-party-jamboree-17th-october-2024/page/2/
