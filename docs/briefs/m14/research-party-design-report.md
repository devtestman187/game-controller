# Research: chaos, catch-up and awards in family party games (for M14)

Job: research for Thumb Party M14 (chaos events, star power-ups, party-night scoring, end-of-night awards).
Filed as `report.md` per the job instructions; the brief named `docs/briefs/m14/research-party-design-report.md`.
All pages fetched 8 Nov 2026 with `fetch.dart`. Confidence tags: **[high]** = primary source or first-hand designer/standards document; **[med]** = good secondary source; **[low]** = community post, wiki, or unverifiable.

Note on safety: no fetched page tried to give me instructions, and I found nothing suspicious.

---

## 1. Catch-up ("rubber band") mechanics

There are two distinct families, and the sources treat them very differently:

- **Hidden, dynamic adjustment of AI/speed** (classic rubber banding). Adam Saltsman's analysis: Mario Kart limits the gap between first and last by changing CPU speed (slowing dramatically if you are far back, speeding up if you lead) and by a "sliding scale" of power-ups by position; the last-place racer has a much better chance of a race-changing item. — https://www.gamedeveloper.com/design/game-changers-dynamic-difficulty (7 May 2009) **[high]**
- **Benefits of that system** (Saltsman): "almost anyone can win at any point in the race", the pack stays near you so combat keeps pace high, and it is cheap to implement and test. **[high]** (same URL)
- **Costs** (Saltsman): "easily exploitable and frequently punishes skillful play"; in Mario Kart Wii, being first at the start of the final lap all but guarantees a blue shell, so the optimal strategy is to *not* lead — which he calls nonsensical. **[high]** (same URL)
- **What makes hidden rubber banding feel like cheating**: Dave Mark's examples are speed-matching so obvious that rivals appear to teleport, or rivals stopping dead when you stop dead; both read as fake. He also notes Split/Second's case, where the design *requires* you not to be in front (you can only trigger the game's core "power plays" from behind), which a reviewer called unfair. — https://www.gamedeveloper.com/design/rubber-banding-as-a-design-requirement (2 Jun 2010) **[med]**
- **Designer's rule of thumb (Soren Johnson, Civilization IV lead)**: invisible rubber banding "either dulls their sense of accomplishment when they win or raises suspicions when they lose"; *explicit* self-balancing (Mario Kart's position-based item odds, the robber in Settlers of Catan) "don't feel like cheating because the game is so explicit about how the system works", and players know the same bonus applies to them when they fall behind. Conclusion: transparency is the antidote to suspicion; "when the question is one of fairness, the player is always right." — http://www.designer-notes.com/game-developer-column-7-our-cheain-hearts/ (posted 1 Sep 2009; first published Game Developer, May 2009) **[high]**
- **Catch-up in a family party game, from a board-game designer**: Mario Party is "a casual game through and through" and should never let players lose hope, so it carries several catch-ups "even if that might irritate skill players": lucky coin bonuses on event spaces, random events that hand out coins, stealing a star from the leader at Boo, and being paired with a strong player in 2v2 minigames. Crucially he pairs this with a second rule: still reward smart play (most minigame wins earns the Minigame bonus star). — https://brandonthegamedev.com/5-lessons-from-mario-party-for-board-game-developers/ (12 Dec 2020 / 4 Jan 2021) **[med]**
- **Nintendo's own rationale for the blue shell**: introduced in Mario Kart 64 to keep players together because of N64 limits — the director is quoted as wanting "a race where everyone was in it until the end"; another director said removing it made the game feel like something was missing. The shell only drops for players in lowly positions (varies by game; in Mario Kart Wii it is 4th–8th, with the best odds in 6th, ~7.5%), and it always targets the current leader. — https://www.mariowiki.com/Spiny_Shell_(blue) (wiki, undated) **[med]** for the item rules, **[low]** for the interview paraphrase (quotes second-hand via Kotaku 2011 / Eurogamer 2017).
- **Players do complain when they can feel it**: Mario Kart World shipped with aggressive CPU rubber banding; the 1.2.0 update (29 Jul 2025) reportedly dialled CPU aggression back across modes except Battle "creating breathing room for newcomers and kids", and added a "No COM" toggle for local play. — https://www.nintendoreporters.com/en/news/nintendo-switch-2/mario-kart-world-120-update-brings-fan-requested-fixes-new-rules-and-smoother-races/ (9 Aug 2025) **[med]** — secondary report; I did not read Nintendo's own patch notes.

