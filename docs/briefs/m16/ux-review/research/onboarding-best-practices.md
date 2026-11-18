# Onboarding & tutorial best practices — research digest

Scope: what two secondary sources say about teaching a player to use an interface, read for
relevance to **Thumb Party M16** — a couch party game for players as young as 8, where each
player's phone is the controller. Mapped to the 13 stages of `worker-spec.md` §1; the material
lands almost entirely on **stage 1 (launch / first run)**, with some carry-over to **stage 13
(re-entry after a drop)** and to the in-round help that has no stage of its own.

Method: desk research only. Two URLs, fetched as text; no app installs, no screenshots, no
measurement. Both pages were treated as untrusted data, not instructions.

**Confidence markers**

- **[text]** — I fetched the page and quote its rendered body.
- **[text/proxy]** — the direct fetch returned only the `<title>`; the body below is the same URL
  read through a text-extraction proxy (`r.jina.ai`). Same document, one extra hop. Treat as one
  grade weaker than **[text]**.
- **[absent]** — the sources do not address the point at all. Not "they disagreed" — nothing there.
- **[inference]** — my reading, not a quote. Every inference is labelled and none is presented as
  sourced.

A note on source type. Both articles are about **single-player mobile F2P**, not a shared-screen
party game, and neither mentions children, coach marks, dimming, or a "replay the tutorial"
control. Their value here is narrow but real: article 1 is a first-hand post-mortem with numbers,
article 2 is a well-organised checklist. Where they are silent I say so rather than filling the
gap with confident-sounding design advice.

