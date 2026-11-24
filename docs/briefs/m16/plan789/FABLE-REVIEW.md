# Independent review of the M16 items 7, 8, 9 plan (Fable, Nov 24)

Read: PLAN.md, QUESTIONS.md, PRD M16 scope and acceptance, APP-START.md. Three read-only helpers checked the code. Claims marked "(not checked)" are open.

## Verdict
The order (9, then 7a, then 8) is right and Q2, Q3, Q4 stand. I disagree on Q5 and Q6, and Q1 and Q7 need a sharper rule. The biggest miss is not in items 7 to 9 at all: B-040's final winner card can name the wrong winner, and that ships in m16.3.

## Checked facts that change the plan
- **The +3 mismatch is real.** The phone's last `view_end` is sent when the results card appears (`game_screen.dart:248`, `puzzle_screen.dart:220`). Awards are decided later, on Next (`party_night.dart:81-86`). Nothing is sent to phones after the reveal. Three awards at +3 each can move up to 9 points, so the phone's final place, and B-040's final winner card, can differ from the host's final scores.
- **It is not a "fix that number only" job.** Putting the +3 in the existing send spoils the reveal. A second send after the reveal works only if the view is still open (`server_game_frames.dart:91` returns early otherwise; not checked whether it is).
- **The stale-host error card still exists.** With no host discovered, `reconnectToLastHost` connects to the stale address (`connection.dart:199-200`) and the `_Failed` card shows (`connect_panels.dart:198-235`). APP-START says "never a raw error; fall back to Home". No job covers it.
- **Back from Connect when unpaired** lands on a dead, disconnected pad (root is `ControllerScreen`, `main.dart:103`). Home must become the place Back goes; that is a routing decision no job owns.
- **Host start is inline** in `_NoTvActions` (`connect_panels.dart:85-135`), not a function. Home cannot reuse it without an extract.
- **"TV" appears in 40 controller_app test files and 58 party_host test files.** 8e is far larger than M/L.
- **There is no "Remember this screen" switch** and no auto-join setting in code; APP-START assumes the first exists.
- **Fifteen more lib files sit at 371 to 380**, including `live_stats.dart`, `host_server.dart` and `providers/view.dart` at exactly 380.

## Q1 to Q7
- **Q1: agree with A on scope** (no awards on phones, no ceremony, no Skip, no timing injection: one production use, M17 can do it). **Disagree that the +3 is a number fix**; it is a design call, see Q8.
- **Q2: agree with A.** Add: under Q7-A the pad stays a second ask site, so 8d keeps one ask function with two entry points, not "moves the ask to Home".
- **Q3: agree with A.** It is also the cheap one (missing key means show). With Q7-A a paired tester sees the marks on their first Home visit, not first launch; the acceptance wording still holds for fresh installs.
- **Q4: agree with A** for the switch. But "failure goes to Home, not an error card" must not be deferred with it; that is the measured problem item 8 exists for.
- **Q5: disagree, pick B.** A flag nothing reads is dead code that still needs tests. Worse, if M16 ever writes it, every current tester is marked "has hosted" before Thumby exists and misses the M17 first-time intro. M17 Phase 0 should define what "first time" means and add it then. If the owner wants A, the brief must say the key is never written in M16.
- **Q6: disagree, pick B** (one number, 400, in both documents; split only files a job touches). 9f is five jobs across four packages, in core files (`game_session.dart`, `gyro.dart`), with no tester-visible gain, while bug-fix agents work in the same worktree. And 380 would keep failing: three files are at exactly 380 and twelve more within nine lines. Keep one split: `arena_map.dart`, only if 9d must touch it (put map names in a text file and it need not).
- **Q7: agree with A, with a precise rule.** "Paired" today means a saved host and token, which is true for anyone who played last week. Rule: pad only when the last host is found live inside the discovery wait; otherwise Home. A failed connect returns to Home.

## What the plan missed
1. **B-040 and awards (blocks m16.3).** See Q8.
2. **Item 8 states from APP-START with no job:** the green highlight that moves with discovery, "Found nearby", "search again" after a drop, the empty-identity row, failure to Home. 8b names only the chip. Either build them or have the owner cut them explicitly.
3. **Puzzle HUD.** "Round N of M" is planned for Arena only. Shape Race has no map, but needs the night's round number too (not checked what it shows today); `puzzle_screen.dart` is 377.
4. **48 dp on the host side.** The acceptance says every touch target; 9b measures controller_app only. Phone-host screens live in party_host (footer buttons, the award "i").
5. **Proof for the strings sweep.** Add a guard test that fails on a whole-word "TV" in text files outside an allow-list ("Thumb Party TV", "Android TV", look names). Without it the acceptance is checked by eye.
6. **Coach marks versus auto-join and Show-tips replay.** Marks must not sit over a screen that auto-navigates. Say in the contract that marks run only while Home is idle.
7. **Start after m16.3 is tagged.** B-040 and bugs3 are live in this worktree and touch `providers/view.dart` and the results path.

## Slicing problems
- **8a is not a full contract.** It lists keys and strings but not the navigation (which route is root, where Back goes, when the pad is skipped), Home's inputs (a discovery-state value in, callbacks out) or the anchor keys the marks point at. 8b and 8c run in the same wave and both need the anchors.
- **8b is too big for Haiku (M/H).** Cut into: 8b0 extract host start and join into functions (behaviour-free); 8b1 Home as a pure widget, both looks, all sizes; 8b2 routing and the test re-pins.
- **8e needs an inventory first.** The driver lists every string and the tests asserting it, then one job per text file with its tests. `host_text.dart` is at 379 and rewording can push it over.
- **9b is open-ended** ("fix the offenders"). Make 9b1 the measuring test with a recorded offender list, then size 9b2 from that list.
- **9d is three things in two packages** plus an extract from a 379-line file. Cut into: extract (behaviour-free), round and red clock, map name.
- **9c:** a helper shared by party_host and controller_app needs a third package to live in. Set the callback at the four sites, or put the helper in `toy_look` and say so.
- **Wave 2:** 9b and 9e both touch the phone bar and pill area (not checked for a shared file); run them in sequence if so.
- **Agree** with Opus on 8e after 8b, 7a after B-040, and a coverage baseline.

## Top 3 changes, ranked
1. Decide the phone's final card against the awards before m16.3 ships (Q8); do not leave it to 7a.
2. Re-cut item 8: a real contract (navigation, Home inputs, anchors), 8b in three jobs, failure-to-Home in scope, the Q7 rule as written above.
3. Drop the no-value work and bound the vague work: Q5 to B, Q6 to B (no 9f), inventory-first for 8e and 9b, each with a guard test.

## New owner question
**Q8. On a party night's last round, what does a joined phone show?** (Blocks m16.3.)
- **A (recommended for m16.3):** the round result only, with "Awards are on the big screen" in place of the final winner card. No protocol change, never wrong.
- **B:** A now, and after the reveal the host sends the final card with the +3 included (a second send of the existing message; needs the view kept open; one job in item 7).
- **C:** ship the final winner card as B-040 has it; it can disagree with the host's final scores.

I recommend A in m16.3 and B as job 7b.
