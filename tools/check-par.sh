# The parallel suites of tools/check.sh: sourced by check.sh when -j N or CHECK_JOBS=N is above 1, never
# run on its own. It uses check.sh's variables and functions (deferred, jobs, logs, root, run_cmd,
# skipped_by_env, skip_reason, print_result). Each suite runs in the background into its own log and
# writes a status file last; the lines print afterwards in check order, as the serial run prints them.
# Bash 3.2 has no `wait -n`, so the running suites are polled for their status files.

# run_parallel_suites: runs the deferred suites jobs at a time, then prints each one's line in check order.
run_parallel_suites() {
  local i n name dir cmd about rc secs
  local -a line_name skip_line active pid_of
  n=${#deferred[@]}
  line_name=()
  skip_line=()
  active=()
  pid_of=()
  for ((i = 0; i < n; i++)); do
    IFS='|' read -r name dir cmd about <<< "${deferred[i]}"
    line_name[i]="$name"
    if skipped_by_env "$name"; then
      skip_line[i]="SKIPPED $name (CHECK_SKIP)"
    elif [ -n "$skip_reason" ]; then
      skip_line[i]="SKIPPED $name ($skip_reason)"
    else
      while [ ${#active[@]} -ge "$jobs" ]; do
        sleep 0.2
        reap_finished
      done
      start_suite "$i" "$name" "$dir" "$cmd"
    fi
  done
  while [ ${#active[@]} -gt 0 ]; do
    sleep 0.2
    reap_finished
  done
  for ((i = 0; i < n; i++)); do
    if [ -n "${skip_line[i]:-}" ]; then
      printf '%s\n' "${skip_line[i]}"
    else
      read -r rc secs < "$logs/${line_name[i]}.status"
      print_result "${line_name[i]}" "$rc" "$secs" "$logs/${line_name[i]}.log"
    fi
  done
}

# start_suite <index> <name> <folder> <command>: runs one suite in the background; its status file (the
# exit code and the seconds) is written last, so a file that exists means the suite has finished.
start_suite() {
  local i="$1" name="$2" dir="$3" cmd="$4" log status start
  log="$logs/$name.log"
  status="$logs/$name.status"
  (
    start=$(date +%s)
    (cd "$root/$dir" && run_cmd "$cmd") > "$log" 2>&1
    rc=$?
    echo "$rc $(($(date +%s) - start))" > "$status.tmp" && mv "$status.tmp" "$status"
  ) &
  pid_of[i]=$!
  active+=("$i")
}

# reap_finished: drops each active suite whose status file exists, and reaps its process.
reap_finished() {
  local kept=() i
  for i in ${active[@]+"${active[@]}"}; do
    if [ -f "$logs/${line_name[i]}.status" ]; then
      wait "${pid_of[i]}"
    else
      kept+=("$i")
    fi
  done
  active=(${kept[@]+"${kept[@]}"})
}
