# openclaw-skills

Backup repository for custom OpenClaw skills.

## Structure

- `skills/` — individual skill folders
  - `portfolio-builder-v2/` — workflows and command guidance for the portfolio-builder v2 project
  - `remote-android-adb/` — remote Android ADB over Tailscale + SSH relay
  - `skill-backup-flow/` — standardized skill backup workflow with sanitization checks and git push
  - `v2ray-fleet-ops/` — role-aware V2Ray fleet operations (health checks, cautious OS upgrades, SSH-config-driven node management)

## Safety

- Do not commit private runtime config files containing real hosts, usernames, device serials, PINs, or tokens.
- Keep only sanitized examples under `references/`.
