# Research matrix — six party-game digests, keyed by the 13-stage taxonomy

Compiled 2026-11-17 from the six digests under `../research/` and the flow taxonomy in
`worker-spec.md` §1. This is a **per-stage comparison only**: no ranking, no recommendation —
that is the architect's step. Citations are by game name; the URLs live in each digest.
Nothing here is a measurement: the digests are desk research, not findings records, so every
px/dp/contrast value is `unmeasured` by design.

**Reading convention.** One line per game per stage, short name first. `absent` alone = no
evidence at all for that stage. `absent — …` = absent at the documented layer, but with a
scope qualification or a documented substitute worth recording.

**Game short names.** Superstars = *Mario Party Superstars* (Switch, 2021). Jamboree =
*Super Mario Party Jamboree* (Switch, 2024). LEGO = *LEGO Party!* (SMG Studio / Fictions,
2025, 1.6.x line). Jackbox = *The Jackbox Party Pack* series. AirConsole = N-Dream's
phone-as-controller platform. WiiParty = *Wii Party* (Wii, 2010).

---

## 1. Launch / first run

| Game | Key mechanic |
|---|---|
| Superstars | Three-way play-style select on boot (Offline / Local Play / Online Play), then the Village Square hub; no first-run state, no tutorial, no account gate; identity is inherited from the console profile. |
| Jamboree | HOME Menu → Joy-Con strap notice modal → title screen gated on L + R pressed together → player-count screen; online needs an update and a Nintendo Switch Online membership; Pro Rules unlock after the first completed board. |
| LEGO | Main Menu is the entry surface (`Play`, `Load Game`, News panel, online panel with the LEGO Party ID username); a tutorial exists but no source describes its content or skip path; codes are entered here. |
| Jackbox | Host launches the pack and lands on that pack's game menu; the player has no first-run screen at all — no app and no install — the player's "first run" is the same browser join form every time. |
| AirConsole | Big screen: a single `START PLAYING` button. Controller: an identity choice (Guest or linked Google / iOS / Facebook / email) made **before** the code. In-car first launch plays an intro video. |
| WiiParty | Disc → health-and-safety screen → Wii Menu / Disc Channel → wrist-strap screen → title screen requiring two buttons pressed simultaneously → Party Phil intro → main menu; first run also creates a save file (two blocks). |

## 2. Host setup

| Game | Key mechanic |
|---|---|
| Superstars | Settings are single-owner: offline Player 1 picks mode and settings; online the host does `Create Room`, sets entry restrictions, an optional passcode and a per-system player count (≤3); the eight game settings live inside the Warp Pipe; no vote, no ready-check. |
| Jamboree | Local: player count 1–4, link or rename guests, a character per player, then A when everyone is ready. Online: `Create Room` → 4- or 8-player room (8 only in single-player mode), optional four-digit passcode, host controls mode and settings; X info / Y invite (hold Y for the passcode) / B ends and closes. |
| LEGO | `Play > Host Game` generates a 5-digit code shareable with up to three more players; the host sets board, round count, rules and 1.6 advanced rules; public-lobby hosting added in 1.6.0; invites also via the Online menu. |
| Jackbox | Starting a game *is* room creation: a 4-letter code appears in the lobby, unique per launch; per-game settings sit before the lobby (Family Friendly, Audience on/off, Extended Timers, Volume); moderation adds a numeric password and a second web surface, `mod.jackbox.tv`. |
| AirConsole | Zero-configuration hosting: open the TV app or airconsole.com and press start; the screen then shows a connect code plus a QR code. No host account, host name, room name or configuration step is documented. |
| WiiParty | No host role. One linear, single-screen sequence driven by Player 1's remote: mode → confirm contents and player count → number of players → connect remotes → Mii per player → CPU skill (and rounds/difficulty where the mode has them) → Start. |

## 3. Party join

