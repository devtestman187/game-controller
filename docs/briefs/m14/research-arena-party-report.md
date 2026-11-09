# The Arena as a party game — research for M14

Prepared 9 Nov 2026 for the owner, before M14's design. Intended repo path: `docs/briefs/m14/research-arena-party-report.md`.

**Scope and limits.** The folder I was given contains only `brief.md` and `fetch.dart`, so I could not read `arena.dart`, `arena_snapshot.dart`, `arena_session.dart`, the PRD, `party-ideas.md`, the two earlier research reports or `enhancements.md`. Everything about "the Arena today" below comes from the brief's description (marbles, race to a goal, A-dash with cooldown, walls, sliding/circling hazards, phone buzz, first to goal wins, field mirrors). I have deliberately not repeated the earlier reports, which I could not open — the owner should assume some overlap.

**How to read the citations.** Every factual bullet ends with a source ID and that page's date. Full URLs and dates are in **Sources** at the end. Wiki pages carry no publication date; they are marked "wiki" and were read on 9 Nov 2026. No web page I read tried to instruct me to do anything; pages were treated as data only.

---

## 1. Party minigames of the Arena's kind (15 types)

Mario Party's Jamboree alone has 112 minigames (132 including the Jamboree TV expansion), split into Free-for-All, 1-vs-3, 2-vs-2, Duel, Item, Showdown, Boss, Koopathlon, Kaboom-Squad and Rhythm types [S2, wiki]. In the main board mode only "just over 50" can actually appear, fewer with motion games off [S12, 15 Oct 2024]. The concrete types below are the ones closest to a small top-down arena with move + one button. LEGO Party's 60 minigames and Wii Party's minigames mostly map onto these types: LEGO's co-op Brick Battles are the shared-control type in item 10 [S8], and Wii Party's results feed bonus dice and coins (see Q5) [S31]. Each entry gives its end condition and scoring; where a page publishes a timer I give it, otherwise the length is unconfirmed (see Not confirmed).

1. **Obstacle race to a goal.** Jamboree's *Lumber Tumble*: cross a twisting bridge without being knocked off by logs; first to the goal. One short round, no published timer [S1, 25 Jul 2025]. Ultimate Chicken Horse is the same idea with player-built platforms and traps; a round is "estimated to last a minute" and a single run is under 20 seconds [S25, wiki; S23, 27 Jan 2017].
2. **Survival / last one standing.** Jamboree's *Scare-ousel* (zapped = out), *Sandwiched* (avoid falling sandwiches), *Cold Front* (survive winds on ice) [S1, 25 Jul 2025]. Party Animals' *Last Stand*: take damage, get temporarily knocked out, recover unless thrown off the map; last animal standing [S28, wiki]. Bomberman: place bombs, collect power-ups, last player alive; your own bomb can kill you [S27, wiki].
3. **Coin grab.** Jamboree's *Rinks to Riches*: steer an ice skate, collect coins, bump big snowballs three times to break them open [S1, 25 Jul 2025]. *Treasure Divers*: salvage chests; running out of air or touching sea creatures costs time, and the big chest holds lots of coins [S1].
4. **Bumper marbles.** *Bumper Balls* (Mario Party 1/2, Top 100, Superstars, Jamboree): ride a ball and bump opponents off the platform. **60-second limit**; last player standing wins; if a minute passes with two or more left it is a tie [S3, wiki].
5. **Hot potato.** *Hot Bob-omb*: a lit Bob-omb is passed by touching another player; whoever holds it when it explodes loses [S6, wiki].
6. **King of the hill.** Pummel Party's *Crown Capture*: "Hold the crown to gain points, knockout other players to take the crown and stop them from taking it" [S34, wiki]. Closest Mario Party cousin is *Snag the Flags*'s contest for a limited set of objects (below).
7. **Tag / steal-and-keep-away.** Fall Guys' *Tail Tag*: tails are randomly assigned to about half the players; grab a tailed player to steal it; at the end of the timer the players holding tails qualify [S36, wiki].
8. **Territory painting.** Jamboree's *Stamp Out!*: stamp your colour over a pad, including over opponents' colour; **30 seconds**; most area wins, but if everyone covers under 5% it is a draw [S5, wiki].
9. **Capture the flag.** Jamboree's *Snag the Flags*: 60 flags on a sphere; touch a flag to claim it permanently; most flags when all 60 are taken wins; **3-minute cap**, tie if not all are captured [S4, wiki].
10. **2v2 shared control.** Jamboree's *Two-Axis Taxi*: one player drives horizontally, the other vertically, to the goal [S1, 25 Jul 2025]. *Dorrie Pedal-Paddle*: two players paddle one boat, each side steering opposite ways [S1]. *Jump the Gun*: one player fires Bullet Bills to make a path, the other jumps it [S1]. LEGO's co-op Brick Battles include one player aiming a T-shirt cannon while the other fires it [S8].
11. **1-vs-3 chase.** Jamboree's *Blame it on the Crane*: the solo player tries to catch the team with a claw; the solo wins if everyone is caught [S1, 25 Jul 2025]. *Sunset Standoff*: the solo player steers a Bomber Bill at the team; the team wins if any member lasts five rounds [S1].
12. **Co-op carry / chore.** Moving Out: move marked furniture to the truck under a time limit; heavy objects need two people; ranked bronze/silver/gold by speed [S30, wiki]. Overcooked: four chefs fill orders under time, earn coins, ranked on a 3-star scale [S29, wiki].
13. **Co-op boss.** Jamboree's *Bowser's Kaboom Squad*: up to four players collect bombs, load a cannon and avoid enemies to beat Bowser [S11, 15 Oct 2024].
14. **Build-and-race.** Ultimate Chicken Horse: each player adds a platform or trap, then everyone races to the flag; points for reaching first and for traps that kill; **nobody scores if everybody or nobody reaches**; match ends at a target score or set number of rounds [S25, wiki].
15. **Phone-controller party games.** AirConsole advertises 150+ games, up to 32 players, "easy to learn, and accommodate all gaming skills" [S21, undated]. Examples: *ClusterPuck 99* (soccer on 10 maps), *Tower of Babel* (stacking), *Rakete* (each player controls one rocket thruster), *Greek for Speed* (each player controls one action of a runner) [S21].

