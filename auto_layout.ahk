#Requires AutoHotkey v2.0
#SingleInstance Force

; ==============================================================================
; WinTile5 - 5-Window Layout Manager (Windows 11 / DPI-aware / 与原生 2x2 零冲突)
;
; 布局架构：
;   - 左半区：4 个终端按 2x2 网格排布 (槽位 7:左上, 8:右上, 1:左下, 2:右下)
;   - 右半区：1 个主界面全高 (槽位 6:右侧全高)
;   - 支持左半区 2x2 复合分屏态 (78:上半宽, 12:下半宽, 71:左列全高, 82:右列全高, 7812:左半区全高)
;   - 原生 2x2 网格状态机完全同构流动，仅在 8、2、82 槽位按向右才会进入 6 号位，6 号位按向左回到 82 号位
;
; 细节技术实现：
;   1. 隐形边框补偿 —— DWM 扩展边界测量 (DWMWA_EXTENDED_FRAME_BOUNDS)，消除 Windows 11 9px 隐形缝隙
;   2. 最小宽度自适应 —— 自动探测终端最小宽度 (如 714px)，动态保护列宽防止重叠
;   3. 全直角无缝模式 —— DWMWCP_DONOTROUND 消除圆角弧形缺口；退出时精准恢复受影响窗口
; ==============================================================================

; --------------------------------- 配置 ---------------------------------
g_Cfg := {
    LeftRatio: 0.50,          ; 期望的左半区占比 (0.5 = 左右各半)
    ForceRatio: false,        ; true = 强制用 LeftRatio，不自动加宽 (会有重叠，慎用)
    Gap: 0                    ; 窗口之间的额外缝隙 (0 = 完全无缝)
}
; ------------------------------------------------------------------------

A_IconTip := "WinTile5 分屏助手"
try TraySetIcon("shell32.dll", 249)

global g_TakeoverMode  := false
global g_MinTermWidth  := 0        ; 实测的终端最小宽度(物理像素)，0 = 未测量
global g_InsetCache    := Map()    ; hwnd -> [left, top, right, bottom]
global g_StateCache    := Map()    ; hwnd -> {state, targetRect, monitorIndex}
global g_ModifiedHwnds := Map()    ; 记录被本脚本去除圆角的 HWND，退出时精准还原
global g_Debug         := false    ; true = 输出诊断日志

; 注册退出钩子：脚本退出时恢复已处理窗口的圆角
OnExit(RestoreModifiedCorners)

; 检查命令行参数：支持纯无界面自检
if (A_Args.Length > 0 && A_Args[1] == "--self-test") {
    ExitApp(RunSelfTest())
}

BuildTrayMenu()

BuildTrayMenu() {
    A_TrayMenu.Delete()
    A_TrayMenu.Add("⚡ 5窗口自动排版  (Win+Alt+A)", (*) => ArrangeAllWindows())
    A_TrayMenu.Add("⊞ 2x2网格自动排版  (Win+Alt+Q)", (*) => Arrange2x2Windows())
    A_TrayMenu.Add()
    A_TrayMenu.Add("🔄 切换 Win+方向键 临时接管  (Win+F11)", (*) => ToggleTakeoverMode())
    A_TrayMenu.Add("📐 重新测量终端最小宽度", (*) => RemeasureMinWidth())
    A_TrayMenu.Add()
    A_TrayMenu.Add("⏸ 暂停 / 恢复快捷键", (*) => Suspend(-1))
    A_TrayMenu.Add("❌ 退出程序", (*) => ExitApp())
}

; ==============================================================================
; 1. 快捷键
; ==============================================================================

; 1.1 一键排版
#!a:: ArrangeAllWindows()          ; 一键排 5 窗口 (4 CLI + 1 主界面)
#!q:: Arrange2x2Windows()          ; 一键排标准 2x2 网格

; 1.2 小键盘槽位直达 (同时支持 NumLock 开启与关闭状态)
#Numpad7::    SnapActiveWindow(7)
#NumpadHome:: SnapActiveWindow(7)

#Numpad8::    SnapActiveWindow(8)
#NumpadUp::   SnapActiveWindow(8)

