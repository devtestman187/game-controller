# M14 bugs14 b028 — the "Blue is taken tonight" band (B-028)

## Summary

The band now compares the colour the host gave with the colour the **last hello asked for**, and it goes
after 5 s or when the round moves on, whichever is first. A colour change in Settings while joined shows
no band, and the new colour applies on the next join. No protocol change, no look or text change, no
change to how the host assigns colours.

- `ClientSnapshot` gained `askedCharacter` (nullable), set where the hello is built and sent
  (`ClientConnection._attach`), so the screens get it through the snapshot they already watch.
- `TakenNoticeNotifier` (`providers/profile.dart`) owns the band: it compares `askedCharacter` with
  `character` by colour slot, times the band with one timer (`takenNoticeDuration` = 5 s), and hides it
  on a view starting or ending on this phone (the round moving on).
- `TakenNotice` (the widget) only draws that provider's record; it no longer watches `profileProvider`.
- Tests: 4 new widget tests in `controller_app/test/taken_notice_profile_test.dart`, each failing on the old
  code (reasons below), and the pinned test in `m14_phone_test.dart:57` updated to set the hello's colour.
  Ran here: `flutter test test/taken_notice_profile_test.dart test/m14_phone_test.dart` → 11 passed.
- Checks here: `tools/check.sh format analyze phone connection` → PASS format, PASS analyze,
  PASS connection (290 tests), PASS phone (500 tests).

## Decisions

1. The hello's colour lives in `ClientSnapshot.askedCharacter`, recorded in `ClientConnection._attach`:
   the screens already watch the snapshot (`clientStateProvider`), so the widget and its test need no new
   plumbing, and the value can't drift from the hello that was actually sent.
2. Compared by colour slot only, as before: the line names colours, never accessories.
3. "A phase change" = a view starting or ending on this phone (`ViewStarted`/`ViewEnded`): that is the
   round's phase a joined phone knows (m12 rule 6: joined phones never read `roundPhaseProvider`). The host
   phone's own player gets no view, so its band ends on the 5 s alone (question 1).
4. The timer lives in a provider, copied from `AbandonedNoticeNotifier` (`providers/view.dart`): one owner
   for the kept state, cancelled on dispose, on a matching answer and on a new answer; the widget stays a
   draw of state.
5. The provider is in `providers/profile.dart`, because that file is exported by `providers.dart`, which is
   outside `allow:`; a new file under `providers/` would have needed a barrel edit.
6. A repeated answer keeps the running seconds; only a different answer restarts them. Every heartbeat pong
   brings a snapshot, so without this the band would never time out.

## Files and what changed

- `packages/connection/lib/src/client_types.dart` — `askedCharacter` field, constructor, dartdoc and the
  `copyWith` arm (with the `_keep` sentinel).
- `packages/connection/lib/src/client_connection.dart` — `_attach` builds the hello once, sends it, then
  records `hello.character` in the snapshot.
- `controller_app/lib/src/providers/profile.dart` — `TakenColours`, `takenNoticeDuration` (5 s),
  `takenNoticeProvider`, `TakenNoticeNotifier`.
- `controller_app/lib/src/ui/taken_notice.dart` — draws the provider's record instead of comparing the
  live profile; same band, keys and text.