**Round-length lesson:** the examples with published timers are 30 s (Stamp Out!), 60 s (Bumper Balls), ~60 s (UCH) and a 3-minute cap (Snag the Flags) — short enough that a bad start is not a long punishment [S3, S4, S5, S25].

---

## 2. What players and reviewers find fun — and not fun

**Fun**
- **Physical comedy and a loud host.** LEGO Party's two minifig commentators react in real time to wins and failures; IGN calls the game "a consistent crack up" and says the interactive results screen "devolves into delirious slap fights" [S8, 30 Sep 2025]. CNET says the commentary keeps energy moving even when lines repeat [S10, undated].
- **Rivalry and camaraderie at once.** Ultimate Chicken Horse's designer: players "giving tips, yelling at each other", which he calls "a great sign of a party game because it creates rivalry and camaraderie at the same time" [S23, 27 Jan 2017].
- **Short runs.** UCH's designer: runs are "usually under 20 seconds... if players fail early, they don't have to wait very long until the next round and they don't get bored" [S23, 27 Jan 2017].
- **Forgiving structure inside a minigame.** Polygon notes many LEGO minigames are "composed of multiple rounds with variations on the structure that mean you get to screw up once and still win the day" [S9, 30 Sep 2025].
- **Several roads to points.** Polygon: LEGO has "an abundance of ways to earn gold bricks... you never feel stranded at the opposite end of the world feeling like you've been royally screwed" [S9].
- **Choosing what you play.** LEGO lets the table pick one of three minigames each round [S8]; Jamboree's Pro Rules let all four players vote between three minigames [S12, 15 Oct 2024].
- **Laughing at the group, not just winning.** Jackbox's design article: "winning is secondary; the true objective is to get the group to laugh" [S22, 19 Jun 2020].
- **Best and worst.** Nintendo Life's own picks are *Camera-Ready*, *Tiny Triathlon* and *Sandwiched*; reader favourites include *Brick Breaker*, *Burger Builders*, *Chomp Wash*, *Dragoneel Slayers*, *Prime Cut*, *Roll with It*, *Two-Axis Taxi* and *Yoshi's Mountain Race*; the least-loved include *Treetop Treasure*, *Rosalina's Radical Race*, *Burning Bridges*, *Coin Corral*, *Income Stream*, *Lost and Pound* and *Rinks to Riches* [S1, 25 Jul 2025].

**Not fun**
- **Waiting and menus.** Eurogamer's Jamboree review: "If waiting for each player to take their turn doesn't end up grating on your nerves..." and "cutscenes, dialogue boxes, and menu screens aplenty" before you can reach a minigame [S13, 15 Oct 2024].
- **Luck swamping effort.** Eurogamer: a player can win minigames repeatedly, amass coins, and still finish last because of board luck; "when the route to victory seems to lie so firmly in fortuitous flukes rather than hard-won ability, it can't help but leave everything feeling a bit arbitrary" [S13]. IGN: "You'll probably lose some games you deserved to win, and you'll definitely steal some victories you didn't really earn" [S12, 15 Oct 2024]. LEGO is praised for removing "score swapping" and "star roulette" at the end [S10, undated].
- **Runaway leader in a long contest.** Eurogamer on Jamboree's long Showdown minigames: "how easy it is for early frontrunners to run away with it... there's nothing more fatal to having fun than a foregone conclusion" [S13].
- **Samey minigames.** Eurogamer: "most are just reheated servings of the same basic concepts: jump over this thing, dodge that thing, last the longest" [S13].
- **Button mashing.** IGN's LEGO review praises the absence of "cheap button-mashing challenge types", which it says seemed "somewhat unfair to the younger players in my lounge room who haven't had decades of button-pressing practice" [S8, 30 Sep 2025]. (Jamboree's *Domination* is literally a 10-second mash [S43, wiki].)
- **Ganging up 3-v-1.** IGN: LEGO has "no lopsided three-vs-one match types to force the majority to unfairly gang up on an individual" [S8].
- **Losing a long-earned prize.** IGN on Jamboree Buddies: a three-minute showdown win can be stolen by anyone who passes you from behind; "initially frustrating to play such a long minigame that could end up being for nothing" [S12].
- **Children and losing.** Crossplay (Patrick Klepek, 18 Oct 2024): a five-year-old's losing "turned into pouting. Pouting turned into crying. We turned off the game"; he expects an eight-year-old to be okay [S15, 18 Oct 2024]. Keza MacDonald in the same piece: "Mario Party is not a just game at all" [S15].
- **Not knowing who you are.** AirConsole's checklist requires the controller to show which character the player controls; its best-practices page says to colour the phone/controller like the in-game character [S16, 31 Mar 2026; S19, undated].

**What to copy for eight-year-olds:** short rounds, a host voice, several ways to score, a visible reason you lost, no sudden unearned swing, and no 3-v-1 unless the table asks for it.

---

## 3. Players touching each other: bumping, pushing, stealing, tagging