#Numpad1::    SnapActiveWindow(1)
#NumpadEnd::  SnapActiveWindow(1)

#Numpad2::    SnapActiveWindow(2)
#NumpadDown:: SnapActiveWindow(2)

#Numpad6::    SnapActiveWindow(6)
#NumpadRight::SnapActiveWindow(6)

; 1.3 方向键状态流转
#!Left::  MoveIn5Zones("Left")
#!Right:: MoveIn5Zones("Right")
#!Up::    MoveIn5Zones("Up")
#!Down::  MoveIn5Zones("Down")

; 1.4 临时接管原生 Win+方向键开关
#F11:: ToggleTakeoverMode()

#HotIf g_TakeoverMode
#Left::   MoveIn5Zones("Left")
#Right::  MoveIn5Zones("Right")
#Up::     MoveIn5Zones("Up")
#Down::   MoveIn5Zones("Down")
#HotIf

ToggleTakeoverMode() {
    global g_TakeoverMode
    g_TakeoverMode := !g_TakeoverMode
    if (g_TakeoverMode)
        TrayTip("WinTile5 接管模式：已开启`nWin+方向键 将在 5 分区状态机内平滑流动`n按 Win+F11 切回系统原生", "WinTile5", 1)
    else
        TrayTip("原生 2x2 模式：已恢复`nWin+方向键 已完全交还 Windows 11", "WinTile5", 1)
}

; ==============================================================================
; 2. 唯一几何源 (Single Source of Truth)
; ==============================================================================

; 计算指定显示器的完整布局几何参数与 9 个目标可见矩形
GetLayoutInfo(monitorIndex := 1) {
    global g_Cfg, g_MinTermWidth
    MonitorGetWorkArea(monitorIndex, &WL, &WT, &WR, &WB)
    workW := WR - WL
    workH := WB - WT
    gap   := g_Cfg.Gap

    colW := Floor((workW - gap * 3) * g_Cfg.LeftRatio / 2)

    ; 终端硬性最小宽度保护 (避免溢出造成窗口重叠)
    if (!g_Cfg.ForceRatio && g_MinTermWidth > 0) {
        maxAllowed := Floor((workW - gap * 3) / 2)
        colW := Min(Max(colW, g_MinTermWidth), maxAllowed)
    }

    leftW   := colW * 2 + gap
    rightW  := workW - leftW - gap
    halfH   := Floor((workH - gap) / 2)
    bottomH := workH - halfH - gap

    rects := Map()
    ; 4 个单格槽位 (四角)
    rects[7]  := {x: WL,                 y: WT,               w: colW,   h: halfH}
    rects[8]  := {x: WL + colW + gap,    y: WT,               w: colW,   h: halfH}
    rects[1]  := {x: WL,                 y: WT + halfH + gap, w: colW,   h: bottomH}
    rects[2]  := {x: WL + colW + gap,    y: WT + halfH + gap, w: colW,   h: bottomH}

    ; 5 个 2x2 复合分屏态
    rects[78]   := {x: WL,                 y: WT,               w: leftW,  h: halfH}
    rects[12]   := {x: WL,                 y: WT + halfH + gap, w: leftW,  h: bottomH}
    rects[71]   := {x: WL,                 y: WT,               w: colW,   h: workH}
    rects[82]   := {x: WL + colW + gap,    y: WT,               w: colW,   h: workH}
    rects[7812] := {x: WL,                 y: WT,               w: leftW,  h: workH}

    ; 1 个右侧全高主界面
    rects[6]    := {x: WL + leftW + gap,   y: WT,               w: rightW, h: workH}

    return {
        workRect: {x: WL, y: WT, w: workW, h: workH},
        leftW: leftW,
        rightW: rightW,
        colW: colW,
        halfH: halfH,
        bottomH: bottomH,
        rects: rects
    }
}

Get2x2Coordinates(quadIndex, &outX, &outY, &outW, &outH) {
    MonitorGetWorkArea(1, &WL, &WT, &WR, &WB)
    workW := WR - WL
    workH := WB - WT
    halfW := Floor(workW / 2)
    halfH := Floor(workH / 2)

    switch quadIndex {
        case 1: outX := WL,          outY := WT,          outW := halfW,           outH := halfH
        case 2: outX := WL + halfW,  outY := WT,          outW := workW - halfW,   outH := halfH
        case 3: outX := WL,          outY := WT + halfH,  outW := halfW,           outH := workH - halfH
        case 4: outX := WL + halfW,  outY := WT + halfH,  outW := workW - halfW,   outH := workH - halfH
    }
}

