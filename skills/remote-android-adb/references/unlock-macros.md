# Unlock Macros

This skill supports pluggable unlock macros via `unlock.macro` in config.

## Config shape

```json
"unlock": {
  "macro": "miui_swipe_pin",
  "pin": "1234",
  "submit_enter": true,
  "wake_keyevent": 224,
  "swipe": {
    "x1": 540,
    "y1": 2200,
    "x2": 540,
    "y2": 280,
    "duration_ms": 320
  }
}
```

## Supported macros

### 1) `miui_swipe_pin`
Best for MIUI-style lockscreen:
1. Wake (`KEYCODE_WAKEUP`, default 224)
2. Long swipe up
3. Input PIN
4. Optional Enter key submit

### 2) `wake_menu_pin`
Fallback for devices where `KEYCODE_MENU` opens password/PIN UI:
1. Wake
2. `KEYCODE_MENU` (82)
3. Input PIN
4. Optional Enter key submit

## Run command

```bash
./scripts/unlock_device.sh --config ~/.openclaw/remote-android-adb.json
```

## Notes

- Do not hardcode PINs in scripts.
- Keep PIN in local config file with strict permissions (`chmod 600`).
- Tune swipe coordinates/duration per device and lockscreen layout.