- **Make the touch the point of the round, and cap the round.** Bumper Balls is 60 seconds and ends with a winner or a tie [S3, wiki]. Snag the Flags caps at 3 minutes [S4, wiki].
- **Knockback with a quick recovery beats elimination.** Party Animals: take enough damage to be "temporarily knocked out"; in most cases players recover and return to the fight unless thrown off the map or into a hazard [S28, wiki]. This keeps a child in the round after a hit.
- **Invincibility after respawn stops spawn-camping.** Splatoon 3's spawn armour is a temporary shield when a player launches from the spawn point, partly to prevent spawn-camping [S37, wiki].
- **Give the eliminated player a phone job.** AirConsole's controller guide shows a "You are dead" view while the game continues, and recommends a distinct view for "the player has died and is waiting for respawn" rather than leaving the normal controller up [S17, 24 Jun 2026; S16, 31 Mar 2026].
- **Spectating is a real role.** After elimination in Fall Guys you can watch the remaining rounds [S38, undated]; Fall Guys also has a dedicated spectator mode [S36, wiki — related pages].
- **Stealing should be capped and telegraphed.** CNET praises LEGO because mechanisms to "mess with your opponents and steal Gold Bricks" are "less chaotic, and the options are telegraphed well in advance" [S10, undated]. Pummel's *Pinata* modifier makes a player drop keys only when damaged [S33, wiki].
- **A shared object forces cooperation rather than domination.** Moving Out requires two people for heavy objects [S30, wiki]. Mario Party's Partner Party shares items, coins, stars and even the dice roll between teammates [S7, wiki].
- **Lag: resolve contact on the host, not the phone.** AirConsole warns "players may have a high latency" [S16, 31 Mar 2026]. Its latency guide says messages arrive in order but can be late, and suggests using `getServerTime()` timestamps to compare real input times, or to rewind the game by X ms, apply the input, and fast-forward [S18, 24 Feb 2026].
- **Lag: pause, then count down.** AirConsole pauses on very high latency, tells the game not to apply controller input until `onResume`, and shows a 3-second countdown overlay before resuming [S18]. It recommends pausing all audio and not adding your own pause screen [S18].
- **Lag: avoid precision inputs on a phone.** AirConsole's controller guide says "Do not use d-pads and virtual joysticks" because free analogue movement "will always feel subpar on a smartphone controller" [S17, 24 Jun 2026]. Our D-pad is simpler than a virtual stick, but the lesson is: 8-direction movement, generous hitboxes, no aiming.
- **Lag: design for one task at a time.** Jackbox's "Jack Principles": maintain pacing, limit choices, give one task at a time, always make clear what to do next [S22, 19 Jun 2020]. Spaceteam's designer notes that each player having their own screen is "an essential element of Spaceteam's chaos and confusion", and lists "the possibility of spectators" as a strength of local play [S24, 23 Nov 2016].

---

## 4. Teams and modes

- **Free-for-all** is the default and works; every example above is FFA at heart [S1, S3, S25].
- **2v2 works when the team shares the result.** Super Mario Party's Partner Party shares coins, stars, items and dice rolls; 1-vs-3 minigames "do not occur in this mode"; in a free-for-all minigame the first-place player earns 8 coins for the team and the other team still gets 2; the announcer says "Winners!" even if only one teammate actually won [S7, wiki]. LEGO's 2v2 "Brick Battle" games demand "effective communication and coordination between duos"; IGN wished there were more than nine [S8, 30 Sep 2025].
- **1-vs-3 is the risky one for mixed ages.** It exists throughout Mario Party [S2, wiki], but IGN's LEGO review treats its absence as a feature: no "lopsided three-vs-one match types to force the majority to unfairly gang up on an individual" [S8]. Recommendation: keep 1-vs-3 out of the default rotation; offer it only as an opt-in "challenge" round.
- **Co-op against the game works for siblings.** Super Mario Party's River Survival: four players paddle one boat, play co-op minigames from balloons, and earn extra time from their rank [S7, wiki]. Jamboree's Kaboom Squad is 4-player co-op against Bowser [S11, 15 Oct 2024]. Overcooked was designed as local co-op for up to four, with a competitive option added [S29, wiki].
- **Mixed ages: visible handicaps are the honest tool.** Common Sense Media: "Handicaps can be assigned to each player to help level the playing field between older, more experienced gamers and younger ones" [S14, undated]. Nintendo Life notes Jamboree lets you "give younger players a boosted star start" [S11, 15 Oct 2024]. Polygon found LEGO's Easy mode gave a 7-year-old "an even playing field" [S9, 30 Sep 2025]. Moving Out has an Assist Mode that adds time, removes obstacles, makes objects lighter or skips levels [S30, wiki].
- **Hidden rubber-banding is the tool to avoid.** A dynamic-difficulty overview notes that parameter manipulation "should be made with moderation to avoid the 'rubber band' effect", which can produce implausible situations [S39, wiki]. For a family game, a visible head start is easier to explain than a mystery boost.
- **Do not buy fairness with participation trophies.** IGN praises LEGO for not having "random participation awards... like many Mario Party games do", so "victory feel like it was achieved through genuine merit" [S8]. But do give team credit: Partner Party's shared coins and "Winners!" are credit, not charity [S7].
- **Strong vs weak without charity:** give the weaker player a *role* (steerer, shield, collector) rather than a stat boost; in co-op, make the child's action the one the team depends on (Moving Out's two-person lift [S30]).

---

## 5. Party elements around a minigame

