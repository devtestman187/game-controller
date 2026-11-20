# M17 — Thumby, the AI host: UX + architecture proposal v2

Status: **proposal** (owner decides; nothing implemented). Date: 2026-11-20. Supersedes `PROPOSAL.md` (v1).
Paths are under `packages/party_host/lib/src/` unless noted. Anything not checked in code is marked *unverified*.

## 1. Summary

- Thumby hosts a whole **party** (the code's "night"), not just three ceremony cards: 7 beats, from "Hi, I'm Thumby" to a full-party goodbye, plus an end-of-party **bonus round**.
- Thumby never generates anything at run time. It says **pre-written, human-reviewed lines**, pre-rendered with Kokoro-82M `af_heart` (Apache-2.0) at build time. Captions are always on.
- Lines are **compositional**: fixed phrases plus slots from closed sets (avatars, colours, games, awards, numbers), each slot a separate clip, so "the winner is... the Red Bow!" is spoken, never synthesised.
- **Option A (now):** an LLM drafts the line bank at build time, a person reviews it. At run time a rule-based **Director** turns events into facts, picks lines, and feeds a speech queue.
- **Option B (later):** a live LLM *selector* returns only line IDs and closed-set slot values as JSON, validated against the bank, with the rule selector as the fallback. The `LineSelector` interface and JSON contract are fixed now (section 5), so B is a drop-in.
- Phone-host first: Thumby is a **small corner avatar plus a one-line caption strip**, and it grows on tablet/TV/Windows.
- The bonus round v1 is a **scoring rule on an existing game**. Both games already take a `pointsScale`, so the first rules are cheap.
- **What changed vs v1:** v1 had six ceremony surfaces, optional cloud TTS and an LLM-written line behind an adult opt-in. v2 drops all of that: no run-time text or audio generation, so the adult opt-in, nickname sanitiser and cloud-TTS budget go away. v2 adds the lobby, pre-game intro, leaderboard insight, party synopsis and bonus round, plus a Director with a defined selector interface.

## 2. The 7 beats and the bonus round

Sizes: **S** = phone-host (smallest), **M** = tablet, **L** = TV/Windows. S shows a 56 dp Thumby head in the bottom-left corner with a caption strip (max 2 lines, 14 sp or more) above the bottom bar. M uses a 96 dp half-body and a speech bubble. L uses a 160 dp full body and a bubble. Thumby never covers text, buttons, the crown or the "+3" (v1 rule, kept). The mouth flaps while a clip plays; there is no lip-sync.

Seams: `ui/night_start_screen.dart:32`, `ui/games_screen.dart:46-68`, `ui/join_screen.dart:127`, `ui/game_screen.dart:268` and `:279`, `ui/puzzle_pick.dart:226`, `ui/night_scoreboard_screen.dart:42`, `ui/night_reveal_screen.dart:44`, `ui/night_reveal_widgets.dart:94`.
Layout caveat: the cards are fixed-width logical px (`nightStartCardWidthPx` 1040 at `ui/night_start_screen.dart:22`, `nightScoreCardWidthPx` 900 at `ui/night_scoreboard_screen.dart:10`, `nightRevealCardWidthPx` 860 at `ui/night_reveal_screen.dart:33`), drawn for a 1280 frame. How they fit a ~360 dp phone host is *unverified*: I found no FittedBox or breakpoint in `ui/`. Phase 0 must measure it.

| # | Beat | Trigger | Thumby does | Sample lines (kid-safe) | Place S / M+L | Budget | Skip | First-time vs returning |
|---|---|---|---|---|---|---|---|---|
| 1 | Intro | Host opens the Party card (`games_screen.dart:66`) | Waves, introduces itself and the party | "Hi, I'm Thumby, and I'll be your host!" / "Welcome to the party! Grab your phones." | Corner + strip / bubble | 6 s first, 3 s returning | Tap anywhere or Skip | First: full intro. Returning: one "Welcome back!" clip, no self-intro |
| 2 | Lobby | `playerJoinedProvider` (`providers.dart:46`), look pick, game choice on the start card | First time: explains the game choices. Returning: waits in the corner, light comments | "Ooh, a Red Bow just joined!" / "Four players, nice!" / "Shape Race is a team puzzle. Bumper Round is a coin scramble." | Strip only / bubble | Explainer 15 s; comment 2.5 s, at most one per 8 s | Explainer skippable; a comment drops if a newer event arrives | First: explainer once (new stored flag). Returning: comments only |
| 3 | Pre-game | Round starts (`game_screen.dart:176`, puzzle start from the pick) | Names the game and says how to win | "Next up: Bumper Round! Grab the most coins." / "Shape Race! Work together to fill the picture." | Strip over the countdown card / bubble | 6 s, ends before the 3-2-1 | Skip; the countdown wins | Both; the first game of a party gets the longer how-to-win |
| 4 | In-round | Round playing | **Hidden.** No audio, no head (in-round commentary is future) | none | none | 0 | n/a | same |
| 5 | After a round | `RoundResult` is in (`game_screen.dart:268`) and the results card shows | Short synopsis, congratulates the winner, encourages the rest; never names a loser | "That was close! The Blue Ears take the round!" / "Everybody did great. Next round, anyone can win!" | Strip under the headline / bubble beside it (v1 seam `ui/arena_results.dart:88-90`) | 6 s | Skip; Next cuts it off | same |
| 6 | Leaderboard | Scoreboard opens (`ui/night_scoreboard_screen.dart:42`) | Names the leader and how close it is; never says who is last | "Red Bow leads by 3, but there are 2 rounds to go!" / "It's anyone's game!" | Strip / bubble | 5 s | Skip | same; "last round is worth double!" when `isNextRoundTheLast` (`night_state.dart`) |
| 7 | Party end | `night.isOver` (`game_screen.dart:270`, `:280`): reveal, then final scores | Ceremony 3rd, 2nd, 1st; full party synopsis; two or three jokes; invites everyone back | "In third place... the Green Antenna!" / "And your champion... the Red Bow!" / "Why did the thumb win? Great grip!" / "Come back soon!" | Bar + winner name on the crown screen / Thumby beside the podium | 25-35 s in chunks | Skip per chunk; Skip all | same; jokes drawn from a pool, no repeat across parties |
| B | Bonus | After the final scores, host taps "One more round?" | Announces the twist, then a normal round plays with the rule | "Bonus round! Everyone's points count double!" / "A special rule! The player in front plays with a twist!" | Strip, as beat 3 | 8 s intro, 5 s result | Skip | Always optional (section 6) |

Notes:
- Beat 7 reuses the award reveal (`ui/night_reveal_screen.dart`, 4000 ms won / 2000 ms missed at :25 and :29). Thumby's line is the *spoken* line only; the caption stays `outcome.reason ?? outcome.award.line` (`ui/night_reveal_widgets.dart:94`).
- 1st/2nd/3rd come from `NightRow.place` and `tied` (`night/night_state.dart:60-64`). A tie is spoken "Joint third!" with its own clip, so a draw is never a loss.
- Robo (`roboPlayerId`, used at `ui/arena_results.dart:86`) can win a round but is no host player; Thumby never calls Robo the host. Awards already exclude Robo (`night/party_night.dart:107-115`).
- On a phone, beats 5 and 6 chain into one speech item per round so the scoreboard is not read twice.

## 3. Line bank

**Moments x tones.** Three tones per moment: *warm* (default), *hype* (close finish, last round), *gentle* (a draw, a quiet lobby, a trailing player). The facts choose the tone. No tone ever names a loser.

| Moment | Slots (closed sets) | Variants per tone | Fixed-phrase clips |
|---|---|---|---|
| intro_first / intro_back | none | 4 / 6 | ~14 |
| lobby_join | avatar (36), count (1-6) | 6 | ~40 |
| lobby_games_explain (first time) | game (2), mode (2) | 2 | ~8 |
| lobby_comment | game, avatar, count | 5 | ~30 |
| game_intro, how_to_win | game | 3 per game | ~18 |
| round_result | avatar, game, margin (close/clear), draw | 5 per margin | ~60 |
| encourage | none (never names anyone) | 12 | 12 |
| leaderboard | avatar, number (gap), rounds_left, last_round_double | 5 | ~40 |
| final third / second / first | avatar | 4 each | ~12 |
| award | award (12, `night/night_awards.dart:27-111`), avatar | 3 each | ~36 |
| synopsis | game, avatar, award, number | 6 | ~40 |
| jokes | none | pool of 30 | 30 |
| invite_back | none | 6 | 6 |
| bonus (intro, rule, result) | rule (~6), avatar | 3 each | ~30 |

**Story patterns (added after the owner's walk-through, Nov 20).** The bank also carries lines for *stories*, not just moments, so a selector can tell what happened rather than only who won. Each pattern has a rule detector (section 4) and its own lines in every tone. They serve the rule selector now and the LLM selector later, so none of the work is lost if B never ships.

| Pattern | Detected when (from `NightState` history) | Sample line | Used in moments |
|---|---|---|---|
| `comeback` | a player was last (or bottom half) after an earlier round and wins this one / leads now | "From last place to first! What a comeback for the Blue Ears!" | round_result, leaderboard, synopsis |
| `rivalry` | the same two players swapped 1st at least twice | "These two just can't stop trading places!" | leaderboard, synopsis |
| `streak` | one player won 3+ rounds in a row; lines turn the spotlight to the others | "Can anyone catch the Red Bow? Everyone else, this is your round!" | round_result, leaderboard, bonus |
| `close_all_night` | the first-second gap stayed ≤ 3 every round | "It's been neck and neck all night!" | leaderboard, synopsis, bonus |
| `underdog_star` | a player outside the top 3 leads one counter (coins, snaps, carries) | "And our coin champion tonight… the Green Antenna!" | synopsis, ceremony |
| `trend` | 3+ players share an accessory or colour family in the lobby | "Bows are in fashion tonight!" | lobby_comment |
| `photo_finish` | this round's margin was 1 point or a tie | "By ONE point! Did you see that?" | round_result |
| `double_drama` | the last (x2) round changed the leader | "The double-points finale changed everything!" | synopsis, ceremony |

Moment-themed joke pools (bumper, puzzle, general) replace the single pool, so a joke can fit the round just played. Story lines add about 120 texts (~350 clips) to the bank.

**Sequences.** A spoken item may be a *sequence* of up to three bank lines, e.g. the synopsis: `close_all_night` → `streak` (Blue) → `double_drama` (Red). Sequence templates per moment (`synopsis` = opening, middle, finish; `round_result` = result → optional story → `encourage`) say which line roles may follow which, so the rule selector builds sequences too. Each line is vetted on its own; a template only orders vetted lines, so safety is unchanged.

**Slot sets.** Avatars today are a colour slot 1-6 plus one of 6 accessories (`protocol/lib/src/character.dart:6,16-41`), unique per player: 36 combinations. Each combination is its own clip ("the Red Bow") for natural prosody. The six colours are `playerColors` (`protocol/lib/src/messages.dart:344`). The spoken avatar name must match the identity text M16 item 5 shows. Colour-name strings: *unverified* (none found in `text/`). Numbers 0-20 plus tens to 100; games 2-3; awards 12; bonus rules ~6.

**Counts.** About 280 moment line texts plus ~120 story line texts (~400 to review) at ~3 segments each, plus ~36 avatar clips and ~60 slot clips: **about 1,000-1,300 clips** for v1, headroom to ~1,500.

**Size.** Mono Ogg Vorbis/Opus, 24 kHz, ~20 kbps, ~2 s average: ~5 KB a clip, **~5 MB for 1,000 clips**, under ~10 MB at the ceiling. `assets/audio` is 2.4 MB today. Ship as a separate folder (`assets/voice/`) so a build can drop it if a store size limit bites (*unverified*).

**Stitching.** A spoken item is an ordered list of clip IDs. Gaps: 60 ms phrase to slot, 120 ms slot to trailing phrase, 300 ms between sentences. Phrase clips that lead into a slot are rendered with a rising tail ("the winner is..."); slots in a ceremony have a *final* variant with a falling ending. Checked by ear in Phase 2.

**Authoring workflow (build time).**
1. A script (LLM-assisted, Option A) drafts lines per moment x tone from a brief plus the closed sets into `tools/thumby/bank.json`: `id`, `moment`, `tone`, `text`, `slots`, `weight`, `needs`, `first_time_only`, `reviewed`.
2. A person reviews every line (tone, kid-safety, no loser callouts, no brands). Only `reviewed: true` lines export.
3. A render script produces one clip per segment with Kokoro-82M `af_heart`, normalises loudness, encodes Ogg, writes `manifest.json` (id, text, duration, hash).
4. A check confirms every closed-set value has a clip, every line's segments exist, and no item exceeds its time budget.
5. The generated assets are committed; the app build never runs an LLM or Kokoro.

## 4. Director architecture

**Where it lives.** New package `packages/thumby_host`: pure Dart (Director, bank loader, selectors, speech queue), unit-testable. A thin Riverpod adapter in `party_host` follows the pattern at `providers.dart:46`. The widget goes in `toy_look` (the character pipeline, per v1; *unverified*, not re-checked). Games import none of it: they only build a `RoundResult` (`game_kit/lib/src/round_result.dart:74`) and the Director reads `PartyNight` (`night/party_night.dart:56`), keeping the rule "nothing in a game imports the night" (`party_night.dart:55`).

**Pipeline:** events -> facts -> selection -> speech queue -> audio + caption.

1. **Events.** `PartyStarted`, `PlayerJoined/Left` (`gamePlayersProvider`, `providers.dart:8`; `playerJoinedProvider`, :46), `LookPicked` (`GamePlayer.character`), `GameChosen`, `RoundStarted` (`game_screen.dart:176`), `RoundEnded` (`RoundResult`), `ScoreboardShown`, `NightOver`, `AwardRevealed` (`night_reveal_screen.dart:85`), `BonusChosen`. The Director uses `ref.listen` where a provider exists. Explicit one-line `ThumbyEvents.x(...)` calls are added at `game_screen.dart:268`/`:279`, `puzzle_pick.dart:226` and the start card, where no provider fires (e.g. the game choice).
2. **Facts.** A `PartyFacts` value rebuilt on each event: players (count, avatar IDs; **no nicknames**), `round`/`rounds` (`nightRoundNumbers`, `party_night.dart:130`), `isLastRound`, `leader`, `gap` and `gapBand` (tie/close/clear), `lastRoundWinners`, `lastRoundMargin`, `gamesPlayed`, `closestGameType`, `strongestPlayer`, `awardsWon`, `firstTimeHost`, `recentLineIds`, `mood` (quiet lobby, close finish, runaway lead), and `stories`: the story patterns (section 3) the detectors found, each with its players and a salience score. The facts keep the per-round history (places and gaps after each round) the detectors need. This struct is also the Option B summary: one source of truth.
3. **Selection.** `LineSelector` (section 5). `RuleSelector` filters by moment, tone and `needs`, drops `recentLineIds`, prefers lines for the highest-salience story, applies `weight` plus a small jitter, and fills the moment's sequence template (up to three lines). `LlmSelector` comes later, wrapped in `FallbackSelector(primary, fallback)`.
4. **Speech queue.** Items carry `priority` (ceremony > result > leaderboard > lobby comment > chatter), `maxAge` (a stale item is dropped), `cooldownKey` (e.g. `lobby_join` 8 s) and are always skippable. One item at a time: Thumby never talks over itself. A higher-priority item waits for the current clip unless marked `interrupts` (only Skip and the game-start countdown). The queue clears at round start (beat 4). The Next button always works and cuts speech off; no round or screen waits on Thumby.
5. **Voice player.** A separate `ThumbyVoicePlayer`, not the `SoundKey` enum: `SoundKey` loads every sound at start (`sound.dart:173-207`), which does not scale to ~1,000 clips. It loads clips on demand (the ceremony set ahead of time) through `flutter_soloud` (`sound.dart:105-108`; `loop_audio_engine.dart:39`) with its own volume. It must live in its own file: **`sound.dart` is 375 lines against a 380 cap**. Ducking uses the existing `SoundPlayer.musicVolume` setter (`sound.dart:333-337`): lower by ~10 dB during speech, restore after. If a new interface method is needed, put it in an extension or a new file (cap unverified beyond the brief).
6. **Captions.** Always on, in the strip/bubble. The caption is the line text with slot display text; a nickname may appear in a caption (if a player has one) but is never spoken.

**Settings.** `ThumbySettings` in its own file beside `sound_settings.dart` (same pattern, `sound_settings.dart:12-60`): `thumbyOn` (default on), `voiceOn` (default on), `voiceVolume` 0-100, `duckMusic` (default on); captions are fixed on. Persistent memory in `shared_preferences` (`prefs.dart`): `firstTimeHost` and recent line IDs per moment. *Unverified:* there is no existing first-time-host flag; M16's "Show tips" is controller-side. `SoundSettings.muted` (`sound_settings.dart`) also silences Thumby; captions stay.

## 5. Option B contract

**Interface (Dart).**

```
abstract interface class LineSelector {
  Future<Choice?> select(SelectRequest request);   // null = nothing; caller falls back
}
class SelectRequest { Moment moment; PartySummary summary; List<Candidate> candidates; Duration budget; }
class Choice { List<LineChoice> lines; }                    // 1-3 lines, spoken in order
class LineChoice { String lineId; Map<String, String> slots; } // slot name -> closed-set value ID
```

**What the LLM adds over the rules** (owner walk-through, Nov 20): it never adds sentences; it adds judgement. It picks *which* of many true facts is worth saying (the kid who didn't place but collected the most coins), tells a 3-line story in the right order for the synopsis and ceremony, keeps the tone kind when one player runs away with it, remembers what Thumby said earlier in the party, fits jokes and the bonus rule to what happened, and handles fact combinations no detector covers. Expected gain: round result, leaderboard, synopsis, ceremony and bonus pick (about a third of Thumby's speech); intro, explainers and how-to-win are as good from rules.

`RuleSelector` implements it now. `LlmSelector` and `FallbackSelector` arrive later; nothing else changes.

**Request (what leaves the device).** Numbers and closed-set IDs only. Never nicknames, device names, IPs, pairing codes, photos or free text.

```
{ "v":1, "moment":"leaderboard", "tone_hint":"warm",
  "players":[{"avatar":"red_bow","rank":1,"points":14,"rounds_won":2}],
  "round":2, "rounds":3, "is_last_round":false,
  "last_round":{"game":"bumper","winner_avatars":["red_bow"],"margin":"close"},
  "games_played":{"puzzle":1,"bumper":1}, "awards_won":{"red_bow":1},
  "first_time_host":false,
  "candidates":[{"id":"lb_close_03","slots":["avatar","number"]}],
  "recent_ids":["lb_close_01"] }
```

The request also carries `"history"` (places and gaps after each round), `"stories"` (detected patterns with players and salience) and `"said"` (line IDs already spoken this party), so the model can pick the best story and avoid repeats.

**Response** (JSON only): `{ "v":1, "lines":[{"line_id":"syn_close_02","slots":{}}, {"line_id":"syn_streak_04","slots":{"avatar":"blue_ears"}}, {"line_id":"syn_double_01","slots":{"avatar":"red_bow"}}] }` — 1 to 3 lines.

**Validation (on device, before queueing).** `v` matches; JSON parses with exactly these keys; 1–3 lines whose roles fit the moment's sequence template; each `line_id` is one of the offered candidates, reviewed and not recent; every slot is declared by that line and its value is in the closed set; avatar values must be players in the party; numbers must equal the facts (a wrong number is a wrong sentence). Anything else is invalid and the rule choice is used.

**Timeouts and fallback.** Budget 1.2 s mid-flow, 2.0 s for beat 7. `FallbackSelector` runs the rule selector immediately and speaks its choice if the LLM misses the budget; a late answer is dropped. Timeout, network error, non-200, bad JSON, bad ID or slot all fall back silently. No round waits on it.

**Transport and privacy.** A thin HTTPS endpoint holds the API key (none ships in the app); provider undecided. No identifiers, no free text, nothing generated comes back, so the kid-safety surface stays the reviewed bank. A "Smarter Thumby (uses the internet)" switch, default ON (owner answer 5), lets a host turn it off. If B proves too complex, an **on-device model** on newer iOS/Android implements the same `LineSelector` with the same JSON and validator.

## 6. Bonus round v1: a special scoring rule

**How scoring works today.**
- A party ("night") is 3 or 5 rounds (`night/night_state.dart:10-18`). Rounds are Shape Race (puzzle) or a Bumper Round (arena). A night plays only Bumper mode, never the race (`ui/game_screen.dart:180`).
- Each game computes its round points and hands them over scaled in `RoundResult.points` (`game_kit/lib/src/round_result.dart:105`). The night sums them (`night_state.dart` `record`, ~:226-245) and counts `counters`, `roundsWon` and the awards (+3 each, `awardsWonBy`).
- Bumper: (coins + `bumperWinBonus` 5 per leader) x `pointsScale` (`test_game/lib/src/arena_bumper.dart:220`, `arena.dart:22`).
- Puzzle: each award is base x `pointsScale` (`puzzle_game/lib/src/puzzle_points.dart:29`); bases are snap 2, wrong snap 1, together 1, finish 5, cat 1 (`puzzle_game/lib/src/points.dart`; the puzzle setting caps the scale at 4, `settings.dart:90`).
- `pointsScale` is one integer per round set in one place: 1 normally, **2 for the last round** (`night/party_night.dart:14-15,40-45`; `ui/game_screen.dart:184-186`). A rule that changes the scale needs no game rewrite.

**Candidate rules (the closed catalogue the selector picks from).**

| Rule ID | What it does | Hook | Cost |
|---|---|---|---|
| `double_everyone` | Every player's round points x2 | `NightChaos.settingsForRound` / `ArenaGame(pointsScale:)` (`party_night.dart:40`, `game_screen.dart:186`) | Low |
| `catch_up_triple` | Bottom-half players x3, the rest x1 | Night layer, remap `RoundResult.points` by place | Low-Med |
| `leader_handicap` | Leader x1, everyone else x2 | Night layer | Low-Med |
| `winner_takes_bonus` | Round winner(s) get +10 | Night layer (`record`) | Low |
| `team_together` | Shape Race "together" carries x3 | New puzzle setting (`puzzle_points.dart`) | Med |
| `coin_rush` | Bumper coin worth 2, no win bonus | New bumper setting (`arena_bumper.dart:220`) | Med |

v1 ships the first four (night layer, no game change); the last two wait for game settings. Control and map modifiers are later.

**Stats that feed the pick.** From `NightState`: totals, `place`/`tied`, `roundsWon`, `counters` (coins, snaps, carries, `wrongDrops`), `lastRoundPoints`, game types played (`RoundResult.game`, `maps`), first-second gap. Derived: `closestGameType` (smallest average first-second gap), `strongestPlayer`, `gapBand`. Tight (gap <= 3): `winner_takes_bonus` or `double_everyone`. Runaway leader: `leader_handicap` or `catch_up_triple`. The Director only chooses a rule *ID*, so Option B can choose it too.

**Kid-safety.** The bonus is **offered**, not forced. No rule removes points. Handicaps are worded "the player in front plays with a twist". Until the owner decides (question 4), the bonus is its own mini-podium and does not rewrite the crowned result.

## 7. Dependencies, conflicts, open questions

**M16 conflicts.**
- **Home screen (APP-START.md).** M16 fixes three roles (Join / Play here / Display here) in a fixed order. "Party mode as default, other modes in a separate menu" collides with that, and with the picker where Party night is one card (`ui/games_screen.dart:63-68`).
- **Item 5 identity.** Thumby speaks avatar names, which must come from the M16 colour + accessory set. More colours/accessories later mean more clips (a new colour adds 6). Nicknames stay caption-only.
- **Item 6 awards.** The reveal screen exists; beat 7 layers on it, so v1's build order stands (after item 6 is stable).
- **Phone-host layout.** Cards are drawn for 1280x720; a phone host may be cramped. *Unverified.*

**Open questions for the owner.**
1. Party as default: keep the three-role home and make Party the first card in the picker, or let a Party-first start replace "Play here"?
2. Only two game types exist (Shape Race, Bumper Round). Is "light commentary on game types" enough, or does a third game come first?
3. Beat 1 plays before the 3/5-round length is chosen on the start card. Move the intro after the length choice?
4. May the bonus round change the champion, or is it its own mini-podium (proposed)?
5. Is a "Smarter Thumby" internet switch, default off, acceptable for Option B, or on-device only?
6. One voice (`af_heart`) for all tones, no per-tone voice changes: OK?
7. Any joke topics to avoid? (Proposal: only thumbs and games, never people.)
8. Should Thumby also speak on joined phones (a protocol change), or host screen only as in v1?
9. Who reviews the ~400 lines? A named reviewer is needed before Phase 2 ships.
10. Is a 5-10 MB voice pack acceptable on the TV, Windows and iOS builds?

**Owner answers (Nov 20, 2026, all recommendations accepted).**
1. Keep M16's three-role home; Party night becomes the first, highlighted card in the game picker.
2. Two game types are enough for v1.
3. Beat 1 is a short "Hi, I'm Thumby" when the host opens Party; the game summary plays after the 3/5-round length is chosen.
4. The bonus round has its own mini-podium and never changes the crowned champion.
5. "Smarter Thumby" (Option B) is ON by default with a switch in settings, since no personal data leaves the device; the privacy policy and store data forms are updated when B ships.
6. One voice, `af_heart`, for all tones.
7. Jokes are only about thumbs and games, never people.
8. Host screen only; joined phones stay silent (no protocol change).
9. The owner reviews the bank after a Claude screening pass.
10. A ~5-7 MB voice pack is acceptable on all platforms.

## 8. Phased build plan

Each phase is shippable alone, phone-first. A job is at most 150 turns. Estimates are rough.

| Phase | Ships | Jobs | Notes |
|---|---|---|---|
| 0. Decisions | Answers to the questions; measure the night cards at ~360x640 dp | 1 | Closes the layout gap |
| 1. Captions-only Thumby | Widget (S/M/L), caption strip, `ThumbySettings`, beats 1, 3, 5, 6, 7 as caption text; `RuleSelector`, `PartyFacts`, speech queue (silent timing) | 7-9 | No audio; fully testable; sizes decided here |
| 2. Voice pack v1 | Bank + `tools/thumby/` scripts, Kokoro render, `ThumbyVoicePlayer` (own file), ducking, volume/mute, stitching | 6-8 | Human review is the long pole |
| 3. Lobby + first-time host | Beat 2, `firstTimeHost` flag, tone selection | 3-4 | Hooks `playerJoinedProvider` |
| 4. Ceremony + synopsis + stories | Full beat 7, party synopsis, themed jokes, invite back; story detectors (8 patterns), round history in facts, sequence templates; story lines in the bank | 6-8 | Uses the existing reveal; story lines need review too |
| 5. Bonus round v1 | Catalogue (4 rules), offer after final scores, mini-podium, rule lines | 4-5 | `pointsScale` seam |
| 6. Option B | `LlmSelector`, endpoint, validator, `FallbackSelector`, consent switch, fake-network tests | 5-7 | No bank change |
| 7. Tablet/TV polish | Larger Thumby, animation pass, Windows check | 2-3 | Needs devices |

Total about 34-45 jobs. Phases 1 and 2 are the minimum "Thumby talks" release; Phase 1 alone is a safe first TestFlight.

**Recon surprises.**
- A "night" already exists with rounds, per-round scaling (last round x2), counters, awards and a reveal, so beats 5-7 and the bonus round hook into existing code.
- Only two game types exist, and a night never plays the Arena race.
- `SoundKey` loads everything at start and `sound.dart` is at 375 of 380 lines, so the voice needs its own player file.
- No first-time-host flag exists, and there are no spoken avatar-name strings (only a colour slot plus an accessory enum).
