#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  is_locked.sh --config <path> [--verbose]

Outputs:
  LOCKED     (exit 0)
  UNLOCKED   (exit 0)

Notes:
  - Uses KeyguardServiceDelegate fields from `dumpsys window policy`.
  - `showing=true` or `mIsShowing=true` => LOCKED
EOF
}

CONFIG=""
VERBOSE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --config)
      CONFIG="${2:-}"
      shift 2
      ;;
    --verbose)
      VERBOSE=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Error: unknown arg: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$CONFIG" || ! -f "$CONFIG" ]]; then
  echo "Error: --config is required and must point to an existing file" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REMOTE_ADB="$SCRIPT_DIR/remote_adb.sh"

if [[ ! -x "$REMOTE_ADB" ]]; then
  echo "Error: remote_adb.sh not found or not executable at: $REMOTE_ADB" >&2
  exit 1
fi

POLICY_OUT="$($REMOTE_ADB --config "$CONFIG" shell dumpsys window policy)"

SHOWING="$(printf '%s\n' "$POLICY_OUT" | sed -n 's/^[[:space:]]*showing=\(true\|false\).*/\1/p' | head -n1)"
MISSHOWING="$(printf '%s\n' "$POLICY_OUT" | sed -n 's/^[[:space:]]*mIsShowing=\(true\|false\).*/\1/p' | head -n1)"
INTERACTIVE="$(printf '%s\n' "$POLICY_OUT" | sed -n 's/^[[:space:]]*interactiveState=\(.*\)$/\1/p' | head -n1)"
SCREEN_STATE="$(printf '%s\n' "$POLICY_OUT" | sed -n 's/^[[:space:]]*screenState=\(.*\)$/\1/p' | head -n1)"

STATE="UNLOCKED"
if [[ "$SHOWING" == "true" || "$MISSHOWING" == "true" ]]; then
  STATE="LOCKED"
fi

echo "$STATE"

if [[ "$VERBOSE" -eq 1 ]]; then
  echo "showing=${SHOWING:-unknown}"
  echo "mIsShowing=${MISSHOWING:-unknown}"
  echo "interactiveState=${INTERACTIVE:-unknown}"
  echo "screenState=${SCREEN_STATE:-unknown}"
fi