- `controller_app/test/m14_phone_test.dart` — the pinned band test now sets `askedCharacter` to blue (the
  phone's `ControllerProfile.initial`) on both snapshots; same intent: the line shows for a taken colour
  and goes when the host gives the asked one.
- `controller_app/test/taken_notice_profile_test.dart` — new, 4 tests.

## Tests and computed values

Run: `cd controller_app && flutter test test/taken_notice_profile_test.dart test/m14_phone_test.dart` →
`+11: All tests passed!` (4 new, 7 in m14_phone_test).

Each new test and why it fails on the old code:

1. "changing the colour in Settings while joined shows no band" — joined with the asked blue given back;
   then Settings saves colour 4 + crown. Old code compared profile (teal) with the answer (blue) → band
   shows. New: `profileCharacter` holds `"c":4` and the client's identity is teal, and no band.
2. "a hello that asked blue and was given teal says so, and still says blue after a change" — the answer
   is teal for an asked blue, so the line reads `Blue is taken tonight, you're Teal`
   (`ToyCharacter.colourNames` = Blue, Orange, Purple, Teal, Pink, Yellow; asked slot 1 → Blue, assigned
   slot 4 → Teal). After Settings moves the profile to teal, the old code hides the band (profile = answer);
   the new code still says Blue. Then the 5 s end it.
3. "the band goes after five seconds on its own" — the answer is emitted, `settle` advances 0.5 s, then
   `pump(4 s)` = 4.5 s after the answer (still shown) and `pump(1 s)` = 5.5 s (hidden). Old code never
   expired.
4. "the band goes as the round starts" — a taken answer shows the band, then `viewStart(arenaStart())`
   hides it. Old code kept it over the game.

Timing in test 2: the answer at t=0, `settle` 0.5 s, Settings open and close 1.5 s → the band is asserted
at 2.0 s, inside the 5 s; `pump(5 s)` afterwards leaves no timer pending. Test 3 consumes its timer; tests 1
and 4 start none (test 1 no band; test 4 the phase change cancels it). `m14_phone_test`'s test clears the
band by giving the asked colour back.

## Self-check (review-rules.md part A, items 1–5)

1. **Every host setup.** TV/PC host: no phone UI, unchanged. Phone "Play on this phone": the own player's
   band compares its own hello's colour with the host's answer and ends on the 5 s (no view events —
   question 1). Phone "Show on this device": no own client, the TV client's snapshot is idle, so
   `askedCharacter` is null and no band shows. Joined phone: tested (tests 2–4). One build older: an older
   host that sends no character gives no band, as before; the protocol is untouched so an older phone
   simply doesn't read `askedCharacter` (the field is phone-side only).
2. **When the kept state starts and ends.** The timer starts when the host answers a colour other than the
   last hello's; it ends at 5 s (test 3), at a view start or end (test 4), when the answer matches the ask
   (test 2's last step), when the link drops (`character` goes null) and when the client changes (the
   provider rebuilds and disposes it). Nothing pends while there is no differing answer (test 1).
3. **How the state combines.** The band takes no touch (`IgnorePointer`) and pauses nothing; the results
   card is drawn above it and a `view_end` hides it, so it can't sit over the results. It can sit over the
   host-away/waiting card for up to 5 s (question 2). Pairs tested: band + game start (test 4). Not
   directly tested: the `ViewEnded` branch (the same statement as `ViewStarted`), the host-away overlap.
4. **Stay in the job's folder.** Only `allow:` files changed: `client_types.dart`, `client_connection.dart`,
   `providers/profile.dart`, `ui/taken_notice.dart`, `test/m14_phone_test.dart`, the new
   `test/taken_notice_profile_test.dart` and this report.
5. **Stop rather than overstep.** No stop needed. `controller_app/lib/src/providers.dart` (the barrel) is
   outside `allow:`, so the new provider went into the exported `providers/profile.dart` instead
   (decision 5).

## Questions and suggestions

1. The host phone's own player ("Play on this phone") gets no view messages, so its band ends on the 5 s
   only. Should it also end on the host's round phase (`party.roundPhaseProvider`)? That would mean a
   provider reading `party_host`'s phase outside the host screens, which m12 rule 6 says joined phones
   never read.
2. The stack in `controller_screen.dart` draws the band above the waiting card (host away, dropped link),
   so it can sit over that card for up to 5 s. Hide it on `HostAway` too?
3. Should an accessory that was taken also show the band? Only the colour is compared, as before.
4. The hello recording itself (`_attach`) has no test in `packages/connection/test`, because the brief
   allows new tests only in the new file; a small test there would pin the snapshot value.

## Hand-over

Fixed, unverified on a device. Device check: with two phones, have both pick blue and join a host — the
band names blue and teal at join, goes within 5 s and when the round starts; then change the colour in
Settings while still joined — no band appears, and the next join gets the new colour. On a phone hosting
"Play on this phone", the same band clears after 5 s (question 1).

## Commit message

```
Fix the taken-colours band so it stops over the game (B-028)

The band compared the host's answer with the live saved profile, so a
colour change in Settings made them differ at once and it never expired.
The client now records the character its hello asked for in the
snapshot, and the band compares the host's answer with that colour. It
goes after 5 s, or when the game starts or ends on the phone, whichever
is first; a new colour applies on the next join.
```

## Status row

**bugs14 (Nov 15, done, unpushed, nothing built):** B-028 (the "Blue is taken tonight" band stuck over the game after a colour change in Settings): the band compares the host's answer with the colour the last hello asked for (`ClientSnapshot.askedCharacter`, recorded where the hello is built) and hides after 5 s or when the game starts or ends. Fixed, unverified: needs a device check (two phones pick blue: the band shows at join and clears by itself; a Settings colour change while joined shows no band). Open: the host phone's own player's band ends on the 5 s only, and the band can sit over the host-away card for up to 5 s (report questions 1–2).

## Delete

- none