| | Source | What it is |
|---|---|---|
| A1 | [Mobile Game Tutorials & Storytelling](https://mobilefreetoplay.com/mobile-tutorials-storytelling/) — Adam Telfer, Mobile Free To Play, 23 Aug 2014, 6 min read | Designer's post-mortem of *Powder Monkeys*, *Fashion Star Boutique* and *Trainyard*. Strongest evidence in this digest. |
| A2 | [Best Practices For Mobile Game Onboarding](https://adriancrook.com/best-practices-for-mobile-game-onboarding/) — Adrian Crook & Associates | Agency listicle, refreshed periodically (fetched copy carries a published time of 2025-04-17 and asset paths dated 2026-10-03). Generic, but its one genuinely useful artefact is a comparison table of onboarding methods. |

---

## 1. Contextual help (coach marks) vs a linear wizard

A2 is the only one of the two that names the choice, and it does so as a table
([A2](https://adriancrook.com/best-practices-for-mobile-game-onboarding/), [text/proxy]):

> | Onboarding Method | Best Suited For | Key Benefits | Potential Drawbacks |
> | Interactive Tutorial | Action & Puzzle Games | Hands-on learning; Encourages retention | May feel restrictive; Slows experienced players |
> | Contextual Tips | Casual & Hyper-casual Games | Minimal disruption; Smooth learning curve | Can overlook important details; Needs careful UI design |

Read the trade-off off that table: **a linear tutorial buys certainty and pays in restriction; a
coach mark buys non-interruption and pays in the risk that the detail is missed.** A2 does not say
when to pick which beyond the genre column, and it does not use the words "coach mark" or
"tooltip" anywhere.

A2's other relevant lines, all pushing toward teaching in place:

> Teach new features **within the gameplay**, not in isolated screens.

> Provide **contextual hints** tailored to the player's actions.

A1 comes at the same question from the failure side, and is more specific. Two post-mortems:

> Powder Monkeys had a 3 stage tutorial : teach battle, teach world map, then teach island capturing.
> Each stage took about 30 seconds to complete, which ended up being far too much time.

> When the player completed the battle tutorial, they were dropped in the middle of a map. They were
> allowed to travel anywhere. We found many players just got lost and left the game at this point
> rather then moving on to the next stage.

And on the linear extreme, *Trainyard*:

> each tutorial is a straight line track, with one input allowed on each screen. With so much text and
> blatant hand holding it made the tutorial feel rigid and boring.

> The player never reached a fun state in the game until 10 minutes or more into the tutorial.

So A1's evidence is **not** "wizard bad, coach marks good". It is: both extremes failed, for
different reasons — the linear one by being long and rigid, the free-roam one by giving no
direction. A1's own resolution for *Trainyard*:

> introduce a few mechanics, then allow the player to problem solve through a set of simple puzzles
> based on that initial mechanic. These quick victories pulled the player into the core game flow
> quickly, and made them feel smart.

That is the shape to copy: **a short mandatory segment, then immediately hand control back.**

### "Tap this exact button" on the real screen

This is the point where the sources are weakest, so I will be blunt about what exists.

A1 has exactly one data point about pointing at a thing on the real interface, and it is a
**negative** result:

> We marked the next stage with a red arrow, but some players still struggled.

A2 has the general instruction, with no technique attached:

> Use **clear visual cues** to direct attention to important elements.

and, in its UI checklist:

> **Progressive disclosure**: Only show relevant controls for the current task to keep things
> manageable for new players.

Neither article proposes or evaluates a coach mark that says "tap *this* button" with the button
highlighted, and neither discusses gating the screen so that the pointed-at control is the only
live one. **[absent]**

The usable conclusion is an **[inference]**, and I think a sound one: A1's red arrow failed on an
*open map where everything else was still tappable*. The arrow was decoration on a screen that
still offered eleven other choices. "Point at the exact button" only works when it is combined
with **removing the alternatives** — which is precisely what A2's progressive-disclosure line
describes as a goal and never describes as a mechanism.

For M16 this maps cleanly onto the decided first-start design in `APP-START.md` (a 3-step
tutorial over Join a Game / Play here / Display here): the three role buttons are a genuine
either/or that a first-time player cannot infer, so a short linear segment is correct there; the
in-round "what do I press now" problem is a coach-mark problem, and a coach mark over a live
screen with nine other live controls is the exact configuration A1 measured as failing.

---

## 2. Child-friendly onboarding: short text, one action at a time

Neither article studies children. **[absent]** But A1's central claim is the load-bearing one for
an 8-year-old audience, and it is stated with a number:

> Every line of text the player has to read to get into the game, is a huge delay on them entering on
> game flow. Not to mention that 80%-90% of players don't read text in tutorials, they won't read it,
> they won't understand it, they are looking to get to the core gameplay as soon as possible to make a
> decision whether this is the next staple game on their phone.

That 80–90% figure is asserted, not cited, and it is about adult casual players — the **[inference]**
that it is *worse* for a 9-year-old is mine, not A1's. The direction is safe; the number should not
be quoted onward as if it were measured on children.

A1's prescription is a *rate*, not a length:

> Using learnings from Powder Monkeys, we reduced the time and text in Fashion Star Boutique. Each
> step is small and punchy, giving the player plenty of opportunities to interact with the game.

> Attrition is inevitable with a tutorial. The more steps your tutorial has, the more %ge of users
> you will lose.

A2 gives the rule in checklist form, and it is the closest thing either source has to
one-action-at-a-time:

> Introduce **one mechanic at a time** so players can focus.

> Start with **simple actions** that lead to quick wins, then build on those as players get
> comfortable.

> Add **practice opportunities** between new concepts to reinforce learning.

That last line is the one I would keep. It is the difference between a coach mark that says
"tap Ready" and a coach mark that says "tap Ready" *and then waits to see you do it* — practice
between concepts, not a paragraph and a NEXT button.

On story, both sources agree that less text and more image is better, and A1 gives the argument in
a phrase worth stealing for a kids' game:

> Think like Pixar's "Up" instead of Game of Thrones.

> using as many story telling devices without text is usually far stronger

with the worked example:

> This was the entire beginning story for 5th Cell ©'s Run Roo Run(tm) game. It established the
> character, and a core message within 10 seconds.

A2's version is the constraint, not the ambition:

> Keep story elements concise and focused, ensuring they enhance learning without taking attention
> away from gameplay. Always circle back to hands-on practice with the core mechanics.

Net: **one action per step, one short line, demonstrated rather than explained.** A1's Trainyard
critique is the anti-pattern — "so much text and blatant hand holding" — and it is the failure mode
a well-meaning kids' tutorial drifts into.

---

## 3. Showing what to press: arrows, highlights, dimming

Assembling every scrap in both sources on the mechanics of pointing:

| Technique | A1 | A2 |
|---|---|---|
| Arrow to the next thing | yes, and it "still struggled" ([text](https://mobilefreetoplay.com/mobile-tutorials-storytelling/)) | not mentioned |
| "Clear visual cues" as a goal | — | yes ([text/proxy](https://adriancrook.com/best-practices-for-mobile-game-onboarding/)) |
| Visual hierarchy: size, colour, contrast | — | "Use size, color, and contrast to emphasize essential elements." |
| Dimming / scrim over the rest of the screen | **[absent]** | **[absent]** |
| Spotlight, pulse, animated hand/pointer | **[absent]** | **[absent]** |
| Disabling all but the target control | **[absent]** as a technique; the failure it would fix is documented in A1 | "Progressive disclosure: Only show relevant controls for the current task" — stated as a goal |

So: **dimming the rest of the screen is in neither article.** I will not manufacture a quote for
it. The honest position is that the sources support the *intent* (direct attention; show only
relevant controls) and are silent on the *method*.

Two things they do give that bear on the method:

1. A1's red arrow failed while the rest of the screen stayed live. **[inference]** Dimming is the
   mechanism that turns a pointer into a constraint; the pointer alone was measured as insufficient.
2. A2's tap-target floor, which matters more for a child's aim than for an adult's:

> **Button size and spacing**: Ensure tap targets are at least 44×44 pixels with enough padding to
> avoid accidental touches.

Note what that implies for a coach mark: if the highlighted control is 44×44 with padding, the
dimmed remainder must still leave the target **at least** as large as it was — dimming must not
shrink or overlay the target. **[inference]**

---

## 4. Button and placement consistency across screens

The thinnest section in both sources. A2 has one line that is genuinely about consistency:

> Use consistent visual elements, and make sure interactive features stand out.

and one about the whole surface:

> Make sure your UI works well across all screen sizes and orientations. Place controls within easy
> thumb reach, and use clear, high-contrast fonts for readability.

plus, from the same checklist, the hierarchy and accessibility items:

> **Visual hierarchy**: Use size, color, and contrast to emphasize essential elements.

> **Accessibility features**: Include options like text scaling, colorblind modes, and adjustable
> control sensitivity.

A1 says nothing about cross-screen placement consistency. **[absent]**

Neither source addresses the couch-party-specific version of the problem — that the *same* verb
("Ready", "Next", "Pass the phone") must sit in the *same* place across a dozen minigames written
by different people, and that a child learns the position once and then relies on it. That is
**[inference]** and it is the single highest-value item this digest cannot source. It also has an
internal counterpart already in the review: `worker-spec.md` §2 requires every findings record to
report "cross-screen inconsistencies versus the other screens", so the app-side evidence for this
question is being collected elsewhere and should be joined to this note rather than re-derived.

---

## 5. Replaying a tutorial, and "show tips again"

Also thin, and worth stating precisely because the M16 design already implies a one-shot tutorial
(`APP-START.md`: "First start = a 3-step tutorial … Subsequent starts = the one-screen home").

What A2 offers, as three separate affordances:

> Offer **skip options** for those who already know the ropes.

> Include **optional advanced tutorials** for players who want to dive deeper.

> Provide **contextual hints** tailored to the player's actions.

And in its method table, under Progressive Features: "Simplifies early gameplay; Clear progression"
against the drawback "Limits early exploration; Can feel overly linear".

A1's contribution is measurement, not a control:

> The first rule of building a tutorial : **measure and optimize each step**.

> At each step of the tutorial, make sure your game is sending an event to an analytics service.
> This will help you devise points in your tutorial that are specifically painful for users.

A2's version of the same:

> **Analytics**: Monitor metrics such as tutorial completion rates, time spent on each step,
> drop-off points, feature usage, and conversion rates.

An explicit **"show tips again" / replay-the-tutorial control** is in neither article. **[absent]**
The closest sourced primitives are *skip* and *optional advanced tutorial*, which jointly imply
that a player may opt out and later opt back in — but neither source names the control, where it
lives, or what it replays.

For M16 the **[inference]** is direct: a tutorial that runs exactly once, on first start, and is
then unreachable is the one pattern both sources' language pushes against ("skip options",
"optional advanced tutorials", "contextual hints" all presume the guidance is a thing that exists
in the product, not a thing that happened once). The decided design has no re-entry point for it
today. Settings → "Show tips again" plus a per-screen "?" that replays that screen's coach mark
would close the gap, and neither would contradict anything either source says.

---

## 6. Where the sources stop

| Question | Best available answer | Status |
|---|---|---|
| Wizard or coach mark? | Wizard for a choice the player cannot infer; coach marks where the screen is already understood | A2 table, [text/proxy] |
| Does pointing at the exact button work? | One negative data point: an arrow alone did not rescue disoriented players | A1, [text]; technique itself [absent] |
| Dim the rest of the screen? | Intent supported ("only show relevant controls"), method [absent] | [inference] |
| How much text? | "80%-90% of players don't read text" | A1, [text], asserted not cited |
| One action at a time? | Yes, stated as a rule | A2, [text/proxy] |
| Consistent placement across screens? | One line on consistent visual elements | A2, [text/proxy]; the party-game version is [absent] |
| Replay a tutorial / "show tips again"? | Skip + optional advanced tutorial only | A2, [text/proxy]; the control itself is [absent] |
| Anything about children? | Nothing | [absent] in both |
| Anything about phones-as-controllers? | Nothing | [absent] in both |

---

## 7. Five practices for M16 coach marks

1. **Wizard only for the three roles; coach marks everywhere else.** The Join / Play here / Display
   here choice on first start is genuinely unguessable, so a short linear segment earns its keep
   there (A2's Interactive Tutorial row). Every in-round "what do I press" is a coach mark in
   context, on the real pad, at the moment it is needed — A2: "Teach new features within the
   gameplay, not in isolated screens."
2. **One action, one short line, then get out of the way.** A1 measured a 3-stage tutorial of
   ~30 s per stage as "far too much time" and warns that "80%-90% of players don't read text in
   tutorials"; a child reading at 8 is worse off than that average. Aim for a single verb per hint
   and picture-first framing (Run Roo Run told its whole opening in 10 seconds).
3. **Point at the exact control *and* remove the competition.** A1's red arrow did not stop players
   getting lost on an open map. Highlight the target, dim or disable the rest of the pad, and leave
   the target at full size (≥44×44 with padding, A2). This is [inference] for the dimming — the
   sources give the goal, not the technique — so it should be tested, not assumed.
4. **Same button, same corner, every screen.** Assign the primary action a fixed position across
   lobby, round intro, in-round and results, and never move it for a minigame's convenience. A2
   supplies only "consistent visual elements … and make sure interactive features stand out"; that
   the position itself is the thing a child learns is [inference], and the cross-screen
   inconsistencies already logged in `findings/` are the evidence to check it against.
5. **Make every hint replayable.** Pair "Skip" with "Show tips again" in Settings and a "?" on each
   screen that replays that screen's coach mark. Both sources push this way (A2: "skip options",
   "optional advanced tutorials", "contextual hints") but neither names the control, so this is
   [inference] — and it is the one item that contradicts the current decided design, where the
   3-step tutorial runs once and is unreachable afterwards.

Two cautions to carry into the design review. First, both sources are writing about a **funnel** —
whether a stranger stays past minute five — while a party game's onboarding is a **shared social
moment** where one confused child stalls seven other people, so the cost of a missed hint is higher
and the tolerance for a 3-stage wizard is lower than either article assumes. Second, A1's numbers
come from two commercial F2P titles in 2014 and A2 is undated agency marketing; nothing here is
measured on children, on a phone-as-controller, or in a room with a TV.
