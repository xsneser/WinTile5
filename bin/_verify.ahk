#Requires AutoHotkey v2.0
#SingleInstance Force

; ----------------------------------------------------------------------
; WinTile5 自动化状态机与布局断言测试 (50 项全量断言，零弹窗，输出写入 A_Temp)
; ----------------------------------------------------------------------

outPath := A_Temp "\wintile5_verify.txt"

logText := "=== WinTile5 状态机与几何推导全量断言测试 ===`n"
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

; 模拟布局 (假设 2560x1600, 150% 缩放, WL=0, WT=0, WR=2560, WB=1528, colW=714, leftW=1428, halfH=764)
mockLayout := {
    colW: 714,
    halfH: 764,
    rects: Map(
        7,    {x: 0,    y: 0,   w: 714,  h: 764},
        8,    {x: 714,  y: 0,   w: 714,  h: 764},
        1,    {x: 0,    y: 764, w: 714,  h: 764},
        2,    {x: 714,  y: 764, w: 714,  h: 764},
        78,   {x: 0,    y: 0,   w: 1428, h: 764},
        12,   {x: 0,    y: 764, w: 1428, h: 764},
        71,   {x: 0,    y: 0,   w: 714,  h: 1528},
        82,   {x: 714,  y: 0,   w: 714,  h: 1528},
        7812, {x: 0,    y: 0,   w: 1428, h: 1528},
        6,    {x: 1428, y: 0,   w: 1132, h: 1528}
    )
}

; 纯几何评估函数（与 auto_layout.ahk 完全同构）
TestFindClosestLayoutState(vRect, layout) {
    if (vRect.w <= 0 || vRect.h <= 0)
        return 71

    tol := 15
    for state, r in layout.rects {
        diff := Max(Abs(vRect.x - r.x), Abs(vRect.y - r.y),
                    Abs((vRect.x + vRect.w) - (r.x + r.w)),
                    Abs((vRect.y + vRect.h) - (r.y + r.h)))
        if (diff <= tol)
            return state
    }

    bestState := 71
    minScore := 999999
    baseColW := Max(layout.colW, 100)
    baseHalfH := Max(layout.halfH, 100)

    cx := vRect.x + vRect.w / 2
    cy := vRect.y + vRect.h / 2

    for state, r in layout.rects {
        dLeft   := Abs(vRect.x - r.x) / baseColW
        dTop    := Abs(vRect.y - r.y) / baseHalfH
        dRight  := Abs((vRect.x + vRect.w) - (r.x + r.w)) / baseColW
        dBottom := Abs((vRect.y + vRect.h) - (r.y + r.h)) / baseHalfH

        rcx := r.x + r.w / 2
        rcy := r.y + r.h / 2
        dCenter := (Abs(cx - rcx) / baseColW) + (Abs(cy - rcy) / baseHalfH)

        score := dLeft + dTop + dRight + dBottom + dCenter

        if (score < minScore) {
            minScore := score
            bestState := state
        }
    }

    return bestState
}

; 状态转移判断函数（与 auto_layout.ahk 完全同构）
TestGetNextState(curState, dir, layout, vRect) {
    if (curState == "Unknown" || curState == "") {
        inferredState := TestFindClosestLayoutState(vRect, layout)
        return TestGetNextState(inferredState, dir, layout, vRect)
    }

    if (dir == "Right") {
        switch curState {
            case 7:    return 78
            case 78:   return 8
            case 8:    return 6
            case 1:    return 12
            case 12:   return 2
            case 2:    return 6
            case 71:   return 7812
            case 7812: return 82
            case 82:   return 6
            case 6:    return 6
        }
    } else if (dir == "Left") {
        switch curState {
            case 6:    return 82
            case 82:   return 7812
            case 7812: return 71
            case 71:   return 71
            case 8:    return 78
            case 78:   return 7
            case 7:    return 7
            case 2:    return 12
            case 12:   return 1
            case 1:    return 1
        }
    } else if (dir == "Up") {
        switch curState {
            case 1:    return 71
            case 71:   return 7
            case 7:    return 7
            case 2:    return 82
            case 82:   return 8
            case 8:    return 8
            case 12:   return 7812
            case 7812: return 78
            case 78:   return 78
            case 6:    return 6
        }
    } else if (dir == "Down") {
        switch curState {
            case 7:    return 71
            case 71:   return 1
            case 1:    return 1
            case 8:    return 82
            case 82:   return 2
            case 2:    return 2
            case 78:   return 7812
            case 7812: return 12
            case 12:   return 12
            case 6:    return 6
        }
    }
    return curState
}