; ==============================================================================
; 3. DWM 可见几何与隐形边框补偿
; ==============================================================================

; 读取窗口当前真实的 DWM 可见外接矩形
GetVisibleRect(hwnd) {
    buf := Buffer(16, 0)
    hr := DllCall("dwmapi\DwmGetWindowAttribute", "ptr", hwnd, "int", 9, "ptr", buf, "int", 16, "int")
    if (hr == 0) {
        fl := NumGet(buf, 0, "int"), ft := NumGet(buf, 4, "int")
        fr := NumGet(buf, 8, "int"), fb := NumGet(buf, 12, "int")
        if (fr > fl && fb > ft)
            return {x: fl, y: ft, w: fr - fl, h: fb - ft}
    }
    WinGetPos(&wx, &wy, &ww, &wh, hwnd)
    return {x: wx, y: wy, w: ww, h: wh}
}

; 读取窗口的隐形 DWM 边框厚度 (四边内缩量)
GetFrameInsets(hwnd, &iL, &iT, &iR, &iB) {
    global g_InsetCache
    key := hwnd . "|" . A_ScreenDPI
    if g_InsetCache.Has(key) {
        v := g_InsetCache[key]
        iL := v[1], iT := v[2], iR := v[3], iB := v[4]
        return
    }

    if (WinGetMinMax(hwnd) != 0) {
        WinRestore(hwnd)
        Sleep 30
    }

    buf := Buffer(16, 0)
    hr := DllCall("dwmapi\DwmGetWindowAttribute", "ptr", hwnd, "int", 9, "ptr", buf, "int", 16, "int")
    if (hr != 0) {
        iL := 0, iT := 0, iR := 0, iB := 0
        return
    }
    fl := NumGet(buf, 0, "int"), ft := NumGet(buf, 4, "int")
    fr := NumGet(buf, 8, "int"), fb := NumGet(buf, 12, "int")

    if (fl = 0 && ft = 0 && fr = 0 && fb = 0) {
        iL := 0, iT := 0, iR := 0, iB := 0
        return
    }

    WinGetPos(&wx, &wy, &ww, &wh, hwnd)
    iL := fl - wx
    iT := ft - wy
    iR := (wx + ww) - fr
    iB := (wy + wh) - fb

    g_InsetCache[key] := [iL, iT, iR, iB]
}

; 设置窗口圆角偏好: 0 = 系统默认, 1 = 不要圆角 (直角)
SetWindowCorner(hwnd, pref) {
    v := Buffer(4)
    NumPut("int", pref, v)
    try DllCall("dwmapi\DwmSetWindowAttribute", "ptr", hwnd, "uint", 33, "ptr", v, "uint", 4, "int")
}

; 退出时精准还原已由本脚本修改过直角的窗口，绝不干扰无关窗口
RestoreModifiedCorners(*) {
    global g_ModifiedHwnds
    for h, _ in g_ModifiedHwnds {
        try {
            if WinExist(h)
                SetWindowCorner(h, 0)
        }
    }
}

; 确定窗口所属的显示器序号
GetMonitorIndexForWindow(hwnd) {
    rect := GetVisibleRect(hwnd)
    cx := rect.x + rect.w // 2
    cy := rect.y + rect.h // 2
    monCount := MonitorGetCount()
    Loop monCount {
        MonitorGetWorkArea(A_Index, &WL, &WT, &WR, &WB)
        if (cx >= WL && cx <= WR && cy >= WT && cy <= WB)
            return A_Index
    }
    return MonitorGetPrimary()
}