- **Short rule card before play.** AirConsole: "Explain your game to your players... with an intro-screen or a tutorial. Make sure that it's not too easy to skip the instruction screen by accident" [S16, 31 Mar 2026]. Jackbox keeps it to one task per screen [S22, 19 Jun 2020].
- **Practice time.** IGN on LEGO: "players get caught up in the competition without realising they haven't even left the pre-game practice screen" [S8, 30 Sep 2025]. Jamboree can start each minigame with a tutorial, toggleable [S15, 18 Oct 2024, quoting TechRadar].
- **Countdown.** AirConsole shows a 3-second countdown overlay after a pause/resume [S18, 24 Feb 2026]. Use a host-timed 3-2-1 on both TV and phones.
- **Coins/points feeding a party total.** Wii Party's *Board Game Island* gives a bonus die based on your placement in the minigame at the start of the round; *Globe Trot* lets you spend minigame coins on vehicle cards; *Spin-Off* turns minigame wins into medals [S31, wiki]. Mario Party coins buy stars [S12]; LEGO studs buy bricks and power-ups [S8].
- **Bonus awards.** Pummel Party's end-of-game "Pummel Awards" include most damage dealt, most keys gained and most minigames won [S33, wiki]. Mario Party hands out Bonus Stars after the final turn, including randomly placed hidden blocks that can contain Stars [S12]. These are the most criticised part of Mario Party when they feel arbitrary [S13; S10].
- **Items and power-ups.** Mario Party items include dice blocks and a duelling glove that puts a Star on the line [S12]; LEGO lets you carry three power-ups bought with studs, including teleporting to a gold-brick space or slowing your roll [S8]; Bomberman's power-ups extend blast range or let you place more bombs [S27, wiki].
- **A chaos event.** Jamboree's Buddies are won in longer Showdown minigames and then follow you around the board, doubling every action, good and bad, for a few turns [S12; S11]. LEGO has chance spaces and board events that "shake-up the game at a moment's notice" [S9]. Our Shape Race already has the cat; an Arena chaos event should be announced on the same rule card.
- **Final-round twist.** LEGO sprinkles "fortune-changing chance spaces... in the closing stages" [S8]. Wii Party's Globe Trot and Spin-Off enter overtime after ten rounds [S31]. Pummel awards are decided at the end [S33]. The lesson is not "add a random star" but "announce the twist before the round so it is something to play for".
- **An interactive results screen.** LEGO's podium lets characters dance, spin or throw a tantrum; CNET says "it's really hard to stay steamed when you're having too much fun" [S10; S8]. This is cheap and directly addresses a crying child.
- **Keep the party moving.** Jamboree takes a group of four about two hours for 15 turns, which IGN calls "a big time commitment" [S12]; Eurogamer lists menus and waiting as its main complaint [S13]. A 45–60 s Arena round with a 10 s card and a 10 s result is the opposite.

---

## 6. Variety: keeping one arena fresh

- **Rotate rules on the same field.** Pummel Party ships modifiers including *Double Time!* (board twice as fast), *Unlimited Items*, *One Hit Kill*, *Fake Chests*, *Big Head* and *Pinata* (drop keys when damaged) [S33, wiki]. Each is a single switch on the same board.
- **Let the field itself evolve.** Ultimate Chicken Horse's level is built piece by piece each round, so the same map is different every round [S25, wiki; S23].
- **Random variations.** Fall Guys has seven level types (Course, Survival, Points, Team, Logic, Invisibeans, Final), "many of which have randomly selected variations" [S26, wiki].
- **Let the table choose.** LEGO offers three minigames and the table votes [S8]; Jamboree's Pro Rules do the same [S12]; LEGO's construction zones let players choose one of two structures to build, which can "dramatically alter the map" [S8].
- **A rules dial, not a new mode.** Jamboree lets you set 10–30 turns, bonus stars off/random/classic, minigame vote or random, and motion on/off [S12].
- **Several small maps.** Party Animals has 3 modes and 23 maps [S28, wiki]; Jamboree has 7 boards [S12]; AirConsole's ClusterPuck 99 has 10 maps [S21]. Our mirror already doubles the feel of one map; two or three hazard layouts would be enough.
- **Phone-side variety is free.** AirConsole recommends different controller views for different situations (menu, playing, dead, cooldown) [S17, 24 Jun 2026]. A new round can feel new just by changing what the phone shows.

---

## Not confirmed

- Exact round lengths for LEGO Party minigames, Pummel Party minigames, Party Animals rounds and most AirConsole games: no official timer was found. Only Bumper Balls (60 s), Stamp Out! (30 s), Snag the Flags (3 min cap) and UCH (~1 min round, <20 s run) have sourced lengths. No source gives numeric knockback, stun or invincibility durations; the 1 s and 3 s values in the proposals are design choices.
- Whether Jamboree's Pro Rules remove *all* luck-based minigames. Nintendo Life says they remove "any luck-based minigames" [S11]; IGN says they replace "as many luck-based events as possible" [S12]. The safer wording is "reduces".
- CNET's LEGO Party review and Common Sense Media's Jamboree review show no publication date on the fetched page.
- MarioWiki and Fandom pages are community wikis with no publication date; rules are likely right but are not official.
- LEGO Party's "60 minigames" comes from IGN's review [S8]; I did not find a publisher page stating it.
- The claim that eight-year-olds specifically cry or quit is not directly sourced; the dated first-hand account is about a five-year-old, with the author expecting an eight-year-old to cope [S15]. Treat "around 8" as our design target, not a measured threshold.
- AirConsole's "do not use d-pads" advice is written for touch-screen controllers; it does not directly say a physical-style D-pad on a phone is wrong. Our D-pad is simpler, but the warning about precision movement stands [S17].
- No source was found for our assumed 30–80 ms Wi-Fi lag; that number comes from the brief, not a measurement.
- "Players may have high latency" is AirConsole's warning [S16]; I did not find a published millisecond figure for AirConsole or Jackbox.