dummyRect := {x: 0, y: 0, w: 100, h: 100}

; ----------------------------------------------------------------------
; 1. Right 方向 10 项断言
; ----------------------------------------------------------------------
Assert(TestGetNextState(7,    "Right", mockLayout, dummyRect) == 78,   "Right: 7 -> 78")
Assert(TestGetNextState(78,   "Right", mockLayout, dummyRect) == 8,    "Right: 78 -> 8")
Assert(TestGetNextState(8,    "Right", mockLayout, dummyRect) == 6,    "Right: 8 -> 6 (进6号主位)")
Assert(TestGetNextState(1,    "Right", mockLayout, dummyRect) == 12,   "Right: 1 -> 12")
Assert(TestGetNextState(12,   "Right", mockLayout, dummyRect) == 2,    "Right: 12 -> 2")
Assert(TestGetNextState(2,    "Right", mockLayout, dummyRect) == 6,    "Right: 2 -> 6 (进6号主位)")
Assert(TestGetNextState(71,   "Right", mockLayout, dummyRect) == 7812, "Right: 71 -> 7812")
Assert(TestGetNextState(7812, "Right", mockLayout, dummyRect) == 82,   "Right: 7812 -> 82")
Assert(TestGetNextState(82,   "Right", mockLayout, dummyRect) == 6,    "Right: 82 -> 6 (进6号主位)")
Assert(TestGetNextState(6,    "Right", mockLayout, dummyRect) == 6,    "Right: 6 -> 6 (保持)")

; ----------------------------------------------------------------------
; 2. Left 方向 10 项断言
; ----------------------------------------------------------------------
Assert(TestGetNextState(6,    "Left", mockLayout, dummyRect) == 82,   "Left: 6 -> 82 (从6号位回左半区右列)")
Assert(TestGetNextState(82,   "Left", mockLayout, dummyRect) == 7812, "Left: 82 -> 7812")
Assert(TestGetNextState(7812, "Left", mockLayout, dummyRect) == 71,   "Left: 7812 -> 71")
Assert(TestGetNextState(71,   "Left", mockLayout, dummyRect) == 71,   "Left: 71 -> 71 (保持)")
Assert(TestGetNextState(8,    "Left", mockLayout, dummyRect) == 78,   "Left: 8 -> 78")
Assert(TestGetNextState(78,   "Left", mockLayout, dummyRect) == 7,    "Left: 78 -> 7")
Assert(TestGetNextState(7,    "Left", mockLayout, dummyRect) == 7,    "Left: 7 -> 7 (保持)")
Assert(TestGetNextState(2,    "Left", mockLayout, dummyRect) == 12,   "Left: 2 -> 12")
Assert(TestGetNextState(12,   "Left", mockLayout, dummyRect) == 1,    "Left: 12 -> 1")
Assert(TestGetNextState(1,    "Left", mockLayout, dummyRect) == 1,    "Left: 1 -> 1 (保持)")

; ----------------------------------------------------------------------
; 3. Up 方向 10 项断言
; ----------------------------------------------------------------------
Assert(TestGetNextState(1,    "Up", mockLayout, dummyRect) == 71,   "Up: 1 -> 71")
Assert(TestGetNextState(71,   "Up", mockLayout, dummyRect) == 7,    "Up: 71 -> 7")
Assert(TestGetNextState(7,    "Up", mockLayout, dummyRect) == 7,    "Up: 7 -> 7 (保持)")
Assert(TestGetNextState(2,    "Up", mockLayout, dummyRect) == 82,   "Up: 2 -> 82")
Assert(TestGetNextState(82,   "Up", mockLayout, dummyRect) == 8,    "Up: 82 -> 8")
Assert(TestGetNextState(8,    "Up", mockLayout, dummyRect) == 8,    "Up: 8 -> 8 (保持)")
Assert(TestGetNextState(12,   "Up", mockLayout, dummyRect) == 7812, "Up: 12 -> 7812")
Assert(TestGetNextState(7812, "Up", mockLayout, dummyRect) == 78,   "Up: 7812 -> 78")
Assert(TestGetNextState(78,   "Up", mockLayout, dummyRect) == 78,   "Up: 78 -> 78 (保持)")
Assert(TestGetNextState(6,    "Up", mockLayout, dummyRect) == 6,    "Up: 6 -> 6 (保持)")

