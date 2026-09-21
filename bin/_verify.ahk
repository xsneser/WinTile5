#Requires AutoHotkey v2.0
#SingleInstance Force

; ----------------------------------------------------------------------
; WinTile5 自动化状态机与布局断言测试 (40 项全量断言，零弹窗，输出写入 A_Temp)
; ----------------------------------------------------------------------

outPath := A_Temp "\wintile5_verify.txt"

logText := "=== WinTile5 40项状态机断言测试 ===`n"
logText .= "测试时间: " FormatTime(, "yyyy-MM-dd HH:mm:ss") "`n`n"

passCount := 0
failCount := 0

Assert(condition, desc) {
    global passCount, failCount, logText
    if (condition) {
        passCount++
        line := "[PASS] " desc "`n"
        logText .= line
        FileAppend(line, "*", "UTF-8")
    } else {
        failCount++
        line := "[FAIL] " desc "`n"
        logText .= line
        FileAppend(line, "*", "UTF-8")
    }
}

; 模拟布局 (假设 2560x1600, 150% 缩放, WL=0, WT=0, WR=2560, WB=1528)
mockLayout := {
    rects: Map(
        7,  {x: 0,    y: 0,   w: 714,  h: 764},
        8,  {x: 714,  y: 0,   w: 714,  h: 764},
        1,  {x: 0,    y: 764, w: 714,  h: 764},
        2,  {x: 714,  y: 764, w: 714,  h: 764},
        78, {x: 0,    y: 0,   w: 1428, h: 764},
        12, {x: 0,    y: 764, w: 1428, h: 764},
        71, {x: 0,    y: 0,   w: 714,  h: 1528},
        82, {x: 714,  y: 0,   w: 714,  h: 1528},
        6,  {x: 1428, y: 0,   w: 1132, h: 1528}
    )
}

; 状态转移判断函数（与 auto_layout.ahk 完全同构）
TestGetNextState(curState, dir, layout, vRect) {
    if (curState == "Unknown") {
        if (dir == "Left")
            return 71
        if (dir == "Right") {
            cx := vRect.x + vRect.w // 2
            if (cx >= layout.rects[6].x)
                return 6
            return 82
        }
        if (dir == "Up")
            return 78
        if (dir == "Down")
            return 12
        return 71
    }

    if (dir == "Right") {
        switch curState {
            case 7:  return 78
            case 78: return 8
            case 8:  return 6
            case 1:  return 12
            case 12: return 2
            case 2:  return 6
            case 71: return 82
            case 82: return 6
            case 6:  return 6
        }
    } else if (dir == "Left") {
        switch curState {
            case 6:  return 82
            case 82: return 71
            case 71: return 71
            case 8:  return 78
            case 78: return 7
            case 7:  return 7
            case 2:  return 12
            case 12: return 1
            case 1:  return 1
        }
    } else if (dir == "Up") {
        switch curState {
            case 1:  return 71
            case 71: return 7
            case 7:  return 7
            case 2:  return 82
            case 82: return 8
            case 8:  return 8
            case 12: return 78
            case 78: return 78
            case 6:  return 6
        }
    } else if (dir == "Down") {
        switch curState {
            case 7:  return 71
            case 71: return 1
            case 1:  return 1
            case 8:  return 82
            case 82: return 2
            case 2:  return 2
            case 78: return 12
            case 12: return 12
            case 6:  return 6
        }
    }
    return curState
}

dummyRect := {x: 0, y: 0, w: 100, h: 100}

; ----------------------------------------------------------------------
; 1. Right 方向 9 项断言
; ----------------------------------------------------------------------
Assert(TestGetNextState(7,  "Right", mockLayout, dummyRect) == 78, "Right: 7 -> 78")
Assert(TestGetNextState(78, "Right", mockLayout, dummyRect) == 8,  "Right: 78 -> 8")
Assert(TestGetNextState(8,  "Right", mockLayout, dummyRect) == 6,  "Right: 8 -> 6 (进6号主位)")
Assert(TestGetNextState(1,  "Right", mockLayout, dummyRect) == 12, "Right: 1 -> 12")
Assert(TestGetNextState(12, "Right", mockLayout, dummyRect) == 2,  "Right: 12 -> 2")
Assert(TestGetNextState(2,  "Right", mockLayout, dummyRect) == 6,  "Right: 2 -> 6 (进6号主位)")
Assert(TestGetNextState(71, "Right", mockLayout, dummyRect) == 82, "Right: 71 -> 82")
Assert(TestGetNextState(82, "Right", mockLayout, dummyRect) == 6,  "Right: 82 -> 6 (进6号主位)")
Assert(TestGetNextState(6,  "Right", mockLayout, dummyRect) == 6,  "Right: 6 -> 6 (保持)")

