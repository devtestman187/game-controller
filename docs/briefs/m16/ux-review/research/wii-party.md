# Wii Party (Nintendo Wii, 2010) — competitive research digest

**Scope.** Player-facing flow of *Wii Party* (NDcube / Nintendo SPD, Nintendo, 2010) — a
local, single-console party game for 1–4 players using Wii Remote controllers, built on
board-game and minigame modes. This digest maps what the game does to the 13 stages of
`../worker-spec.md` section 1, and records where a stage is **absent**.

**Release facts used below.** Japan 8 July 2010; North America 3 October 2010; Australia
7 October 2010; Europe 8 October 2010 (<https://en.wikipedia.org/wiki/Wii_Party>).
"More than 80 different mini-games" in "13 different game modes" is Nintendo's own
count (<https://www.nintendo.com/en-gb/News/2010/Make-your-Wii-the-life-and-soul-of-the-party--252279.html>).

**Headline result.** 10 of the 13 stages exist in a recognisable form (1, 2, 3, 6, 7, 8, 9,
10, 11, 12). Stage 4 exists only as *Mii selection* — no colour, no accessory, no creation.
Stage 13 exists only as *substitution*: the roster is fixed when Start is pressed, and the
only in-game stand-in for a missing human is the pause menu's Autoplay (CPU) toggle, which
cannot be applied to Player 1. Stage 5 has **no version at all**: there is no lobby.

---

## 0. Evidence method and grades

Three grades of evidence appear below and are labelled:

- **A — fetched and read.** The page was retrieved and the quoted text is on the page.
- **B — manual text read from the search index.** The scanned Nintendo manual (34 pp.) is
  mirrored by several hosts, all of which return HTTP 403 to a direct fetch
  (Cloudflare). The quoted English text is the OCR of the manual page as exposed in the
  search index, and each quote below is corroborated by **at least two independent
  mirrors** (ManualsLib, Notice-Facile, HandleidingKwijt, Yumpu, or the arquivo.pt capture
  of Nintendo's own PDF). Page numbers are the manual's printed page numbers where the
  excerpt shows them.
- **C — secondary.** Reviews and community wikis; single-source and treated as
  supporting, never as the sole basis for a flow claim.

No claim below is inferred from a screenshot I did not see; where the mechanism is
undocumented, the digest says so in the stage's **Gap** line and again in section 15.

---

## 1. Launch / first run — **present**

The first-run path is the Wii platform's standard disc-boot path plus one game-specific
step. From the manual's "Starting the Game" page:

> "Insert the Wii Party Game Disc into the disc slot on the Wii console. The console
> power will turn on. **Health and Safety Screen** — The screen on the right will be
> displayed. Once you have read the message, press [A] to continue. **Wii Menu** — On the
> Wii Menu, point at the Disc Channel and press [A] to bring up the Channel Preview
> screen. … Point at Start and press [A] … [bring] up the Strap Usage screen. … Once you
> have properly adjusted your wrist strap, press [A] to reach the title screen.
> **Title Screen** — … at the same time to proceed to the main menu."

— manual p. 5 (B), <https://www.manualslib.fr/manual/202416/Nintendo-Wii-Party.html?page=5>

Three consequences for flow design:

1. **Two mandatory platform interstitials before the game's own content** — the disc's
   health-and-safety screen (press A) and the wrist-strap screen (press A) — then the
   title screen, which requires two buttons pressed *simultaneously* ("at the same time";
   the OCR drops the button glyphs). The simultaneous press is a deliberate friction
   gate: a single stray button press cannot skip the title.
2. **First run differs from later runs only by save-file creation.** "The first time the
   game is played, a Wii Party save file will be created. Two empty blocks on the Wii
   console are necessary" — manual p. 5 (B), same URL. There is **no account, profile,
   name entry, or sign-in** anywhere in the documented boot path.
3. **Party Phil's introduction runs between the title screen and the main menu.** A TAS
   submission documents the screen sequence and its variable load time: "Upon booting up
   the game for the first time, Party Phil asserts that there are three styles of games to
   choose from: Party Games, Pair Games, and House Party games", and lists "Party Phil's
   intro prior to the main menu" as one of four variable-length load points between the
   title screen and gameplay (A) — <https://tasvideos.org/Forum/Topics/23738?CurrentPage=1&Highlight=517700>.
   Phil's greeting is quoted as "Hello, and welcome to Wii Party! I'm your charming host,
   Party Phil!" (A) — <https://miiwiki.org/wiki/Party_Phil>.

The per-mode rules explanation is *not* a first-run-only gate: "When a game is played for
the first time, the rules will be explained by the host. From the second time onward, you
can choose whether or not to hear the explanation. Press [A] to skip an explanation and
start the game" — manual p. 6 (B),
<https://handleidingkwijt.com/nintendo-wii-wii-party/?page=6>.

**Gap.** The manual does not state whether the health-and-safety and strap screens can be
skipped, and no source documents a "returning player" fast path on the title screen.

---

## 2. Host setup — **present, but there is no host**

Wii Party has no host/guest role split. The console on the shared TV is the only authority;
every setting is chosen in one linear, single-screen-at-a-time sequence by whoever holds
Player 1's remote. The documented order is: **pick mode → confirm contents and player
count → pick number of players → connect remotes → pick a Mii per player → pick CPU skill
(and rounds/difficulty where the mode has them) → Start.**

> "Choose the game you'd like to play. Once you've confirmed the game contents and number
> of players, press [A] to continue. For game progression, see P 11-13."
> — manual p. 6 (B), <https://www.notice-facile.com/en/manual/151454/nintendo+wii-party-_f>

> "**The Basics** — Choose the number of players and Mii characters in order using the
> steps below. When a game finishes, the rankings and scores are announced. **Number of
> Players** — The number of players that can be selected depends on the type of game being
> played and the number of Wii Remotes connected."
> — manual p. 7 (B), <https://www.manualslib.fr/manual/202416/Nintendo-Wii-Party.html?page=7>

> "Depending on the game, CPU Mii characters will be added automatically. You can choose
> the skill of these computer-controlled players. Also, for some games, you can choose the
> number of rounds or the difficulty level. Choose Start to begin the game."
> — manual pp. 6–7 (B), <https://www.notice-facile.com/en/manual/151454/nintendo+wii-party-_f>

Nintendo's own guide gives the same order and adds the skill vocabulary: "Tras elegir Mii
deberás escoger el nivel de habilidad de tus rivales en caso de jugar menos de cuatro
personas. En la mayoría de juegos podrás elegir entre Principiante, Intermedio o
Avanzado, aunque hay algunos que tienen bloqueados los dos últimos" [after choosing Miis
you choose the rivals' skill level; most games offer Beginner / Intermediate / Advanced,
some lock the top two] (A) —
<https://www.guiasnintendo.com/2a_WII/wii_party/wii_party_sp/explicacion.html>.

Two setup rules that shape the flow:

- **Party Games always field four characters**, regardless of humans: "En este modo de
  juego siempre tendrán que participar cuatro personajes. En caso de jugar menos de cuatro
  personas, la consola manejará aquellos Mii que no sean controlados por jugadores" (A) —
  <https://www.guiasnintendo.com/2a_WII/wii_party/wii_party_sp/juegos_fiesta.html>.
  So the player-count choice is really a human/CPU split, not a headcount.
- **Setup is once per session.** Nothing in the manual, Nintendo's guide, or the mode pages
  documents returning to setup mid-game except quitting (stage 12).

**Gap.** No source describes a "back" affordance inside setup; the sequence is presented as
forward-only with a confirm step before Start.

---

## 3. Party join — **present (as remote pairing), local only**

Joining is a physical act: add a Wii Remote, and the slot lights up. This is the whole
join flow.

> "**Adding Wii Remotes** — You can add one Wii Remote at a time by selecting Add Wii
> Remote. Press [1] and [2] at the same time on the Wii Remote you want to add. Once a Wii
> Remote is connected, the relative icon on the screen will light up. Note: You can also
> connect additional Wii Remotes from the HOME Menu."
> — manual p. 7 (B), <https://www.manualslib.fr/manual/202416/Nintendo-Wii-Party.html?page=7>

> "A connected Wii Remote will display **OK!**"
> — manual p. 7 (B), <https://handleidingkwijt.com/nintendo-wii-wii-party/?page=7>

Nintendo's guide describes the same step from the player's side, including the case where
there are not enough remotes: "Si quieren jugar más de una persona y no hay suficientes
mandos de Wii conectados, selecciona 'Añadir mandos' y luego pulsa simultáneamente los
botones 1 y 2 en aquellos mandos que quieras conectar" (A) —
<https://www.guiasnintendo.com/2a_WII/wii_party/wii_party_sp/explicacion.html>.

Properties of this join:

- **One remote at a time**, sequential, with per-slot visual confirmation ("icon … will
  light up", "OK!").
- **The remote count caps the player count**: "The number of players that can be selected
  depends on the type of game being played and the number of Wii Remotes connected" —
  manual p. 7 (B).
- **Remote count ≠ player count in some modes**: "Depending on the game mode, there will be
  times when the number of players differs from the number of Wii Remotes being used" —
  manual p. 4 (B), <https://www.manualslib.fr/manual/202416/Nintendo-Wii-Party.html?page=4>.
  Two extremes are documented: Animal Tracker "requires at least two Wii Remote controllers
  regardless of the number of players", and Hide 'n' Hunt "requires one to four Wii Remote
  controllers regardless of the number of players" (B) —
  <https://www.notice-facile.com/en/manual/482449/nintendo+wii-party-wii>.
- **Late connection, but not late joining.** The manual's note routes extra remotes through
  the console's HOME Menu, i.e. the system-level reconnect, and no source describes a new
  *player* being added to a running game.
- **No network join exists.** All documented joins are physical remotes on one console: the
  manual's join step is a radio pairing, its reconnection note is the console's HOME Menu,
  and the game's player range is 1–4 on one Wii (A) —
  <https://en.wikipedia.org/wiki/Wii_Party>.

**Gap.** Whether a remote connected mid-game can take over an *existing* player slot is not
documented. See stage 13.

---

## 4. Player creation / colour & accessory — **absent as creation; replaced by Mii selection**

There is **no avatar creation, no colour picker, and no accessory picker** in Wii Party. The
player selects a pre-existing Mii; the avatar is authored outside the game, in the console's
Mii Channel.

> "**Mii Selection** — Select the Mii you want to play with. You can choose a Mii saved to
> the Wii console or a guest Mii. Note: For information on how to add a Mii to your Wii
> console, please see the Wii Operations Manual."
> — manual p. 7 (B), <https://www.manualslib.fr/manual/202416/Nintendo-Wii-Party.html?page=7>

> "Después de elegir el número de jugadores que van a participar tendrás que elegir un Mii
> para cada uno de ellos. Podrás seleccionar cualquiera que tengas guardado en tu consola
> Wii, o elegir a un invitado predeterminado." [After choosing the number of players you
> choose a Mii for each of them; any Mii saved on your Wii, or a preset guest.] (A) —
> <https://www.guiasnintendo.com/2a_WII/wii_party/wii_party_sp/explicacion.html>

The documented setup sequence (mode → player count → remotes → Mii per player → CPU skill →
Start) contains **no colour step and no accessory step**; Nintendo's guide enumerates every
step and colours never appear. Identity is carried entirely by the Mii's face plus the
player's number:

- **Per-player colour is assigned by the game, not chosen.** In Derby Dash "Player 1 has a
  light brown horse, player 2 has a brown horse, player 3 has a dark brown horse, and
  player 4 has a white horse" (A) — <https://miiwiki.org/wiki/Derby_Dash>. Colours used
  inside modes (Swap Meet shirt colours, Balance Boat green/pink/yellow Miis) are game
  pieces, not player identity.
- **Guest Miis are second-class data.** "Los datos de un jugador sólo se guardarán si juega
  con un Mii procedente del Canal Mii. Si juega con un Mii invitado, los datos de juego no
  quedarán salvados, ya que solo será una especie de modo de demostración" [records are
  only saved for a Mii from the Mii Channel; a guest Mii saves nothing] (A) — same URL.

**Gap (deliberate absence).** No source documents any in-game recolouring, hat, or outfit
choice; the closest thing to customisation is which Mii you own. A product that wants
colour-as-identity must invent it, because Wii Party's model is face-as-identity.

---

## 5. Lobby & waiting — **absent**

Wii Party has **no lobby**. There is no room, no party code, no ready-up state, no list of
waiting players, and no chat. The flow goes: setup screens (stage 2–4) → Start → play. The
manual's setup page is titled "The Basics" and shows the player-count/Mii/remote steps as
the complete pre-game phase; no waiting screen is documented (B) —
<https://www.manualslib.fr/manual/202416/Nintendo-Wii-Party.html?page=7>.

The waiting states that *do* exist are short and instrumental, not a lobby:

1. **Per-remote confirmation while joining** — "Once a Wii Remote is connected, the relative
   icon on the screen will light up" / "will display OK!" (stage 3).
2. **Mii selection**, one player at a time, with no timer (stage 4).
3. **Turn waiting inside the board game** — non-active players watch the current player
   roll and move; the game alternates minigame → turn order → individual turns (stage 7).
4. **Physical waiting in House Party modes**, where the remote is not in anyone's hands:
   "In House Party mode Wii Remote controllers are placed on the floor or a table, or one
   Wii Remote is passed around among multiple players" — manual p. 4 (B),
   <https://www.manualslib.fr/manual/202416/Nintendo-Wii-Party.html?page=4>. Hide 'n' Hunt
   adds a timed hunt with a fixed hint cadence: "During the hunting phase, each Wii Remote
   will make a hint sound every 10 seconds" (B) —
   <https://handleidingkwijt.com/nintendo-wii-wii-party/?page=6>.

**Gap.** Because there is no lobby, there is also no leave-and-return behaviour for a player
between games; see stages 12–13. For a networked product this is the stage Wii Party gives
you no prior art for at all.

---

## 6. Game selection — **present, two paths**

**Path A, by mode.** The main menu groups modes into three styles plus a minigames section.
Party Phil states the taxonomy at boot: "there are three styles of games to choose from:
Party Games, Pair Games, and House Party games" (A) —
<https://tasvideos.org/Forum/Topics/23738?CurrentPage=1&Highlight=517700>. The same source
notes "Alongside these game styles in the main menu is the Minigames section".

| Category | Modes (A) — <https://miiwiki.org/wiki/Wii_Party> |
|---|---|
| Party Games (1–4) | Board Game Island, Globe Trot, Swap Meet (Mii of a Kind, PAL), Spin-Off, Bingo |
| Pair Games (1–2) | Friend Connection (2 humans only), Balance Boat, Match-Up |
| House Party (2–4) | Animal Tracker, Hide 'n' Hunt, Time Bomb, Word Bomb, Buddy Quiz, Quick Draw (JP/KR only) |
| Minigames (1–4) | Free Play, Battle, Solo, Challenge, Spot the Sneak (Rule Reversal, PAL) |

The mode tile advertises **both** the player count and the expected duration before you
commit: the guide pages print "N.º de jugadores. De 1 a 4" and "Duración. 45 minutos
aproximadamente" for Board Game Island (A) —
<https://www.guiasnintendo.com/2a_WII/wii_party/wii_party_sp/juegosfiesta_islaventura.html>;
a review describes the same affordance: "there's a time estimate in the corner of each
mode select" (C) —
<https://www.nintendolife.com/reviews/2010/10/wii_party_wii>.

**Path B, by recommendation ("Suggestions").** Phil runs a mode that asks for the party's
shape and returns a mode:

> "Inicialmente tendrás que seleccionar el número de personas que van a jugar (de 1 a 4).
> Luego deberás elegir los Mii correspondientes de cada jugador. … Finalmente, tendrás que
> escoger el tipo de juego que más te interesa: Corto o Largo." (A) —
> <https://www.guiasnintendo.com/2a_WII/wii_party/wii_party_sp/sugrencias.html>

A review independently describes it as "a Suggestion menu item that lets you enter how many
players you have and whether you want a short or long game" (C) —
<https://www.nintendolife.com/reviews/2010/10/wii_party_wii>.

**In-session selection.** Once a mode is running, the player mostly does not choose games; the
game does. Board Game Island "starts with every player … compet[ing] in a 4-player Minigame
which determines the order they will go" (A) —
<https://miiwiki.org/wiki/Board_Game_Island>; minigames in Free Play are chosen from the
list of 41 four-player, 5 one-vs-three, 11 one-vs-one and 22 pair minigames (A) —
<https://miiwiki.org/wiki/Free_Play>.

There is exactly one documented case of a *player* choosing a minigame mid-session, and it
is a catch-up grant rather than a preference: in Spin-Off, "After the 7th round, the player
in last place is able to choose the 4-player minigames, and additional minigame spaces appear
on the wheel" (A) — <https://miiwiki.org/wiki/Spin-Off>. That is the only per-round
selection right the game hands to a player, and it is given to the player who is losing.

**Gap.** The count of modes differs by source (Nintendo says 13; Wikipedia's lead says
"nine … divided between three categories" while enumerating fourteen; MiiWiki enumerates
5 + 3 + 6). Treat any specific total as regional-variant dependent.

---

## 7. Round intro / countdown — **present, but the gate is a confirm, not a countdown**

A round has a documented, fixed preamble.

1. **Rules/controls screen, with an explicit start gate.** "During each game, you'll also
   play several minigames. To learn the rules, view the Rules screen. To learn the controls,
   view the Controls screen. Choose Start to begin a minigame … [you] can also choose to
   practice each minigame if you'd like" — manual p. 6 (B),
   <https://handleidingkwijt.com/nintendo-wii-wii-party/?page=6>. The same page documents
   the first-play rule: the host explains, and from the second play "you can choose whether
   or not to hear the explanation. Press [A] to skip an explanation and start the game".
2. **A dedicated instruction screen with its own music.** The soundtrack list names
   "Minigames: Explanation — The song that plays during the instructions before every
   minigame" (A) — <https://miiwiki.org/wiki/Wii_Party>.
3. **Round-scoped consequences are announced in the preamble**, because they change how you
   play: in Board Game Island "Before the turn starts, everyone will compete in a 4-player
   Minigame which determines the order they will go (If there is a tie, a die roll decides
   the order.)" (A) — <https://miiwiki.org/wiki/Board_Game_Island>.

**Countdown: no numeric 3-2-1 is documented for Wii Party.** What the sources show instead
is a **false-start rule inside the minigame** — Flag Fracas: "Grab it first to win, but be
careful not to jump the gun. Do it twice, and it's a DQ" (A) —
<https://miiwiki.org/wiki/Free_Play>. That implies a start signal the game enforces, not a
countdown the players coordinate on. For contrast, the *sequel* Wii Party U adds a
per-player ready gate ("Alle Teilnehmer müssen zunächst signalisieren, dass sie bereit
sind … indem jeder Spieler gleichzeitig das Steuerkreuz … und 'Knopf 2' … drückt. Wenn alle
Mitspieler bereit sind, startet der Countdown des Spiels") (A) —
<https://www.nintendo.com/de-de/Support/Wii-U/Spiele-Tipps/Wii-Party-U/Wii-Party-U-874263.html>.
That ready-check is **Wii Party U, not Wii Party**; do not attribute it to the 2010 game.

**Gap.** No source gives the countdown's length, whether the countdown can be cancelled, or
what happens to the round if a remote drops between instruction and start (stage 13).

---

## 8. In-round controls — **present, uniform shell, per-minigame body**

The control model is one remote per player, no attachments, and an orientation that changes
per minigame. From the manual's Controls page:

> "Wii Party is played using the Wii Remote controller. If two or more people are playing,
> please connect an additional Wii Remote for each player. Note: Depending on the game mode,
> there will be times when the number of players differs from the number of Wii Remotes
> being used. **Holding the Wii Remote** — Hold the Wii Remote as shown. **Holding the Wii
> Remote Sideways** — Some games require the Wii Remote to be held sideways as shown."
> — manual p. 4 (B), <https://www.manualslib.fr/manual/202416/Nintendo-Wii-Party.html?page=4>

Each minigame then teaches its own verb on the instruction screen, in one sentence, with
the orientation stated explicitly. Two examples of that prompt text:

- "Hold the Wii Remote vertically and swing the Wii Remote to boost." — Derby Dash (A),
  <https://miiwiki.org/wiki/Derby_Dash>.
- "Grab the rope, swing back and forth to build up your momentum, and let go to sling as far
  as you can!" — Rope Sling (A), <https://miiwiki.org/wiki/Free_Play>.

The board layer adds its own small control vocabulary: dice roll, bonus die roll, and
"the player who gets two of the same number ('Doubles') … get[s] to roll another die" (A) —
<https://miiwiki.org/wiki/Board_Game_Island>.

**Pause is the universal escape hatch**, and it is also where substitution and exit live:

> "**Pause Menu** — You can pause a game or minigame by pressing [button] to access the pause
> menu. You can then continue the game by pressing [it] again or choose another option.
> **Continue** — Return to the game. **Restart** — Start the game over from the beginning.
> This is only available on the pause menu of Party Games. **Autoplay** — You can change a
> Mii that started as a human player to CPU control (except Player 1). You can also revert a
> Mii from CPU control if it started as a human player. **Quit** — End the game and return
> to the main menu. When you quit a game, your progress will not be saved, so please be
> careful."
> — manual p. 8 (B), <https://www.manualslib.fr/manual/202416/Nintendo-Wii-Party.html?page=8>
> (same text: <https://www.yumpu.com/fr/document/view/443078/wwwnintendocom/8>)

**Gap.** The manual does not print the pause button glyph in the OCR, and no source
documents per-mode control remapping or an accessibility alternative to motion input.

---

## 9. Round end — **present**

Round end is a three-beat sequence, and the *first* beat feeds the next round rather than
just scoring it:

1. **Minigame placing is announced** and converted into a turn-order and dice advantage.
   Board Game Island: "1st place gets a golden die (contains numbers 1-6), 2nd place gets a
   silver die (contains numbers 1-3), 3rd place gets a bronze die (contains numbers 1-2),
   and 4th place doesn't get a bonus die" (A) —
   <https://miiwiki.org/wiki/Board_Game_Island>. A review describes the same loop:
   "playing minigames for turn placement between each round. Winners are awarded special
   gold, silver or bronze dice for their next turn" (C) —
   <https://www.nintendolife.com/reviews/2010/10/wii_party_wii>.
2. **Board resolution**, i.e. each landed space fires once: "Different spaces in this mode
   cause an effect to happen to the player. But they aren't cumulative, meaning that if the
   player gets launched to another space, that space will be unaffected" (A) — same URL.
3. **Next player.** With four characters and one shared screen, the game hands the turn on
   automatically; no source documents a "press to pass" confirmation for the board layer.

Round-window bookkeeping exists in the non-distance modes. Spin-Off runs in fixed round
windows — "After the 4th, 7th, and 10th round, the wheel changes. … After 10 rounds, the
game goes into overtime / extra time" (A) — <https://miiwiki.org/wiki/Spin-Off> — and its
final standings are presented as a chart rather than a list: "The end of Spin Off shows a
line graph with each player's performance charted, like Mario Party" (C) —
<https://web.archive.org/web/20200505185620/https://tvtropes.org/pmwiki/pmwiki.php/VideoGame/WiiParty>.

**Gap.** Whether the minigame results screen requires a button press to advance, or is
timed, is not documented in any source found.

---

## 10. Results / scoreboard — **present**

Two levels of results are documented.

**Per-game final results**, in a fixed two-step order with the player advancing each step:

> "**Scores and Rankings** — When a game is finished, the scores are announced. Press [A] to
> proceed and see the overall rankings."
> — manual p. 8 (B), <https://www.manualslib.fr/manual/202416/Nintendo-Wii-Party.html?page=8>

**A per-mode presentation of the same data.** Spin-Off ends with a chart rather than a
table: "The end of Spin Off shows a line graph with each player's performance charted, like
Mario Party" (C) — <https://web.archive.org/web/20200505185620/https://tvtropes.org/pmwiki/pmwiki.php/VideoGame/WiiParty>.
Board Game Island ends on a victory screen (the wiki notes "If a player wins while the
volcano is still active, the island will go back to normal on the victory screen") (A) —
<https://miiwiki.org/wiki/Board_Game_Island>.

The results screen is **mode-specific in tone as well as layout**: Spin-Off "shows the player
in last with a sad face at the results screen", which the wiki flags as unlike most Party
Games (A) — <https://miiwiki.org/wiki/Spin-Off>. So the end-of-game surface is not one
shared component with a data slot; each mode renders its own.

**Persistence is separate from presentation**: results are only written for console Miis
(stage 4), and are browsable later from a Records menu — "Aquí podrás ver los récords y
puntuaciones obtenidas en los distintos juegos y minijuegos" (A) —
<https://www.guiasnintendo.com/2a_WII/wii_party/wii_party_sp/records.html>.

**Gap.** No source states whether the rankings screen can be skipped or revisited, or
whether it is shown at all when the session is quit early.

---

## 11. Next round / Play again — **present, two different mechanisms**

Inside a mode, "next round" is automatic and has no UI: rounds follow the mode's own
structure (Board Game Island: minigame → turn order → four turns → repeat; Spin-Off: ten
rounds then overtime; Globe Trot: ten rounds then overtime).

After the final results, the game offers a menu whose items are documented but whose
labels are lost to OCR:

> "**Finishing a Game** — Once the scores and rankings are announced, a menu like the one
> shown to the right is displayed. You can choose to replay the same game or return to the
> main menu. If you started the game from Suggestions, you can also see another suggestion
> [P 10]. Note: The menu displayed may differ depending on the situation."
> — manual p. 8 (B), <https://www.notice-facile.com/en/manual/482449/nintendo+wii-party-wii>

So "play again" has three documented variants, and the third is contextual: replay the same
mode, return to the main menu, or — only if you arrived via Suggestions — get a different
suggestion. The manual explicitly warns the menu is not identical in every mode.

**Mid-game restart is a different control**: pause → Restart, "only available on the pause
menu of Party Games", starts "the game over from the beginning" (B), manual p. 8.

**Gap.** The manual does not say whether replaying re-runs setup (same players/Miis) or
returns to mode selection; "replay the same game" implies the roster is retained.

---

## 12. End of night — **present as "game over → menu"; there is no session concept**

Wii Party has no night, session, or party-session object. Each mode is a self-contained
sitting with a printed expected length — Board Game Island "Duración. 45 minutos
aproximadamente" (A) —
<https://www.guiasnintendo.com/2a_WII/wii_party/wii_party_sp/juegosfiesta_islaventura.html>;
the manual's tile strip shows the same convention as "1-4 players / 45 min", "1-4 players /
30-45 min", "1-4 players / 15 min" (B) —
<https://handleidingkwijt.com/nintendo-wii-wii-party/?page=6>.

The night therefore ends in one of three documented ways:

1. **Win condition reached** (first to the top of the island and past the final challenge;
   most souvenir photos; first bingo line; most medals after overtime) → scores → rankings →
   the stage-11 menu.
2. **Quit from the pause menu** → "End the game and return to the main menu. When you quit a
   game, your progress will not be saved, so please be careful" (B), manual p. 8.
3. **Console off** — nothing to save beyond the records file already written.

What survives the night: the save file (created on first run, two blocks) and the Records
entries for modes and minigames (A) —
<https://www.guiasnintendo.com/2a_WII/wii_party/wii_party_sp/records.html>. Nothing else —
no party history, no per-night summary, no "who won the most games tonight" roll-up — is
documented in the manual, Nintendo's guide, or the wiki mode pages.

**Gap.** Whether quitting mid-game offers any confirmation step is not documented; the
manual only warns that progress is lost.

---

## 13. Re-entry after a drop — **absent as re-entry; substituted by Autoplay**

Wii Party has **no re-join flow**. Once Start is pressed the roster is fixed, and the game
does not describe a way for a player who left to come back into the same game. What exists
is a *substitution* mechanism and a *link-recovery* instruction.

**Substitution (the documented answer to a player who walks away):**

> "**Autoplay** — You can change a Mii that started as a human player to CPU control (except
> Player 1). You can also revert a Mii from CPU control if it started as a human player."
> — manual p. 8 (B), <https://www.manualslib.fr/manual/202416/Nintendo-Wii-Party.html?page=8>

A contemporaneous review describes the same feature as the intended use case: "the ability
for the game to take over if one of the players gets tired or fed up … Simply pause the
game and select CPU for the missing player and you can carry on playing seamlessly"
(C — search-index excerpt; the two hosts carrying this sentence did not serve the article
body to a direct fetch) — <https://geekdad.com/2010/09/wii-party-game-of-the-year/amp/>
(the sentence also appears at <https://gamepeople.co.uk/family_wii_wiiparty.html>).

Two hard limits follow directly from the quote:

- **Player 1 cannot be handed to the CPU.** A Player 1 drop has no in-game recovery other
  than Restart or Quit (both on the same pause menu).
- **Reverting is allowed** ("You can also revert a Mii from CPU control"), so a returning
  player can take their Mii back — this is the closest thing the game has to re-entry, and
  it is a pause-menu transaction, not a join flow.

**Link recovery (a dropped remote, not a dropped player):** the game's own guidance is to
move closer and press a button —

> "If the Wii Remote controllers are hidden too far from the Wii console, communications with
> the Wii Remote could be interrupted, which may affect game play. If this occurs, bring the
> Wii Remote controllers closer to the Wii console and press any button."
> — manual, Hide 'n' Hunt notes (B), <https://www.notice-facile.com/en/manual/482449/nintendo+wii-party-wii>

…and the manual's join note routes reconnection through the console: "You can also connect
additional Wii Remotes from the HOME Menu" (B), manual p. 7. At platform level the Wii
raises a "Communications with the Wii Remote have been interrupted" dialog — that exact
string is the title of a Dolphin emulator issue (URL checked, issue body not read; grade C)
<https://bugs.dolphin-emu.org/issues/4339>. **No source found attributes a specific
paused-reconnect overlay to Wii Party**, so the on-screen treatment of a mid-round
disconnect is recorded here as unverified rather than described.

**Gap (explicit).** No evidence for: a pause-and-wait reconnect prompt inside Wii Party; a
timeout after which a disconnected player is dropped; whether a dropped player's turn is
auto-played or blocked; whether the game rewinds a minigame after a disconnect.

---

## 14. Cross-cutting: what Wii Party does not have

Useful as a checklist of stages where this game provides no prior art:

| Missing thing | Stage | Evidence |
|---|---|---|
| Lobby / room / ready-up / party code | 5 | No such screen in manual pp. 5–8 or Nintendo's guide (B/A) |
| Colour or accessory authoring | 4 | Setup steps enumerated with no colour step (A/B) |
| Character creation in-game | 4 | "choose a Mii saved to the Wii console or a guest Mii" (B) |
| Join-in-progress for a new player | 3, 13 | Roster fixed at Start; only Autoplay substitution (B) |
| Player-1 substitution | 13 | "except Player 1" (B) |
| Reconnect prompt attributable to the game | 13 | Not found (section 13) |
| Online play of any kind | 3, 5 | All joins are physical remotes on one console (A) |
| Session/night object, cross-game scoring | 12 | Only per-mode records exist (A) |
| Skip for health-and-safety / strap screens | 1 | Not documented (B) |

---

## 15. Stages with no evidence found, and open questions

**No evidence found:** no stage of the 13 came back empty-handed, but three are unevidenced
*in the specific respect the brief asks about*:

1. **Stage 13, in-game handling of a dropped controller.** No source describes a Wii Party
   pause/reconnect overlay, a timeout, or what happens to the in-progress round. Everything
   found is either substitution (Autoplay), generic link advice, or platform-level dialogs.
2. **Stage 5, waiting.** No source describes any pre-game waiting surface beyond the
   per-remote "OK!" confirmation and Mii selection; there is no lobby to observe.
3. **Stage 7, countdown.** No source gives a countdown for Wii Party; only the
   "Choose Start"/instruction gate and per-minigame false-start rules are documented. The
   ready-check-plus-countdown belongs to Wii Party U.

**Other open questions** (documented absences, not gaps in my search): whether replay
retains the roster (11); whether quitting asks for confirmation (12); whether the rankings
screen is skippable (10); whether setup has a back affordance (2); how mid-game remote
reconnection affects an existing player slot (3).

---

## 16. Sources

**Primary — manual (Nintendo, 2010; English OCR, read via search index — grade B)**
- Manual p. 4, Controls / holding sideways / House Party placement:
  <https://www.manualslib.fr/manual/202416/Nintendo-Wii-Party.html?page=4>
- Manual p. 5, Starting the Game / first-time save file:
  <https://www.manualslib.fr/manual/202416/Nintendo-Wii-Party.html?page=5>
- Manual p. 6, rules explanation, rules/controls screens, mode tiles, Suggestions link:
  <https://handleidingkwijt.com/nintendo-wii-wii-party/?page=6> and
  <https://www.notice-facile.com/en/manual/151454/nintendo+wii-party-_f>
- Manual p. 7, The Basics / number of players / adding remotes / Mii selection / "OK!":
  <https://www.manualslib.fr/manual/202416/Nintendo-Wii-Party.html?page=7> and
  <https://handleidingkwijt.com/nintendo-wii-wii-party/?page=7>
- Manual p. 8, Pause Menu / Scores and Rankings / Finishing a Game:
  <https://www.manualslib.fr/manual/202416/Nintendo-Wii-Party.html?page=8> and
  <https://www.yumpu.com/fr/document/view/443078/wwwnintendocom/8>
- Manual mode notes (Animal Tracker, Hide 'n' Hunt incl. link-interruption advice):
  <https://www.notice-facile.com/en/manual/482449/nintendo+wii-party-wii>

**Primary — Nintendo**
- Guía Wii Party, general explanation (setup order, remotes, Miis, skill):
  <https://www.guiasnintendo.com/2a_WII/wii_party/wii_party_sp/explicacion.html>
- Guía, Party Games (always four characters; CPU fills):
  <https://www.guiasnintendo.com/2a_WII/wii_party/wii_party_sp/juegos_fiesta.html>
- Guía, Board Game Island (45 min, 73 spaces, round opening minigame, dice):
  <https://www.guiasnintendo.com/2a_WII/wii_party/wii_party_sp/juegosfiesta_islaventura.html>
- Guía, Sugerencias (players → Miis → short/long):
  <https://www.guiasnintendo.com/2a_WII/wii_party/wii_party_sp/sugrencias.html>
- Guía, Récords: <https://www.guiasnintendo.com/2a_WII/wii_party/wii_party_sp/records.html>
- Nintendo UK, 13 modes / up to four remotes / release 8 Oct 2010:
  <https://www.nintendo.com/en-gb/News/2010/Make-your-Wii-the-life-and-soul-of-the-party--252279.html>
  and <https://www.nintendo.com/en-gb/News/2010/Wii-Party-comes-bundled-with-Wii-Remote--252651.html>
- Nintendo support, Wii Party U ready-check and countdown (sequel only):
  <https://www.nintendo.com/de-de/Support/Wii-U/Spiele-Tipps/Wii-Party-U/Wii-Party-U-874263.html>

**Secondary — reference and community (grade A unless noted)**
- Wikipedia, release dates and mode overview: <https://en.wikipedia.org/wiki/Wii_Party>
- MiiWiki, mode list and player counts / "Minigames: Explanation" track:
  <https://miiwiki.org/wiki/Wii_Party>
- MiiWiki, Party Phil (host role, Suggestions): <https://miiwiki.org/wiki/Party_Phil>
- MiiWiki, Board Game Island (round opening minigame, bonus dice, spaces, victory screen):
  <https://miiwiki.org/wiki/Board_Game_Island>
- MiiWiki, Spin-Off (round windows, overtime, last-place minigame choice, results screen):
  <https://miiwiki.org/wiki/Spin-Off>
- MiiWiki, Free Play (minigame counts, instruction text, player-select caption):
  <https://miiwiki.org/wiki/Free_Play>
- MiiWiki, Derby Dash (control prompt, per-player horse colours):
  <https://miiwiki.org/wiki/Derby_Dash>
- TASVideos #7829 submission (boot sequence, three mode styles, variable load points):
  <https://tasvideos.org/Forum/Topics/23738?CurrentPage=1&Highlight=517700>
- TV Tropes, Wii Party (Spin-Off end-of-game line graph), Wayback capture:
  <https://web.archive.org/web/20200505185620/https://tvtropes.org/pmwiki/pmwiki.php/VideoGame/WiiParty>

**Secondary — reviews (grade C)**
- Nintendo Life, 2 Oct 2010 (time estimate per mode, Suggestions, AI fill, bonus dice):
  <https://www.nintendolife.com/reviews/2010/10/wii_party_wii>
- IGN, 3 Oct 2010: <https://www.ign.com/articles/2010/10/03/wii-party-review>
- GeekDad, 20 Sep 2010 (CPU substitution for a missing player):
  <https://geekdad.com/2010/09/wii-party-game-of-the-year/amp/>
- Wii Sports Wiki, Party Phil (secondary character detail): <https://wiisports.fandom.com/wiki/Party_Phil>