; ----------------------------------------------------------------------
; 4. Down 方向 10 项断言
; ----------------------------------------------------------------------
Assert(TestGetNextState(7,    "Down", mockLayout, dummyRect) == 71,   "Down: 7 -> 71")
Assert(TestGetNextState(71,   "Down", mockLayout, dummyRect) == 1,    "Down: 71 -> 1")
Assert(TestGetNextState(1,    "Down", mockLayout, dummyRect) == 1,    "Down: 1 -> 1 (保持)")
Assert(TestGetNextState(8,    "Down", mockLayout, dummyRect) == 82,   "Down: 8 -> 82")
Assert(TestGetNextState(82,   "Down", mockLayout, dummyRect) == 2,    "Down: 82 -> 2")
Assert(TestGetNextState(2,    "Down", mockLayout, dummyRect) == 2,    "Down: 2 -> 2 (保持)")
Assert(TestGetNextState(78,   "Down", mockLayout, dummyRect) == 7812, "Down: 78 -> 7812")
Assert(TestGetNextState(7812, "Down", mockLayout, dummyRect) == 12,   "Down: 7812 -> 12")
Assert(TestGetNextState(12,   "Down", mockLayout, dummyRect) == 12,   "Down: 12 -> 12 (保持)")
Assert(TestGetNextState(6,    "Down", mockLayout, dummyRect) == 6,    "Down: 6 -> 6 (保持)")

; ----------------------------------------------------------------------
; 5. Unknown 状态智能几何推导转移断言
; ----------------------------------------------------------------------
; 5.1 处于 7 号位区域: Down -> 71 (解决用户核心痛点: 7号位按下键到71合并位，不再到12)
Assert(TestGetNextState("Unknown", "Down", mockLayout, mockLayout.rects[7]) == 71, "Unknown at slot 7 + Down -> 71")

; 5.2 处于 8 号位区域: Right -> 6 (用户要求: 8/2/82按右键应当到6号位)
Assert(TestGetNextState("Unknown", "Right", mockLayout, mockLayout.rects[8]) == 6, "Unknown at slot 8 + Right -> 6")

; 5.3 处于 2 号位区域: Right -> 6
Assert(TestGetNextState("Unknown", "Right", mockLayout, mockLayout.rects[2]) == 6, "Unknown at slot 2 + Right -> 6")

; 5.4 处于 82 号位区域: Right -> 6
Assert(TestGetNextState("Unknown", "Right", mockLayout, mockLayout.rects[82]) == 6, "Unknown at slot 82 + Right -> 6")

; 5.5 处于 6 号主区域: Left -> 82 (用户要求: 6号位按左键应当到82合并位)
Assert(TestGetNextState("Unknown", "Left", mockLayout, mockLayout.rects[6]) == 82, "Unknown at slot 6 + Left -> 82")

; 5.6 处于 78 号复合区: Down -> 7812
Assert(TestGetNextState("Unknown", "Down", mockLayout, mockLayout.rects[78]) == 7812, "Unknown at slot 78 + Down -> 7812")

; 5.7 处于 7812 号复合区: Down -> 12
Assert(TestGetNextState("Unknown", "Down", mockLayout, mockLayout.rects[7812]) == 12, "Unknown at slot 7812 + Down -> 12")

; 5.8 处于 12 号复合区: Up -> 7812
Assert(TestGetNextState("Unknown", "Up", mockLayout, mockLayout.rects[12]) == 7812, "Unknown at slot 12 + Up -> 7812")

; ----------------------------------------------------------------------
; 6. 终端最小宽度超限自适应识别测试
; ----------------------------------------------------------------------
oversizedRect := {x: mockLayout.rects[7].x, y: mockLayout.rects[7].y, w: mockLayout.rects[7].w + 150, h: mockLayout.rects[7].h}
Assert(TestFindClosestLayoutState(oversizedRect, mockLayout) == 7, "FindClosestLayoutState on oversized terminal at slot 7 -> 7")
Assert(TestGetNextState("Unknown", "Down", mockLayout, oversizedRect) == 71, "Oversized terminal at slot 7 + Down -> 71")

summary := "`n=== 断言汇总: " passCount "/" (passCount + failCount) " 项通过, " failCount " 项失败 ===`n"
logText .= summary
FileAppend(summary, "*", "UTF-8")
try FileAppend(logText, outPath, "UTF-8")

ExitApp(failCount == 0 ? 0 : 1)