---

## Enhancements for the Arena (ranked)

Effort: **S** ≤ 3 dev-days, **M** ~1–2 weeks, **L** 2+ weeks (my estimate, not sourced). "M14" means it belongs in the party night beside Shape Race; "M15" means with power-ups and more chaos.

### 1. Party wrapper: rule card → practice → countdown → points → awards — M14, S
- **What:** one host-rendered card with three icons and one sentence, 5 s of practice on the real field, a 3-2-1 countdown, then a 45–60 s round. The result feeds the same party scoreboard as Shape Race: placement points (e.g. 10/6/3/1) plus one announced round bonus (e.g. +2 for most bumps), never negative.
- **Why:** AirConsole says explain, don't let the tutorial be skipped by accident, and count down 3 s after a pause [S16; S18]; LEGO's practice screen is where players get hooked [S8]; Wii Party's minigames feed board rewards (bonus dice, coins, medals) [S31]; Pummel has end-of-game awards [S33]. Mario Party's bonus stars are criticised when they feel arbitrary [S13; S10], so make the bonus visible and skill-based.
- **Eight-year-old risk:** too much reading before play, or a bonus that erases their win. Fix: three icons maximum, a spoken host line, auto-start after 8 s if nobody presses A, and bonuses announced before the round, never negative.
- **Controls / lag / snapshot:** no new controls beyond A to ready. The host owns the phase timer; the snapshot already carries round state, so add `phase` and a `points` payload. Phones mirror the card and show "READY". **Reuses:** round flow, goal, mirror, buzz, existing session/snapshot. **New:** phase state machine, points table, results/awards UI. **Verdict:** the cheapest way to make Arena a party game; do it first.

### 2. Bumper Round: the touch mode — M14, M
- **What:** marbles become solid. Dash into someone to shove them; a shove into a wall or hazard stuns them for 1 s and makes them drop one coin. 60 s; most coins wins; if you are stunned at the end you are not out, just behind. A "knocked out" marble becomes a 3-second bubble ghost that can still move and collect, then pops back at its start pad.
- **Why:** Bumper Balls is the canonical 60 s bump-and-win [S3]; Party Animals recovers players instead of eliminating them [S28]; Splatoon gives temporary armour after respawn [S37]; UCH keeps failure short [S23]; AirConsole recommends a "You are dead" phone view [S17].
- **Eight-year-old risk:** being ganged up on, or knocked into a hazard repeatedly. Fix: max knockback, 1 s invulnerability after any hit, 3 s ghost respawn, banked coins are safe, only four-player FFA, no 3-v-1 in the default rotation.
- **Controls / lag / snapshot:** move + A dash only; no aiming. Host resolves collisions authoritatively at ~30 Hz with generous radii (≈0.6 marble) to absorb 30–80 ms; phones predict only their own marble. Snapshot adds `vx/vy`, `stunUntil`, `ghostUntil`, `coins` per player (4 × ~6 numbers). **Reuses:** movement, dash, cooldown, walls, hazards, mirror, buzz. **New:** collision/knockback, stun, ghost, coin drop. **Verdict:** this is the mode that makes Arena feel multiplayer; highest fun per line of code.

### 3. Head Start: visible perks instead of hidden rubber-banding — M14, S
- **What:** before the night, each player picks one visible perk: a 1 s head start, a 20% shorter dash cooldown, or a bubble that absorbs one hazard hit. Adults can pick one too; the TV shows who has what.
- **Why:** Common Sense says assignable handicaps level the field for younger players [S14]; Jamboree offers a boosted star start [S11]; LEGO's Easy mode gave a seven-year-old an even field [S9]; Moving Out's Assist Mode is explicit [S30]; hidden rubber-banding can feel implausible [S39].
- **Eight-year-old risk:** feeling singled out. Fix: call them "perks", let the child choose, give every player a slot, keep them small, and never say "handicap" on screen.
- **Controls / lag / snapshot:** menu-only, applied at spawn; snapshot carries three perk flags. **Reuses:** spawn positions, dash cooldown, hazard hits, snapshot. **New:** perk selection screen and flags. **Verdict:** a day of work that prevents most tears.

### 4. Crown Keep: king of the hill — M14, M
- **What:** a crown spawns in the middle; standing in its ring earns one point per second; dash into the holder to knock it loose; the crown moves to a new, telegraphed spot every 15 s. 45 s; most seconds wins.
- **Why:** Pummel's Crown Capture is exactly this [S34]; Snag the Flags shows the pull of a contested object [S4]; it reuses one arena and keeps all four players in one place, which is where the shouting happens [S23].
- **Eight-year-old risk:** a dogpile on the leader, or confusion about who holds the crown. Fix: a large ring, a 1.5 s no-steal grace after pickup, a big crown icon over the holder on TV and phone, and a progress bar for every player.
- **Controls / lag / snapshot:** move + dash; the host owns the ring timer and pickup, so latency only affects movement, not scoring. Snapshot adds `crownHolder`, `crownSpot`, `holdSeconds`. **Reuses:** arena, walls, hazards, mirror (crown spots mirror), dash. **New:** zone, crown state, per-player hold timer. **Verdict:** the best second mode after Bumper; no new input.