; 将窗口可见画面精确摆放到目标矩形
SnapWindowTo(hwnd, tx, ty, tw, th) {
    global g_ModifiedHwnds
    if (WinGetMinMax(hwnd) != 0) {
        WinRestore(hwnd)
        Sleep 80
    }
    ; 先设置直角并立即通知 DWM 刷新非客户区帧 (0x0037 = SWP_NOSIZE|SWP_NOMOVE|SWP_NOZORDER|SWP_NOACTIVATE|SWP_FRAMECHANGED)
    SetWindowCorner(hwnd, 1)
    g_ModifiedHwnds[hwnd] := true
    try DllCall("user32\SetWindowPos", "ptr", hwnd, "ptr", 0, "int", 0, "int", 0
              , "int", 0, "int", 0, "uint", 0x0037, "int")

    GetFrameInsets(hwnd, &iL, &iT, &iR, &iB)
    WinMove(tx - iL, ty - iT, tw + iL + iR, th + iT + iB, hwnd)
}

; 将指定窗口直接吸附到特定布局状态
SnapWindowToState(hwnd, state, monitorIndex := 0) {
    global g_StateCache
    if (!hwnd || !WinExist(hwnd))
        return
    if (monitorIndex == 0)
        monitorIndex := GetMonitorIndexForWindow(hwnd)

    layout := GetLayoutInfo(monitorIndex)
    if (!layout.rects.Has(state))
        return

    targetRect := layout.rects[state]
    SnapWindowTo(hwnd, targetRect.x, targetRect.y, targetRect.w, targetRect.h)
    actualRect := GetVisibleRect(hwnd)
    g_StateCache[hwnd] := {state: state, targetRect: targetRect, actualRect: actualRect, monitorIndex: monitorIndex}
}

; 吸附当前激活窗口到指定状态
SnapActiveWindow(state) {
    hwnd := WinExist("A")
    if !hwnd
        return
    SnapWindowToState(hwnd, state)
}

; ==============================================================================
; 4. 状态识别与四向状态转移引擎
; ==============================================================================

