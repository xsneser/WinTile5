# WinTile5 - 5-Window Tiling Assistant (Zero Conflict with Windows 11 Native 2x2)

<div align="center">

[English Documentation](README_EN.md) | [中文说明](README.md)

</div>

Press **`Win + Alt + A`** to instantly snap **4 CLI terminals + 1 main workspace** into a seamless layout: a 2×2 grid of four terminals on the left, and a full-height workspace window on the right.

- **Left Zone**: 4 CLI terminals arranged in a 2×2 grid (Slot 7: Top-Left, Slot 8: Top-Right, Slot 1: Bottom-Left, Slot 2: Bottom-Right).
- **Right Zone**: 1 full-height main application (Slot 6: Right Full-Height).
- **Seamless Tiling**: Zero gaps, zero overlaps, and no Windows 11 rounded corner gaps.

---

## 🔒 Zero Conflict Promise with Windows 11 Native 2x2

| Operation | Shortcut | Description |
| :--- | :--- | :--- |
| **Native 2x2 Snapping** | **`Win + Left/Right/Up/Down`** | **100% preserves native Windows 11 behavior** — zero hijacking, zero unhooking. |
| **Native Snap Assist** | **`Win + Z`** / Drag to corners | Fully preserved and functional. |
| WinTile5 Actions | `Win + Alt + …` | Uses `Alt` as a physical isolation modifier; never conflicts with native keys. |

---

## ⌨️ Hotkeys Cheatsheet

| Purpose | Shortcut | Behavior & Rules |
| :--- | :--- | :--- |
| **5-Window One-Click Layout** | **`Win + Alt + A`** | Automatically gathers 4 terminals + 1 browser and snaps them in milliseconds (Slots 7, 8, 1, 2 + 6). |
| **Reset to Standard 2x2** | `Win + Alt + Q` | Tiles the top 4 windows into a full-screen standard 2×2 grid. |
| **Numpad Direct Snap** | **`Win + Numpad 1/2/7/8/6`** | 7=Top-Left, 8=Top-Right, 1=Bottom-Left, 2=Bottom-Right, 6=Right Full-Height (works with NumLock On/Off). |
| **Main Keyboard Direct Snap** | `Win + Alt + 1/2/7/8/6` | Direct jump to corresponding slots. |
| **Smooth 5-Window Flow** | **`Win + Alt + Arrow Keys`** | Full isomorphic replication of Windows 11's 2x2 state machine with smooth multi-slot transitions. |
| **Temporary Win+Arrow Takeover** | `Win + F11` | Toggle switch with tray notification; press again to restore native Windows shortcuts. |

---

## 🧭 Directional State Machine Flow Rules (`Win + Alt + Arrows`)

WinTile5 operates from a single source of geometric truth (`GetLayoutInfo()`). It supports compound multi-slot states within the left zone (78: Top Full-Width, 12: Bottom Full-Width, 71: Left Column Full-Height, 82: Right Column Full-Height, 7812: Left Half-Screen Full-Height):

### 1. Right Arrow (`Right`)
- `7` (Top-Left) → `78` (Top Full-Width) → `8` (Top-Right) → **`6` (Right Full-Height)**
- `1` (Bottom-Left) → `12` (Bottom Full-Width) → `2` (Bottom-Right) → **`6` (Right Full-Height)**
- `71` (Left Column Full-Height) → `7812` (Left Half-Screen Full-Height) → `82` (Right Column Full-Height) → **`6` (Right Full-Height)**
- `6` → Remains `6`
> **Core Rule**: An active window **only transitions to slot 6 (Right Full-Height) when pressing Right from column 8, 2, or 82**. Right arrow presses from column 7 or 1 strictly stay within the 2×2 grid.

### 2. Left Arrow (`Left`)
- **`6` (Right Full-Height) → `82` (Right Column Full-Height)** → `7812` (Left Half-Screen Full-Height) → `71` (Left Column Full-Height) → Remains `71`
- `8` (Top-Right) → `78` (Top Full-Width) → `7` (Top-Left) → Remains `7`
- `2` (Bottom-Right) → `12` (Bottom Full-Width) → `1` (Bottom-Left) → Remains `1`

