# Potential enhancements

Ideas the owner has raised for after v2. **Status: noted only (owner, Nov 7, 2026: "Don't act on these yet").** Nothing here is in the PRD, designed or scheduled, and the list is not in priority order. When one is picked up, it gets a PRD section and a milestone first.

Family-party features (chaos events, power-ups, party nights) have their own list: [party-ideas.md](party-ideas.md).

## 1. Internet play
Play with people who aren't on the same Wi-Fi, in phases:
1. **Friends you know:** join someone's game with a code or an invite.
2. **Open games:** search for games anyone can join.

Today this is a firm v2 non-goal ([PRD v2, "Goals and non-goals"](PRD-v2.md#goals-and-non-goals)): the only internet use is the opt-in analytics upload, and leaderboards stay on the host device. Picking it up means a relay or matchmaking service, accounts or invite links, latency over the internet, and a new Families-policy and privacy review (open games mean strangers, so child safety comes first).

## 2. More TV platforms
Samsung, LG, Apple TV and Roku.

Already weighed in [PRD v2, "Platform direction"](PRD-v2.md#platform-direction) as v3 receiver candidates: Apple TV through a community Flutter port; Samsung (Tizen) and LG (webOS) through Flutter ports or web apps that can only connect out; Roku as a video receiver at most. Most of these TVs can't accept incoming connections, so they fit item 3's model, where the TV connects out to the host phone.

## 3. Games streamed from the phone to the TV
The host phone runs the game; the TV app's job becomes showing it on the big screen.

This is PRD v2's **preferred v3 direction** ([Platform direction](PRD-v2.md#platform-direction)): snapshots first, for receivers that can run our game code (as M12's joined phones already draw the game from the host's frames), and low-latency video as the fallback for those that can't. M12's phone hosting and joined view are the groundwork.

## 4. More game types
- An incremental business simulation, kid friendly.
- Racing.
- A shooter, top-down or side-scrolling.
- An adventure game.

Each would be a `GameModule` beside Shape Race and the Arena (game_kit), and may need its own controller mode (item 5). A shooter needs a kid-friendly treatment for the Families policy.

## 5. Controller modes that suit each game
Controls designed for a game rather than one pad for all. Example, for Shape Race: steer the dot with a finger on the screen, and rotate pieces with a multi-touch twist gesture.

The pieces that exist: game-defined layouts and labels (`GameLayoutMessage`), the modes (sticks, D-pad, gyro) and the joined phone that already draws the game under the controls, which a touch-the-game mode would build on. A new mode means new input in the protocol and a way for a game to ask for it.
