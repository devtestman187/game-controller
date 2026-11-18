# Competitive-research digest — *Mario Party Superstars* (Nintendo Switch, 2021)

| Field | Value |
|---|---|
| Game | *Mario Party Superstars* |
| Platform | Nintendo Switch (also runs on Switch 2 / Lite / OLED per Nintendo support) |
| Release | 29 October 2021 (worldwide) |
| Developer / publisher | NDcube, CAProduction, WILL et al. / Nintendo |
| Mode | 1–4 players; offline, local wireless, online |
| Compiled | 2026-11-17 |
| Taxonomy | `worker-spec.md` section 1, 13 stages |

**Method and evidence quality.** No first-party design documentation, UI spec, or
measurement data exists for this title; there is no public equivalent of the
`look-and-sound.md` token table, so nothing here is a px/dp measurement. Evidence is
drawn from: Nintendo's own support article for multiplayer setup (the single most
specific first-party source), the Super Mario Wiki, the Japanese Wikipedia article
(which is by far the most detailed account of the in-pipe setup sequence and end-of-game
rules), the Nintendo Life review (hands-on), IGN's online guide, and several guide sites.
Where a claim rests on exactly one weak source I say so inline. Quotations are verbatim
in English; Japanese quotations are given with my translation in brackets.

**Scope caveat.** *Mario Party Superstars* is a console party game, not a
phone-as-controller system: there is no per-player handset, no host app, no room
joining by QR. Several taxonomy stages therefore map onto console concepts (room,
system, controller) rather than phone concepts. That mapping is stated per stage rather
than forced.

---

## 0. Stage coverage at a glance

| # | Stage | Present? | Where it happens |
|---|---|---|---|
| 1 | Launch / first run | yes (thin) | HOME Menu → Offline / Local / Online → Village Square |
| 2 | Host setup | yes | Create Room (Nintendo) or the Warp Pipe (offline) |
| 3 | Party join | yes | Join Room, by friend list or Room ID, or Global matchmaking |
| 4 | Player creation / colour & accessory | **partial — character only; colour and accessory absent** | Warp Pipe descent (character) + Data House (Mario Party Card) |
| 5 | Lobby & waiting | yes | Room screen before the board, with X / R / Y actions |
| 6 | Game selection | yes | Village Square → Warp Pipe → 5 boards, 8 settings |
| 7 | Round intro / countdown | yes, as board open + turn loop + Last 5 Turns | board arrival; every turn |
| 8 | In-round controls | yes | board turn + minigame explanation screen |
| 9 | Round end | yes | post-minigame coin award, then next turn |
| 10 | Results / scoreboard | yes | bonus stars → ranking from last place up → recap photo → stats |
| 11 | Next round / Play again | **partial — next turn is automatic; "add turns" is the only continuation control; no rematch button documented** | in-game menu; Village Square |
| 12 | End of night | **partial — no night/session lifecycle; the party simply ends at the turn limit** | post-game → Village Square |
| 13 | Re-entry after a drop | **partial — online only; CPU substitution + rejoin; local/drop specifics undocumented** | in-board |

---

## 1. Launch / first run

**Present, but there is no first-run state.** Every launch begins with the same
three-way play-style select, then the hub.

