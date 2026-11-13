# M15 opt2b-4 (sound) — report

## Summary

With `player=wc` the sound now starts: the sound-only WebRTC stream goes on the audio element,
the page shows its "tap to start sound" button when the browser refuses, and a tap **anywhere**
(pointerdown or touchend, once) starts it inside that gesture — on the canvas, on the button, and
again after a reconnect. The sound's state is a fact (`wcsnd`: `none`, `blocked`, `playing`), a
gauge (`wcSoundPlaying` 0/1), a word in the overlay's `wc` line, and two new columns of the report's
"Custom player (wc)" table. `player=webrtc` is untouched.

Root cause of "no sound on the iPhone with SESSION_AUDIO=separate": **proved** on the page,
suspected on the device. The sound-only connection *was* made in wc mode and `play()` *was* called
(brief item 1: yes to all three), but the only control the page offered was wired to
`playback.unmute()`, and in wc mode `Playback.hasSound` is false (the canvas draws the picture, so
`playback.show()` never runs). `unmute()` therefore did `this._sound.muted = !this.hasSound` = true —
it **muted** the very element it was meant to start — hid the button, and then played the hidden,
source-less video element, whose `play()` rejects, so the page said "cannot start the sound: …".
Nothing else unmuted the element until a new stream arrived, so a tap could only lose the sound.
Safari refusing the first ungestured `play()` is the standard rule and **suspected** to be the
reason the button appeared; it cannot be seen from here (no session runs in this batch, no device).

- `wc_sound.js` (new, 137): `WcSound` (the element, the tap, the state), `wcSoundStates`,
  `wcSoundFactText`.
- `wc_sound_selftest.html` (new, 243): 13 checks on a fake audio element whose `play()` a browser
  refuses until a tap, a fake button and a fake tap target.
- `player.js` 380 → **380**: `playSoundOnly` folded into `showSound` (the wc branch), the sound's
  object made once beside the overlay, the button's action is the mode's own, `endSession` stops it.
- `wc_stats.js` 250 → 265: optional `soundState` provider on `WcStats`/`wcStatsOf`, the gauge, the
  fact and the `snd` word in the line; no provider → nothing added, so every existing check holds.
- `report_stream_wc.dart`: two columns (`sound`, `snd playing`), two private name constants.
- Tests: `wc_sound_selftest.html` **13/13** (run by hand, see obstacles), `marker_selftest` 60/60,
  `jbtarget_selftest` 24/24, `wc_selftest` 30/30, `wc_stats_selftest` 28/28,
  `secure_selftest` 8/8; metrics package **168 tests pass**; `dart format` 0 changed;
  `tools/check.sh format` PASS.
- Obstacle: `bench.sh --selftest` lists the pages it runs, and `bench.sh` is outside `allow:`, so
  the new page was loaded by the same headless Chrome by hand (command in Hand-over); it must be
  added to that list by a later job (question 1).

## Decisions (why)

1. The sound's code went into a new `wc_sound.js`: `player.js` was already at its 380-line cap, and
   keeping `playSoundOnly` plus the tap there would have made it 386. It ends at 380 exactly.
2. The state reaches the batch through an **optional** `soundState` provider on `WcStats`
   (`wcStatsOf(options, player, soundState)`), not through a default: a page that passes none sends
   neither gauge nor fact, so `wc_stats_selftest.html`'s exact gauge-list and line checks (and any
   other page) stay true, and only the wc page adds the sound.
3. `wcSoundPlaying` is a **gauge** (0/1), as `reporter.js` takes only stages, gauges and facts from
   an extra series (f3 decision 3); a run's `max` is 1 when the sound played at any point.
4. The overlay's `wc` line carries the sound's **word** (`snd playing`) and the table carries both
   the word and the 0/1: the number is the same information, the word is what a person reads.
5. `wireSoundButton` gets the mode's own action: with `player=wc` a tap anywhere (the button
   included) is `WcSound.tap()`, so the button's click only adds the fullscreen request;
   `player=webrtc` keeps `() => playback.unmute()` character for character. A chosen action, not a
   branch inside the sound code.
6. The tap target is `document`: `#sound` is a full-page overlay button and the canvas sits beneath
   it, so one listener on the page covers the canvas, the button and everything else, as the brief
   asks.