**What "feels robbed" looks like, in these sources:** the leader is punished for playing well; the trailing player's comeback looks unearned because they did nothing; the aid is visible as speed-matching or teleporting; the aid is secret and only discovered when it hurts you. What reads as fair: rules that are stated, aids that apply to everyone by position, and rewards that are announced before they matter.

---

## 2. Random events and chaos

- **Mario Party's chaos sits on a visible, opt-in space.** "? / Happening / Event" spaces "activate special board-specific events that can change the outcome of a turn or even a whole game", and the events "can be positive or negative". Landing is the player's own move, so the event is caused by a choice, not a timer. Since Super Mario Party the character who lands shows a shocked expression before the event fires — a small pre-event beat. — https://www.mariowiki.com/Event_Space (wiki, undated) **[med]**
- **Hidden single events are the risky kind.** Soren Johnson: "single events based on hidden mechanics need to be handled with great care", and sports-game developers must be "very sensitive to how often a random event hurts the player" (fumble, steal, ill-timed error) because "the dangers of perceived unfairness are simply too great". His remedy is to bias lucky breaks toward the human and explain any balancing that remains. — http://www.designer-notes.com/game-developer-column-7-our-cheain-hearts/ (Sep 2009) **[high]**
- **Warning is the standard fix for unavoidable randomness.** In the RPG random-encounter case, the writer argues that "output randomness of movement" feels like the enemies are getting one over on you; the fix is a visible rising-risk indicator (zones that grow red, or a risk meter) so players can prepare, take a safer route, or trigger the fight themselves on good terms. — https://www.gamedeveloper.com/design/watch-your-step-fixing-random-encounters-with-area-tracking (23 Jan 2020) **[med]**
- **Mario Kart's blue shell is telegraphed on three channels**: a launch siren, an "incoming item" warning sound from Mario Kart 7 onward, and a flight time during which the target can still dodge (Mushroom), block it (Super Horn) or lose the lead so it retargets. — https://www.mariowiki.com/Spiny_Shell_(blue) **[med]**
- **Frequency / duration**: I found no published guideline giving numbers for party games. The nearest concrete facts are structural: Mario Party's chaos is tied to one space per turn, and its end-of-night awards scale with session length (2 bonus stars by default, 3 if the game reaches 20 turns in Super Mario Party or 30 turns in Superstars/Jamboree). — https://www.mariowiki.com/Bonus_Star **[med]** — treat "one chaos event every N rounds" as inference, not sourced.
- **A chaos/difficulty setting is recommended practice**: "Offer a wide choice of difficulty levels", "Allow gameplay to be fine-tuned by exposing as many variables as possible", "Avoid any sudden unexpected movement or events" (advanced), and "Include an option to adjust the game speed". — https://gameaccessibilityguidelines.com/full-list/ (undated, accessed 8 Nov 2026) **[high]** (industry-standard guideline set)
- **Precedent for a "no surprises" rules mode**: Mario Party Superstars added an option to use only the three classic bonus stars regardless of turn count; Jamboree's "Pro Rules" fixes games at 12 turns, one bonus star, and *announces which star it is at the start of the game*. — https://www.mariowiki.com/Bonus_Star **[med]**
- **Children and unpredictability**: nothing found that says chaos is bad for 8-year-olds; the child-UX sources instead stress that the goal and the consequences must be comprehensible (see §5).

---

## 3. End-of-night and bonus awards

