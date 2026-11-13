#!/usr/bin/env bash
# headless-env.sh
# Prints KEY=value lines for headless mode, or one "ERROR: <code>" line.
# Only WORKSPACE_HEADLESS=1 turns headless on. Any other value prints HEADLESS=0.
# Codes: no_ticket, invalid_bound.
if [ "${WORKSPACE_HEADLESS:-}" != 1 ]; then
  echo "HEADLESS=0"
  exit 0
fi
ticket="${WORKSPACE_TICKET:-}"
if [ -z "$ticket" ]; then
  echo "ERROR: no_ticket"
  exit 1
fi
minutes="${WORKSPACE_MAX_MINUTES:-60}"
retries="${WORKSPACE_MAX_IMPL_RETRIES:-1}"
tasks="${WORKSPACE_MAX_TASKS:-10}"
for v in "$minutes" "$retries" "$tasks"; do
  case "$v" in
    '' | *[!0-9]*) echo "ERROR: invalid_bound"; exit 1 ;;
  esac
done
# Strip leading zeros with no integer arithmetic ("08" -> "8", "000" -> "0").
for name in minutes retries tasks; do
  eval "v=\$$name"
  while :; do
    case "$v" in 0?*) v="${v#0}" ;; *) break ;; esac
  done
  eval "$name=\$v"
done
# Retries never exceed 1. A string compare avoids integer overflow.
case "$retries" in 0 | 1) ;; *) retries=1 ;; esac
# Other bounds have at most 9 digits, so later arithmetic cannot overflow.
if [ "${#minutes}" -gt 9 ] || [ "${#tasks}" -gt 9 ]; then
  echo "ERROR: invalid_bound"; exit 1
fi
echo "HEADLESS=1"
echo "TICKET=$ticket"
echo "MAX_MINUTES=$minutes"
echo "MAX_IMPL_RETRIES=$retries"
echo "MAX_TASKS=$tasks"
