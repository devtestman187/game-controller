# night2c v1b — the setup offers Vote

tests-first: exempt the offered list is data; the updated tests pin the new list.

## Files changed
- night_setup_options.dart: offeredPickers now host, director, shuffle, playlist, vote; Rotating stays hidden.
- night_setup_text.dart: added pickerVoteHelp; pickerHelp(vote) returns it, rotating keeps the host line.
- night_setup_options_test.dart: Vote offered last (exact list), Rotating not offered.
- night_setup_screen_test.dart: last-row test taps Vote, checks picker vote saved and its help line shows; the "no
  Vote word" check dropped (the Vote chip now exists).
- night_labels_fit_test.dart, phone_fit_matrix_test.dart, night_setup_screen.dart: unchanged (fit tests pass, the
  chip list already follows offeredPickers).

## Computed values
None; expectations are the literal picker list and the help text.

## Checks
tools/mine.sh: OK 36 tests packages/party_host (format, analyze clean).

## Questions
None.

## Suggestions
None.

## Commit message
night2c v1b: the setup offers the Vote picker

offeredPickers gains Vote as the last row; pickerHelp(vote) shows the new
pickerVoteHelp line. Rotating stays hidden for M17b. Tests pin the new list,
tap the Vote row and check its help line.

## Status row
v1b done: the setup offers Vote (last row, help line, tests); Rotating still hidden for M17b.

## Delete
- none
