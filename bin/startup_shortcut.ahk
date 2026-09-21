#Requires AutoHotkey v2.0
#SingleInstance Force

; 用 AHK 自带的快捷方式 API 创建 / 删除开机自启项，避免 .bat 的引号与编码问题。
; 用法：AutoHotkey64.exe startup_shortcut.ahk            -> 创建
;       AutoHotkey64.exe startup_shortcut.ahk remove     -> 删除

ROOT_DIR   := RegExReplace(A_ScriptDir, "\\bin$", "")
AHK_EXE    := A_ScriptDir "\AutoHotkey64.exe"
AHK_SCRIPT := ROOT_DIR "\auto_layout.ahk"
LNK_NEW    := A_Startup "\WinTile5.lnk"
LNK_OLD    := A_Startup "\AutoLayout5Windows.lnk"

Log(msg) {
    try FileAppend(msg, "*", "UTF-8")
}

if (A_Args.Length > 0 && A_Args[1] = "remove") {
    removed := false
    if FileExist(LNK_NEW) {
        FileDelete(LNK_NEW)
        removed := true
    }
    if FileExist(LNK_OLD) {
        FileDelete(LNK_OLD)
        removed := true
    }
    if (removed)
        Log("  [OK] 已移除开机自启项。`n")
    else
        Log("  [--] 开机自启项本来就不存在。`n")
} else {
    ; 清理旧名字的快捷方式（如果有）
    if FileExist(LNK_OLD)
        FileDelete(LNK_OLD)

    FileCreateShortcut(AHK_EXE, LNK_NEW, ROOT_DIR, '"' AHK_SCRIPT '"'
        , "WinTile5 - 5-Window Layout Manager"
        , AHK_EXE, , 1)
    if FileExist(LNK_NEW) {
        Log("  [OK] 已写入开机自启项：`n")
        Log("       " LNK_NEW "`n")
    } else {
        Log("  [!!] 快捷方式创建失败，请检查权限。`n")
        ExitApp(1)
    }
}

ExitApp(0)