| Game | Key mechanic |
|---|---|
| Superstars | `Join Room` → Find a Friend's Room, or Search by Room ID (plus passcode); no browseable server list. The Global Game path has no join step at all — you pick character/rules and match with players who chose the same preferences. |
| Jamboree | Local has no join screen (controllers are added at the player-count step, which disables online). Online: `Join a Room` → room list, or Y → search by Room ID → passcode; rooms split into 4- and 8-player listings; `Worldwide` for randoms. |
| LEGO | Three routes: type the 5-digit code on the Main Menu, accept/send a platform invite via the Online menu, or (1.6+) pick a public lobby from a cross-platform list. No matchmaking at launch (developer: "No matchmaking"). The Netflix build joins by per-device QR scan, up to four. |
| Jackbox | `jackbox.tv` → 4-letter code + name (≤12 characters) → `Play`. One controller per browser per device; the host cannot play on the host device; QR join from Party Pack 9; late joiners are demoted to audience, not blocked. |
| AirConsole | Scan the QR (a deep link to the controller) or type the connect code in the app/web app; many phones join on one code; the cap is per game and the game must render the overflow message; official pages contradict each other on whether same Wi-Fi is required. |
| WiiParty | Physical only: add one Wii Remote at a time via `Add Wii Remote` (press 1+2); the slot icon lights up and shows `OK!`; the remote count caps the player count; no network join. |

## 4. Player creation / colour & accessory

| Game | Key mechanic |
|---|---|
| Superstars | Character only: 10 fixed cosmetic characters with no stats; **colour absent, accessory absent**. The Mario Party Card (favourite character, title, board, minigame, card design) is hub profile, not party setup; an unlinked player shows as "Guest". |
| Jamboree | Character selection only: 22-character roster (Pauline and Ninji locked at start); **colour absent** (implied by the character); **accessory absent at setup** — stickers, reactions and collectibles are Party Points purchases in the plaza. |
| LEGO | Deepest authoring of the six: one minifigure per slot, preset or built from head, hair/hat, expression, upper body and lower body; CPU identity and difficulty on the same step. No separate colour picker — colour arrives as part variants; colour-blind shapes/patterns provided. |
| Jackbox | Name only (≤12 characters, changeable, cookie-persisted); **colour and avatar absent at party level** — character creation (a champ, a monster, a role model, a shirt) is the first beat inside each title, not a party step. |
| AirConsole | Nickname prompted once, then skipped on return visits; avatar is the account profile photo, editable in settings rather than the lobby; **colour absent, accessory absent**; colour is pushed into per-game custom state. |
| WiiParty | Mii selection only (a console Mii or a preset guest Mii); creation, colour picker and accessory **absent**; the game assigns per-player colour itself (Derby Dash horse colours); a guest Mii saves no records. |

## 5. Lobby & waiting

| Game | Key mechanic |
|---|---|
| Superstars | Waiting is an explicit step with three buttons — X invite, R voice chat (out-of-app, Nintendo Switch App only), Y view restrictions — plus a passive Room ID; no ready-check, no countdown, no kick. Random matchmaking reportedly fills with AI after 90 s (single-sourced, unconfirmed); no lobby exists while a board runs. |
| Jamboree | The online room is the lobby: X info, Y invite, B end session/close room, hold Y for the passcode; the host drives progression; no ready-check, countdown or kick documented; matchmaking pads empty seats with human-named bots (reported); the host must walk to the balloon to leave. |
| LEGO | Four-slot lobby keyed by the 5-digit code: minifigures rendered, **a ready action per slot including CPU slots** (player report, not official), the host starts, a waiting-on-sync prompt exists, public games show ping; no timer, kick, chat or native voice chat documented. |
| Jackbox | Host-screen room showing the 4-letter code; a name appears on join; start is gated on a minimum player count, and the **first player (VIP) presses start from their own phone** ("Everybody's In"), with a host setting to reclaim it; moderation can kick in the lobby and transfers VIP; late joiners go to audience; no countdown or auto-start. |
| AirConsole | Phone-side `Player Lobby` plus a screen lobby with the QR on the left; the first player becomes Main Controller; the start gate is a human confirmation on that phone — "Has everyone joined?" → `Yes`; no timer, auto-start or per-player ready; mid-round arrivals can be parked by player silencing (off by default). |
| WiiParty | absent |