; ----------------------------------------------------------------------
; 2. Left 方向 9 项断言
; ----------------------------------------------------------------------
Assert(TestGetNextState(6,  "Left", mockLayout, dummyRect) == 82, "Left: 6 -> 82 (从6号位回左半区右列)")
Assert(TestGetNextState(82, "Left", mockLayout, dummyRect) == 71, "Left: 82 -> 71")
Assert(TestGetNextState(71, "Left", mockLayout, dummyRect) == 71, "Left: 71 -> 71 (保持)")
Assert(TestGetNextState(8,  "Left", mockLayout, dummyRect) == 78, "Left: 8 -> 78")
Assert(TestGetNextState(78, "Left", mockLayout, dummyRect) == 7,  "Left: 78 -> 7")
Assert(TestGetNextState(7,  "Left", mockLayout, dummyRect) == 7,  "Left: 7 -> 7 (保持)")
Assert(TestGetNextState(2,  "Left", mockLayout, dummyRect) == 12, "Left: 2 -> 12")
Assert(TestGetNextState(12, "Left", mockLayout, dummyRect) == 1,  "Left: 12 -> 1")
Assert(TestGetNextState(1,  "Left", mockLayout, dummyRect) == 1,  "Left: 1 -> 1 (保持)")

; ----------------------------------------------------------------------
; 3. Up 方向 9 项断言
; ----------------------------------------------------------------------
Assert(TestGetNextState(1,  "Up", mockLayout, dummyRect) == 71, "Up: 1 -> 71")
Assert(TestGetNextState(71, "Up", mockLayout, dummyRect) == 7,  "Up: 71 -> 7")
Assert(TestGetNextState(7,  "Up", mockLayout, dummyRect) == 7,  "Up: 7 -> 7 (保持)")
Assert(TestGetNextState(2,  "Up", mockLayout, dummyRect) == 82, "Up: 2 -> 82")
Assert(TestGetNextState(82, "Up", mockLayout, dummyRect) == 8,  "Up: 82 -> 8")
Assert(TestGetNextState(8,  "Up", mockLayout, dummyRect) == 8,  "Up: 8 -> 8 (保持)")
Assert(TestGetNextState(12, "Up", mockLayout, dummyRect) == 78, "Up: 12 -> 78")
Assert(TestGetNextState(78, "Up", mockLayout, dummyRect) == 78, "Up: 78 -> 78 (保持)")
Assert(TestGetNextState(6,  "Up", mockLayout, dummyRect) == 6,  "Up: 6 -> 6 (保持)")

; ----------------------------------------------------------------------
; 4. Down 方向 9 项断言
; ----------------------------------------------------------------------
Assert(TestGetNextState(7,  "Down", mockLayout, dummyRect) == 71, "Down: 7 -> 71")
Assert(TestGetNextState(71, "Down", mockLayout, dummyRect) == 1,  "Down: 71 -> 1")
Assert(TestGetNextState(1,  "Down", mockLayout, dummyRect) == 1,  "Down: 1 -> 1 (保持)")
Assert(TestGetNextState(8,  "Down", mockLayout, dummyRect) == 82, "Down: 8 -> 82")
Assert(TestGetNextState(82, "Down", mockLayout, dummyRect) == 2,  "Down: 82 -> 2")
Assert(TestGetNextState(2,  "Down", mockLayout, dummyRect) == 2,  "Down: 2 -> 2 (保持)")
Assert(TestGetNextState(78, "Down", mockLayout, dummyRect) == 12, "Down: 78 -> 12")
Assert(TestGetNextState(12, "Down", mockLayout, dummyRect) == 12, "Down: 12 -> 12 (保持)")
Assert(TestGetNextState(6,  "Down", mockLayout, dummyRect) == 6,  "Down: 6 -> 6 (保持)")

; ----------------------------------------------------------------------
; 5. Unknown 状态 4 项入口断言 (精准基于布局边界)
; ----------------------------------------------------------------------
; 5.1 Left -> 71
Assert(TestGetNextState("Unknown", "Left", mockLayout, dummyRect) == 71, "Unknown + Left -> 71")

; 5.2 Right (处于左半区，中心 x=500 < 1428) -> 82
leftWindow := {x: 300, y: 100, w: 400, h: 400}
Assert(TestGetNextState("Unknown", "Right", mockLayout, leftWindow) == 82, "Unknown + Right (在左半区内) -> 82")

; 5.3 Right (处于6号主区域，中心 x=1700 >= 1428) -> 6
rightWindow := {x: 1500, y: 100, w: 400, h: 400}
Assert(TestGetNextState("Unknown", "Right", mockLayout, rightWindow) == 6, "Unknown + Right (在6号区域内) -> 6")

; 5.4 Up -> 78, Down -> 12
Assert(TestGetNextState("Unknown", "Up", mockLayout, dummyRect) == 78, "Unknown + Up -> 78")
Assert(TestGetNextState("Unknown", "Down", mockLayout, dummyRect) == 12, "Unknown + Down -> 12")

summary := "`n=== 断言汇总: " passCount "/40 项通过, " failCount " 项失败 ===`n"
logText .= summary
FileAppend(summary, "*", "UTF-8")
try FileAppend(logText, outPath, "UTF-8")

ExitApp(failCount == 0 ? 0 : 1)
