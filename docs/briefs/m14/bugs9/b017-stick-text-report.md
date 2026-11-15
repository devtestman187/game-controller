# B-017: the floating-sticks switch text is unreadable

## Summary

**Cause found.** `toyTheme` colours every `ListTile` for text straight on the sky (`toy_theme.dart:41`,
`textColor: colors.onBackground`), which is white in Night (`toy_colors.dart:76`), while paper is cream `#FFF6E3` in
both palettes (`:50`, `:77`): a tile on paper drew white on cream. `ToyCard` puts what it holds back to ink
(`toy_card.dart:180-188`), so Settings read; an `AlertDialog` has no card, so the Sticks dialog did not.

**Numbers.** The `Floating sticks` title on the dialog's paper, measured by the new test: before **1.07:1** at night
(`#FFFFFFFF` on `#FFFFF6E3`; Sunny was ink, 15.53:1, so Night only); after **17.41:1** at night (`#FF120D2E`) and
15.53:1 at midday, the subtitle through the same `textColor`. The dialog's other text was already right and is asserted
too: its stick line (`inkSoft`) 6.09:1 at midday and 6.87:1 at night, its slider lines ink on paper. Settings measured
the same before and after: `ToyCard` had it.

**Fix.** New `controller_app/lib/src/ui/paper_tiles.dart`: `paperTileTheme(look)` is the one definition of a paper
surface's tile colours (the look's ink text and icons); the Sticks dialog wraps its content in it.

**Tests.** New `controller_app/test/stick_text_contrast_test.dart`, four widget tests (dialog and Settings section,
midday and night) that resolve each line's effective colour and the surface behind it from the tree, blend
`inkSoft`'s alpha, and assert 4.5:1. **Which tests are the evidence:** on the old code the two *dialog* tests failed at
1.07:1 (the switch title drew white on cream paper at night); the two *Settings section* tests passed then too,
because `ToyCard` already put its tiles back to ink — they guard that behaviour, not this fix. All four pass now.
`tools/check.sh format analyze phone`: format PASS, analyze PASS, phone PASS (468 tests). A later review job added
the dialog's title (`PhoneText.sticks`, found inside the `AlertDialog` because 'Sticks' also names the mode tab), its
Defaults and Done buttons (5.61:1 at midday, 6.29:1 at night) and all three slider lines, found by the same
`SettingsText` calls the dialog makes (see `f1-review-fixes-report.md`).

**Decisions:** (1) at the widget, not in `toyTheme`, because `packages/toy_look` and `main.dart` are outside `allow:` and
ink there would darken the tiles standing on the sky; (2) one shared `paperTileTheme(look)`, not an inline theme, because
the brief wants one place and Settings needed none (ToyCard already does it); (3) Night from Auto's clock (20:00),
because the palette follows the Look setting and the clock, not the system brightness; (4) `textColor`/`iconColor` only,
because `ListTile` applies `textColor` to title and subtitle alike (the test proves both).

**Not done.** `toyTheme`'s `listTileTheme` still hands out `onBackground`, so the TV app and any other tile on paper keep
the Night bug until a job may change `toy_look` (see Hand-over). Settings got no change.

## Hand-over

- The real fix belongs in `packages/toy_look/lib/src/toy_theme.dart:41`: `ListTileThemeData(textColor: colors.ink,
  iconColor: colors.ink)` is what a tile on paper needs, and every tile in both apps sits on paper except the ones on the
  sky the theme was written for. `paperTileTheme` in the phone app can go once that lands (as `ToyCard._body` could).
- The test measures the dialog and the Settings Sticks section. The same helper would cover the TV's dialogs
  (`packages/party_host`) if that job is wanted; nothing there is asserted today.
- No device check was possible here: the fix is a colour, so it needs the owner's eye on the next build.

### Self-check (review-rules.md part A)

1. **Every host setup.** Not affected: colours only, no state, no host, no network. The test pumps the phone app alone.
2. **When kept state starts and ends.** Not affected: nothing held, timed or counted; the theme is built with the tree.
3. **How a new state combines with the others.** Not affected: no input, pause, away or hidden state involved.
4. **Stay in the job's folder.** Done: only `controller_app/lib/src/ui/{paper_tiles.dart,stick_dialog.dart}`,
   `controller_app/test/stick_text_contrast_test.dart` and this report.
5. **Stop rather than overstep.** Followed. `toy_look` holds the cause and is outside `allow:`, so the phone app
   compensates in one shared place; that needs Claude's yes, as noted above.

## Files changed

- `controller_app/test/stick_text_contrast_test.dart` — new: four widget tests measuring the resolved text colour and the
  surface behind it (dialog and Settings Sticks section, midday and night) against a 4.5:1 WCAG ratio; fails on the old
  code at 1.07:1.
- `controller_app/lib/src/ui/paper_tiles.dart` — new: `paperTileTheme(look)`, the look's ink text and icon colours for a
  list tile on paper that has no card under it.
- `controller_app/lib/src/ui/stick_dialog.dart` — the dialog's content is wrapped in `ListTileTheme(data:
  paperTileTheme(look))`, so its `Floating sticks` switch, subtitle and any future tile read in ink at night.
- `docs/briefs/m14/bugs9/b017-stick-text-report.md` — this report.

## Computed test values

| What | Colour on paper `#FFFFF6E3` | Ratio |
| --- | --- | --- |
| `Floating sticks` title, Night, before the fix | `#FFFFFFFF` | 1.07:1 (test failure) |
| `Floating sticks` title, Night, after the fix | `#FF120D2E` | 17.41:1 (measured) |
| `Floating sticks` title, Sunny, after the fix | `#FF1E1646` | 15.53:1 (measured) |
| its subtitle, Night (same `textColor` as the title) | `#FF120D2E` | 17.41:1 (asserted) |
| the dialog's line about the sticks, Sunny (`inkSoft`) | `#FF625975` | 6.09:1 (measured) |
| the dialog's line about the sticks, Night (`inkSoft`) | `#FF595364` | 6.87:1 (measured) |
| the button size's line, Night (dialog's `contentTextStyle` ink) | `#FF120D2E` | 17.41:1 (asserted) |
| the Settings title and subtitle, Night (before and after) | `#FF120D2E` | 17.41:1 (measured) |

Ratios are WCAG 2's `(L1 + 0.05) / (L2 + 0.05)` with the sRGB channel curve undone, computed in the test itself from the
colours it resolves; the ones marked *asserted* passed the 4.5 floor and were not printed.

## Commit message

Fix the floating-sticks text at night (B-017)

The look's theme colours list tiles with onBackground, which is white in the
Night palette, so the Sticks dialog's 'Floating sticks' switch and its
subtitle came out white on cream paper: 1.07:1. Cards already put their tiles
back to ink, so only the dialog was wrong. A shared paperTileTheme(look) gives
a paper surface's tiles the look's ink, and the dialog wraps its content in it
(17.41:1 at night). A new contrast test measures both the dialog and the
Settings section at midday and at night; it failed at 1.07:1 before the fix.

## Status row

- **B-017 floating-sticks text:** fixed; the Sticks dialog's tile is ink on paper at night (1.07:1 → 17.41:1) with a
  contrast test over the dialog and Settings at midday and at night; open: the owner's device check on the next build,
  and the same colour in `toy_look`'s `listTileTheme`, which is outside this job's files.

## Delete

- none