## 6. Game selection

| Game | Key mechanic |
|---|---|
| Superstars | Plaza mode select (Mario Party vs Mt. Minigames with 7 courses); board and rules inside the Warp Pipe: 5 boards rated 1–5★, turns 10/15/20/25/30 with printed 30–90 min estimates, Bonus Stars as On/Fixed/Off; Toad gives the board intro as part of selection. |
| Jamboree | Island-map mode select (Mario Party, Minigame Bay, Motion Island, Bowser Challenges, Party-Planner Trek); inside Mario Party the order is opponent type → rule type → map; 7 boards (4 unlocked, 3 by progression); Party Rules is adjustable vs Pro Rules locked at 12 turns, one bonus star announced up front, minigame vote. |
| LEGO | `Select Game Mode`: Mini Games, Challenge Zones, Mini Game Rush, Score Chaser (Brick Battles named only in patch notes); Challenge Zone adds one of 4 boards, round count (default 10), The Lab modifiers and optional Bonus Bricks; **inside each round the minigame is chosen by player vote** among three named tiles plus one random. |
| Jackbox | Host-only and outside any room: pick a title from the pack menu by preference, description or supported player count (Steam's Megapicker browses across packs); players get no vote and no menu — their phone is already bound to the room. |
| AirConsole | The store renders on the big screen; the master controller is the only device that can pick or change a game (enforced at product level), and premium devices are prioritised for the master role; no per-player vote or queue. |
| WiiParty | Two paths: by mode (Party Games / Pair Games / House Party / Minigames) or by Suggestions (players → Miis → short/long); a mode tile shows player count and expected duration before commitment; in-session the game usually picks, except Spin-Off's last-place player choosing 4-player minigames after round 7. |

## 7. Round intro / countdown

| Game | Key mechanic |
|---|---|
| Superstars | No round intro as such: board open with a dice roll-off for turn order, Toad's board explanation, a 10-coin grant and star-position reveal, then the repeated turn loop; a pre-minigame explanation screen can be permanently suppressed; the Last 5 Turns event re-announces standings. |
| Jamboree | An opening dice roll decides turn order (highest first, lowest last); the board introduction is read together; the minigame is announced after the last player's turn, with an instruction phase plus a practice round; no numeric 3-2-1 countdown documented. |
| LEGO | Each round opens with the minigame vote and a countdown; a brief intro states the goal and controls before play, with practice available for some minigames; the host plays Challenge Zone intros online; "Round X" animations are branded. |
| Jackbox | Tutorials run before play and are skippable, and the VIP controls them; timed input windows are a first-class setting (Extended Timers). No numeric countdown or round title card is evidenced. |
| AirConsole | absent — per game; the only platform-owned countdown is the 3-second resume countdown after a pause. |
| WiiParty | A rules/controls screen with an explicit `Start` gate and a practice option, an instruction screen with its own music, and no numeric countdown (a false-start rule inside Flag Fracas implies a start signal, not a coordinated countdown); the ready-check-plus-countdown belongs to Wii Party U, not the 2010 game. |

## 8. In-round controls

| Game | Key mechanic |
|---|---|
| Superstars | Button-only by design (no motion), one half-Joy-Con or Pro Controller per player; the board phase is use ≤1 item then hit the Dice Block (items cap 3); per-minigame controls are taught on the explanation screen; a safety interstitial covers stick-spinning; the pause menu holds minigame-explanation and exit controls. |
| Jamboree | A rolls the dice (hold A to spin faster), a prompted button stops it, and a junction asks for a direction; map and items live on the turn UI; turn HUD top-left with a scrolling turn-order bar; **30-second turn timer in online random games**; motion minigames can be removed from the pool. |
| LEGO | Four simplified schemes: joystick only, D-pad only, action button(s) only, movement + action; required controls shown before each minigame and filterable in accessibility settings; controller and keyboard/mouse with rebinding; CPU turns in turn-based minigames can be skipped; colour-blind shapes and visual sound cues. |
| Jackbox | The controller is a live web page driven by host state; input types are free text, multiple choice, drawing canvases, vote buttons and rapid tapping, on timed prompt windows; a documented weakness is that slow players get left behind. |
| AirConsole | A platform shell (top bar with logo menu, orientation, stay-alive, fullscreen) around per-game controller views; design rules are prescriptive — big buttons, label by function, no d-pads or virtual joysticks, personalised controllers; message delivery is ordered and lossless across disruptions. |
| WiiParty | One remote per player, no attachments, orientation changing per minigame (vertical or sideways); each minigame teaches its verb in one sentence on the instruction screen; the pause menu is the universal shell — Continue, Restart (Party Games only), Autoplay, Quit. |

## 9. Round end

| Game | Key mechanic |
|---|---|
| Superstars | A coin payout screen: 10 / 3 / 2 / 0 coins for 1st / 2nd / 3rd / last, with interim results shown, then straight into the next turn; space effects resolve inside the turn before the minigame; no between-turn continue gate or vote. |
| Jamboree | A minigame payout, not a board scoreboard: the winner takes a large coin sum, the other three much less, and Bonus Minigames double the payout; control returns to the board for the next turn with no inter-round menu documented. |
| LEGO | A `Minigame Results` screen: studs awarded there with host commentary and emote/dance/slap interactions, continue reduced to one press in 1.2.0; placement then sets board turn order; the board portion ends after all players have moved. |
| Jackbox | The host screen becomes the reveal surface: submissions are shown, then a vote, then points are assigned; per-round score review is minimal by design — reviewers note there is rarely a chance to record scores. |
| AirConsole | absent — per game. |
| WiiParty | A three-beat sequence: minigame placing is announced and converted into a dice advantage (gold/silver/bronze die for 1st/2nd/3rd), landed spaces fire once (non-cumulative), then the turn advances automatically with no documented pass confirmation. |

## 10. Results / scoreboard

| Game | Key mechanic |
|---|---|
| Superstars | A ceremony, not a table: bonus stars announced → places revealed from last to first → Toad's recap → commemorative photo → optional detailed stats. Tie-break is stars → coins → a one-roll dice-off; 9 bonus-star categories of which 2–3 are awarded; rewards persist to the linked User account. |
| Jamboree | Ranking by stars with coins as tiebreak in Jamboree (a source conflict with a dice-off rule is marked unverified); the ceremony is standings + bonus stars → star graph → final results → detailed results; the winner is titled "Super Star"; bonus-star count depends on turn count. |
| LEGO | Ranking by Golden Bricks with studs as tiebreak; the four return to the studio for the reveal; **no random participation awards** at launch and no stats graph; from 1.4 an optional Bonus Brick Zone vote adds Golden Bricks; no per-round standings table documented. |
| Jackbox | Per-game only: a winner is announced, generally the highest score; a cross-game or whole-night scoreboard is **absent** (a reviewer explicitly asks for one). |
| AirConsole | absent — per game; the substitute is persistent high scores exposed as a global leaderboard API (world / country / region / city / friends) plus profile stats, not a session scoreboard. |
| WiiParty | Two steps, player-advanced: scores announced → press A → overall rankings; each mode renders its own presentation (Spin-Off a line graph, Board Game Island a victory screen); only console Miis persist, browsable later from Records. |

## 11. Next round / Play again

| Game | Key mechanic |
|---|---|
| Superstars | The next round is automatic. The one continuation control is "add turns" once per game (never past 30); suspend/resume via the game menu with between-turn saves, up to 10 sessions, no character change on resume; a fresh party re-runs the Warp Pipe setup; **no rematch button** on the results screen. |
| Jamboree | Automatic next turn inside a board; leaving the final-results screen ends the session and returns to Party Plaza with Party Points; "Play Again" is documented only for Free Play (patch note); no rematch-with-same-settings control documented. |
| LEGO | The session runs to its preset round count; the results screen's continue advances the loop; quitting is pause → `Quit to Main Menu` → save prompt → `Load Game` (local/couch only — online sessions cannot be saved); no Play again/rematch control evidenced. |
| Jackbox | Two routes: an in-place restart with the same players, or back to the pack menu (Esc → confirm), which issues a new code; whether the in-place restart keeps the same 4-letter code is unmeasured. |
| AirConsole | absent — the game restarts itself, or the master controller re-enters the store via the logo menu ("Change Game" / "New game", two official names for one control); an optional full-screen multiscreen ad can sit between games. |
| WiiParty | Automatic inside a mode; after final results a menu offers replay the same game, return to the main menu, or (only if arrived via Suggestions) another suggestion; the labels are lost to OCR; mid-game `Restart` is a separate pause-menu control limited to Party Games. |

## 12. End of night

| Game | Key mechanic |
|---|---|
| Superstars | No session or night object: the party ends at the turn limit (10–30 turns, ~90 min outer bound) and the post-game tail returns to the hub. The real payoff is persistent — coins to Toad's Shop, Mario Party Lv, credits at Lv 50 — and a night can be split across up to 10 saved sessions. No session close, teardown confirmation, across-party summary or party history. |
| Jamboree | The night ends on the results ceremony, then Party Points, then Party Plaza; meta-progression is Party Points, achievements/ranks and board unlocks; no session-level summary across several boards, and no save/confirm prompt at exit is documented (unverified). |
| LEGO | Last round → studio reveal → winner with trophy → XP (player rank and board rank) + carrots + minifigure unlocks → Main Menu; optional Bonus Bricks; no "keep the party going"/next-session hook documented. |
| Jackbox | A host action with no ceremony: the host leaves the game and the pack, the room ceases to exist and the next launch issues a new code; there is no party-level state to end (no cross-game score, no account), and the phone-side end moment is absent from every source. |
| AirConsole | absent |
| WiiParty | "Game over → menu", no session concept: a win condition → scores → rankings → the stage-11 menu; or quit from the pause menu (progress lost); or console off; what survives is the save file and the Records entries — no party history, no per-night roll-up. |

## 13. Re-entry after a drop

| Game | Key mechanic |
|---|---|
| Superstars | Online only: a disconnect or force-quit is replaced by a CPU **immediately, and the game does not stop**; the human can rejoin on the next turn. Local drop and host drop have **no evidence**; the re-entry UI itself and the rejoin window are unmeasured. |
| Jamboree | A dropped seat is taken by a CPU and the board continues; the same player can reconnect to the same match, reportedly "at any time" and fast enough not to affect turns; a host leaving intentionally is a different path (B ends the session); no join-in-progress for a player never in the match, no rejoin window, no host migration. |
| LEGO | A dropped human is replaced in-session by a **Normal-difficulty CPU**; re-entry is a **rejoin pop-up on the Main Menu**, valid only while friends are still in the session and haven't progressed too far; no host migration, and a host who leaves hits error 0202-0019 and cannot start a new lobby until the others leave. |
| Jackbox | Re-entry is a **browser refresh**, and it depends on cookie state (clearing cache/cookies mid-session prevents rejoining); a late return after start may be reclassified as audience (conflicts with a Party Pack 7 report of straight rejoin); a host drop now pauses the game for **5 minutes** (Party Pack 9+); a kick is a permanent denial for that room. |
| AirConsole | The most engineered layer: `device_id` is **reserved per device** across disconnect and reconnect, so the same phone returns as the same player/slot/colour/score; the platform owns a pause overlay and a **3-second resume countdown**; the game picks one of **5 documented drop policies** (Level 1 drop-in/out through Level 5 back to menu, including AI replacement and a wait/continue/abandon prompt); the re-entry screen and master-drop transfer are unmeasured. |
| WiiParty | absent — no re-entry: the roster is fixed at Start; the substitute is the pause-menu **Autoplay** toggle (human → CPU, **except Player 1**, revertible), the closest thing to re-entry; link recovery is "move closer and press any button" or reconnect from the HOME Menu; no game-attributable reconnect overlay documented. |

---

# Cross-game patterns

Recurring conventions across the six, with the games that exhibit each. Where a pattern is
notably not universal, the non-exhibitors are named.

## Code-based join

- **Numeric/alphanumeric room code (5 of 6):** Superstars (Room ID plus optional passcode),
  Jamboree (Room ID plus four-digit passcode), LEGO (5-digit), Jackbox (4-letter),
  AirConsole (connect code — press reports six digits; official length `unmeasured`).
- **QR as a second channel:** AirConsole (the primary path; the QR deep-links into the
  controller), Jackbox (from Party Pack 9), LEGO (Netflix build only, one QR per device).
- **Not code-based:** WiiParty — physical Wii Remote pairing only.
- **Convention:** the code is per party and is the only thing a non-friend needs. No game in
  the set offers a reusable or persistent room code: Jackbox issues a new code per launch,
  AirConsole a new code per session, LEGO one per lobby, and Superstars/Jamboree one per
  created room. Switching games costs a re-join in every case except AirConsole, where the
  phones stay attached to the session while the screen changes game.

## Name/avatar only vs colour + accessory

- **No game in the six has a colour + accessory picker as a distinct party-setup stage.**
  This is the sharpest negative result in the matrix.
- **Name/avatar only:** Jackbox (name ≤12 characters; avatars are per-title), AirConsole
  (nickname plus account profile photo), LEGO (a minifigure built from head, hair/hat,
  expression and body parts — the closest to accessory authoring, but no separate colour
  picker), WiiParty (Mii selection; identity is a face, not a colour token).
- **Character-only, colour and accessory absent:** Superstars (10 fixed characters, cosmetic
  only), Jamboree (22 characters, two locked).
- **How colour arrives instead of being chosen:** implied by the character (Superstars,
  Jamboree), a property of parts (LEGO), auto-assigned by the game per mode (WiiParty, Derby
  Dash horse colours), or pushed down into per-game state (AirConsole custom device state);
  never a per-player token the player picks.
- **Second-class identity:** Superstars labels an unlinked player "Guest" and banks no coins
  or Lv; Jamboree lets a guest be renamed or linked at the player-count step; WiiParty's
  guest Mii saves no records at all.

## Ready-check vs auto-start

- **Per-slot ready action:** LEGO only — and it includes CPU slots (player report, not
  official documentation).
- **Host confirmation without per-player ready:** AirConsole — "Has everyone joined?" →
  `Yes` on the Main Controller's phone.
- **Minimum-player-count gate plus a player pressing start:** Jackbox — the VIP (first
  joiner) starts from their own device as "Everybody's In", with a host setting to reclaim
  start authority.
- **Host starts directly, no ready gate:** Superstars, Jamboree, and LEGO's host start sits
  on top of its per-slot ready.
- **No lobby at all:** WiiParty.
- **Auto-start on a timer:** none of the six documents one. The closest is Superstars'
  reported 90-second matchmaking fill with AI (single-sourced, unconfirmed) — a matchmaking
  rule, not a lobby timer.
- **Caveat:** a ready-check plus countdown exists in *Wii Party U*, the sequel, and is
  explicitly not in the 2010 *Wii Party*; it should not be attributed to the earlier title.

## CPU fills a dropped seat

- **Automatic and online:** Superstars (immediate on disconnect or force-quit), Jamboree
  (a CPU takes the seat), LEGO (in-session, Normal difficulty).
- **Optional and game-chosen:** AirConsole — Level 2 of its published 5-level drop ladder
  ("AI replaces dropped players or new players replace AI players"); the platform mandates
  nothing, the game picks its level.
- **Manual, pause-menu:** WiiParty — the Autoplay toggle flips a human slot to CPU and back,
  except Player 1.
- **Not exhibited:** Jackbox — no bot/CPU fill is documented; a dropped player refreshes back
  in or returns as audience.
- **Adjacent convention:** CPU fill is also used *before* a drop — Jamboree pads empty
  matchmaking seats with human-named bots, LEGO always fields four contestants with "smart
  AI" filling missing humans, Superstars fills slots with CPUs during the Warp Pipe descent,
  and WiiParty's Party Games always field four characters.

## Host-drop handling

- **No host migration documented:** Superstars (no evidence at all), Jamboree, LEGO (a host
  who leaves cannot start a new lobby while others remain — error 0202-0019), AirConsole
  (master-controller drop transfer is explicitly `unmeasured`).
- **Time-boxed pause for host reconnection:** Jackbox — a host drop pauses the game for
  5 minutes from Party Pack 9; before that, a host drop destroyed the game and lost progress.
- **Start-authority transfer:** Jackbox reassigns the VIP when the VIP is kicked; AirConsole's
  master role (premium-prioritised) has no documented transfer rule.
- **No host role at all:** WiiParty — Player 1 cannot be handed to the CPU, so a Player 1
  drop has no in-game recovery other than Restart or Quit.

## End-of-night ceremony

- **Ceremony present:** Superstars (bonus stars → last-to-first reveal → recap → photo),
  Jamboree (standings → bonus stars → star graph → final results → detailed results; winner
  titled "Super Star"), LEGO (studio reveal → trophy → XP/rank payout), WiiParty (scores →
  rankings, with per-mode presentation such as Spin-Off's line graph).
- **No ceremony:** Jackbox (the host exits and the room dies; the next launch is a new code),
  AirConsole (absent entirely; the session ends implicitly when the big screen closes or
  refreshes, and the store is the only resting state).
- **Session-level summary across multiple games or a whole night:** none of the six. Every
  substitute is either per-title results or persistent meta-progress — Superstars' Mario
  Party Lv and card, Jamboree's Party Points, LEGO's player/board ranks, AirConsole's profile
  counters (biggest group size, total sessions), WiiParty's Records.

## Re-entry mechanism

- **Identity reserved at the transport layer (strongest):** AirConsole — `device_id` is
  reserved per device across disconnect and reconnect, so the returning phone is the same
  player with the same slot, colour and score; the platform owns the pause overlay and the
  3-second resume countdown, and the game chooses its drop policy.
- **Automatic CPU substitution plus reclaim:** Superstars (rejoin on the next turn),
  Jamboree (reconnect "at any time", reported), LEGO (Main Menu rejoin pop-up while friends
  are still in the session).
- **Manual or user-facing:** Jackbox (refresh the browser; cookie-dependent; may come back
  as audience), WiiParty (pause-menu Autoplay revert).
- **Absent as re-entry:** WiiParty — the roster is fixed at Start and substitution is the
  only mechanism; Superstars' local drop and host drop have no evidence either.
- **Documented time box:** Jackbox pauses 5 minutes for a host; LEGO requires the friends not
  to have "progressed too far"; Superstars, Jamboree and AirConsole document no rejoin window
  at all.

---

## Coverage notes

- No stage is empty for all six games; the minimum is five of six. Seven stages have one
  absent game — 5 and 13 (WiiParty) and 7, 9, 10, 11, 12 (AirConsole). For the AirConsole
  five the reason is the same: the platform has no opinion and delegates the surface to each
  game.
- Seven `absent` stage cells: WiiParty stage 5 (no lobby), AirConsole stages 7, 9, 10, 11
  and 12 (all platform-level; those surfaces belong to each game), and WiiParty stage 13
  (no re-entry, only pause-menu substitution). WiiParty stage 12 is present, but as
  "game over → menu" rather than a session.
- The one stage *attribute* with zero evidence across all six is stage 4's colour + accessory
  picker: no game asks the player to choose a colour and an accessory at party setup. Stage 4
  itself is not empty — every game has some identity step (character, minifigure, Mii,
  nickname) — but the colour/accessory axis is absent everywhere.