7. A `play()` that resolves but leaves `element.paused` true counts as `blocked` — the brief's "or
   the sound has not started" — because a browser may answer and still not start.
8. An unknown state is reported as `none` in the fact: the host drops a fact it cannot read, so a
   word it does not know would be a lost fact instead of a state (f3's rule for the error text).
9. The sound's own refusal is logged with `console.warn` and turned into the `blocked` state, the
   boundary being the browser's autoplay policy; it is never shown to a viewer as an error, because
   "tap the screen to start the sound" is what to do next.
10. An ended session stops the sound (`wcSound?.stop()` in `endSession`): element paused and
    emptied, button hidden, tap listener removed, so a tab left open starts nothing.

## Tests and values

`wc_sound_selftest.html`, 13 checks, on a fake element (its `play()` refuses the first *n* calls with
`NotAllowedError`, `pause()` sets `paused`), a fake button and a fake `EventTarget`:

- allowed play: state `playing`, `muted` false, `srcObject.id` `sound-stream`, button hidden, no
  line shown.
- one refusal: state `blocked`, button visible, the line `tap the screen to start the sound` once.
- `play()` that answers but never unpauses: state `blocked`, `paused` true, button visible.
- tap after one refusal: state `playing`, **2** plays (one refused, one accepted), `muted` false,
  `paused` false, button hidden, lines `[tap …, playing]`.
- `touchend` instead of `pointerdown`: state `playing`, 2 plays; two more taps and a `touchend` leave
  the count at **2** (the tap is asked for once).
- `sound.tap()` (the page's button): state `playing`, 2 plays, button hidden.
- a reconnect with two refusals: `play(null)` gives state `none` and `srcObject` null, then the new
  stream is refused and the tap starts it — state `playing`, `srcObject.id` `second`, 3 plays.
- no stream: state `none`, **0** plays after a tap, button hidden, no line.
- `stop()`: state `none`, `srcObject` null, `paused` true, plays stay at **1**, button hidden, and a
  later tap plays nothing.
- `wcSoundFactText`: `none`→`none`, `blocked`→`blocked`, `playing`→`playing`, `undefined`→`none`,
  `wat`→`none`.
- batch with `soundState` `playing`: gauge `wcSoundPlaying` **1**, fact `wcsnd` = `playing`, and the
  line contains `snd playing`; with `blocked`: gauge **0**, fact `blocked`; with no provider: the
  gauge is absent and the fact undefined.

Before the code, the page could not run at all: with `wc_sound.js` moved away the page stays at
`SELFTEST RUNNING` (checked in the distro copy, then restored). The wc sound behaviour it checks did
not exist before this job.

Dart, `report_stream_wc_test.dart`: the main row sends `wcSoundPlaying` 0 then 1 (max **1**) and the
fact `wcsnd` `playing` → cells `playing`, `1` (the stage medians are still 11.0 and 3.0, drops 5,
backlog 3, keys 2, queue 2, errors 2, rebuilds 2, error `EncodingError boom`); a page with no decoder
numbers and no sound numbers shows a dash in all **fourteen** columns after the viewer; a page that
needed a tap shows `cfg hw dec ok  - - -  blocked  0`.

Runs: in `tp-stream`, `timeout 300 bash streaming/bench.sh --selftest` → 60/60, 24/24, 30/30, **28/28**,
8/8; `wc_sound_selftest.html` by hand → **13/13**;
`cd packages/metrics && dart test` → **168 tests passed**;
`dart format --output=none --set-exit-if-changed` on both Dart files → 0 changed;
`tools/check.sh format` → PASS.

## Self-check (review-rules part A)

1. Every host setup: the page, not a host — nothing here runs on a TV, PC or phone host; the wc path
   exists only in `streaming/player` behind `player=wc`, `player=webrtc` keeps its own unmute path,
   and a page one build older sends no `wcsnd`/`wcSoundPlaying`, which the new columns show as dashes.
2. When kept state starts and ends: the state starts at `none` with the player, becomes `blocked` on
   a refused start and `playing` on a started one, and ends at `none` with `play(null)` (a sound that
   dropped), `stop()` (the session ended) or a page with no sound stream; the tap listener exists only
   while `blocked`, and a tap ends it.
3. Combining with other states: `playing` clears the tap line, a decoder message is not cleared by
   the sound (it only writes on a refusal or on a tap that worked), the button the sound shows is the
   same one the WebRTC path uses and only one mode ever wires it, and an ended session stops the
   sound before its line says so (tested: retap after `stop()` plays nothing).
4. Stay in the job's folder: only the files in `allow:` were written (`wc_sound.js`,
   `wc_sound_selftest.html`, `player.js`, `wc_stats.js`, the two Dart files, this report);
   `git status` shows those and the six line-ending-only `tv_test_app/*/generated_*` entries.
5. Stop rather than overstep: the new page is not in `bench.sh --selftest`'s list and `bench.sh` is
   outside `allow:` — the page was run by hand with the same headless Chrome (Hand-over), and the
   one-line addition is question 1.

## Hand-over

What exists: `wc_sound.js` (`WcSound`: `state`/`play`/`tap`/`stop`, `wcSoundStates`,
`wcSoundFactText`), `wc_sound_selftest.html`, the wc branch of `showSound` in `player.js`, the
optional `soundState` on `WcStats`/`wcStatsOf` with `wcNames.soundPlaying`/`soundFact`, and the
`sound` + `snd playing` columns in `report_stream_wc.dart`.

Commands that worked:
- `tools/wsl-sync.sh tp-stream`, then in `tp-stream`:
  `cd /work/<folder>/streaming && timeout 300 bash bench.sh --selftest`.
- the new page, by hand: in `streaming/player`, `python3 -m http.server 8793 --bind 127.0.0.1 &`,
  then `/opt/chrome-headless-shell/chrome-headless-shell-linux64/chrome-headless-shell --no-sandbox
  --disable-gpu --dump-dom http://127.0.0.1:8793/wc_sound_selftest.html`, then `pkill -f http.server`.
- `cd packages/metrics && dart test`; `dart format --output=none --set-exit-if-changed <files>`.
- `tools/check.sh format` (at the repository root).

Don't redo: the sound's start is one path (`_start`), for the first stream and for the tap; don't add
a second `play()` call for the button. Nothing in the wc path touches `playback` (its `hasSound` is
false there by design) — a future change that calls `playback.unmute()` in wc mode will mute the
sound again.

Open problems: the fix is only confirmed by code and the fake element — an iPhone run with
`--set SESSION_AUDIO=separate --player-query "player=wc"` is what proves the sound is heard, and the
`wcsnd` fact then reads `playing`.

## Questions and suggestions

1. `bench.sh` (outside `allow:`) should list `wc_sound_selftest.html` in `run_page_selftest`, beside
   `wc_stats_selftest.html`; until then the page is run by hand.
2. A sound stream with no audio track (a host-side fault) still reads `playing`: the element plays
   silence. Should `WcSound` say `none` for a stream whose `getAudioTracks()` is empty?
3. `wcSoundPlaying` and `wcsnd` belong in `StreamWc` (`stream_names.dart`, outside `allow:`); they
   are private constants in `report_stream_wc.dart` for now, as f3's three names are.
4. The overlay's `wc` line shows the word, not the 0/1 (decision 4); say if a number is wanted there.
5. `wc_sound_selftest.html` is a fourth page in this folder; `wc_selftest.html` and
   `wc_stats_selftest.html` are both still at their 500-line caps, so the next wc check needs a
   fifth page (or a split) as f3's hand-over warned.

## Commit message

Player page: the custom player's sound starts after a tap anywhere

In wc mode the sound-only stream plays on the audio element, and the sound's state is `none`,
`blocked` or `playing`. The page's tap-to-start button was wired to `playback.unmute()`, which mutes
the audio element in wc mode (`hasSound` is false there) and hides the button, so a tap could never
start the sound; `WcSound` (new `wc_sound.js`) now owns the element, shows the button and starts it
inside the gesture of a tap anywhere on the page (pointerdown or touchend, once, also after a
reconnect). The state rides the batch as the gauge `wcSoundPlaying` and the fact `wcsnd`, is a word
in the overlay's wc line, and the report's Custom player table gained the `sound` and `snd playing`
columns. `player=webrtc` is unchanged.

## Status row

M15 opt2b-4 done: in wc mode the sound starts after a tap anywhere (also on reconnect) and its state
is sent (`wcsnd`, `wcSoundPlaying`) and reported — open: an iPhone run to hear it, the new page not
in `bench.sh`'s list (question 1), and the names not yet in `StreamWc` (question 3).

## Delete

- none
