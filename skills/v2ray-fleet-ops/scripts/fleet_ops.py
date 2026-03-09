#!/usr/bin/env python3
import argparse
import json
import shlex
import subprocess
import sys
from pathlib import Path


def run(cmd: str):
    p = subprocess.run(cmd, shell=True, text=True, capture_output=True)
    return p.returncode, p.stdout.strip(), p.stderr.strip()


def ssh_target(node):
    user = node.get("user", "root")
    host = node["host"]
    port = int(node.get("port", 22))
    return f"{user}@{host}", port


def ssh_cmd(node, remote_cmd, timeout=20):
    target, port = ssh_target(node)
    cmd = (
        f"ssh -o BatchMode=yes -o ConnectTimeout={timeout} -p {port} "
        f"{shlex.quote(target)} {shlex.quote(remote_cmd)}"
    )
    return run(cmd)


def select_nodes(cfg, roles):
    nodes = cfg.get("nodes", [])
    if not roles:
        return nodes
    out = []
    role_set = set(roles)
    for n in nodes:
        nroles = set(n.get("roles", []))
        if role_set.intersection(nroles):
            out.append(n)
    return out


def health(node):
    rc, out, err = ssh_cmd(
        node,
        """
set -e
printf 'host=%s\n' "$(hostname)"
if [ -f /etc/os-release ]; then os=$(grep '^PRETTY_NAME=' /etc/os-release | cut -d= -f2- | tr -d '"'); printf 'os=%s\n' "$os"; fi
printf 'kernel=%s\n' "$(uname -r)"
printf 'uptime=%s\n' "$(uptime -p)"
if command -v df >/dev/null; then
  disk_line=$(df -hP / | awk 'NR==2 {print $2" used=" $3" avail=" $4" use%=" $5}')
  inode_line=$(df -iP / | awk 'NR==2 {print "inodes=" $2" iused=" $3" ifree=" $4" iuse%=" $5}')
  printf 'disk_root=%s\n' "$disk_line"
  printf 'disk_inode_root=%s\n' "$inode_line"
fi
if command -v apt >/dev/null; then
  c=$(apt list --upgradable 2>/dev/null | tail -n +2 | wc -l)
  printf 'pkg=apt upgradable=%s\n' "$c"
elif command -v dnf >/dev/null; then
  dnf -q check-update >/dev/null; ec=$?
  if [ $ec -eq 100 ]; then s=available; elif [ $ec -eq 0 ]; then s=none; else s=error_$ec; fi
  printf 'pkg=dnf updates=%s\n' "$s"
fi
if command -v docker >/dev/null; then
  printf 'docker=installed\n'
  docker ps --format 'ctr={{.Names}}|{{.Status}}' | sed -n '1,20p'
else
  printf 'docker=missing\n'
fi
""",
    )
    return rc, out, err


def upgrade(node, aggressive=False):
    # Conservative defaults for relay/egress nodes.
    rc, out, err = ssh_cmd(
        node,
        """
set -e
if command -v apt >/dev/null; then
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y
  apt-get upgrade -y
elif command -v dnf >/dev/null; then
  dnf -y clean all
  dnf -y makecache
  if dnf module list container-tools 2>/dev/null | grep -q '\\[e\\]'; then
    dnf -y module reset container-tools || true
    dnf -y module disable container-tools || true
  fi
  if [ """ + ("1" if aggressive else "0") + """ = "1" ]; then
    dnf -y upgrade --allowerasing
  else
    dnf -y upgrade
  fi
else
  echo 'No supported package manager found' >&2
  exit 2
fi
""",
        timeout=25,
    )
    return rc, out, err


def main():
    ap = argparse.ArgumentParser(description="Operate a v2ray node fleet via SSH")
    ap.add_argument("--config", required=True, help="Path to fleet config JSON")
    ap.add_argument("--role", action="append", default=[], help="Filter by role (repeatable)")
    sub = ap.add_subparsers(dest="cmd", required=True)
    sub.add_parser("health")
    up = sub.add_parser("upgrade")
    up.add_argument("--aggressive", action="store_true", help="Allow allowerasing on dnf nodes")
    args = ap.parse_args()

    cfg = json.loads(Path(args.config).read_text())
    nodes = select_nodes(cfg, args.role)
    if not nodes:
        print("No nodes matched filter", file=sys.stderr)
        sys.exit(1)

    failed = 0
    for n in nodes:
        name = n.get("name", n["host"])
        roles = ",".join(n.get("roles", []))
        print(f"\n=== {name} ({n['host']}:{n.get('port',22)}) roles=[{roles}] ===")
        if args.cmd == "health":
            rc, out, err = health(n)
        else:
            rc, out, err = upgrade(n, aggressive=args.aggressive)
        if out:
            print(out)
        if err:
            print(err, file=sys.stderr)
        if rc != 0:
            failed += 1
            print(f"[FAIL] exit={rc}", file=sys.stderr)
        else:
            print("[OK]")

    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