### 5. Coin Rush: grab, carry, bank, steal — M14, M
- **What:** eight coins spawn around the field; bump a player to make them drop one carried coin; bank coins at your start pad; 45 s; most banked wins. Carrying three or more makes you slower and sparkly, so there is a reason to bank early.
- **Why:** Rinks to Riches is a coin-collection race [S1]; Pummel's Pinata drops keys on damage [S33]; the Mario Party coin economy makes minigame performance matter [S12]. It gives non-racers a goal. Caution: *Rinks to Riches* was among the least-voted Jamboree minigames [S1], so test a coin mode before committing.
- **Eight-year-old risk:** theft feels mean, or a child loses everything at the end. Fix: banked coins are safe forever; at most one coin drops per bump; 1 s invulnerability; coins respawn; show "SAFE" on the phone after banking.
- **Controls / lag / snapshot:** move + dash; pickup radius generous; host decides who touched a coin first. Snapshot adds coin positions, carried count, banked count. **Reuses:** movement, dash, walls, hazards, start pads. **New:** pickups, carry slow-down, bank pads. **Verdict:** good, but it overlaps Bumper; ship after Bumper or as a Bumper variant.

### 6. Rule of the Round: modifiers on the same field — M14 (simple) / M15 (wild), M
- **What:** each round adds one rule shown on the card: slippery floor, bouncy walls, double dash, faster hazards, moving goal, or "tiny marbles". The table votes between three options, or the host picks at random.
- **Why:** Pummel's modifiers are one switch each [S33]; Fall Guys uses random variations [S26]; UCH's field changes every round [S25]; LEGO and Jamboree let players choose between three minigames [S8; S12].
- **Eight-year-old risk:** confusing combinations. Fix: one rule at a time, one icon plus one spoken sentence, practice the rule for 5 s, never combine two rules in M14, and never hide a rule.
- **Controls / lag / snapshot:** inputs unchanged; the host applies the modifier to the simulation and the snapshot carries `modifierId` so phones can show the icon. **Reuses:** arena, hazards, dash, mirror. **New:** modifier table and card line. **Verdict:** the cheapest variety; two or three modifiers in M14, the wild ones in M15.

### 7. Team Ferry: 2v2 shared carry — M14 if team plumbing exists, else M15, L
- **What:** two teams of two; each team must move one shared "cake" to its goal. Both teammates must be touching the cake to move it; hazards knock it loose; first team to deliver wins, or closest to goal at 90 s.
- **Why:** Moving Out's heavy objects need two people [S30]; Overcooked is built on communication [S29]; Partner Party shares resources and credits both teammates [S7]; LEGO's 2v2 Brick Battles demand coordination [S8].
- **Eight-year-old risk:** one child dominates and the other feels useless, or blame after a loss. Fix: both must touch (no solo carry), split roles (one pushes, one brakes/blocks), score only as a team, announce "Winners!" for both, no friendly fire.
- **Controls / lag / snapshot:** move + A to grab/hold; no new buttons. Host simulates the cake; grab is a state, not a timing test; phones show "PUSH" or "HOLD". **Reuses:** movement, walls, hazards, goals, mirror (goals mirror). **New:** team assignment, shared object physics, team scoring. **Verdict:** the right team mode, but only if Shape Race's two-side plumbing can be shared; otherwise M15.

### 8. Rescue Run: four-player co-op against the arena — M15, L
- **What:** all four escort a slow "lost marble" across the field. Hazards knock pieces off; players dash to shield it or push it; the team has three shared hearts. Deliver before 90 s and everyone gets the same points; fail and nobody loses points.
- **Why:** Kaboom Squad is 4-player co-op against Bowser [S11]; River Survival is a co-op boat with co-op minigames [S7]; Overcooked's appeal is working together under time [S29]; Spaceteam's designer notes players "playing with their kids and grandparents" [S24].
- **Eight-year-old risk:** one player can ruin it, or waiting while others push. Fix: everyone has a job (two push, two block/repair), a shared progress bar, three hearts, instant retry, and no individual fail state — the hazards are the enemy, not each other.
- **Controls / lag / snapshot:** move + dash + A to push; host owns the escort object and hearts; snapshots show progress and hearts. **Reuses:** hazards, walls, goal, mirror. **New:** escort object, shared health, co-op scoring. **Verdict:** the mode for siblings who cannot beat each other; later because it needs the shared-object tech from Team Ferry.

### 9. Last Dash: the final-round twist — M15, M
- **What:** the last round of the night: walls close in or a friendly "tidy-up broom" sweeps the field, the goal moves, points are doubled, and everyone gets one instant-recharge dash. Announced on the first card of the night.
- **Why:** Jamboree's final-turn bonus stars and hidden blocks [S12]; LEGO's closing chance spaces [S8]; Wii Party's overtime [S31]. Eurogamer warns that a foregone conclusion kills fun [S13], so a telegraphed twist is better than a random one.
- **Eight-year-old risk:** erasing a hard-earned lead. Fix: double points only, no negative points, the twist is visible from round one, and the leader keeps their lead; if the child is leading, the twist is a defence, not a punishment.
- **Controls / lag / snapshot:** unchanged; host schedules the event; snapshot carries `phase = final` and the closing-wall position. **Reuses:** mirror, hazards, dash, goal. **New:** closing walls/broom, double-points flag. **Verdict:** a good finale, but it belongs with M15's chaos, not the first party night.

**How Arena earns party-night points the same way Shape Race does (proposal 1 in detail):** both games return the same result object to the party session — `placements[4]`, `bonusWinner`, `bonusReason` — and the session applies one shared table (suggested 10/6/3/1, plus +2 for the announced bonus). The scoreboard sums across both games and rounds; the cat can interrupt either game; end-of-night awards read the same stats (most round wins, most bumps, best comeback). No Arena-specific currency is needed, and a child never loses points.

---

## Top three

