# Review rules

What a review checks, beyond [coding-guidelines.md](coding-guidelines.md) (which every job already follows). Written Nov 7, 2026 from the M12 build 4 findings, with the owner: "If the review has a high cost then let's make it count."

## When reviews happen (owner's decision, Nov 7, 2026)
- **Every job:** the worker's self-check (part A) in its report; Claude reads the report and the risky parts of the diff and runs the checks.
- **A full review** at the end of a milestone, and before a public release: before a build is promoted to the external TestFlight group `Testers` or released to a store. Internal-only builds don't need one.
- **A targeted look before the first tag** of a change that is hard to take back: a new protocol message or field, a saved file's format, a store setting.
- **How a full review runs, to keep its cost down:** the worker reviews first, against parts A to C, split by area so each pass fits; Claude then verifies every `must` finding and samples the rest, and reads only the risky paths itself. Findings Claude confirms become fixes (small ones by Claude, the rest as worker jobs) or tech debt with an owner's decision.
- **Each finding that repeats becomes a rule** here or in the guidelines, so the next review finds less.
- **Every finding Claude keeps goes into [code-health.md](code-health.md)**, by area, as *now*, *when touched* or *before a milestone*, with its risk and benefit; briefs that touch an area take its items.

## A. Every job: the worker's self-check
Answer each in the report, one line, with the test that shows it. "Not affected" is an answer; silence is not.

1. **Every host setup.** How the change behaves on: a TV or PC host; a phone on "Play on this phone"; a phone on "Show on this device"; a joined phone; a phone or host one build older. Test the ones that differ. *(Found: the host's own player joined a side in "Show on this device".)*
2. **When kept state starts and ends.** For anything held, timed, counted or remembered (a slot, a timer, a wait, a cache, a flag): when it starts, every way it ends, and what happens when nothing is going on (no round, no players, the app hidden). *(Found: a dropped player's slot was held on the game picker, so the next round would start paused.)*
3. **How a new state combines with the others.** For anything that pauses, hides, waits or blocks input: how it combines with the pause menu, the host away, a player away, "Get ready", a dropped link, the results, and leaving. Name the pairs that can happen together and test them. Exactly one owner decides each state (today: `Pausable` for a round's pause and phase).
4. **Stay in the job's folder.** Write only inside the job's own folder, and only the files in `allow:`. *(Found: a plan written to `E:\game-controller-m12-jobs`.)*
5. **Stop rather than overstep.** A needed file outside `allow:`, a brief that contradicts the code, a rule that can't be met: stop and say which and why. *(Done well in s10b.)*

## B. Game code: what a review looks for
The guidelines' §5 rules (fixed step, determinism, untrusted input, per-frame cost, snapshots, events, dispose) plus:

1. **Round lifecycle.** A round's states (joining, get ready, playing, paused, waiting, results, gone) are explicit and have one owner; no screen infers them from side signals (a layout's labels, a route's name). Every transition has a test, including leaving from each state.
2. **Time.** Rules run on steps; screens count on the host's clock; a pause stops the clock and never catches up; nothing measures a pause as delay. Timers live with an owner that cancels them, and none runs while there is nothing to time.
3. **The host is the authority.** Phones send input and draw frames; they never decide the game. A message may arrive late, twice or not at all: say what happens in each case, and what a reconnecting phone needs re-sent (`view_start`, its layout, its panel, away players).
4. **Input safety.** No stuck input: every way input stops (hide the pad, lock, drop, leave) releases everything. A press is counted once (edge detection), and a press that starts one screen never acts on the next.
5. **Drawing from snapshots only.** A view draws what the frame holds and the box it's given; it never reads host state, the clock or the platform. Sizes come from mm (`pxPerMm`) with a floor, so they hold on the smallest supported phone.
9. **Content will grow.** Layout and sizing rules are computed from the content's shape (a puzzle's board, its pieces, the number of players), never tuned to today's set, and tested over a spread of made-up shapes, with today's content as a sample only. M13 brings the puzzles to 9 and more games follow. *(Found: the mirror's fit was judged puzzle by puzzle.)*
6. **Per-frame budget.** No allocation proportional to history, no I/O, no decoding outside the frame path; anything extra a frame draws (the mirror) is bounded and says its cost.
7. **Compatibility.** A new message is behind a capability; an older peer ignores it and still plays; a newer peer talking to an older host still plays. Tested both ways.
8. **Kid-safe text.** What a player reads is short, plain, kind, and says what to do next.

## C. Built for what comes next
Check each change against the work ahead (PRD v2 milestones, [party-ideas.md](party-ideas.md), [enhancements.md](enhancements.md)). Report only what would cost much more to fix later than now.

| Coming | What the code must allow | Look for |
| --- | --- | --- |
| Look-and-sound milestone (shaders, outlines, music, volume) | Swapping how things look without touching rules | Colours, sizes and styles as literals inside painters instead of a theme or settings; sound names hard-coded in rules |
| M13 (countdown, celebration, last-15-s warning, hint glow, best times, nicknames) | One round flow every game and host shares | Round moments (start, beat, end, results, logs) that live in one game's screen instead of `game_kit`/`party_host`; a TV-only or phone-only copy of the same moment |
| Party features (chaos events, power-ups, points, party nights) | Rules that grow by events, rounds that chain | Rules calling out instead of returning events; a round that can't be followed by another without a screen change; scores that live in a widget |
| More game types (simulation, racing, shooter, adventure) | Adding a game = a new `GameModule` | `if (game == …)`, puzzle types or names inside `party_host`, `game_kit` or the app; screens (join, results, pause) that only fit Shape Race |
| Controller modes per game (touch the board, twist to rotate) | A game asking for its input | Input shapes fixed in the protocol with no room to add one; pad logic keyed on a game instead of a capability or layout |
| Streaming to a TV (v3) | A TV as a viewer of a phone's game | Viewer code that assumes a phone (touch, pad, own side) instead of a capability; host state a viewer can't get from frames |
| Internet play | A transport that isn't the LAN | Addresses, mDNS or "same Wi-Fi" assumptions outside `connection`; trust in a peer's input or timing; anything that breaks with 100 ms of delay |

## D. The review report
- **Findings, most severe first:** `must | should | later` · `file:line` · the rule (A1–5, B1–9, C row, or a guideline §) · the concrete failure ("the host locks during Get ready while P2 is away → …"). A `must` is a bug a tester could hit or a rule broken; `should` is risk or cost; `later` is a C-table item, with what it would cost to fix now.
- **Combination table** (rule A3) for the states the diff touches: one row per pair, "tested by" or "not tested".
- **Not checked:** what the pass did not cover.
- At most 120 lines; no praise, no summary of what the code does; no fixes.