; 纯几何评估：在全部 10 个状态中找出视觉上最贴合的目标槽位 (支持终端最小宽度超限自适应)
FindClosestLayoutState(vRect, layout) {
    if (vRect.w <= 0 || vRect.h <= 0)
        return 71

    tol := 15
    ; 1. 优先检查精确贴靠 (四边误差 <= tol)
    for state, r in layout.rects {
        diff := Max(Abs(vRect.x - r.x), Abs(vRect.y - r.y),
                    Abs((vRect.x + vRect.w) - (r.x + r.w)),
                    Abs((vRect.y + vRect.h) - (r.y + r.h)))
        if (diff <= tol)
            return state
    }

    ; 2. 智能综合距离与中心点评估
    bestState := 71
    minScore := 999999
    baseColW := Max(layout.colW, 100)
    baseHalfH := Max(layout.halfH, 100)

    cx := vRect.x + vRect.w / 2
    cy := vRect.y + vRect.h / 2

    for state, r in layout.rects {
        ; 归一化四边距离 (除以基础网格单格尺度)
        dLeft   := Abs(vRect.x - r.x) / baseColW
        dTop    := Abs(vRect.y - r.y) / baseHalfH
        dRight  := Abs((vRect.x + vRect.w) - (r.x + r.w)) / baseColW
        dBottom := Abs((vRect.y + vRect.h) - (r.y + r.h)) / baseHalfH

        ; 归一化中心点距离
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

; 智能识别窗口当前状态：优先缓存提示校验 -> 几何回退 -> Unknown 保护
GetWindowState(hwnd, layout, monitorIndex) {
    global g_StateCache
    vRect := GetVisibleRect(hwnd)
    tol := 15   ; 像素容差

    ; 1. 缓存提示校验：优先校验实际可见矩形 actualRect，其次校验理想目标矩形 targetRect
    if g_StateCache.Has(hwnd) {
        c := g_StateCache[hwnd]
        if (c.monitorIndex == monitorIndex) {
            if (c.HasOwnProp("actualRect")) {
                ar := c.actualRect
                if (Abs(vRect.x - ar.x) <= tol && Abs(vRect.y - ar.y) <= tol
                 && Abs(vRect.w - ar.w) <= tol && Abs(vRect.h - ar.h) <= tol) {
                    return c.state
                }
            }
            tr := c.targetRect
            if (Abs(vRect.x - tr.x) <= tol && Abs(vRect.y - tr.y) <= tol
             && Abs(vRect.w - tr.w) <= tol && Abs(vRect.h - tr.h) <= tol) {
                return c.state
            }
        }
    }

    ; 2. 几何回退：计算最贴近的布局状态，并登记缓存
    bestState := FindClosestLayoutState(vRect, layout)
    if (bestState != "Unknown" && layout.rects.Has(bestState)) {
        g_StateCache[hwnd] := {state: bestState, targetRect: layout.rects[bestState], actualRect: vRect, monitorIndex: monitorIndex}
        return bestState
    }

    ; 3. 超出容差阈值，判定为自由浮动窗口 (Unknown)，清除旧缓存
    if g_StateCache.Has(hwnd)
        g_StateCache.Delete(hwnd)
    return "Unknown"
}

; 纯状态转移函数 (无副作用，可独立测试断言)
GetNextState(curState, dir, layout, vRect) {
    ; 1. Unknown 状态：基于窗口当前几何推导最近状态，并在转移矩阵中正常流转
    if (curState == "Unknown" || curState == "") {
        inferredState := FindClosestLayoutState(vRect, layout)
        return GetNextState(inferredState, dir, layout, vRect)
    }

    ; 2. 10 个状态的严密状态转移矩阵
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

; 执行方向键移动
MoveIn5Zones(dir) {
    hwnd := WinExist("A")
    if !hwnd
        return
    monIndex := GetMonitorIndexForWindow(hwnd)
    layout := GetLayoutInfo(monIndex)
    vRect := GetVisibleRect(hwnd)
    curState := GetWindowState(hwnd, layout, monIndex)
    nextState := GetNextState(curState, dir, layout, vRect)
    SnapWindowToState(hwnd, nextState, monIndex)
}

; ==============================================================================
; 5. 终端最小宽度探测
; ==============================================================================

MeasureTerminalMinWidth(hwnd) {
    if !hwnd
        return 0
    WinGetPos(&ox, &oy, &ow, &oh, hwnd)
    WinMove(ox, oy, 120, oh, hwnd)
    Sleep 80
    WinGetPos(&nx, &ny, &nw, &nh, hwnd)
    WinMove(ox, oy, ow, oh, hwnd)
    Sleep 50
    return nw
}

AutoMeasureMinWidth(cliList) {
    global g_MinTermWidth
    for hwnd in cliList {
        w := MeasureTerminalMinWidth(hwnd)
        if (w > 0) {
            g_MinTermWidth := w
            return w
        }
    }
    return Floor(476 * A_ScreenDPI / 96)
}

RemeasureMinWidth() {
    global g_MinTermWidth
    g_MinTermWidth := 0
    ToolTip("正在重新测量终端最小宽度…")
    SetTimer () => ToolTip(), -800
}

; ==============================================================================
; 6. 一键排版核心
; ==============================================================================

InList(arr, val) {
    for v in arr {
        if (v = val)
            return true
    }
    return false
}

ProcKey(hwnd) {
    return StrReplace(StrLower(WinGetProcessName(hwnd)), ".exe")
}

CollectWindows() {
    cliProcs := ["windowsterminal", "cmd", "powershell", "pwsh", "mintty", "conhost"
               , "bash", "git-bash", "alacritty", "wezterm-gui", "openconsole"]
    brProcs  := ["chrome", "msedge", "firefox", "brave", "zen", "opera", "vivaldi"]

    cands := [], procs := Map()
    for hwnd in WinGetList() {
        try {
            if !(WinGetStyle(hwnd) & 0x10000000)
                continue
            title := WinGetTitle(hwnd)
            if (title == "" || title == "Program Manager" || title == "Settings")
                continue
            if (InStr(title, "run_layout") || InStr(title, "arrange_now") || InStr(title, "verify"))
                continue
            if (WinGetMinMax(hwnd) = -1)
                continue
            cands.Push(hwnd)
            procs[hwnd] := ProcKey(hwnd)
        }
    }

    browser := 0
    for hwnd in cands {
        if (procs[hwnd] != "" && InList(brProcs, procs[hwnd])) {
            browser := hwnd
            break
        }
    }

    clis := []
    for hwnd in cands {
        if (hwnd = browser)
            continue
        if (clis.Length >= 4)
            break
        proc := procs[hwnd]
        isCli := (proc != "" && InList(cliProcs, proc))
        if (!isCli) {
            t := WinGetTitle(hwnd)
            isCli := InStr(t, "Claude Code") || InStr(t, "MINGW") || InStr(t, " - bash")
        }
        if (isCli)
            clis.Push(hwnd)
    }

    return {clis: clis, browser: browser}
}

ArrangeAllWindows() {
    global g_MinTermWidth

    found := CollectWindows()
    if (found.clis.Length = 0 && !found.browser) {
        ToolTip("✖ 未找到可排版的窗口")
        SetTimer () => ToolTip(), -1800
        return
    }

    isFirstRun := (g_MinTermWidth = 0)
    if (isFirstRun && found.clis.Length > 0)
        AutoMeasureMinWidth(found.clis)

    slots := [7, 8, 1, 2]
    for i, h in found.clis {
        SnapWindowToState(h, slots[i], 1)
        Sleep 40
    }
    if (found.browser) {
        SnapWindowToState(found.browser, 6, 1)
        Sleep 40
    }

    ; 冷启动首次排版保护：Windows 11 DWM 最大化还原动画与圆角切换存在异步时滞，
    ; 自动在首轮排版沉降后执行一次快速无感复位，确保初次使用无需按第二次 Win+Alt+A 即可 100% 严丝合缝
    if (isFirstRun) {
        Sleep 60
        for i, h in found.clis {
            SnapWindowToState(h, slots[i], 1)
        }
        if (found.browser)
            SnapWindowToState(found.browser, 6, 1)
    }

    ToolTip("✔ WinTile5 无缝排版完成 (4 终端 + 1 主界面)")
    SetTimer () => ToolTip(), -2500
}

Arrange2x2Windows() {
    global g_StateCache
    wins := []
    for hwnd in WinGetList() {
        try {
            if !(WinGetStyle(hwnd) & 0x10000000)
                continue
            title := WinGetTitle(hwnd)
            if (title == "" || title == "Program Manager" || title == "Settings")
                continue
            if (WinGetMinMax(hwnd) = -1)
                continue
            wins.Push(hwnd)
            if (wins.Length >= 4)
                break
        }
    }
    for i, h in wins {
        if g_StateCache.Has(h)
            g_StateCache.Delete(h)
        Get2x2Coordinates(i, &x, &y, &w, &h2)
        SnapWindowTo(h, x, y, w, h2)
        Sleep 40
    }
    ToolTip("✔ 标准 2x2 网格排版完成")
    SetTimer () => ToolTip(), -1800
}

; ==============================================================================
; 7. 单元测试自检 (--self-test 模式，10状态转移与几何识别全量断言)
; ==============================================================================

RunSelfTest() {
    layout := GetLayoutInfo(1)
    passCount := 0
    failCount := 0

    AssertEqual(expected, actual, desc) {
        if (expected == actual) {
            FileAppend("[PASS] " desc ": expected " expected ", got " actual "`n", "*", "UTF-8")
            return true
        } else {
            FileAppend("[FAIL] " desc ": expected " expected ", but got " actual "`n", "*", "UTF-8")
            return false
        }
    }

    ; 1. Right 状态转移 (10项)
    expectedRight := Map(7,78, 78,8, 8,6, 1,12, 12,2, 2,6, 71,7812, 7812,82, 82,6, 6,6)
    for s, exp in expectedRight {
        res := GetNextState(s, "Right", layout, {x: 0, y: 0, w: 100, h: 100})
        AssertEqual(exp, res, "Right: " s " -> " exp) ? passCount++ : failCount++
    }

    ; 2. Left 状态转移 (10项)
    expectedLeft := Map(6,82, 82,7812, 7812,71, 71,71, 8,78, 78,7, 7,7, 2,12, 12,1, 1,1)
    for s, exp in expectedLeft {
        res := GetNextState(s, "Left", layout, {x: 0, y: 0, w: 100, h: 100})
        AssertEqual(exp, res, "Left: " s " -> " exp) ? passCount++ : failCount++
    }

    ; 3. Up 状态转移 (10项)
    expectedUp := Map(1,71, 71,7, 7,7, 2,82, 82,8, 8,8, 12,7812, 7812,78, 78,78, 6,6)
    for s, exp in expectedUp {
        res := GetNextState(s, "Up", layout, {x: 0, y: 0, w: 100, h: 100})
        AssertEqual(exp, res, "Up: " s " -> " exp) ? passCount++ : failCount++
    }

    ; 4. Down 状态转移 (10项)
    expectedDown := Map(7,71, 71,1, 1,1, 8,82, 82,2, 2,2, 78,7812, 7812,12, 12,12, 6,6)
    for s, exp in expectedDown {
        res := GetNextState(s, "Down", layout, {x: 0, y: 0, w: 100, h: 100})
        AssertEqual(exp, res, "Down: " s " -> " exp) ? passCount++ : failCount++
    }

    ; 5. Unknown 状态的智能几何推导转移断言
    ; 5.1 处于 7 号位区域: Down -> 71 (解决用户反馈的核心痛点: 7 号位按 Down 到 71 而不是 12)
    res := GetNextState("Unknown", "Down", layout, layout.rects[7])
    AssertEqual(71, res, "Unknown at slot 7 + Down -> 71") ? passCount++ : failCount++

    ; 5.2 处于 8 号位区域: Right -> 6 (用户要求: 8/2/82按右键应当到6号位)
    res := GetNextState("Unknown", "Right", layout, layout.rects[8])
    AssertEqual(6, res, "Unknown at slot 8 + Right -> 6") ? passCount++ : failCount++

    ; 5.3 处于 2 号位区域: Right -> 6
    res := GetNextState("Unknown", "Right", layout, layout.rects[2])
    AssertEqual(6, res, "Unknown at slot 2 + Right -> 6") ? passCount++ : failCount++

    ; 5.4 处于 82 号位区域: Right -> 6
    res := GetNextState("Unknown", "Right", layout, layout.rects[82])
    AssertEqual(6, res, "Unknown at slot 82 + Right -> 6") ? passCount++ : failCount++

    ; 5.5 处于 6 号主区域: Left -> 82 (用户要求: 6号位按左键应当到82合并位)
    res := GetNextState("Unknown", "Left", layout, layout.rects[6])
    AssertEqual(82, res, "Unknown at slot 6 + Left -> 82") ? passCount++ : failCount++

    ; 5.6 处于 78 号复合区: Down -> 7812
    res := GetNextState("Unknown", "Down", layout, layout.rects[78])
    AssertEqual(7812, res, "Unknown at slot 78 + Down -> 7812") ? passCount++ : failCount++

    ; 5.7 处于 7812 号复合区: Down -> 12
    res := GetNextState("Unknown", "Down", layout, layout.rects[7812])
    AssertEqual(12, res, "Unknown at slot 7812 + Down -> 12") ? passCount++ : failCount++

    ; 5.8 处于 12 号复合区: Up -> 7812
    res := GetNextState("Unknown", "Up", layout, layout.rects[12])
    AssertEqual(7812, res, "Unknown at slot 12 + Up -> 7812") ? passCount++ : failCount++

    ; 6. 终端最小宽度超限自适应识别测试 (宽度大于 colW 但仍在 7 号位)
    oversizedTermRect := {
        x: layout.rects[7].x,
        y: layout.rects[7].y,
        w: layout.rects[7].w + 150,
        h: layout.rects[7].h
    }
    identifiedState := FindClosestLayoutState(oversizedTermRect, layout)
    AssertEqual(7, identifiedState, "FindClosestLayoutState on oversized terminal at slot 7 -> 7") ? passCount++ : failCount++
    res := GetNextState("Unknown", "Down", layout, oversizedTermRect)
    AssertEqual(71, res, "Oversized terminal at slot 7 + Down -> 71") ? passCount++ : failCount++

    totalTests := passCount + failCount
    FileAppend("`n=== Test Summary: " passCount "/" totalTests " Passed, " failCount " Failed ===`n", "*", "UTF-8")

    return (failCount == 0) ? 0 : 1
}
