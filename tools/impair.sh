#!/usr/bin/env bash
# Test-only network impairment for the headless proof (M15 opt2c): the browser's
# hop to the player relay on the loopback alias 127.0.0.2, in the tp-stream distro,
# with `tc netem` (installed there). Nothing else on loopback is touched.
#
#   wsl -d tp-stream -u root -- bash <repo>/tools/impair.sh <profile> <start_delay_s> <seconds>
#   profiles: stall (200-500 ms blackholes every ~3 s) | loss (1.5 %) | rate (11 Mbit/s cap)
#             | all (loss 1 %, 12 Mbit/s, stalls) | clear
# The impairment always ends: after <seconds>, on a signal, and on exit.
set -u
profile="${1:-clear}"; delay_s="${2:-0}"; secs="${3:-30}"
dev=lo; ip=127.0.0.2
clear_all() { tc qdisc del dev "$dev" root 2>/dev/null || true; }
setup() {
  clear_all
  tc qdisc add dev "$dev" root handle 1: prio bands 3 priomap 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
  tc qdisc add dev "$dev" parent 1:3 handle 30: netem delay 1ms
  tc filter add dev "$dev" parent 1: protocol ip prio 1 u32 match ip dst "$ip"/32 flowid 1:3
  tc filter add dev "$dev" parent 1: protocol ip prio 1 u32 match ip src "$ip"/32 flowid 1:3
}
set_netem() { tc qdisc change dev "$dev" parent 1:3 handle 30: netem "$@"; }
trap clear_all EXIT INT TERM
[[ "$profile" == clear ]] && { clear_all; echo "impair: cleared"; exit 0; }
sleep "$delay_s"
setup
echo "impair: $profile on for ${secs}s at $(date +%T)"
end=$((SECONDS + secs))
base=(delay 1ms)
case "$profile" in
  loss) base=(delay 2ms loss 1.5%) ;;
  rate) base=(delay 1ms rate 11mbit limit 200) ;;
  all) base=(delay 2ms loss 1% rate 12mbit limit 200) ;;
esac
set_netem "${base[@]}"
if [[ "$profile" == stall || "$profile" == all ]]; then
  while (( SECONDS < end )); do
    sleep 3
    ms=$((200 + RANDOM % 301))
    echo "impair: stall ${ms} ms at $(date +%T.%N)"
    set_netem loss 100%
    sleep "0.$(printf %03d "$ms")"
    set_netem "${base[@]}"
  done
else
  sleep "$secs"
fi
clear_all
echo "impair: ended at $(date +%T)"