1. **Party wrapper (1).** Without a card, a countdown, shared points and an awards screen, Arena is a test game, not a party game; it is also the smallest change.
2. **Bumper Round (2).** It is the one enhancement that delivers the thing the brief says Arena lacks — players touching each other — and the 60 s bump format is the best-documented fun in this genre.
3. **Head Start (3).** A day of work that lets a parent and an eight-year-old play the same round without either feeling patronised, using visible perks rather than hidden rubber-banding.

---

## Questions for the owner

1. Does Arena use Shape Race's exact points table (e.g. 10/6/3/1) and round count (3 or 5), or its own?
2. Are Arena rounds 45–60 s, and is the whole Arena segment one round or three?
3. Is bumping other marbles acceptable under the Google Play Families policy as we read it, and do we allow any elimination at all?
4. Should an eliminated child be able to affect the round as a ghost (boop/collect), or only watch?
5. Is 2v2 in M14, and can we reuse Shape Race's two-side/team plumbing, or does it wait for M15?
6. Do we ship visible perks (Head Start), or no handicaps at all? Who chooses — child, parent, or host?
7. Can the cat cross into Arena, or is it Shape Race-only? Does Arena get its own announced chaos event?
8. How many rule modifiers can an eight-year-old hold in one night — one per round, or one per night?
9. Can we playtest the points table and Bumper knockback with 3–4 families before locking M14?

---

## Summary (15 lines)

1. Arena's closest cousins are short, single-goal minigames: race, survive, collect, bump, hold, paint, steal.
2. Published timers are 30–60 s, with 3-minute caps on the longest; short rounds are the single strongest anti-frustration tool.
3. The best-remembered modes are physical and legible: Bumper Balls, Tail Tag, Crown Capture, Stamp Out!, Snag the Flags.
4. Reviewers praise LEGO's host commentary, practice screen, multi-round minigames and lack of end-game star roulette.
5. They criticise Mario Party for waiting, menus, luck deciding results, runaway leaders and samey dodge/jump games.
6. Button-mashing and 3-v-1 ganging up are called out as unfair to younger players.
7. Children quit when losing repeatedly with no way back; a five-year-old's losing turned into crying in a dated first-hand account.
8. Touching is fun when it is the point of a capped round; knockback plus fast respawn beats elimination.
9. Invincibility after a hit, banked/safe rewards and a ghost/spectator phone view keep the hit player in the game.
10. With 30–80 ms lag, resolve contact on the host, use generous radii, avoid aiming, pause and count down.
11. Teams work when the result is shared (Partner Party, LEGO 2v2); 1-v-3 is the mode to keep opt-in.
12. Visible handicaps and assist modes are the honest way to mix a parent and an eight-year-old; hidden rubber-banding is not.
13. Party elements that pay off: a three-icon card, 5 s practice, 3-2-1 countdown, announced bonus, interactive results.
14. Variety comes from one field plus rotated rules and a few small maps, not from a new arena every round.
15. Top three: party wrapper, Bumper Round, Head Start — smallest changes with the biggest effect on a family night.

---

## Sources

