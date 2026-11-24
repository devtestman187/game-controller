# nk1 report: the phone client lists `night` and exposes the night's end

## Summary

The phone's hello now lists `Capability.night` beside `Capability.identity`. A paired
client that receives a `night_end` message from its host passes it on a new
`ControllerClient.nightEnds` stream. A `night_end` received before pairing is dropped,
as `players` is. No card, no provider, no host change.

Files changed:

- `packages/connection/lib/src/controller_identity.dart`: `libraryCapabilities` is now
  `[Capability.identity, Capability.night]`, documented.
- `packages/connection/lib/src/client_controls.dart`: a broadcast `_nightEnds` stream,
  `nightEnds` getter, `addNightEnd`, closed in `close()`.
- `packages/connection/lib/src/client_messages.dart`: the `NightEndMessage` case goes to
  `addNightEnd`, only while `snapshot.isConnected` (it was a `break` placeholder from nc1).
- `packages/connection/lib/src/controller_client.dart`: `Stream<NightEndMessage> get nightEnds`.
- `packages/connection/test/night_end_client_test.dart` (new): four tests, each run on
  both transports (`TestTransport.values`).
- `packages/connection/test/m9_test.dart`: pinned hello list gets `Capability.night`.
- `packages/connection/test/identity_client_test.dart`: pinned hello list gets `Capability.night`.
- `controller_app/test/phone_metrics_test.dart`: pinned hello list gets `Capability.night`;
  the test name "six capabilities" becomes "seven capabilities" (5 app + identity + night).
- `controller_app/test/support/fakes.dart`: `FakeClient` overrides `nightEnds` with a
  broadcast controller (closed in `dispose`) and adds `void nightEnd(NightEndMessage end)`.

## Tests and values

Tests-first: `night_end_client_test.dart` was written first and failed to load
(`The getter 'nightEnds' isn't defined for the type 'ControllerClient'`), as expected.

Test values (all in `night_end_client_test.dart`, run through the `FakeHost` pairing helper):

1. `the hello lists night beside identity, whatever the app listed`: the app lists nothing;
   the hello is `[Capability.identity, Capability.night]`.
2. `a paired client gets the night_end on nightEnds`: the host sends
   `NightEndMessage(awards: [Fast "Fastest" 2 pts, winners phone-1], standings: [phone-1 #1 "Mia" 2])`
   after connecting; the client's `nightEnds.first` equals it.
3. `a night_end before pairing is dropped, as players is`: the host sends the same message
   just before its pair result. After connecting, the host sends a `PlayersMessage` with one
   player (Dad, number 2), and `clientUntil` sees it; the `nightEnds` listener got nothing.
4. `an older host that never lists or sends night_end leaves the client working as before`:
   the host lists only `identity`, sends a `PlayersMessage` (Dad). The players list shows
   "Dad", the status is `connected`, and `nightEnds` got nothing.

Checks run with `tools/mine.sh` (the final run):

- `OK 18 tests controller_app`
- `OK 53 tests packages/connection`
- `RESULT: ok: 9 file(s) formatted, 2 package(s) analyzed, 2 package(s) tested`

The earlier run, before the lib change, failed to load the new test as described above.
`tools/check.sh` was not run here, as the brief says.

## Self-check (docs/review-rules.md part A)

1. Host setups: this is the phone-client layer only. The tests cover a paired joined phone
   (test 2), a phone before pairing (test 3), and a peer one build older (test 4). The TV and
   "Play on this phone" / "Show on this device" hosts are not touched by this job.
2. Kept state: `_nightEnds` is a broadcast stream owned by `ClientControls`, which lives for
   the app's life; it is closed only in `close()`. Nothing is kept between messages.
   Nothing going on: no event is emitted (test 4).
3. Combinations: the gate is `snapshot.isConnected`, the same gate as `players` and the
   haptics. The pause menu, host away, player away, "Get ready", dropped link, results and
   leaving are not changed by this job; nothing in them reads `nightEnds` yet (that is the card job).
4. Folder and allow: every changed file is in the `allow:` list.
5. Stops: none.
6. Looks: no UI change in this job.

## Hand-over

Nothing is left open in this job. The card (nk2 or later) is the consumer of `nightEnds`.

## Commit message — a draft

```
Phone client lists night and exposes the night's end

The hello now lists Capability.night beside identity, so a host one
build newer sends its night_end to this phone. ClientControls keeps a
broadcast nightEnds stream, fed only while paired, as players is, and
ControllerClient exposes it. An older host sends none and nothing else
changes. FakeClient gets nightEnd() for tests. The pinned hello lists in
m9, identity_client and phone_metrics follow the new entry.
```

## Status row

nk1 done: phone client lists `night` in its hello and exposes the night's end on `nightEnds` (paired only, dropped before pairing); tests in night_end_client_test.dart. Open: the results card that reads `nightEnds` (later nk job); no UI yet.

## Delete

- none