- Boot gives a play-style choice, not a title-menu: "Start the *Mario Party Superstars*
  game from the HOME Menu and choose how you'd like to play" — **Offline** (single
  system), **Local Play** (nearby systems), **Online Play** (internet)
  ([Nintendo Support](https://en-americas-support.nintendo.com/app/answers/detail/a_id/56964)).
- Japanese Wikipedia states the same order explicitly: 「ソフト起動後、「1台で遊ぶ」
  「もちよって遊ぶ」「オンラインで遊ぶ」から遊び方を選択し、その後広場の画面で…」
  [after the software starts, choose how to play from "play on one system", "bring your
  own systems", "play online", then on the plaza screen choose the mode]
  ([ja.wikipedia](https://ja.wikipedia.org/wiki/%E3%83%9E%E3%83%AA%E3%82%AA%E3%83%91%E3%83%BC%E3%83%86%E3%82%A3_%E3%82%B9%E3%83%BC%E3%83%91%E3%83%BC%E3%82%B9%E3%82%BF%E3%83%BC%E3%82%BA)).
- The hub is **Village Square**: a Warp Pipe at the centre leads to Mario Party; also
  present are Toad's Shop (キノピオショップ), the Option House, the Friend House
  (Toadette; create/join online rooms) and the Data House (Kamek; records, Mario Party
  Card), and a river boat to Mt. Minigames
  ([Super Mario Wiki — Village Square](https://www.mariowiki.com/Village_Square),
  [ja.wikipedia](https://ja.wikipedia.org/wiki/%E3%83%9E%E3%83%AA%E3%82%AA%E3%83%91%E3%83%BC%E3%83%86%E3%82%A3_%E3%82%B9%E3%83%BC%E3%83%91%E3%83%BC%E3%82%B9%E3%82%BF%E3%83%BC%E3%82%BA)).
- Persistent progress is visible without entering a mode: "Mario Party Level … is
  indicated at the top right corner of the screen while on the Village Square screen"
  ([SAMURAI GAMERS](https://samurai-gamers.com/mario-party-superstars/how-to-increase-mario-party-level-fast/)).
- **No onboarding gate.** All 10 characters and all 5 boards are available from first
  boot: "Es gibt keine freischaltbaren Charakteren. Alle Figuren sind von Anfang an
  spielbar" ([GIGA](https://www.giga.de/tipp/mario-party-superstars-alle-spielbretter-minispiele-und-charaktere/)).
- Identity is inherited from the console, not created at launch: the player name on the
  Mario Party Card "is linked to the Switch console's friend name" and must be changed in
  the console profile
  ([niko-shufublog](https://niko-shufublog.com/mp-card)).

**Absent:** first-run tutorial, account creation, permission/privacy prompt, patch note
screen, "press start" title screen as a distinct stage. None is documented in any source
consulted.

---

## 2. Host setup

Two different host surfaces exist: the **Nintendo room** (Local Play / Online) and the
**Warp Pipe** (the offline, or post-room, game settings).

**Offline (single system).** "Select **Offline Game** → Select the number of players, up
to 4, then connect a controller for each player. If desired, link a User account to any of
the additional players… If a User account isn't linked, 'Guest' will appear under their
controller icon. When you reach the map screen, Player 1 can select the game mode and
settings"
([Nintendo Support](https://en-americas-support.nintendo.com/app/answers/detail/a_id/56964)).

**Create Room (Local Play / Online Friend Game).** The host, in this order:
1. "Select **Create Room**."
2. Online only: "Set the Entry Restrictions to **Friends Only** or **Open to All** —
   **Open to All** will allow players you have not registered as Friends to join, but they
   will need the unique Room ID to find the room."
3. "Select whether or not to set a passcode."
4. "Set the number of players, up to 3, who will play on your system, then connect a
   controller for each player."
5. Optional User-account linking per extra player.
6. "Wait for the remaining systems and players to join."
7. "Select the game mode and settings, then get ready to play!"
   ([Nintendo Support](https://en-americas-support.nintendo.com/app/answers/detail/a_id/56964)).

**The eight game settings, in order.** Mario Party's own settings live inside the Warp
Pipe, under Koopa Troopa's guidance: 「「使用キャラクター」「CPUプレイヤーの強さ」
「ボードマップ」「ターン数（10-30ターンのいずれか）」「ボーナススターの有無」
「ミニゲームの説明の有無」「ハンデ」「ミニゲームパック」を設定する」
[set the character used, CPU player strength, board map, turn count (any of 10–30), bonus
stars on/off, minigame explanations on/off, handicap, and minigame pack]
([ja.wikipedia](https://ja.wikipedia.org/wiki/%E3%83%9E%E3%83%AA%E3%82%AA%E3%83%91%E3%83%BC%E3%83%86%E3%82%A3_%E3%82%B9%E3%83%BC%E3%83%91%E3%83%BC%E3%82%B9%E3%82%BF%E3%83%BC%E3%82%BA)).
The same list is corroborated from hands-on: options include "what kind of Bonus Stars
will turn the tide", "how many turns the game will last (up to 30), whether minigames
should tell you what you need to do, and whether anyone should start the game with a Star
handicap", plus a minigame-pool filter by era/type
([Nintendo Life](https://www.nintendolife.com/reviews/nintendo-switch/mario-party-superstars)).

**Authority model.** Settings are single-owner: offline, "Player 1 can select the game
mode and settings"; in a joined room, "The host will select the game mode and settings"
([Nintendo Support](https://en-americas-support.nintendo.com/app/answers/detail/a_id/56964)).
No vote, no per-player preferences, no ready-check.

**Player-count ladder** (first-party): up to **4** on one system offline; up to **3** per
system in Local Play and Online with Friends; exactly **1** per system in a Global Game
([Nintendo Support](https://en-americas-support.nintendo.com/app/answers/detail/a_id/56964)).

---

## 3. Party join

**Local Play / Online Friend Game — Join Room.** "Select **Join Room** → Select whether
to **Find a Friend's Room** or **Search by Room ID**… Select the room you want to join
once it is found. If the host set a passcode, you will need to enter the code to join. Set
the number of players, up to the max number of remaining slots, who will play on your
system, then connect a controller for each player… Wait for the remaining systems and
players to join. The host will select the game mode and settings, then get ready to play!"
([Nintendo Support](https://en-americas-support.nintendo.com/app/answers/detail/a_id/56964)).

- Two join paths only: **Find a Friend's Room** (searches rooms opened by registered
  friends) or **Search by Room ID** (works for non-friends if they were given the ID).
  There is no browseable server list
  ([Nintendo Support](https://en-americas-support.nintendo.com/app/answers/detail/a_id/56964)).
- The Room ID is a shareable string shown in the host's room and is the only way a
  non-friend can locate it; community room-share boards are built around posting it,
  e.g. 「部屋ID：〇〇〇-〇〇〇 / パスワード：〇〇〇〇」 and join steps 「フレンド→部屋IDで
  探す→部屋IDなどを入力して参加！」 [friends → search by room ID → enter ID → join]
  ([game8.jp](https://game8.jp/marioparty-superstars/409855)).
- **Global Game (random).** There is no join step at all. "When you reach the map screen,
  select the game mode you'd like to play… In **Mario Party**, you can select which rules
  and boards you'd like to play and match with random players who have selected the same
  preferences"
  ([Nintendo Support](https://en-americas-support.nintendo.com/app/answers/detail/a_id/56964)).
  Japanese Wikipedia adds the ordering: 「自分が使用するキャラクターとプレイしたいマップ、
  ターン数やボーナススターの設定をして対戦相手を検索する」 [set your own character, the
  map you want to play, the turn count and bonus-star settings, then search for opponents]
  ([ja.wikipedia](https://ja.wikipedia.org/wiki/%E3%83%9E%E3%83%AA%E3%82%AA%E3%83%91%E3%83%BC%E3%83%86%E3%82%A3_%E3%82%B9%E3%83%BC%E3%83%91%E3%83%BC%E3%82%B9%E3%82%BF%E3%83%BC%E3%82%BA)).
- A friend room cannot be back-filled from public matchmaking: a community answer states
  "if you're looking for a way to queue up with completely random people, you can't. This
  is to prevent 2 people from queueing up and working together" — attributed to a
  GameFAQs answer, not first-party
  ([GameFAQs](https://gamefaqs.gamespot.com/switch/323655-mario-party-superstars/answers/601885-when-i-join-my-friend-online-we-can-only-select-the-cpu-as-the-other-2-players)).

---

## 4. Player creation / colour & accessory — **character only; colour and accessory absent**

- **Roster = 10, fixed.** Mario, Luigi, Peach, Daisy, Wario, Waluigi, Yoshi, Rosalina,
  Donkey Kong, Birdo
  ([Super Mario Wiki](https://www.mariowiki.com/Mario_Party_Superstars)). All are
  available immediately and there are no unlockable characters
  ([GIGA](https://www.giga.de/tipp/mario-party-superstars-alle-spielbretter-minispiele-und-charaktere/)).
- **Characters are purely cosmetic**: "None of them give any competitive advantage over
  the other as they don't have stats, the characters are just purely cosmetic", and
  character-specific Dice Blocks from *Super Mario Party* do not return
  ([Game Rant](https://gamerant.com/mario-party-superstars-all-playable-characters/),
  [Super Mario Wiki](https://www.mariowiki.com/Mario_Party_Superstars)).
- **Where selection happens:** during the Warp Pipe descent into the board, and it is a
  per-slot assignment rather than a single-avatar affair — "Tumble down a surprisingly
  long pipe… During said tumbling you'll need to choose a character for each of the four
  players, with CPUs filling any slots not occupied by the meat machines"
  ([Nintendo Life](https://www.nintendolife.com/reviews/nintendo-switch/mario-party-superstars)).
- **Colour selection: absent.** No source documents a colour picker. The character *is*
  the colour; there is no second axis.
- **Accessory selection: absent.** No hats, outfits, skins, or trinkets are documented for
  party play. The only cosmetic layer in the product is the Mario Party Card *design*
  (a profile card skin), bought at Toad's Shop
  ([niko-shufublog](https://niko-shufublog.com/mp-card)).
- **Persistent profile identity (not per-party).** The **Mario Party Card** lives in the
  Data House and its editable fields are: favourite character, title, favourite series,
  favourite board, favourite minigame; card design is changed with Y and designs are
  purchased at Toad's Shop
  ([niko-shufublog](https://niko-shufublog.com/mp-card),
  [Super Mario Wiki — Data House](https://www.mariowiki.com/Data_House)). Titles are
  unlocked through achievements at Kamek's Crystal Ball and then appear on the card
  ([SAMURAI GAMERS](https://samurai-gamers.com/mario-party-superstars/how-to-unlock-all-badges/)).
  This card is the profile other players see when connected; it is **not** edited during
  party setup.
- **Guests.** A player without a linked User account is labelled "Guest" under their
  controller icon and does not bank coins or Mario Party Lv. points
  ([Nintendo Support](https://en-americas-support.nintendo.com/app/answers/detail/a_id/56964)).

**Unmeasured:** whether two human players may take the same character. No source
consulted states it either way, and the character-select UI is not described in enough
detail to infer it. Treat as unknown.

---

## 5. Lobby & waiting

The waiting surface exists and is dense with tertiary actions, but has no ready-check.

- Waiting is an explicit step with its own affordances. "Wait for the remaining systems
  and players to join. While waiting, you can… Press the **X Button** to invite a Friend
  to your room. Press the **R Button** to start a Voice Chat room in your Nintendo Switch
  App. Press the **Y Button** to view the restrictions you set on the room. View the
  unique Room ID"
  ([Nintendo Support](https://en-americas-support.nintendo.com/app/answers/detail/a_id/56964)).
- So the lobby exposes exactly three buttons (X invite, R voice chat, Y restrictions) plus
  a passive Room ID readout. No kick, no lock, no per-player ready toggle, no countdown,
  no estimated wait time is documented.
- **Voice chat is out-of-app.** It runs in the separate Nintendo Switch App and only for
  a Friend Game: "Voice Chat is available using the Nintendo Switch App while playing
  online in a Friend Game"
  ([Nintendo Support](https://en-americas-support.nintendo.com/app/answers/detail/a_id/56964)).
  There is no in-game text chat.
- **The lobby has no time limit; matchmaking does.** A single wiki source states that in
  random matchmaking the game waits **90 seconds** for a full party and then fills the
  empty seats with AI: 「90秒の待ち時間の間に人が4人全員入らないと、足りない人員はAIに
  代わってゲームが始まる」 [if all four people have not joined within the 90-second wait,
  the missing members are replaced by AI and the game starts]
  ([namu.wiki](https://ja.namu.wiki/w/%EB%A7%88%EB%A6%AC%EC%98%A4%20%ED%8C%8C%ED%8B%B0%20%EC%8A%88%ED%8D%BC%EC%8A%A4%ED%83%80%EC%A6%88)).
  **This 90 s figure is single-sourced — treat as unconfirmed.** No first-party source
  gives any matchmaking timer.
- **No lobby exists while a board is running**: joining is a pre-game action, and once a
  Global Game starts 「一度入るとマップ選択に出られない」 [once you are in, you cannot get
  back out to map selection]
  ([namu.wiki](https://ja.namu.wiki/w/%EB%A7%88%EB%A6%AC%EC%98%A4%20%ED%8C%8C%ED%8B%B0%20%EC%8A%88%ED%8D%BC%EC%8A%A4%ED%83%80%EC%A6%88)).

**Absent:** ready-up, host start button as a distinct control (the settings screen *is*
the start trigger), lobby chat, player-countdown, "waiting for host" state text, kick/ban.

---

## 6. Game selection

Mode selection happens on the plaza; board+rules selection happens inside the pipe.

- **Two modes.** Mario Party (board game) and Mt. Minigames, the latter with **7**
  courses — Daily Trial, Tag Match, Trio Challenge, Coin Battle, Sports & Puzzle,
  Survival, Free Play
  ([ja.wikipedia](https://ja.wikipedia.org/wiki/%E3%83%9E%E3%83%AA%E3%82%AA%E3%83%91%E3%83%BC%E3%83%86%E3%82%A3_%E3%82%B9%E3%83%BC%E3%83%91%E3%83%BC%E3%82%B9%E3%82%BF%E3%83%BC%E3%82%BA)).
  Per-course player counts and friend/random support: Free Play 1–4 friends; Tag Match
  (2v2) 1–4 friends; Trio Challenge (1v3) 1–3 friends; Coin Battle 1–4 friends and
  randoms; Daily Challenge 1 random only; Sports & Puzzles 1–4 friends and randoms;
  Survival 1 random only
  ([SAMURAI GAMERS](https://samurai-gamers.com/mario-party-superstars/how-to-play-online/)).
- **Five boards, each with a displayed difficulty rating.** Yoshi's Tropical Island
  ★☆☆☆☆ (from *Mario Party*), Space Land ★★☆☆☆ (*Mario Party 2*), Peach's Birthday Cake
  ★★★☆☆ (*Mario Party*), Woody Woods ★★★★☆ (*Mario Party 3*), Horror Land ★★★★★
  (*Mario Party 2*)
  ([Super Mario Wiki](https://www.mariowiki.com/Mario_Party_Superstars)).
- **Turn count = 10 / 15 / 20 / 25 / 30**, with developer time estimates printed next to
  each: 「10（30min）、15（45min）、20（60min）、25（75min）、30（90min）」
  ([Nintendo-Town review](https://www.nintendo-town.fr/2021/10/28/mario-party-superstars-nintendo-switch-le-test/)).
  This 30–90 min bracket matches the "1–4 players · 30–90 min" framing used by
  third-party rule summaries
  ([howtoplaygames](https://www.howtoplaygames.com/games/mario-party-superstars)).
- **Bonus Stars** is a three-state rule, not a checkbox: On (「あり」), Fixed/classic
  (「固定」), and off. On gives 2 star categories at 10–25 turns and 3 at 30 turns; Fixed
  always awards the three classic ones — Minigame, Coin, Happening
  ([ja.wikipedia](https://ja.wikipedia.org/wiki/%E3%83%9E%E3%83%AA%E3%82%AA%E3%83%91%E3%83%BC%E3%83%86%E3%82%A3_%E3%82%B9%E3%83%BC%E3%83%91%E3%83%BC%E3%82%B9%E3%82%BF%E3%83%BC%E3%82%BA),
  corroborated at [GameFAQs](https://gamefaqs.gamespot.com/switch/323655-mario-party-superstars/answers/602623-how-is-it-decided-how-many-bonus-stars-you-get-at-the-end-of-a-game-board-party)).
- **Board intro is part of selection**: on arriving at the map, Toad explains the board,
  and on boards derived from *Mario Party* Koopa gives a 10-coin lap bonus; on *Mario
  Party 2/3* boards Koopa runs the Koopa Bank
  ([ja.wikipedia](https://ja.wikipedia.org/wiki/%E3%83%9E%E3%83%AA%E3%82%AA%E3%83%91%E3%83%BC%E3%83%86%E3%82%A3_%E3%82%B9%E3%83%BC%E3%83%91%E3%83%BC%E3%82%B9%E3%82%BF%E3%83%BC%E3%82%BA)).

**Absent:** per-player veto or preference, random board pick, board preview/zoom, "host
is choosing…" progress.

---

## 7. Round intro / countdown

There is no "round intro" in the app sense. The real structure is: **board open (with a
dice roll-off) → repeated turn loop → Last 5 Turns event**. Numbers below are from
Japanese Wikipedia unless noted.

- **Turn order is resolved by a roll-off on arrival.** 「ボードマップに到着すると
  キノピオからそのボードマップの説明を聞き、プレイヤー全員でサイコロを叩き出た目の
  大きい順でターンの行動順が決まる」 [on arriving at the board you hear Toad's
  explanation of the map, then all players hit a dice block and turn order is decided by
  highest roll first]
  ([ja.wikipedia](https://ja.wikipedia.org/wiki/%E3%83%9E%E3%83%AA%E3%82%AA%E3%83%91%E3%83%BC%E3%83%86%E3%82%A3_%E3%82%B9%E3%83%BC%E3%83%91%E3%83%BC%E3%82%B9%E3%82%BF%E3%83%BC%E3%82%BA)).
- **Opening grant and reveal.** 「その後、キノピオから10コインをもらいスターの位置を
  確認してからゲームが開始する」 [then you receive 10 coins from Toad, confirm the Star's
  position, and the game begins]
  ([ja.wikipedia](https://ja.wikipedia.org/wiki/%E3%83%9E%E3%83%AA%E3%82%AA%E3%83%91%E3%83%BC%E3%83%86%E3%82%A3_%E3%82%B9%E3%83%BC%E3%83%91%E3%83%BC%E3%82%B9%E3%82%BF%E3%83%BC%E3%82%BA)).
  Star price is **20 coins** from Kinopiko
  ([ja.wikipedia](https://ja.wikipedia.org/wiki/%E3%83%9E%E3%83%AA%E3%82%AA%E3%83%91%E3%83%BC%E3%83%86%E3%82%A3_%E3%82%B9%E3%83%BC%E3%83%91%E3%83%BC%E3%82%B9%E3%82%BF%E3%83%BC%E3%82%BA),
  [CBR](https://www.cbr.com/mario-party-superstars-super-mario-party/)).
- **The turn loop.** Each player hits the Dice Block (1–10) in turn order, moves that many
  spaces, and resolves the space; "once every player has rolled, a minigame is played"
  ([Super Mario Wiki](https://www.mariowiki.com/Mario_Party_Superstars),
  [ja.wikipedia](https://ja.wikipedia.org/wiki/%E3%83%9E%E3%83%AA%E3%82%AA%E3%83%91%E3%83%BC%E3%83%86%E3%82%A3_%E3%82%B9%E3%83%BC%E3%83%91%E3%83%BC%E3%82%B9%E3%82%BF%E3%83%BC%E3%82%BA)).
  A minigame is drawn at random from the pool of **100**
  ([ja.wikipedia](https://ja.wikipedia.org/wiki/%E3%83%9E%E3%83%AA%E3%82%AA%E3%83%91%E3%83%BC%E3%83%86%E3%82%A3_%E3%82%B9%E3%83%BC%E3%83%91%E3%83%BC%E3%82%B9%E3%82%BF%E3%83%BC%E3%82%BA)).
- **Pre-minigame explanation screen with a persistent setting.** 「ミニゲームの開始前に、
  そのミニゲームのルールや操作方法などの説明画面が表示される（…『スーパースターズ』は
  ボードマップのポーズ画面の設定でミニゲームの説明画面を省略することも可能」 [before a
  minigame starts, a screen explains its rules and controls; in Superstars the explanation
  screen can be suppressed in the board map's pause-screen settings]
  ([ja.wikipedia — series article](https://ja.wikipedia.org/wiki/%E3%83%9E%E3%83%AA%E3%82%AA%E3%83%91%E3%83%BC%E3%83%86%E3%82%A3%E3%82%B7%E3%83%AA%E3%83%BC%E3%82%BA)).
  This is the only "intro gate" in the loop, and the player can permanently turn it off.
- **Last 5 Turns event.** When 5 turns remain the standings are announced and "one player
  is nominated at random" and receives 20 coins or an item; plus/minus spaces change to
  **6 coins**; two players landing on the same space trigger a coin-wagering Duel
  minigame; on maps with a Koopa Bank the toll rises from **3 to 5 coins**; the map BGM
  changes
  ([ja.wikipedia](https://ja.wikipedia.org/wiki/%E3%83%9E%E3%83%AA%E3%82%AA%E3%83%91%E3%83%BC%E3%83%86%E3%82%A3_%E3%82%B9%E3%83%BC%E3%83%91%E3%83%BC%E3%82%B9%E3%82%BF%E3%83%BC%E3%82%BA),
  [Super Mario Wiki](https://www.mariowiki.com/Mario_Party_Superstars)).

**Absent:** an explicit "Turn N of M" interstitial, a 3-2-1 countdown into a turn, an
accept/ready gate between turns, a skip-able intro for the board itself.

---

## 8. In-round controls

- **Button-only by design.** Every minigame is playable with buttons: 「スーパー マリオ
  パーティとは異なり、ボタン操作でプレイ可能となっている」 [unlike *Super Mario Party*,
  it is playable with button controls]
  ([ja.wikipedia](https://ja.wikipedia.org/wiki/%E3%83%9E%E3%83%AA%E3%82%AA%E3%83%91%E3%83%BC%E3%83%86%E3%82%A3_%E3%82%B9%E3%83%BC%E3%83%91%E3%83%BC%E3%82%B9%E3%82%BF%E3%83%BC%E3%82%BA));
  "you won't need to use motion controls for these games either, as all of them have button
  controls" ([HardwareZone, E3 2021](https://preview.hardwarezone.com.sg/tech-news/e3-2021-mario-party-superstars-boards-and-minigames)).
- **Supported controllers:** Joy-Con, Joy-Con held horizontally, and Pro Controller
  ([Super Mario Wiki infobox](https://www.mariowiki.com/Mario_Party_Superstars)) — i.e. one
  half-Joy-Con per player is sufficient, which is what makes 4-player single-system work.
- **Board-phase input** is one action: use at most one item before moving, then hit the
  Dice Block. Items cap at **3** held, and no items can be acquired on the final turn
  ([ja.wikipedia](https://ja.wikipedia.org/wiki/%E3%83%9E%E3%83%AA%E3%82%AA%E3%83%91%E3%83%BC%E3%83%86%E3%82%A3_%E3%82%B9%E3%83%BC%E3%83%91%E3%83%BC%E3%82%B9%E3%82%BF%E3%83%BC%E3%82%BA)).
- **Per-minigame controls are taught, not memorised**, via the explanation screen in
  stage 7; the same screen can be turned off for experienced groups
  ([ja.wikipedia](https://ja.wikipedia.org/wiki/%E3%83%9E%E3%83%AA%E3%82%AA%E3%83%91%E3%83%BC%E3%83%86%E3%82%A3%E3%82%B7%E3%83%AA%E3%83%BC%E3%82%BA)).
- **Safety interstitial.** For the revived analogue-stick-spinning minigames the game
  shows a caution not to spin the stick with the palm, after historic hand-injury reports
  with the originals
  ([ja.wikipedia](https://ja.wikipedia.org/wiki/%E3%83%9E%E3%83%AA%E3%82%AA%E3%83%91%E3%83%BC%E3%83%86%E3%82%A3_%E3%82%B9%E3%83%BC%E3%83%91%E3%83%BC%E3%82%B9%E3%82%BF%E3%83%BC%E3%82%BA)).
- **Pause menu** is where the loop's meta-controls live: minigame explanations on/off and
  the exit/save path (see stage 11)
  ([ja.wikipedia](https://ja.wikipedia.org/wiki/%E3%83%9E%E3%83%AA%E3%82%AA%E3%83%91%E3%83%BC%E3%83%86%E3%82%A3%E3%82%B7%E3%83%AA%E3%83%BC%E3%82%BA)).

**Unmeasured:** the exact button mapping for the board phase (which button hits the dice
block, which cancels) is not stated in any source consulted.

---

## 9. Round end

Round end is a coin payout screen, then straight into the next turn.

- Coin award is rank-based and the winner's payout is **10 coins**: 「ミニゲームで勝利
  したプレイヤーは10コインもらえ（『スーパー』以降は2位、3位のプレイヤーも少額の
  コインをもらえる…）、途中結果が表示される」 [the player who wins the minigame gets 10
  coins (since *Super Mario Party*, 2nd and 3rd also get a small number of coins), and the
  interim results are displayed]
  ([ja.wikipedia — series article](https://ja.wikipedia.org/wiki/%E3%83%9E%E3%83%AA%E3%82%AA%E3%83%91%E3%83%BC%E3%83%86%E3%82%A3%E3%82%B7%E3%83%AA%E3%83%BC%E3%82%BA)).
- The full rank ladder is documented for the Mt. Minigames variants: "coins are awarded
  according to the rank of the players: **10 for 1st, 3 for 2nd, 2 for 3rd, and none for
  last**" ([Super Mario Wiki — Mt. Minigames](https://www.mariowiki.com/Mt._Minigames)).
- The loop then repeats: "This flow is one 'turn', and it repeats for the number of turns
  set before the game started" (paraphrase of
  [ja.wikipedia](https://ja.wikipedia.org/wiki/%E3%83%9E%E3%83%AA%E3%82%AA%E3%83%91%E3%83%BC%E3%83%86%E3%82%A3_%E3%82%B9%E3%83%BC%E3%83%91%E3%83%BC%E3%82%B9%E3%82%BF%E3%83%BC%E3%82%BA)).
- Space effects resolve inside the turn, before the minigame: blue/red coin spaces, Lucky
  Spaces, Item Spaces, Item Shops, VS Spaces (pot paid into a minigame), Bowser Spaces
  ([Super Mario Wiki](https://www.mariowiki.com/Mario_Party_Superstars)). Item prices are
  small integers: Skeleton Key 3, Mushroom 3, Cursed Dice Block 3, Double Dice 5, Chomp
  Call 7, Warp Block 7, Triple Dice 10, Custom Dice Block 12, Golden Pipe 25 coins
  ([Super Mario Wiki](https://www.mariowiki.com/Mario_Party_Superstars)).

**Absent:** a per-turn scoreboard "continue" gate, a between-turn vote, a host
acknowledgement.

---

## 10. Results / scoreboard

Awards first, then ranking, then a photo, then optional stats.

- **Order of operations at the end.** 「設定したターン数が経過するとゲーム終了となる。
  「ボーナススター」の設定を「あり」か「固定」にしていたときはボーナススターの受賞者の
  発表が行われ、その後「スター」をもっとも多く持っている…プレイヤーが優勝となる」 [when
  the set number of turns elapses the game ends. If Bonus Stars are set to On or Fixed, the
  bonus-star winners are announced, and then the player holding the most Stars wins]
  ([ja.wikipedia](https://ja.wikipedia.org/wiki/%E3%83%9E%E3%83%AA%E3%82%AA%E3%83%91%E3%83%BC%E3%83%86%E3%82%A3_%E3%82%B9%E3%83%BC%E3%83%91%E3%83%BC%E3%82%B9%E3%82%BF%E3%83%BC%E3%82%BA)).
- **Tie-breaks, in order:** most Stars → if tied, most coins by even 1 → if still tied, a
  one-roll dice-off between the tied players, higher roll wins
  ([ja.wikipedia](https://ja.wikipedia.org/wiki/%E3%83%9E%E3%83%AA%E3%82%AA%E3%83%91%E3%83%BC%E3%83%86%E3%82%A3_%E3%82%B9%E3%83%BC%E3%83%91%E3%83%BC%E3%82%B9%E3%82%BF%E3%83%BC%E3%82%BA),
  [howtoplaygames](https://www.howtoplaygames.com/games/mario-party-superstars)).
- **Reveal order is reversed**: 「最終結果発表では、最下位から順に発表される演出と
  なった」 [in the final results, places are announced starting from last place]
  ([ja.wikipedia](https://ja.wikipedia.org/wiki/%E3%83%9E%E3%83%AA%E3%82%AA%E3%83%91%E3%83%BC%E3%83%86%E3%82%A3_%E3%82%B9%E3%83%BC%E3%83%91%E3%83%BC%E3%82%B9%E3%82%BF%E3%83%BC%E3%82%BA)).
- **Bonus Star catalogue = 9 categories**, of which 2 or 3 are awarded per game: Minigame,
  Coin, Happening, Item, Shopping, Running, Relaxing (fewest spaces moved), Red (most
  minus spaces), Bowser Space
  ([ja.wikipedia](https://ja.wikipedia.org/wiki/%E3%83%9E%E3%83%AA%E3%82%AA%E3%83%91%E3%83%BC%E3%83%86%E3%82%A3_%E3%82%B9%E3%83%BC%E3%83%91%E3%83%BC%E3%82%B9%E3%82%BF%E3%83%BC%E3%82%BA),
  [Gamepur](https://www.gamepur.com/guides/what-are-the-bonus-stars-in-mario-party-superstars)).
  Shared first place → all tied players receive the Star; if a tracked condition never
  occurred, the award is declared 「該当者なし」 [no applicable winner] and nobody gets it
  ([ja.wikipedia](https://ja.wikipedia.org/wiki/%E3%83%9E%E3%83%AA%E3%82%AA%E3%83%91%E3%83%BC%E3%83%86%E3%82%A3_%E3%82%B9%E3%83%BC%E3%83%91%E3%83%BC%E3%82%B9%E3%82%BF%E3%83%BC%E3%82%BA)).
- **Post-verdict beats:** 「ゲーム終了後はキノピオによる今回のゲームの振り返りとともに
  記念写真が表示される」 [after the game, Toad gives a recap and a commemorative photo is
  shown], with the winner most prominent and the last-place player on the receiving end of
  the stage gimmick
  ([ja.wikipedia](https://ja.wikipedia.org/wiki/%E3%83%9E%E3%83%AA%E3%82%AA%E3%83%91%E3%83%BC%E3%83%86%E3%82%A3_%E3%82%B9%E3%83%BC%E3%83%91%E3%83%BC%E3%82%B9%E3%82%BF%E3%83%BC%E3%82%BA)).
- **Detailed stats screen** is available after the results: Stars, coins, coins earned in
  minigames, and how many times each player stopped on each space type; from *Mario Party 5*
  onward the series also shows a star/coin progression graph
  ([ja.wikipedia — series article](https://ja.wikipedia.org/wiki/%E3%83%9E%E3%83%AA%E3%82%AA%E3%83%91%E3%83%BC%E3%83%86%E3%82%A3%E3%82%B7%E3%83%AA%E3%83%BC%E3%82%BA)).
- **Rewards persist** to the linked User account: "those players will keep any coins and
  Mario Party Lv. points they earn during play in their own User save data"
  ([Nintendo Support](https://en-americas-support.nintendo.com/app/answers/detail/a_id/56964)).

**Absent:** a per-minigame career stat line on the final screen (a German forum thread
complains that minigame wins are not in the end statistics —
[forum.nintendo-online.de](https://forum.nintendo-online.de/t/mario-party-superstars/96799/50)),
export/share of results, and any "MVP of the night" aggregate across parties.

---

## 11. Next round / Play again — **partial**

- **The next round is automatic.** A "round" in the board game *is* a turn; when all four
  have moved and the minigame resolves, the next turn starts with no confirmation
  ([ja.wikipedia](https://ja.wikipedia.org/wiki/%E3%83%9E%E3%83%AA%E3%82%AA%E3%83%91%E3%83%BC%E3%83%86%E3%82%A3_%E3%82%B9%E3%83%BC%E3%83%91%E3%83%BC%E3%82%B9%E3%82%BF%E3%83%BC%E3%82%BA)).
- **The one continuation control is "add turns".** New to this entry: "an option to change
  the number of turns once per game in the menu at any point of the game except for during
  the last turn. The number of turns that can be added cannot make the whole game last more
  than 30 turns"
  ([Super Mario Wiki](https://www.mariowiki.com/Mario_Party_Superstars)); hands-on confirms
  "you can even add turns to extend the game beyond its original lifespan up to the
  maximum of 30 turns"
  ([Nintendo Life](https://www.nintendolife.com/reviews/nintendo-switch/mario-party-superstars)).
- **Suspend/resume is the de-facto "come back later" path**: "press the start button to
  open the game menu and exit to the Village Square or to Mt. Minigames. Your progress will
  automatically be saved, allowing you to resume playing from where you stopped"; saves are
  written **between turns**; up to **10** board sessions can be held at once; "you cannot
  change characters when resuming your game"
  ([SAMURAI GAMERS](https://samurai-gamers.com/mario-party-superstars/how-to-save-in-mario-party-mode/),
  [Nintendo Life](https://www.nintendolife.com/reviews/nintendo-switch/mario-party-superstars)).
- **A fresh party** is started by returning to Village Square and re-entering the Warp Pipe,
  which re-runs the 8-setting setup (stage 2)
  ([ja.wikipedia](https://ja.wikipedia.org/wiki/%E3%83%9E%E3%83%AA%E3%82%AA%E3%83%91%E3%83%BC%E3%83%86%E3%82%A3_%E3%82%B9%E3%83%BC%E3%83%91%E3%83%BC%E3%82%B9%E3%82%BF%E3%83%BC%E3%82%BA)).

**Absent:** a one-button "Play Again / Rematch" on the results screen, a rematch that keeps
the same board and characters, a post-game lobby that keeps the room open. None is
documented; rooms appear to be created per party.

---

## 12. End of night — **partial (no night/session lifecycle)**

- There is no concept of a session, night, or room lifetime in the documentation. The
  party ends when the configured turn count is exhausted (10–30 turns; the in-game
  estimates set the outer bound at **90 minutes** for 30 turns —
  [Nintendo-Town](https://www.nintendo-town.fr/2021/10/28/mario-party-superstars-nintendo-switch-le-test/)).
- What exists instead is a **post-game tail**: bonus stars → ranking announced from last
  place → Toad's recap → commemorative photo (stage 10), then a return to the hub
  ([ja.wikipedia](https://ja.wikipedia.org/wiki/%E3%83%9E%E3%83%AA%E3%82%AA%E3%83%91%E3%83%BC%E3%83%86%E3%82%A3_%E3%82%B9%E3%83%BC%E3%83%91%E3%83%BC%E3%82%B9%E3%82%BF%E3%83%BC%E3%82%BA)).
- **Session-level progression is the real "end of night" payoff.** Coins earned in party
  play are spent at Toad's Shop, and Mario Party Lv. gates stock: new stickers at Lv
  5/15/25/35/40, new card designs at 10/20/30, and the ending credits at the Data House at
  Lv 50
  ([SAMURAI GAMERS](https://samurai-gamers.com/mario-party-superstars/how-to-increase-mario-party-level-fast/),
  [ja.wikipedia](https://ja.wikipedia.org/wiki/%E3%83%9E%E3%83%AA%E3%82%AA%E3%83%91%E3%83%BC%E3%83%86%E3%82%A3_%E3%82%B9%E3%83%BC%E3%83%91%E3%83%BC%E3%82%B9%E3%82%BF%E3%83%BC%E3%82%BA)).
- A night can be split: exiting mid-board saves the session and it is resumed later, up to
  10 sessions
  ([SAMURAI GAMERS](https://samurai-gamers.com/mario-party-superstars/how-to-save-in-mario-party-mode/)).

**Absent:** explicit session close, room teardown/disband confirmation, "thanks for
playing" summary across multiple parties, host migration on close, party history.

---

## 13. Re-entry after a drop — **partial, online only**

- **CPU substitution is automatic and the game does not stop.** "If a player is
  disconnected during an online game, they will be replaced with a computer – however, they
  have the opportunity to reconnect and rejoin the game"
  ([IGN](https://www.ign.com/wikis/mario-party-superstars/How_to_Play_Online_-_All_Online_Modes)).
- **The rejoin lands on the next turn.** "when a player is accidentally disconnected, the
  game will automatically swap in a CPU player. If the disconnected player is able to make
  it back, they can rejoin the group on the next turn. Players also have the option of
  saving the online game and returning to it later"
  ([ComicBook.com](https://comicbook.com/gaming/news/mario-party-superstars-nintendo-switch-huge-improvement-online-play/)).
- **A force-quit is treated the same way, immediately.** 「オンラインプレイ中に一人の
  ユーザーがゲームを強制終了すると、すぐにその場をAIが置き換え、ゲームが続行される」
  [if one user force-quits during online play, an AI replaces them on the spot immediately
  and the game continues]
  ([namu.wiki](https://ja.namu.wiki/w/%EB%A7%88%EB%A6%AC%EC%98%A4%20%ED%8C%8C%ED%8B%B0%20%EC%8A%88%ED%8D%BC%EC%8A%A4%ED%83%80%EC%A6%88)).
  Same source: 「オンラインランダムマッチングは1人プレイのみ可能」 [online random
  matchmaking is single-player-per-system only], consistent with Nintendo's player-count
  ladder.
- This behaviour was promoted pre-release as the headline online feature: persistent
  games where "disconnected players get replaced by CPUs instead of canceling the game
  altogether", "disconnected players being able to return to current games", and "the
  ability to save online sessions" — a community round-up of the announced feature set
  ([ResetEra](https://www.resetera.com/threads/lets-talk-about-the-online-play-of-mario-party-superstars.508506/)).

**Absent / unmeasured:**
- **Local drop** (controller disconnect, system sleep, Joy-Con detach mid-party): no source
  describes what happens. *No evidence.*
- **Host drop**: no source describes host migration or what happens to the room when the
  host disconnects. *No evidence.*
- **The re-entry UI itself**: no source describes how the returning player re-enters (does
  the CPU hand back at the next turn automatically? must they re-join by Room ID?). The
  sources only assert that rejoining is possible. *Unmeasured.*
- **Timeout window** for rejoining: not documented.

---

## 14. What the 13-stage map implies for a phone-controller design

Stated as observations about this game only, not as recommendations:

1. **One authority per party.** Settings, start, and rule changes are all single-owner
   (host / Player 1); there is no per-player preference or vote
   ([Nintendo Support](https://en-americas-support.nintendo.com/app/answers/detail/a_id/56964)).
2. **The lobby is a passive waiting room with three buttons** (invite, voice-chat, view
   restrictions) and no ready state
   ([Nintendo Support](https://en-americas-support.nintendo.com/app/answers/detail/a_id/56964)).
3. **Identity is one axis deep.** Character only; no colour, no accessory, no per-party
   cosmetics; the deeper cosmetic layer (Mario Party Card design, titles) lives in the hub
   and persists across parties
   ([niko-shufublog](https://niko-shufublog.com/mp-card),
   [SAMURAI GAMERS](https://samurai-gamers.com/mario-party-superstars/how-to-unlock-all-badges/)).
4. **Drops never block the game.** CPU substitution is immediate on disconnect and
   force-quit, and the human may take the seat back later — the party never pauses for a
   missing player
   ([IGN](https://www.ign.com/wikis/mario-party-superstars/How_to_Play_Online_-_All_Online_Modes),
   [namu.wiki](https://ja.namu.wiki/w/%EB%A7%88%EB%A6%AC%EC%98%A4%20%ED%8C%8C%ED%8B%B0%20%EC%8A%88%ED%8D%BC%EC%8A%A4%ED%83%80%EC%A6%88)).
5. **Long sessions are resumable, not restartable.** Ten save slots, between-turn saves,
   no character change on resume
   ([SAMURAI GAMERS](https://samurai-gamers.com/mario-party-superstars/how-to-save-in-mario-party-mode/)).
6. **The end state is a ceremony, not a scoreboard**: bonus stars → last-to-first reveal →
   recap → photo, with the stats table behind it
   ([ja.wikipedia](https://ja.wikipedia.org/wiki/%E3%83%9E%E3%83%AA%E3%82%AA%E3%83%91%E3%83%BC%E3%83%86%E3%82%A3_%E3%82%B9%E3%83%BC%E3%83%91%E3%83%BC%E3%82%B9%E3%82%BF%E3%83%BC%E3%82%BA)).

---

## 15. Source list

First-party
- Nintendo Support — How to Start a Multiplayer Game (Mario Party Superstars): https://en-americas-support.nintendo.com/app/answers/detail/a_id/56964

Encyclopaedic
- Super Mario Wiki — Mario Party Superstars: https://www.mariowiki.com/Mario_Party_Superstars
- Super Mario Wiki — Village Square: https://www.mariowiki.com/Village_Square
- Super Mario Wiki — Mt. Minigames: https://www.mariowiki.com/Mt._Minigames
- Super Mario Wiki — Data House: https://www.mariowiki.com/Data_House
- Japanese Wikipedia — マリオパーティ スーパースターズ: https://ja.wikipedia.org/wiki/%E3%83%9E%E3%83%AA%E3%82%AA%E3%83%91%E3%83%BC%E3%83%86%E3%82%A3_%E3%82%B9%E3%83%BC%E3%83%91%E3%83%BC%E3%82%B9%E3%82%BF%E3%83%BC%E3%82%BA
- Japanese Wikipedia — マリオパーティシリーズ (series article, used for the shared turn/minigame/results loop): https://ja.wikipedia.org/wiki/%E3%83%9E%E3%83%AA%E3%82%AA%E3%83%91%E3%83%BC%E3%83%86%E3%82%A3%E3%82%B7%E3%83%AA%E3%83%BC%E3%82%BA
- namu.wiki (ja) — Mario Party Superstars: https://ja.namu.wiki/w/%EB%A7%88%EB%A6%AC%EC%98%A4%20%ED%8C%8C%ED%8B%B0%20%EC%8A%88%ED%8D%BC%EC%8A%A4%ED%83%80%EC%A6%88

Hands-on / press
- Nintendo Life review: https://www.nintendolife.com/reviews/nintendo-switch/mario-party-superstars
- IGN — How to Play Online, All Online Modes: https://www.ign.com/wikis/mario-party-superstars/How_to_Play_Online_-_All_Online_Modes
- ComicBook.com — online disconnect handling: https://comicbook.com/gaming/news/mario-party-superstars-nintendo-switch-huge-improvement-online-play/
- HardwareZone — E3 2021 preview (button controls): https://preview.hardwarezone.com.sg/tech-news/e3-2021-mario-party-superstars-boards-and-minigames
- Nintendo-Town (fr) review — turn-count time estimates: https://www.nintendo-town.fr/2021/10/28/mario-party-superstars-nintendo-switch-le-test/
- CBR — star price 20 coins: https://www.cbr.com/mario-party-superstars-super-mario-party/

Guides
- SAMURAI GAMERS — How to Play Online: https://samurai-gamers.com/mario-party-superstars/how-to-play-online/
- SAMURAI GAMERS — How to Save in Mario Party Mode: https://samurai-gamers.com/mario-party-superstars/how-to-save-in-mario-party-mode/
- SAMURAI GAMERS — How to Increase Mario Party Level: https://samurai-gamers.com/mario-party-superstars/how-to-increase-mario-party-level-fast/
- SAMURAI GAMERS — How to Unlock All Titles: https://samurai-gamers.com/mario-party-superstars/how-to-unlock-all-badges/
- niko-shufublog — Mario Party Card settings: https://niko-shufublog.com/mp-card
- howtoplaygames — rules summary: https://www.howtoplaygames.com/games/mario-party-superstars
- game8.jp — room ID board (room ID / passcode sharing conventions): https://game8.jp/marioparty-superstars/409855
- GIGA (de) — roster/unlockables: https://www.giga.de/tipp/mario-party-superstars-alle-spielbretter-minispiele-und-charaktere/
- Game Rant — all playable characters: https://gamerant.com/mario-party-superstars-all-playable-characters/
- Gamepur — Bonus Star list: https://www.gamepur.com/guides/what-are-the-bonus-stars-in-mario-party-superstars
- GameFAQs — number of Bonus Stars: https://gamefaqs.gamespot.com/switch/323655-mario-party-superstars/answers/602623-how-is-it-decided-how-many-bonus-stars-you-get-at-the-end-of-a-game-board-party
- GameFAQs — friend rooms cannot be publicly back-filled: https://gamefaqs.gamespot.com/switch/323655-mario-party-superstars/answers/601885-when-i-join-my-friend-online-we-can-only-select-the-cpu-as-the-other-2-players
- ResetEra — round-up of announced online features: https://www.resetera.com/threads/lets-talk-about-the-online-play-of-mario-party-superstars.508506/
