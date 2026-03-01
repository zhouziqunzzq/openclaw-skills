#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  unlock_device.sh --config <path>

Reads unlock settings from config JSON and runs the selected unlock macro.

Supported macros:
  - miui_swipe_pin   : wake -> long swipe up -> input PIN -> optional Enter
  - wake_menu_pin    : wake -> KEYCODE_MENU(82) -> input PIN -> optional Enter
EOF
}

CONFIG=""
if [[ ${1:-} == "--config" ]]; then
  CONFIG=${2:-}
  shift 2
else
  echo "Error: --config is required" >&2
  usage
  exit 1
fi

if [[ -z "$CONFIG" || ! -f "$CONFIG" ]]; then
  echo "Error: config file not found: $CONFIG" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REMOTE_ADB="$SCRIPT_DIR/remote_adb.sh"

if [[ ! -x "$REMOTE_ADB" ]]; then
  echo "Error: remote_adb.sh not found or not executable at: $REMOTE_ADB" >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "Error: python3 is required to parse JSON config" >&2
  exit 1
fi

readarray -t UCFG < <(python3 - "$CONFIG" <<'PY'
import json, os, sys
p = os.path.expanduser(sys.argv[1])
with open(p, 'r', encoding='utf-8') as f:
    c = json.load(f)

u = c.get('unlock', {})
macro = u.get('macro', 'miui_swipe_pin')
pin = str(u.get('pin', ''))
submit_enter = bool(u.get('submit_enter', True))
wake = int(u.get('wake_keyevent', 224))

sw = u.get('swipe', {})
x1 = int(sw.get('x1', 540))
y1 = int(sw.get('y1', 2200))
x2 = int(sw.get('x2', 540))
y2 = int(sw.get('y2', 280))
dur = int(sw.get('duration_ms', 320))

print(macro)
print(pin)
print('1' if submit_enter else '0')
print(wake)
print(x1)
print(y1)
print(x2)
print(y2)
print(dur)
PY
)

MACRO="${UCFG[0]}"
PIN="${UCFG[1]}"
SUBMIT_ENTER="${UCFG[2]}"
WAKE_KEY="${UCFG[3]}"
X1="${UCFG[4]}"
Y1="${UCFG[5]}"
X2="${UCFG[6]}"
Y2="${UCFG[7]}"
DUR="${UCFG[8]}"

if [[ -z "$PIN" ]]; then
  echo "Error: unlock.pin is empty in config" >&2
  exit 1
fi

run_adb() {
  "$REMOTE_ADB" --config "$CONFIG" "$@"
}

case "$MACRO" in
  miui_swipe_pin)
    run_adb shell input keyevent "$WAKE_KEY"
    sleep 0.25
    run_adb shell input swipe "$X1" "$Y1" "$X2" "$Y2" "$DUR"
    sleep 0.20
    run_adb shell input text "$PIN"
    if [[ "$SUBMIT_ENTER" == "1" ]]; then
      run_adb shell input keyevent 66
    fi
    ;;
  wake_menu_pin)
    run_adb shell input keyevent "$WAKE_KEY"
    sleep 0.20
    run_adb shell input keyevent 82
    sleep 0.20
    run_adb shell input text "$PIN"
    if [[ "$SUBMIT_ENTER" == "1" ]]; then
      run_adb shell input keyevent 66
    fi
    ;;
  *)
    echo "Error: unsupported unlock macro: $MACRO" >&2
    exit 1
    ;;
esac

echo "Unlock macro executed: $MACRO"
