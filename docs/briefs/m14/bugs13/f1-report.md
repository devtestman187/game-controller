# M14 bugs13 f1: the first host's consent prompt is a thumb's alone (B-023 follow-up)

## Summary

The first host's consent prompt is touch only (B-023): while it is up, a joined
phone's A presses nothing and its B closes nothing, and the remote's OK, Enter
and back reach nothing. A tap on Share or Don't share answers it as before, and
once it is answered the phones work the host's menus again. The Stats screen's
and the Settings row's prompts are unchanged.

- `askConsent` takes `touchOnly` (false by default); `HostScreen` passes true.
- `ThumbOnly` (new, in `controller_menus.dart`) wraps the prompt: a
  `ControlsClaim` with `Controls.menus(only: <String>{})`, so no phone may work
  the menus while it is up, and `ExcludeFocus`, so no key has a button to
  reach. A touch still works.
- New file `controller_app/test/first_host_consent_input_test.dart` (6 tests);
  one new test in `packages/party_host/test/stats_screen_test.dart` (the Stats
  screen's prompt still answers with a phone's A and the remote's OK).
- `joinPhone` now lives in `test/support/host_app.dart`; the new test uses it.
- The "First host prompt vs joined phones" entry is gone from
  `docs/code-health.md`, and its `joinPhone` entry now says where the one
  helper lives.

Tests seen: on the old code the new file ran `+2 -4`: a joined phone's A, its
B, the remote's OK/Enter and the after-answer test fail; the remote's back and
the Don't share tap pass (Decisions 4). With the fix it is `+6`.
`tools/check.sh format analyze phone host`: PASS (host 490 tests, phone 490).

Fixed, unverified: needs device check.

## Decisions

1. **A `touchOnly` flag, not a second function**: the wording, the buttons and
   the saved answer stay one function, and the two other callers pass nothing
   and behave as before.
2. **`Controls.menus(only: <String>{})` means "no phone works the menus"**:
   `controls.dart` is outside this job's allow list, so the natural new
   constructor ("the menus, for nobody") was not added; the pause menu already
   uses `only` to say who may work a screen, and the empty set is its honest
   degenerate case.
3. **`ExcludeFocus`, not a `Focus(onKeyEvent: handled)` wrapper**: a
   `HostButton`'s `ToyButton` installs its own `Shortcuts` *below* any wrapper
   Focus, so Enter and OK are taken there first; with nothing in the dialog
   focusable the keys reach no action at all, and pointers are untouched.
4. **The remote's back never closed this prompt, even before**: `DismissIntent`
   is disabled on a dialog with `barrierDismissible: false`, so escape reached
   nothing. Its test is a guard, and that is why it is one of the two tests
   that passed on the old code; the back behaviour itself is unchanged.
5. **Two guards, because pad and keys are two paths**: a phone's A is
   `Actions.maybeInvoke(ActivateIntent)` on the focused button and sends no key
   event, so key blocking cannot stop it (the claim does); its B is
   `Navigator.maybePop` (the claim stops it too).
6. **A press made while the prompt is up is not replayed**: the menus record
   every phone's buttons every tick, blocked or not, so the press is old news
   once the prompt closes. The after-answer test shows a new press works.
7. **The check comes after the exit frame**: a prompt closed by B animates out,
   so `_stillAsking` settles before it looks (without it the B test passed on
   the old code by looking mid-exit).

## Tests and the values they check

New file, `controller_app/test/first_host_consent_input_test.dart`:

| Test | What it checks |
| --- | --- |
| a joined phone's A leaves the first host's prompt unanswered | `consentDialog` findsOneWidget, `statsStateProvider.consent` null, `prefs['statsConsent']` null after `phone-b`'s A |
| a joined phone's B leaves the first host's prompt up | the same three, after `phone-b`'s B |
| the remote's OK and Enter leave the first host's prompt unanswered | the same three after `select` and after `enter`, and `ShapeRaceScreen` findsNothing (no key pressed the picker under the prompt) |
| the remote's back leaves the first host's prompt up | the same three after `escape` |
| a thumb on "Don't share" answers the prompt, as before | prompt gone, consent `isFalse`, `statsConsent` `isFalse`, `ControllerMenus` still up |
| after the answer, the joined phone's A and B work the host's menus again | a press under the prompt changes nothing; after the tap on Share, A shows `ShapeRaceScreen` and B shows the picker again |

New test in `packages/party_host/test/stats_screen_test.dart`: "the prompt the
Stats screen opens answers with a phone's A and the remote, as before" — p2's A
gives `fake.stats.consents == [false]`, the remote's `select` gives
`[false, false]`. It passes on the old code too: it guards the default path.

## Self-check (review-rules part A)

1. **Every host setup**: phone "Play on this phone" — the A/B/remote tests; phone
   "Show on this device" — the after-answer test hosts that way and its menus
   answer after the prompt; TV/PC host and the Stats/Settings prompts —
   `stats_screen_test.dart`'s new test (remote and a phone's A both answer). A
   build one version older: no protocol or saved-format change, not affected.