### 3. Up Arrow (`Up`)
- `1` (Bottom-Left) → `71` (Left Column Full-Height) → `7` (Top-Left) → Remains `7`
- `2` (Bottom-Right) → `82` (Right Column Full-Height) → `8` (Top-Right) → Remains `8`
- `12` (Bottom Full-Width) → `7812` (Left Half-Screen Full-Height) → `78` (Top Full-Width) → Remains `78`
- `6` → Remains `6`

### 4. Down Arrow (`Down`)
- `7` (Top-Left) → `71` (Left Column Full-Height) → `1` (Bottom-Left) → Remains `1`
- `8` (Top-Right) → `82` (Right Column Full-Height) → `2` (Bottom-Right) → Remains `2`
- `78` (Top Full-Width) → `7812` (Left Half-Screen Full-Height) → `12` (Bottom Full-Width) → Remains `12`
- `6` → Remains `6`

### 5. Floating / Unsnapped Window (`Unknown`) Geometric Inference
When an unsnapped window triggers an arrow key, WinTile5 computes the closest visual slot via `FindClosestLayoutState`:
- Pressing Down near Slot 7 → smoothly snaps to `71` (Left Column Full-Height).
- Pressing Right near Slot 8 / 2 / 82 → smoothly snaps to `6` (Right Full-Height).
- Pressing Left near Slot 6 → smoothly transitions back to `82` (Right Column Full-Height).
- Pressing Down near Slot 78 → smoothly snaps to `7812` (Left Half Full-Height).
- Pressing Up near Slot 12 → smoothly snaps to `7812` (Left Half Full-Height).

---

## 🔧 Four Core Engineering Highlights

### 1. DWM Invisible Frame Margin Compensation
Windows 10/11 adds ~9px of invisible borders to standard resizable windows (`WS_THICKFRAME`). WinTile5 queries visual bounding boxes via `DwmGetWindowAttribute(DWMWA_EXTENDED_FRAME_BOUNDS)` and applies exact insets (`iL, iT, iR, iB`) to `WinMove`, ensuring **zero pixel gaps and zero overlapping**.

### 2. Terminal Minimum Width Protection
Terminal applications (such as Windows Terminal) enforce hardware minimum width constraints (~714px). WinTile5 measures the terminal's boundary limit on the first run, preventing windows from exceeding column boundaries and overlapping.

### 3. Seamless Square Corners with Clean Exit Recovery
Eliminates rounded corner gaps (`DWMWCP_DONOTROUND`). The script tracks modified window handles (`HWND`) and safely restores system default rounded corners upon exit (`OnExit`), leaving other system applications untouched.

### 4. Cold-Start Two-Pass Alignment Guarantee
On the very first layout invocation, windows may be maximized or natively snapped. Windows 11 unmaximize animations and non-client frame recalculation introduce brief asynchronous latency. WinTile5 automatically performs an invisible sub-millisecond settling pass, ensuring 100% pixel alignment on the very first try without requiring a second shortcut press.

---

## 🚀 Getting Started

### Green & Portable (Zero Dependencies)
WinTile5 includes a bundled, portable `AutoHotkey64.exe` (v2.0) runtime in `bin\`. No installation or system environment variable modifications are required.

1. **Quick Test**: Double-click `run_layout.bat` or run `auto_layout.ahk` directly.
2. **Setup Auto-Start on Boot**: Run `setup_startup.bat` (creates a shortcut in Windows Startup folder).
3. **Uninstall Auto-Start**: Run `uninstall_startup.bat`.
4. **Automated Verification**: Run `bin\verify.bat` to run the non-interactive test suite (50 assertions for geometry and transitions).

---

## 📁 Directory Structure

```text
D:\WinTile5\
├── auto_layout.ahk          # Core script (Geometric engine / 50-state transition matrix / DWM compensation)
├── setup_startup.bat        # Add to Windows Startup and launch
├── uninstall_startup.bat    # Remove from Windows Startup
├── run_layout.bat           # Double-click trigger for 5-window layout
├── README.md                # Chinese technical documentation
├── README_EN.md             # English technical documentation
└── bin\
    ├── AutoHotkey64.exe     # Portable v2.0 runtime
    ├── startup_shortcut.ahk # Helper for shortcut management
    ├── arrange_now.ahk      # Lightweight trigger script
    ├── restart.bat          # Background restart script
    ├── verify.bat           # Automated verification test runner
    └── _verify.ahk          # 50-assertion test script
```

---

## 📄 License

MIT License. Free for personal and commercial use.