- **How many**: most Mario Party games award three bonus stars; from Mario Party 7 there are six possible types but only three are given, chosen at random per game. In Super Mario Party, Superstars and Jamboree the default is two, rising to three for 20+ or 30+ turn games. — https://www.mariowiki.com/Bonus_Star (wiki, undated) **[med]**
- **Awards can overturn the result**: the bonus stars are "last-minute bonuses", and "the player who appears to be in first place at the end of the final turn may ultimately lose if an opponent receives enough Bonus Stars to surpass them". — same URL **[med]**
- **Ties**: when players tie for a bonus star, all tied players receive one (in Battle Royale / Tag Team modes nobody does). — same URL **[med]**
- **What the awards reward**: a mix of skill (Minigame star = most minigame coins/wins), participation (Happening star = most event spaces), and *anti-skill* categories such as Slowpoke (lowest dice total), Unlucky/Misfortune (most red spaces) and Doormat (stomped on most). This is how a child who played badly can still come away with something. — same URL **[med]**
- **Reveal**: each star has been given its own distinct look since Mario Party 5, and the end-of-game sequence hands them out one at a time as a ceremony (the announcer line is "these Bonus Stars come to you"), so each is a beat of its own rather than a single score dump. — same URL **[med]** (paraphrase of the page's descriptions, not a frame-by-frame account)
- **When awards decide the winner, predictability is what makes it acceptable**: with the original three classic stars, players can guess who is likely to get each one, so they are "usually not surprising" and "feel fair, even on the 10-20% of time where you're caught off guard". Semi-opaque end scoring is fine if it does not appear to come from nowhere. — https://brandonthegamedev.com/5-lessons-from-mario-party-for-board-game-developers/ (Dec 2020) **[med]**
- **Players do push back on randomness**: a long-running Mario Party Superstars thread is titled as a wish that bonus stars be revealed at the start of the game "or are not random", and there is a joke page with hundreds of followers devoted to losing to three bonus stars. — https://gamefaqs.gamespot.com/boards/323655-mario-party-superstars/79519269 and https://www.facebook.com/3BonusStars/ (both undated; GameFAQs returned 403 to me, so I have only the title/snippet) **[low]**
- **Design implication supported by the above**: announcing the award categories before the night starts (as Jamboree's Pro Rules do for its single star) converts an award from "the game robbed me" into "I was playing for that all along".

---

## 4. Points and scoreboards for mixed-age groups

- **Visible running score plus hidden end bonuses is a proven combination**, provided the bonuses are guessable (see §3). Mario Party keeps stars/coins public all game and adds unknown-to-casual-players but trackable bonus stars at the end. — https://brandonthegamedev.com/5-lessons-from-mario-party-for-board-game-developers/ **[med]**
- **A "last round worth more" precedent** in a party game: Quiplash runs three rounds; the final round puts every player on one shared prompt and gives each player three votes, so the last round carries more weight. — https://mechanicsofmagic.com/2022/04/22/judging-game-quiplash/ (22 Apr 2022, Stanford CS247G student writing) **[low-med]**; a Steam community guide states Quiplash 3's final round ("Thriplash") is worth triple points — https://steamcommunity.com/sharedfiles/filedetails/?id=3735560271 (undated, community) **[low]**. I could not confirm the multiplier from Jackbox's own rules text.
- **Close scores are not automatically good** — a useful counter-argument for rubber banding in the scoreboard: if a game *always* produces tight scores, players learn that losing by a lot means they were stupid or that the game is patronising them; the writer prefers games where choices matter over games engineered to end within a few points. — https://www.universityxp.com/news/2023/11/28/the-runaway-leader-problem (Matt Pioch, orig. 29 Jul 2023; reprinted 28 Nov 2023) **[med]**
- **Keep losing players engaged by giving them live goals, not just points**: the same Mario Party catch-up list (a coin windfall, a star steal, a strong teammate) works because each is a *thing you can do this turn*, not a silent handicap. — https://brandonthegamedev.com/5-lessons-from-mario-party-for-board-game-developers/ **[med]**
- **Scoreboard legibility for young readers**: no source specific to children's scoreboards was found; the applicable child-UX rules are that a bare number without an icon or label confuses 7-year-olds (a test child kept asking what the number "2" meant), and that essential information should not be conveyed by text alone. — https://www.nngroup.com/articles/kids-cognition/ (16 Dec 2018) and https://gameaccessibilityguidelines.com/full-list/ **[high]**

---

## 5. Designing for children around 8

- **Motor skills**: children aged 6–8 can manage simple clicks and keyboard use; dragging, scrolling and small mouse targets are hard; kids under 9 generally prefer a trackpad to a mouse; more advanced interactions become possible around 9, and adult-level input around 11. Recommendation for young children's touch targets: about 2 cm × 2 cm (four times the 1 cm adult size). — https://www.nngroup.com/articles/children-ux-physical-development/ (Feifei Liu, 8 Jul 2018) **[high]**
- **Cognition**: state the goal *and* how to reach it; tailor wording to the child's level; use their prior knowledge; reduce load and prevent errors; keep instructions clear but not over-prescriptive, because children take instructions literally (a 7-year-old switched from trackpad to mouse because the text said "use the mouse", got frustrated and left). Children's working memory is smaller than adults', and their theory of mind is still developing, so feedback needs to be explicit and exaggerated rather than subtle. — https://www.nngroup.com/articles/kids-cognition/ (16 Dec 2018) **[high]**
- The same article frames 7–11 as Piaget's concrete-operational stage: reasoning works on concrete, visible things rather than abstractions, and cognitive flexibility/executive function are still immature — which argues for concrete icons, points shown as objects, and rules that can be re-read on screen. — same URL **[high]**
- **Reading level**: 7–9 year olds are "emerging readers" still on first chapter books, so UI copy should assume very short, common words. — https://www.oxfordowl.co.uk/for-home/summer/summer-reading-age-7-9/ (undated) **[med]**; corroborated by the accessibility guideline "Use simple clear language" — https://gameaccessibilityguidelines.com/full-list/ **[high]**. (I did not find a formal grade-level standard applied to game UI.)
- **Time pressure**: "Do not make precise timing essential to gameplay — offer alternatives, actions that can be carried out while paused, or a skip mechanism"; "Allow players to progress through text prompts at their own pace"; "Include an option to adjust the game speed". — https://gameaccessibilityguidelines.com/full-list/ **[high]**
- **Cooperative vs competitive**: a six-week study with 4–6 year olds (N=65, groups of four, cooperative vs competitive board games) found the game type made no difference: both produced equal cooperative and prosocial behaviour after play. So competition is not inherently bad for young children; the framing around it is what matters. — Eriksson et al., Scandinavian Journal of Psychology (2021), abstract via https://www.semanticscholar.org/paper/ddc61f97450edbfc8d19589c46ff5bad24a8fefb and https://www.researchgate.net/profile/Malin-Eriksson-4 **[med]** (full text paywalled; I read the abstract only)
- **Losing gracefully**: no strong primary source found (see Not confirmed). The transferable design point from the party-game sources is that the losing child should always have one thing still to win — a bonus category, a next-round comeback, a star — rather than one final ranking.

---

## 6. Accessibility and comfort

**Flashing / dark screens ("lights out")**

- WCAG 2.3.1 (Level A): content must not flash more than three times in any one second, or must stay below the general and red flash thresholds; people are more sensitive to saturated red flashing. — https://www.w3.org/WAI/WCAG22/Understanding/three-flashes-or-below-threshold.html (WCAG 2.2 Understanding doc; the standard itself is W3C Recommendation, Oct 2023 — date not re-verified on this page) **[high]**
- A hazard needs all three at once: **area** (over 25% of the screen, or 25% of any 10° field of view for WCAG), **intensity** (about 0.1 relative-luminance change, or saturated-red change), and **rate** (more than 3 flashes in any one second). Ofcom and ITU-R additionally treat flashes whose leading edges are more than 334 ms apart as safe. Broadcast tools include HardingFPA and the free PEAT. Historical harm: the 1997 Pokémon broadcast put 685 children in hospital. — https://pmc.ncbi.nlm.nih.gov/articles/PMC12249941/ (Univers. Access Hum. Comput. Interact., 2025; published 3 Jun 2025) **[high]**
- Practical reading for a TV screen: a full-screen "lights out" is a large-area luminance change, so it counts against the 25%-of-screen rule; a small-area effect, a slow fade, or a lampshaded dim (not a hard cut to black) stays clear of it. **[my inference from the thresholds above — not a sourced rule]**
- Guideline-level: "Avoid flickering images and repetitive patterns" (basic) and "Provide an option to turn off / hide background movement" (intermediate). — https://gameaccessibilityguidelines.com/full-list/ **[high]**

**Motion**

- WCAG 2.3.3 (Level AAA): motion animation triggered by interaction can be disabled unless it is essential; vestibular reactions include dizziness, nausea and migraine; honour the OS reduce-motion setting. — https://www.w3.org/WAI/WCAG22/Understanding/animation-from-interactions.html **[high]**
- Games guideline: "Avoid any sudden unexpected movement or events" (advanced) — directly relevant to a cat that bolts across the screen. — https://gameaccessibilityguidelines.com/full-list/ **[high]**

**Colour**

- "Ensure no essential information is conveyed by a fixed colour alone" (basic, vision); also high contrast between text/UI and background, adjustable contrast, and a choice of cursor/pointer colour. — https://gameaccessibilityguidelines.com/full-list/ **[high]**
- For four players on a shared screen, this means a shape/pattern/icon per player alongside colour (I did not find a primary source for a specific colour-blind palette that I could read; the Okabe–Ito page is image/PDF only — see Not confirmed).

**Sound**

- "Ensure no essential information is conveyed by sounds alone" (basic); "Ensure sound / music choices for each key objects / events are distinct from each other"; separate volume controls for effects, speech and music; "Ensure that all important supplementary information … conveyed by audio is replicated in text / visuals". — https://gameaccessibilityguidelines.com/full-list/ **[high]**
- For the cat: a distinct, repeated sound cue plus a visual marker, so a child who cannot hear the cue still gets the warning. **[my inference]**

**Cognitive / reading**

- "Use simple clear language", "Allow players to progress through text prompts at their own pace", "Highlight important words", "Include a means of practicing without failure", "Indicate / allow reminder of current objectives during gameplay". — https://gameaccessibilityguidelines.com/full-list/ **[high]**

---

## Not confirmed

1. **Any numeric guidance on chaos-event frequency, warning length, or duration.** No designer source found that gives "warn N seconds ahead, once every X rounds". Everything in §2 about timing is inference from Mario Party's structure and from the general telegraphing literature.
2. **The Okabe–Ito colour-blind palette's primary source.** The canonical page is image/PDF only and I could not read text from it; I did not use any third-party summary as a citation.
3. **Eriksson et al. (2021) full text.** Paywalled (Wiley 403); I relied on abstract text from Semantic Scholar and ResearchGate. The finding quoted is from those abstracts.
4. **Nintendo's own Mario Kart World 1.2.0 patch notes.** I have only a secondary news report (NintendoReporters, 9 Aug 2025) saying rubber banding was eased and kid-friendliness improved.
5. **Jackbox's official Quiplash scoring rules** (final-round multiplier). Only a student design write-up and a Steam community guide.
6. **GameFAQs thread contents** (bonus stars revealed at start) — 403; I have the title and snippet only. Reddit threads were also blocked by login.
7. **Any research on showing scores between rounds to children** (anxiety, motivation, "scoreboard pressure"). Nothing found in NN/g, the accessibility guidelines or the game-design sources I read.
8. **Any research on "last round worth double" as a fairness device** — no study found; only design precedent (Quiplash).
9. **Child-development sources on losing gracefully** — only low-quality parenting/teaching blogs surfaced; nothing I would cite.
10. **Effects of time pressure on 8-year-olds in games.** A 2025 study on visual timers with 7–9 year olds exists (theMDPI/Preprints item in search results) but the publisher blocked both URLs, so I have not read it.
11. **Whether a full-screen "lights out" at typical TV brightness passes the flash thresholds.** This needs measurement with a tool like PEAT or HardingFPA on the actual build — the standards give thresholds, not a verdict on our effect.
12. **Dave Mark's article is a 2010 community blog post** republished by Game Developer; the Split/Second reviewer quote in it is second-hand.

---

## Summary: 15 rules for our party features

1. Make every catch-up rule visible and stated: players should be able to explain *why* the leader was slowed or the trailer helped.
2. Never slow or punish the leader invisibly — "mystery speed-matching" is the thing players call cheating.
3. Help the trailing side by giving them *options* (better star, a shoo-able cat, a bonus target), not by secretly weakening the leader.
4. Announce power-up odds or rules once, briefly, at the start of the night; surprise should be in timing, not in the rules.
5. Keep chaos caused by players' own actions where possible (event spaces, star pickups) rather than by an invisible timer.
6. Give at least 1.5–2 s of unambiguous warning before the cat arrives: distinct sound + visual marker on the piece and on the TV.
7. Make the warning repeatable and skippable — a child who missed it once should not lose the round.
8. Keep each chaos event short (a few seconds), resolvable by the players (shoo it), and never able to undo more than one action.
9. Never let chaos hit the same player twice in a row, and cap chaos per round so the last player is not the punchline.
10. Offer a "calm / no chaos" setting and a "chaos off in round 1" teaching round; expose it in the same menu as difficulty.
11. Award 2–3 bonuses at the end, each with a distinct name, look and one-line reason, revealed one at a time with the child's name and character.
12. Include at least one award a losing child can plausibly win (most helpful, most shooing, best comeback), and announce the categories before the night begins.
13. Keep the running scoreboard visible between rounds but show it as icons + numbers, with each player's own total easy to find; no bare numerals.
14. If the final round is worth double, say so on the scoreboard before it starts — otherwise earlier rounds feel wasted.
15. For flashing/dark effects: keep large-area brightness changes under 3 per second and under 25% of the screen, prefer fades to cuts, honour reduce-motion, never rely on colour alone, and never rely on sound alone.
