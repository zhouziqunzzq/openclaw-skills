# Remote Android ADB Setup Checklist

1. Relay machine (physical/home):
   - Install `android-tools` (or equivalent)
   - Confirm `adb devices` shows phone as `device`
   - Install and connect Tailscale
   - Install and run SSH server

2. OpenClaw host (VPS):
   - Install and connect Tailscale
   - Confirm SSH to relay over Tailscale hostname/IP

3. Create config:
   - Copy `references/config.example.json`
   - Set host/user/identity path/device serial
   - Set `unlock` block (`macro`, `pin`, swipe coordinates) for your device

4. Validate path:
   - `./scripts/remote_adb.sh --config ~/.openclaw/remote-android-adb.json devices`
   - `./scripts/remote_adb.sh --config ~/.openclaw/remote-android-adb.json shell getprop ro.product.model`

5. Security checks:
   - No public router port-forward for ADB
   - SSH key-only auth preferred
   - Tailscale ACL restricted to required nodes/ports
