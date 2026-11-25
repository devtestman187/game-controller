# Sourced by tools/brief-check.sh, not run on its own (tune4 T3, Nov 25): the `pins` WARN. A job that allows a lib
# file defining widgets (a class extending StatelessWidget, StatefulWidget, ConsumerWidget, ConsumerStatefulWidget or
# HookWidget) changes what those widgets show; a test file that names the widget pins it, and if no job of this or an
# earlier wave allows that test, the wave's combined check can fail on it (n8b3 of wave2-789: ~100 Home-first test pins).
# It is a WARN, never a FAIL: a widget test that only builds the widget rarely breaks. Same search as the changes rule
# (search_item, first_allow, allow_covers of brief-check.sh); at most 6 widgets per job are looked up.

pins_warn() { # pins_warn <job> <wave>
  local j=$1 w=$2 a name hit found n=0
  local -a list names
  mapfile -t list < "$tmp/$j.allow"
  for a in ${list[@]+"${list[@]}"}; do
    case $a in */lib/*.dart | lib/*.dart) ;; *) continue ;; esac
    [ -f "$root/$a" ] || continue
    mapfile -t names < <(grep -hoE '^(abstract )?class [A-Z][A-Za-z0-9_]* extends (Stateless|Stateful|Consumer|ConsumerStateful|Hook)Widget' "$root/$a" |
      sed -E 's/^(abstract )?class ([A-Za-z0-9_]+) .*/\2/')
    for name in ${names[@]+"${names[@]}"}; do
      n=$((n + 1))
      [ "$n" -le 6 ] || return 0
      while IFS= read -r hit; do
        case $hit in */test/*_test.dart | test/*_test.dart) ;; *) continue ;; esac
        allow_covers "$j" "$hit" && continue
        made_by "$j" "$hit" && continue
        found=$(first_allow "$hit")
        if [ -n "$found" ] && [ "${found##* }" -le "$w" ]; then continue; fi
        warn "pins $j: $hit names the widget $name of $a, but no job of wave $w or earlier allows that test; its pins may break"
      done < <(search_item "$name")
    done
  done
  return 0
}