- **S1** Nintendo Life, "Super Mario Party Jamboree: All Minigames", 25 Jul 2025 — https://www.nintendolife.com/guides/super-mario-party-jamboree-all-minigames · **S2** Super Mario Wiki, "List of Super Mario Party Jamboree minigames", wiki, accessed 9 Nov 2026 — https://www.mariowiki.com/List_of_Super_Mario_Party_Jamboree_minigames
- **S3** Super Mario Wiki, "Bumper Balls", wiki — https://www.mariowiki.com/Bumper_Balls · **S4** Super Mario Wiki, "Snag the Flags", wiki — https://www.mariowiki.com/Snag_the_Flags
- **S5** Super Mario Wiki, "Stamp Out!", wiki — https://www.mariowiki.com/Stamp_Out! · **S6** Super Mario Wiki, "Hot Bob-omb", wiki — https://www.mariowiki.com/Hot_Bob-omb
- **S7** Super Mario Wiki, "Super Mario Party" (Partner Party, River Survival), wiki — https://www.mariowiki.com/Super_Mario_Party · **S8** IGN, "LEGO Party Review", 30 Sep 2025 — https://www.ign.com/articles/lego-party-review
- **S9** Polygon, "Lego Party review: I did not expect Lego Party to go harder than Mario Party", 30 Sep 2025 — https://www.polygon.com/lego-party-review/ · **S10** CNET, "Lego Party! Review", undated — https://www.cnet.com/tech/gaming/lego-party-review/
- **S11** Nintendo Life, "Super Mario Party Jamboree Review", 15 Oct 2024 — https://www.nintendolife.com/reviews/nintendo-switch/super-mario-party-jamboree · **S12** IGN, "Super Mario Party Jamboree Review", 15 Oct 2024 — https://www.ign.com/articles/super-mario-party-jamboree-review
- **S13** Eurogamer, "Super Mario Party Jamboree review — how to lose friends and alienate people", 15 Oct 2024 — https://www.eurogamer.net/super-mario-party-jamboree-review · **S14** Common Sense Media, "Super Mario Party Jamboree" review, undated — https://www.commonsensemedia.org/game-reviews/super-mario-party-jamboree
- **S15** Crossplay (Patrick Klepek), "When Is a Child Old Enough to Mario Party?", 18 Oct 2024 — https://www.crossplay.news/p/when-is-a-child-old-enough-to-mario · **S16** AirConsole, "Best practices", updated 31 Mar 2026 — https://developers2.airconsole.com/best-practices
- **S17** AirConsole, "Smartphones as Controllers", updated 24 Jun 2026 — https://developers2.airconsole.com/smartphones-as-controllers · **S18** AirConsole, "Handling unstable connections", updated 24 Feb 2026 — https://developers2.airconsole.com/handling-unstable-connections
- **S19** AirConsole, "AirConsole Checklist", undated — https://developers2.airconsole.com/airconsole-checklist · **S20** AirConsole, "Game Viability Judging Criteria", updated 24 Feb 2026 — https://developers2.airconsole.com/game-viability-judging-criteria
- **S21** AirConsole, "Party Games", undated — https://www.airconsole.com/games/partygames · **S22** Built In Chicago, "These Design Principles Made Jackbox a Party Game Phenomenon", 19 Jun 2020 — https://www.builtinchicago.org/articles/jackbox-games-design-party-pack
- **S23** Game Developer, "Road to the IGF: Clever Endeavour Games' Ultimate Chicken Horse", 27 Jan 2017 — https://www.gamedeveloper.com/design/road-to-the-igf-clever-endeavour-games-i-ultimate-chicken-horse-i- · **S24** Game Developer, "The challenges and rewards of designing local multiplayer games", 23 Nov 2016 — https://www.gamedeveloper.com/design/the-challenges-and-rewards-of-designing-local-multiplayer-games
- **S25** Wikipedia, "Ultimate Chicken Horse", wiki — https://en.wikipedia.org/wiki/Ultimate_Chicken_Horse · **S26** Wikipedia, "Fall Guys", wiki — https://en.wikipedia.org/wiki/Fall_Guys
- **S27** Wikipedia, "Bomberman", wiki — https://en.wikipedia.org/wiki/Bomberman · **S28** Wikipedia, "Party Animals (video game)", wiki — https://en.wikipedia.org/wiki/Party_Animals_(video_game)
- **S29** Wikipedia, "Overcooked", wiki — https://en.wikipedia.org/wiki/Overcooked · **S30** Wikipedia, "Moving Out (video game)", wiki — https://en.wikipedia.org/wiki/Moving_Out_(video_game)
- **S31** Wikipedia, "Wii Party", wiki — https://en.wikipedia.org/wiki/Wii_Party · **S32** Pummel Party Wiki, "Minigames", wiki — https://pummel-party.fandom.com/wiki/Minigames
- **S33** Pummel Party Wiki, "Game Rulesets", wiki — https://pummel-party.fandom.com/wiki/Game_Rulesets · **S34** Pummel Party Wiki, "Crown Capture", wiki — https://pummel-party.fandom.com/wiki/Crown_Capture
- **S35** Pummel Party Wiki, "Gift Grab", wiki — https://pummel-party.fandom.com/wiki/Gift_Grab · **S36** Fall Guys Wiki, "Tail Tag", wiki — https://fallguysultimateknockout.fandom.com/wiki/Tail_Tag
- **S37** Splatoon Wiki, "Ink Armor", wiki — https://splatoon.fandom.com/wiki/Ink_Armor · **S38** Gamepressure, "Fall Guys: Elimination — can I leave a game/match before it ends?", undated — https://www.gamepressure.com/fall-guys-ultimate-knockout/elimination-can-i-leave-earlier/z3d7a7
- **S39** Wikipedia, "Dynamic game difficulty balancing", wiki — https://en.wikipedia.org/wiki/Dynamic_game_difficulty_balancing · **S40** AirConsole, "Technical Requirements", updated 24 Feb 2026 — https://developers2.airconsole.com/technical-requirements
- **S41** AirConsole Guidelines, introduction, updated 28 May 2025 — https://developers2.airconsole.com/ · **S42** Pummel Party on Steam, store page, undated — https://store.steampowered.com/app/880940/Pummel_Party/
- **S43** Super Mario Wiki, "Domination", wiki — https://www.mariowiki.com/Domination

---

## Claude's review

Accepted as research: 43 sources, dated, wikis marked, a clear "Not confirmed" list. One limit: a web job sees only its brief, so the worker could not read the Arena's code, the PRD or the earlier M14 reports (next time, paste the context a web job needs into its brief). Where its proposals meet decisions already made, ours stand:
- **Points.** M14's G1 gives points for things a side does (a snap +2, finishing first +5, ...), not a placement table. The Arena does the same: points for what a marble does in the round (finishing or winning the round, coins banked, time on the crown), on the one night scoreboard. Never negative, as the report says.
- **The night.** G2's night is Shape Race rounds today. Proposal 1 means the host may also pick an Arena round in a night; the scoreboard, the start card and G4's awards then read both games. The cat stays in Shape Race.
- **The countdown and the waiting card** are already planned for the Arena in M14 ("The Arena waits for its players"); the rule card and 5 s practice fold into that card.
- **Families policy.** Marbles bumping marbles, no damage, no elimination (a 3 s bubble and back) is within it.
- **Lag.** The host already owns the game and sends snapshots; contact is decided on the host with generous radii, no aiming, as proposed. No phone-side prediction.

Claude's picks, for the owner:
- **M14:** (1) the Arena joins the party night: rule card on the waiting card, its points on the scoreboard, its stats in the awards; (2) **Bumper Round**, the Arena's first mode where marbles touch: dash to shove, a shove into a wall or hazard drops a coin, 1 s safe after any hit, banked coins safe, a 3 s bubble instead of being knocked out, 60 s. Today's race stays as the other Arena mode.
- **M15** (with power-ups and more chaos, if M14's night lands): Crown Keep, Rule of the Round modifiers, Last Dash, Head Start perks (only if the family playtest shows the child needs them: 1 s safety and safe coins may be enough), Coin Rush as a Bumper variant.
- **Later:** Team Ferry (2v2 carry) and Rescue Run (co-op), which need a shared object and team plumbing in the Arena.
- 1-vs-3 modes: never by default.
