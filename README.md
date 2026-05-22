# Notchmeister — Advance Life Integration

A fork of [chockenberry/Notchmeister](https://github.com/chockenberry/Notchmeister) extended with a native **Advance Life** effect that renders your current life context directly inside the MacBook notch.

---

## What it does

When you select the **Advance Life** effect, the notch becomes a live status bar showing:

```
[●] [▓▓▓░░]  Deep Work: Fix auth bug          2:47 [▓▓▓░░░]
```

### Features

- **Mode dot** — a 10pt circle colored to your current mode (blue for Deep Work, amber for Meeting, red for Workout, etc.). Pulses gently when active, dims when paused.
- **Confidence bar** — a 30pt bar filled to the engine's confidence level for the detected mode, colored to match the mode.
- **Task text** — shows your highest-priority open task from the project tracker, prefixed with the project name. Truncates gracefully if too long.
  - Shows "Focus mode" (dimmed) during Deep Work when task display is suppressed
  - Shows "No active task" when the task list is empty
  - Strikethrough + dimmed when the session is paused
- **PAUSED badge** — a red pill badge that appears when the Advance Life session is paused.
- **Timer bar** — appears when a Pomodoro or custom timer is running:
  - Progress bar fills left to right as time elapses
  - Green when running, amber when paused, blue when completed
  - Countdown label showing `Label: M:SS`
- **Animated transitions** — all state changes animate smoothly at 0.35s via CoreAnimation.
- **Auto-hide** — the container hides automatically when the desktop companion is not running (no state file present).

### Mode colors

| Mode | Color |
|---|---|
| Deep Work | `#3b82f6` Blue |
| Meeting | `#f59e0b` Amber |
| Workout | `#ef4444` Red |
| Commute | `#8b5cf6` Purple |
| Wind Down | `#f97316` Orange |
| Free Time | `#22c55e` Green |
| Morning | `#eab308` Yellow |

---

## How it works

The desktop companion (`apps/desktop-companion`) writes a JSON state file to:

```
~/Library/Application Support/advance-life/notch-state.json
```

Notchmeister polls this file every second. When the file changes, the notch widget updates instantly. If the file is missing or unreadable, the widget hides itself.

### State file format

```json
{
  "mode": "deep_work",
  "confidence": 0.87,
  "paused": false,
  "taskTitle": "Fix auth bug",
  "taskProject": "Advance Life",
  "showTask": true,
  "timer": {
    "state": "running",
    "label": "Pomodoro",
    "totalMs": 1500000,
    "elapsedMs": 420000,
    "remainingMs": 1080000,
    "progress": 0.28
  },
  "updatedAt": 1716000000000
}
```

`timer` is `null` when no timer is active.

---

## Building

1. Clone the parent repo with submodules:
   ```bash
   git clone --recurse-submodules https://github.com/HarmannBitte/Advance-life.git
   ```

2. Open the Xcode project:
   ```
   apps/notchmeister/Notchmeister/Notchmeister.xcodeproj
   ```

3. Set up code signing by running the setup script or creating `DeveloperSettings.xcconfig` manually (see original Notchmeister README for details).

4. Build and run (`⌘R`).

5. In the Notchmeister control panel, select **Advance Life** from the effect picker.

6. Start the Advance Life desktop companion — the notch will populate automatically.

---

## Architecture

| File | Purpose |
|---|---|
| `AdvanceLifeState.swift` | Data model (`ALNotchState`, `ALTimerSnapshot`, `ALMode`) and `AdvanceLifeStateWatcher` singleton that polls the JSON file |
| `AdvanceLifeEffect.swift` | `NotchEffect` subclass — builds and updates all CALayers inside the notch |
| `Effects.swift` | Registers `advanceLife` as a selectable effect in the picker |

---

## Relationship to the HTML prototype

The `notch.html` file in `apps/desktop-companion/src/` was the original prototype for this UI, rendered as an Electron `BrowserWindow` positioned near the top of the screen. This native implementation replaces it on macOS with a proper notch-integrated experience using CoreAnimation layers instead of web rendering.

The HTML prototype remains in place for Windows and Linux where Notchmeister doesn't apply.
