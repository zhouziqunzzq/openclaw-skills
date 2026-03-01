#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  backup_skill.sh --source <skill_dir> --repo <git_repo_dir> [--message <commit_message>]
  backup_skill.sh --source <skill_dir> --config <config.json> [--message <commit_message>]

Example:
  backup_skill.sh \
    --source /home/harry/.openclaw/workspace/skills/remote-android-adb \
    --config /home/harry/.openclaw/skill-backup-flow.json
EOF
}

SOURCE=""
REPO=""
CONFIG=""
MSG=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --source) SOURCE="$2"; shift 2 ;;
    --repo) REPO="$2"; shift 2 ;;
    --config) CONFIG="$2"; shift 2 ;;
    --message) MSG="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ -n "$CONFIG" ]]; then
  [[ -f "$CONFIG" ]] || { echo "Config not found: $CONFIG" >&2; exit 1; }
  if ! command -v python3 >/dev/null 2>&1; then
    echo "python3 is required for --config" >&2
    exit 1
  fi
  CFG_REPO=$(python3 - "$CONFIG" <<'PY'
import json, os, sys
p=os.path.expanduser(sys.argv[1])
with open(p,'r',encoding='utf-8') as f:
    c=json.load(f)
print(os.path.expanduser(c.get('repo_path','')))
PY
)
  if [[ -z "$REPO" ]]; then
    REPO="$CFG_REPO"
  fi
fi

[[ -d "$SOURCE" ]] || { echo "Source not found: $SOURCE" >&2; exit 1; }
[[ -n "$REPO" ]] || { echo "Missing repo path. Use --repo or --config" >&2; exit 1; }
[[ -d "$REPO/.git" ]] || { echo "Not a git repo: $REPO" >&2; exit 1; }

SKILL_NAME="$(basename "$SOURCE")"
DEST="$REPO/skills/$SKILL_NAME"
mkdir -p "$REPO/skills"
rsync -a --delete "$SOURCE/" "$DEST/"

# High-signal patterns to reduce false positives in docs.
SCAN_REGEX='BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY|ghp_[A-Za-z0-9]{20,}|sk-[A-Za-z0-9]{20,}|xox[baprs]-[A-Za-z0-9-]{10,}|telegram:[0-9]{6,}|\+?[0-9][0-9 \-]{9,}'
SCAN_OUT="$(grep -RInE "$SCAN_REGEX" "$DEST" || true)"

if [[ -n "$SCAN_OUT" ]]; then
  echo "Potential sensitive matches found:" >&2
  echo "$SCAN_OUT" >&2
  echo "Sanitize files, then rerun." >&2
  exit 2
fi

git -C "$REPO" add "skills/$SKILL_NAME"
if git -C "$REPO" diff --cached --quiet; then
  echo "No changes to commit for $SKILL_NAME"
  exit 0
fi

if [[ -z "$MSG" ]]; then
  MSG="Backup skill: $SKILL_NAME (sanitized)"
fi

git -C "$REPO" commit -m "$MSG"
git -C "$REPO" push

echo "Backup complete: $SKILL_NAME"