2. **Kept state**: the claim starts when the prompt mounts and ends with it
   (`ControlsClaim.dispose`), and the menus' `_before` records the presses made
   under it rather than queueing them — the after-answer test shows the press
   under the prompt did nothing and the next one presses the card.
3. **New state with the others**: the prompt is up only at the host route's
   first frame, before any round, so no pause menu, "Get ready", away player,
   dropped link or results can be up with it; a phone can join under it
   (`first_host_consent_link_test.dart` still passes) and is ignored until the
   answer.
4. **The job's folder**: only `controller_app/lib/src/host/host_screen.dart`,
   `controller_app/test/{first_host_consent_input_test.dart, support/host_app.dart}`,
   `packages/party_host/lib/src/ui/{controller_menus.dart, stats_screen.dart}`,
   `packages/party_host/test/stats_screen_test.dart`, `docs/code-health.md` and
   this report were written.
5. **Stop rather than overstep**: nothing outside `allow:` was needed; the one
   idea that would have (`Controls.none` in `controls.dart`) was not taken, and
   is Decisions 2 and Suggestion 1.

## Files changed

- `controller_app/lib/src/host/host_screen.dart`: `_askConsent` passes
  `touchOnly: true`, with the reason in its doc.
- `packages/party_host/lib/src/ui/stats_screen.dart`: `askConsent` takes
  `touchOnly` and wraps the prompt in `ThumbOnly`; no autofocus for it.
- `packages/party_host/lib/src/ui/controller_menus.dart`: the new `ThumbOnly`
  (controllers claim + `ExcludeFocus`).
- `controller_app/test/first_host_consent_input_test.dart`: new, 6 tests.
- `controller_app/test/support/host_app.dart`: `joinPhone` moved here.
- `packages/party_host/test/stats_screen_test.dart`: the prompt's remote/pad
  guard test.
- `docs/code-health.md`: the B-023 entry removed; the `joinPhone` entry updated.

## Hand-over

Not verified on hardware: the phone host's prompt under a real thumb, which is
the point of the change (the tests use taps and a fake pad). The prompt's look
is unchanged. Everything else this job touched is exercised by the suites above.

## Commit message

```
The first host's consent prompt is a thumb's alone

A phone host already accepts phones, so the prompt that asks the adult
about sharing stats could be answered for them: a joined phone's A pressed
the focused "Don't share" and its B closed the dialog (B-023).
askConsent takes touchOnly for that prompt: a controllers claim with no
player in it keeps the phones off the menus, and ExcludeFocus keeps the
remote's keys off the buttons. The Stats screen's and the Settings row's
prompts answer with pad and remote as before.
```

## Status row

- M14 bugs13 f1: the first host's consent prompt answers only to a thumb (a joined phone's A/B and the remote's keys change nothing, and the menus work again after the answer); open: a device check on a phone host.

## Delete

- none
