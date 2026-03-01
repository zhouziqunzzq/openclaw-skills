#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  remote_adb.sh --config <path> <adb-subcommand> [args...]

Examples:
  remote_adb.sh --config ~/.openclaw/remote-android-adb.json devices
  remote_adb.sh --config ~/.openclaw/remote-android-adb.json shell getprop ro.product.model
  remote_adb.sh --config ~/.openclaw/remote-android-adb.json pull /sdcard/screen.png ./screen.png
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

if [[ $# -lt 1 ]]; then
  usage
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "Error: python3 is required to parse JSON config" >&2
  exit 1
fi

readarray -t CFG < <(python3 - "$CONFIG" <<'PY'
import json, os, shlex, sys
p = os.path.expanduser(sys.argv[1])
with open(p, 'r', encoding='utf-8') as f:
    c = json.load(f)

def g(k, d=""):
    v = c.get(k, d)
    if isinstance(v, str):
        return os.path.expanduser(v)
    return v

host = g('ssh_host')
user = g('ssh_user')
port = str(g('ssh_port', 22))
ident = g('ssh_identity_file', '~/.ssh/id_ed25519')
adb = g('adb_path', 'adb')
serial = g('device_serial', '')
relay_tmp = g('relay_tmp_dir', '/tmp')
extra = c.get('ssh_extra_args', [])

if not host or not user:
    print('ERROR')
    sys.exit(2)

print(host)
print(user)
print(port)
print(ident)
print(adb)
print(serial)
print(relay_tmp)
print(' '.join(shlex.quote(x) for x in extra))
PY
)

if [[ ${CFG[0]:-} == "ERROR" || ${#CFG[@]} -lt 8 ]]; then
  echo "Error: invalid config. Need at least ssh_host and ssh_user." >&2
  exit 1
fi

SSH_HOST="${CFG[0]}"
SSH_USER="${CFG[1]}"
SSH_PORT="${CFG[2]}"
SSH_IDENTITY="${CFG[3]}"
ADB_PATH="${CFG[4]}"
DEVICE_SERIAL="${CFG[5]}"
RELAY_TMP_DIR="${CFG[6]}"
SSH_EXTRA_RAW="${CFG[7]}"

# Build SSH command safely
SSH_CMD=(ssh -p "$SSH_PORT" -i "$SSH_IDENTITY" -o BatchMode=yes)
if [[ -n "$SSH_EXTRA_RAW" ]]; then
  # shellcheck disable=SC2206
  EXTRA_ARR=( $SSH_EXTRA_RAW )
  SSH_CMD+=("${EXTRA_ARR[@]}")
fi
SSH_CMD+=("$SSH_USER@$SSH_HOST")

ADB_BASE=("$ADB_PATH")
if [[ -n "$DEVICE_SERIAL" ]]; then
  ADB_BASE+=( -s "$DEVICE_SERIAL" )
fi

subcmd="$1"
shift || true

if [[ "$subcmd" == "pull" ]]; then
  if [[ $# -ne 2 ]]; then
    echo "Error: pull requires <remote_path_on_phone> <local_path_on_vps>" >&2
    exit 1
  fi
  remote_phone_path="$1"
  local_vps_path="$2"

  stamp="$(date +%s)"
  relay_file="$RELAY_TMP_DIR/remote_adb_pull_${stamp}_$$"

  # 1) run adb pull on relay (phone -> relay local file)
  remote_cmd=$(printf '%q ' "${ADB_BASE[@]}" pull "$remote_phone_path" "$relay_file")
  "${SSH_CMD[@]}" "$remote_cmd"

  # 2) scp relay file to VPS local path
  scp -P "$SSH_PORT" -i "$SSH_IDENTITY" "$SSH_USER@$SSH_HOST:$relay_file" "$local_vps_path"

  # 3) cleanup relay temp
  "${SSH_CMD[@]}" "rm -f $(printf '%q' "$relay_file")"

  echo "Pulled $remote_phone_path -> $local_vps_path"
  exit 0
fi

# Generic adb passthrough
remote_cmd=$(printf '%q ' "${ADB_BASE[@]}" "$subcmd" "$@")
"${SSH_CMD[@]}" "$remote_cmd"
