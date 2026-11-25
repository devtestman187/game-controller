# Sourced by tools/brief-check.sh, not run on its own: the per-brief rules of the tune2 batch.
# Uses the parent's field, fail and warn.
#   shrink  FAIL: a do: line shrinks layout (FittedBox, scale-down, smaller font or size to fit) and
#           the brief names no 48 dp touch-target test (`48 dp`, `48dp`, `touch-target`). A brief
#           with a `touch-target: exempt <reason>` line is let through (wave1-789: a shrunk dialog
#           lost its 48 dp targets unseen until the review).
#   model   FAIL: `model:` is not haiku or sonnet; a `model: sonnet` brief has no `turns:` line
#           (Sonnet briefs carry an explicit turns: about 50).

rules_check() { # rules_check <job> <brief>
  local job=$1 brief=$2 m
  m=$(field "$brief" model)
  case $m in
    '' | haiku) ;;
    sonnet) [ -n "$(field "$brief" turns)" ] || fail "model $job: model: sonnet needs an explicit turns: line (about 50)" ;;
    *) fail "model $job: model: must be haiku or sonnet, got $m" ;;
  esac
  if sed -n 's/^[0-9][0-9]* //p' "$brief" |
    grep -qiE 'FittedBox|scale-?down|smaller (font|size|text|icon)|shrink|reduce[sd]? (the )?(font|size)'; then
    field "$brief" touch-target | grep -q '^exempt' && return 0
    grep -qiE '48 ?dp|touch[- ]target' "$brief" ||
      fail "shrink $job: a do: line shrinks layout and the brief lists no 48 dp touch-target test (or add touch-target: exempt <reason>)"
  fi
  return 0
}
