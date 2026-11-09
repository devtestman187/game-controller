job: M13 step 8: the phone's pad in the look at its own sizes. Face buttons in the face colours with ink edges and hard shadows; the D-pad, sticks and small buttons in paper and ink; a press squish; the player's badge with its character (design section 5 "The phone pad", D11, D12, 5b)
pub: no
stop: after it.
read: docs/design/look-and-sound.md sections 2 (D11, D12), 3, 4, 5, 5b and 6 ("Decided at step 6") · packages/toy_look/lib (toy_colors faceA–faceY, toy_sizes, toy_shape, sticker_shadow, toy_button's press, toy_badge, toy_character, toy_accessory) · controller_app/lib/src/ui/pad_widgets.dart, face_buttons.dart, stick_widgets.dart, pad_mode_view.dart, controls_layer.dart, controller_parts.dart, tilt_view.dart, bar_connection.dart (PlayerBadge), host_chip.dart, top_bar_metrics.dart · packages/party_host/lib/src/ui/player_badge.dart · controller_app/test (every test that pins the pad's geometry, hit areas, opacity and the top bar's height) · docs/review-rules.md · docs/coding-guidelines.md

Where it stands: the pad is the last part of the phone still drawn in stock Material colours. `face_buttons.dart` and `pad_widgets.dart` hold the phone's last colour literals: the old face colours, `Colors.black` and `Colors.white`. The look has `faceA`–`faceY` tokens waiting for it.

Claude's rules:
1. **Nothing moves under a thumb (D11).**
   - Every size, position, hit area and geometry stays exactly as it is: `FaceGeometry`, `dpadArms`, `dpadDirection`, the stick's radius and travel, `SmallButton` sizes, the layouts, and C28's opacity on the whole overlay.
   - Every existing test that pins them passes unchanged. If one fails, the drawing is wrong, not the test.
   - The press squish (rule 3) is drawing only: it never changes what a touch hits.
2. **Face buttons (A, B, X, Y):**
   - Each is always filled in its face colour (`look.colors.faceA`… by button, both palettes), with an ink edge `look.sizes.outlineWidth` wide and the look's hard shadow below-right (`toyShadowOffset` scaled as `ToyButton` scales it, ink at `toyShadowAlpha`).
   - **Flat fill, no shade band:** text sits on them (D12, decided at step 6).
   - The letter is ink in the look's button family (Fredoka); a game's label under it is ink in the body family (Nunito). Both keep today's size and fit rules.
   - A hidden button (P5) is a dashed ink outline at `toyShadowAlpha`, with no fill and no shadow, in the same place.
   - `FaceButtonsView.colors` goes; the colours come from the look. Drop the `scheme.surfaceContainerHighest` base.
3. **The press squish** (as `ToyButton`'s press, design 4):
   - A pressed part loses its shadow, and its body is drawn moved by the shadow's offset: it's pushed in. This holds for face buttons, D-pad arms (both arms of a diagonal), small buttons, and the stick's knob while held.
   - The squish is immediate, not animated, so it costs nothing and needs no effects switch.
   - `PressFlash` stays: it's the press's quick feedback. Its colour becomes the look's paper, not `Colors.white`, with today's alpha and timing.
4. **D-pad:**
   - Each arm is paper with an ink edge and the hard shadow. Draw it as one plus shape so the centre has no seams: the union of the arms, with the shadow drawn once under the whole shape.
   - The arrows are ink. A lit arm fills with the player's colour (`look.colors.player(n)` for this phone's player, `player(1)` before one is known) and squishes.
   - The centre dot is ink at `toyShadowAlpha`.
5. **Sticks:**
   - The base ring is paper at its current alpha, with an ink edge.
   - The knob is the player's colour (as rule 4) with an ink edge and the hard shadow. While held it squishes. Not held, it keeps today's faded alpha.
   - `faint` keeps multiplying everything as now.
6. **Small buttons (Start, Select, LB, RB):**
   - A paper pill with an ink edge and the hard shadow, its label ink in the button family. Pressed, it fills with the player's colour and squishes.
   - Hidden stays an empty box.
7. **The player's badge** on the phone's bar and host chip (`bar_connection.dart`'s `PlayerBadge`) becomes the look's `ToyBadge` with `ToyCharacter.forPlayer(n)`, so it wears its accessory like the TV's join badge (4c).
   - Keep its key `playerBadge` and its tooltip.
   - **The bar's height doesn't change.** Choose the badge's diameter so the disc and `toyAccessoryHeadroom(diameter)` fit the bar's current chip height. Report the diameter.
   - One badge widget for both apps if party_host's `PlayerBadge` fits; otherwise keep the phone's, built on `ToyBadge`.
8. **Tilt view and anything else on the pad** that still reads `colorScheme` for a fill: move it to the look's paper, ink and player colours the same way. List each in the report.
9. Painters take a `ToyLook` (or the few colours they need from it) and repaint when it changes.
10. After this step, `controller_app/lib` has no `Color(0x` and no `Colors.` (review.sh's literal check). Files under 400 lines, functions under 60.

tests (each failing first):
- Face buttons, in Sunny and Night, by pixel at each button's centre: unpressed, it's that button's face colour; pressed, the body has moved by the shadow offset (sample a pixel only the moved body covers) and the shadow is gone. A hidden button has no fill at its centre.
- Contrast: ink on each face colour ≥ 4.5:1 in both palettes (in toy_look's contrast test, if it isn't there yet).
- Hit tests unchanged: for each face button, D-pad direction and small button, a touch at today's centre and near today's edge gives the same result as before. These are the existing tests; add edge cases only where none exist.
- D-pad: a lit arm is the player's colour, for player 3 and before a player is known; a diagonal lights and squishes both arms; one shadow under the plus, with no seam at the centre (a pixel in the centre is paper).
- Stick: the held knob is the player's colour and squished; not held, faded.
- Small button: paper unpressed, the player's colour pressed, its label ink.
- `PressFlash` paints paper.
- Badge: the bar shows a `ToyBadge` with player n's character, the bar's height is unchanged, and the accessory's ink shows above the disc for players 1–6.
- The overlay's opacity still applies to the whole pad (the existing C28 test passes).
- All existing tests pass (look, puzzle, arena, host, phone, tv, kit). List any you change, and why. A test that pinned an old Material colour may change to the look's token; nothing else.

in the report:
- test counts before and after;
- the files changed;
- the badge's diameter and the bar's height;
- every place on the pad that took a colour, and the token it takes now;
- the literal check's result for controller_app/lib.
self-check: docs/review-rules.md part A, items 1–5, one line each with the test that shows it.
rules: no lib file over 400 · no function over 60 lines · tests first, each failing for the missing behaviour · tools/review.sh: no FAIL on your lines · write only inside this job's folder.
allow: docs/briefs/m13/s8-pad-look-report.md · packages/toy_look · packages/party_host/lib/src/ui/player_badge.dart · packages/party_host/test · controller_app/lib · controller_app/test
check: format analyze look host phone
report: docs/briefs/m13/s8-pad-look-report.md
