# n9e report: Resume on the host's pause card

## Summary

STOPPED before any code change. No file was edited, and no test was written.

The brief's change cannot be made as described, because its premise is wrong about the code:

- `HostButton` passes `fill` through as `color` to `ToyButton` (`packages/party_host/lib/src/ui/host_button.dart:136`).
- `ToyButton` paints `fill: widget.color ?? look.colors.good` (`packages/toy_look/lib/src/toy_button.dart:235`).
- So a `HostButton` with no `fill` already rests on `look.colors.good`. The paper colour is used only when the button is disabled (`toy_button.dart:332`).

Consequences:

1. Passing `fill: ToyLookScope.of(context).colors.good` to `pauseResume` changes no pixel. The new test would pass on the code as it is, which breaks the tests-first rule (it must fail first).
2. `pauseQuit` is not paper today. It rests on `good` too, so the brief's claim "`pauseQuit` stays paper" is false. Making Quit paper needs a design decision (a paper fill argument, or a change to the look), and that is outside the stated change.

Decision needed from the owner (plan item 9e). Which is wanted?

- (a) Resume and Quit both stay `good`. Then the job is a no-op: close it with no code change.
- (b) Resume `good`, Quit paper. Then Quit needs an explicit paper `fill`, and the test would check that Quit rests on paper and Resume on `good`. This also needs a decision on whether paper is `look.colors.paper` for a resting pill. That may look wrong on the dark TV look, so the owner should see it first.

## Files changed

None.

## Checks

Not run. Nothing was changed, and `tools/mine.sh` was not needed.

## Questions

1. Pick (a) or (b) above. The brief's "Quit stays paper" assumes Quit is paper now, and it is not.
2. If (b): is `look.colors.paper` the right resting fill for Quit on both looks?

## Commit message — a draft: a subject line under 72 characters, a blank line, then at most 8 lines on what changed and why.

(no commit: job stopped before any change)

## Status row — one line for the milestone's STATUS.md: what is now done, and what is open.

n9e: stopped, no change. Resume's `good` fill is already the default, so the change is a no-op; Quit is not paper today. Owner to pick (a) keep both good, or (b) Quit paper.

## Delete

- none
