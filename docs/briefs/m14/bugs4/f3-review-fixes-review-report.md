# M14 bugs4 f3 — the review of the fixes from the bugs3 review

Job: read-only review of commit `55aa6a1` (`git diff 5793f36..55aa6a1`), against the brief
`f3-review-fixes.md`, the report `f3-review-fixes-report.md`, `docs/coding-guidelines.md` and
`docs/review-rules.md` parts A and B. Nothing but this file was changed.

## Summary

`small fixes`. 1 must, 2 should, 6 could.

- must: item 4's six bugs3 report edits are **not in the commit** — `git status` still lists all six as
  modified, so the diff Claude reads contains no item-4 change at all.
- should: `GameField` takes nine constructor parameters, where guidelines §3 allows five.
- should: `_stageBody(Object? night)` drops `PartyNight?` for `Object?` for no stated reason.

## Findings

- **must** docs/briefs/m14/bugs4/f3-review-fixes-report.md:21 item 4's six bugs3 report edits exist only in the working tree — `git status` lists all six as modified and `git diff 5793f36..55aa6a1` contains no `docs/briefs/m14/bugs3` change, so the report's "4 done" is invisible in the commit and the edits are lost on a fresh checkout → commit the six reports (they are inside `allow:`) or say in the report that they are uncommitted.
- **should** packages/party_host/lib/src/ui/game_field.dart:18 `GameField`'s constructor takes nine required parameters (game, playing, debug, hosting, keyboard, roundTags, onEvent, onClock, onFinished), where guidelines §3 allows five and asks for a value object → pass the round's settings and tags plus its three callbacks as one value object.
- **should** packages/party_host/lib/src/ui/game_screen.dart:328 `_stageBody` types the night as `Object?` although `PartyNight?` is in scope (`partyNightProvider` at :296, `../night/party_night.dart` imported at :9) — a type dodge that hides why and is not listed under Decisions → type the parameter `PartyNight?`.
- **could** packages/party_host/lib/src/ui/game_screen.dart:337 `_game!` relies on the stage proving the game is set, which the line does not show; the old `_field()` returned `SizedBox.shrink()` when it was null, and guidelines §2 allow `!` only when the line before proves it → keep a null guard (`final game = _game; if (game == null) return const SizedBox.shrink();`).
- **could** packages/party_host/lib/src/ui/arena_waiting_card.dart:142 `if (!p.local) continue` repeats the local-player split ControllerMenus makes at controller_menus.dart:155, so two owners decide who reads a pad and a change to either filter makes a joined phone's A toggle its row twice → put the split in one shared predicate both read.
- **could** packages/party_host/lib/src/ui/game_field.dart:51 `onEvent`, `onClock` and `onFinished` are public fields with no dartdoc, unlike the six above them (guideline §10) → one line each.
- **could** docs/briefs/m14/bugs3/pr-shape-report.md:22 "nothing in `packages/metrics` reads `gameStats` keys today" is false — `packages/metrics/lib/src/session_player.dart:111-113` iterates those keys into the uploaded summary → say that no report column reads them.
- **could** docs/briefs/m14/bugs4/f3-review-fixes-report.md:52 says the screen is "now 369 lines"; `wc -l` gives 365 for `game_screen.dart` → 365.
- **could** packages/party_host/test/arena_phone_card_test.dart:32 the walk cap `8` is a bare number in a new test (guideline §2 allows only 0, 1, -1, 2 bare) → name it, e.g. `maxWalkSteps`.

## Decisions to confirm

- Item 1's input split by `p.local` (the card reads the host device's own pad, the menus read the joined phones) is the price of reusing `ControllerMenus`; confirm two owners of one pad is acceptable, or take the shared predicate above.
- Item 1 makes a joined phone walk the focus to its own row before A readies it, and the card's first focus is the chosen mode, so a phone that presses A on arrival re-presses the mode — confirm that is the intended feel.
- Item 3 adds `BoardCache({this.onRecord})`, a public observer used only by a test; guidelines §2 allow it, but it is shipped API with no shipping caller — confirm it is wanted.
- Item 4, pr-party: the review named a test that cannot exist (the "Show on this device" host pairs no player); the report pins the rule with two cases instead — confirm the substitute.
- Item 6: the three `generated_plugin` files still show as modified in `git status` (bytes equal `HEAD`, line endings only), so a `git add -A` still carries them — confirm that is accepted.

## Could not check

- The suite counts the report gives (host 399, phone 464, puzzle 403, arena 219): I ran no suite, since a run rewrites the design and site pictures.
- pr-arena's 40 s and 120 s cat arithmetic, and the Spinning Tops bar reach: proposal text with no code to run against.
- Whether the pictures the suites rewrite were really restored byte for byte; `git status` shows none modified, which is consistent with the claim.

## Commit message

M14 bugs4 f3 review: item 4 uncommitted, the field takes nine params

Item 4's six bugs3 report edits sit only in the working tree, so the
commit carries none of them: commit the six reports.
GameField's constructor takes nine parameters; guidelines allow five.
_stageBody types the night Object? where PartyNight? is in scope.
Also: _game! unguarded, the local-pad split written twice, three
undocumented callbacks, a wrong line count, a bare 8 in a new test,
and a false "nothing reads gameStats keys" line in pr-shape's report.

## Status row

The f3 fixes (B-013 phone-operated waiting card, the menus' OK lifted after the press, the board cache keyed by canvas scale with last-used kept and a puzzle swap cleared) are committed and reviewed: 1 must (item 4's six report edits are uncommitted) and 2 should (nine-parameter GameField, Object? night) are open; the suites were not re-run.

## Delete

- none
