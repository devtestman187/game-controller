# Sourced by tools/flash.sh (and its test): a brief's `model:` line to the exact model id the claude
# worker needs (claude-worker.sh takes an exact id, never an alias).
#   worker_model <brief value> <default id>  ->  prints the id; exit 2 for an unknown value
# haiku -> claude-haiku-5-5, sonnet -> claude-sonnet-5-5, no line -> the default (CLAUDE_WORKER_MODEL,
# else claude-haiku-5-5). Only claude workers read it; a flash job ignores the line.
worker_model() {
  case "$1" in
    '' ) printf '%s\n' "$2" ;;
    haiku) printf '%s\n' claude-haiku-5-5 ;;
    sonnet) printf '%s\n' claude-sonnet-5-5 ;;
    *) echo "flash: model: must be haiku or sonnet, got $1" >&2; return 2 ;;
  esac
}
