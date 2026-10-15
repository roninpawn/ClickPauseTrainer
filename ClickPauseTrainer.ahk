; Click -> Pause Trainer (AutoHotkey v2)
#Requires AutoHotkey v2.0
#SingleInstance Force

;@Ahk2Exe-SetDescription Click -> Pause Trainer
;@Ahk2Exe-SetCompanyName Roninpawn
;@Ahk2Exe-SetVersion 1.0
;@Ahk2Exe-SetMainIcon ClickPauseTrainer.ico

configPath := A_ScriptDir "\ClickPauseTrainer.ini"
mouseKeys := ["LButton", "RButton", "MButton", "XButton1", "XButton2"]
timeout := 250
firstKey := ""
firstAt := 0
activeKeys := []
capturing := false

DllCall("QueryPerformanceFrequency", "Int64*", &frequency := 0)

try {
    first := Setting("Inputs", "First", "LButton")
    second := Setting("Inputs", "Second", "e")
    target := Setting("Timing", "Target", 14)
    range := Setting("Timing", "Range", 10)
    Setting("Credits", "Authors", "Roninpawn & ChatGPT")
    Setting("Credits", "Version", "1.0")
    Setting("Credits", "Written", "2026-10-14")
    if !IsNumber(target) || !IsNumber(range) || range < 0
        throw Error("Target must be numeric and Range must be nonnegative.")
    target += 0
    range += 0
    windowX := IniRead(configPath, "Window", "X", "")
    windowY := IniRead(configPath, "Window", "Y", "")
} catch as err {
    MsgBox("Cannot load settings in " configPath ":`n" err.Message)
    ExitApp()
}

; Compact, borderless, always-on-top window.
trainer := Gui("-Caption +AlwaysOnTop +ToolWindow +E0x08000000", "Click → Pause Trainer")
trainer.BackColor := "1B1E1E"
trainer.SetFont("s8 cD0D0D0", "Segoe UI")
header := trainer.AddText("x7 y7 w161 h19", "Click → Pause Trainer")
closeButton := trainer.AddText("x171 y5 w18 h22 Center", "×")
closeButton.OnEvent("Click", (*) => ExitApp())

trainer.SetFont("s20 Bold cFFFFFF")
readout := trainer.AddText("x5 y36 w184 h42 Center", "--.- ms")
trainer.SetFont("s9 Norm cBBBBBB")
bindLabel := trainer.AddText("x7 y83 w140 h24 Center", first " → " second)
settings := trainer.AddText("x157 y83 w27 h24 Center", "⚙")
settings.OnEvent("Click", Configure)
trainer.AddText("x5 y113 w184 h18 Center", "Target: " (target >= 0 ? "+" : "") target " | Range: ±" range " ms")
trainer.OnEvent("Close", (*) => ExitApp())
showOptions := "NoActivate w194 h138"
if PositionVisible(windowX, windowY, 194, 138)
    showOptions .= " x" windowX " y" windowY
trainer.Show(showOptions)
OnExit(SavePosition)

OnMessage(0x201, DragSurface)  ; WM_LBUTTONDOWN anywhere except the two buttons.
try WatchInputs()
catch as err {
    MsgBox("Invalid bindings in " configPath ":`n" err.Message)
    ExitApp()
}
SetTimer(KeepAbove, 500)

; Save the window's actual position when the script exits, including via the tray icon.
SavePosition(*) {
    global trainer, configPath
    try {
        trainer.GetPos(&x, &y)
        IniWrite(x, configPath, "Window", "X")
        IniWrite(y, configPath, "Window", "Y")
    }
}

; Don't restore onto a disconnected monitor or entirely outside the desktop.
PositionVisible(x, y, width, height) {
    if !IsInteger(x) || !IsInteger(y)
        return false

    Loop MonitorGetCount() {
        MonitorGetWorkArea(A_Index, &left, &top, &right, &bottom)
        visibleWidth := Max(0, Min(x + width, right) - Max(x, left))
        visibleHeight := Max(0, Min(y + height, bottom) - Max(y, top))
        if visibleWidth >= 80 && visibleHeight >= 40
            return true
    }
    return false
}

Setting(section, key, default) {
    global configPath
    value := IniRead(configPath, section, key, "__MISSING__")
    if value = "__MISSING__" {
        IniWrite(default, configPath, section, key)
        return default
    }
    return value
}

DragSurface(wParam, lParam, msg, hwnd) {
    global trainer, settings, closeButton
    if hwnd != trainer.Hwnd && !DllCall("User32\IsChild", "Ptr", trainer.Hwnd, "Ptr", hwnd)
        return
    if IsOver(settings.Hwnd) || IsOver(closeButton.Hwnd)
        return

    DllCall("User32\ReleaseCapture")
    PostMessage(0xA1, 2, 0, , "ahk_id " trainer.Hwnd)  ; WM_NCLBUTTONDOWN, HTCAPTION.
}

IsOver(hwnd) {
    point := Buffer(8)
    rect := Buffer(16)
    DllCall("User32\GetCursorPos", "Ptr", point)
    DllCall("User32\GetWindowRect", "Ptr", hwnd, "Ptr", rect)
    x := NumGet(point, 0, "Int"), y := NumGet(point, 4, "Int")
    return x >= NumGet(rect, 0, "Int") && x < NumGet(rect, 8, "Int")
        && y >= NumGet(rect, 4, "Int") && y < NumGet(rect, 12, "Int")
}

WatchInputs() {
    global first, second, activeKeys
    if first = second
        throw Error("First and Second must be different.")
    activeKeys := [first, second]
    for key in activeKeys
        Hotkey("~*" key, Record.Bind(key), "On")
}

UnwatchInputs() {
    global activeKeys
    for key in activeKeys
        Hotkey("~*" key, "Off")
    activeKeys := []
}

Record(key, *) {
    global first, firstKey, firstAt, frequency, timeout, target, range, readout, capturing
    if capturing
        return
    DllCall("QueryPerformanceCounter", "Int64*", &now := 0)
    elapsed := (now - firstAt) * 1000 / frequency
    if firstKey = "" || elapsed > timeout {
        firstKey := key
        firstAt := now
    } else if key != firstKey {
        delta := firstKey = first ? elapsed : -elapsed
        readout.Text := Format("{:+.1f} ms", delta)
        readout.SetFont(Abs(delta - target) <= range ? "c66DD99" : "cFFFFFF")
        firstKey := ""
    }
}

Configure(*) {
    global trainer, mouseKeys, capturing, captureStep, captureGui, captureText, captureHook, firstKey
    if capturing
        return
    UnwatchInputs()
    firstKey := ""
    capturing := true
    captureStep := 1
    captureGui := Gui("+Owner" trainer.Hwnd " +AlwaysOnTop +ToolWindow", "Configure inputs")
    captureGui.SetFont("s11", "Segoe UI")
    captureText := captureGui.AddText("w330 h60 Center", "Press the FIRST input`n(keyboard or mouse button)")
    captureGui.AddText("w330 Center", "Escape: cancel")
    captureGui.OnEvent("Close", CancelConfigure)
    captureGui.OnEvent("Escape", CancelConfigure)
    trainer.Opt("+Disabled")
    captureGui.Show("AutoSize")
    for key in mouseKeys
        Hotkey("~*" key, CaptureMouse.Bind(key), "On")
    captureHook := InputHook()
    captureHook.KeyOpt("{All}", "N")
    captureHook.OnKeyDown := CaptureKeyboard
    captureHook.Start()
}

CaptureMouse(key, *) {
    Captured(key)
}

CaptureKeyboard(hook, vk, sc) {
    Captured(GetKeyName(Format("vk{:x}sc{:x}", vk, sc)))
}

Captured(key) {
    global capturing, captureStep, pendingFirst, captureText, first, second, configPath, bindLabel, readout
    if !capturing
        return
    if key = "Escape" || key = "Esc" {
        CancelConfigure()
        return
    }
    if captureStep = 1 {
        pendingFirst := key
        captureStep := 2
        captureText.Text := "First: " key "`nPress the SECOND input"
        return
    }
    if key = pendingFirst {
        captureText.Text := "Choose a different second input.`nFirst: " pendingFirst
        return
    }
    try {
        IniWrite(pendingFirst, configPath, "Inputs", "First")
        IniWrite(key, configPath, "Inputs", "Second")
    } catch as err {
        MsgBox("Could not save settings:`n" err.Message)
        CancelConfigure()
        return
    }
    first := pendingFirst
    second := key
    bindLabel.Text := first " → " second
    CancelConfigure()
    readout.Text := "--.- ms"
    readout.SetFont("cFFFFFF")
}

CancelConfigure(*) {
    global capturing, trainer, captureHook, captureGui, mouseKeys, firstKey
    if !capturing
        return
    capturing := false
    captureHook.Stop()
    for key in mouseKeys
        Hotkey("~*" key, "Off")
    trainer.Opt("-Disabled")
    captureGui.Destroy()
    firstKey := ""
    WatchInputs()
}

KeepAbove() {
    global trainer
    if WinActive("ahk_exe Clustertruck.exe")
        DllCall("User32\SetWindowPos", "Ptr", trainer.Hwnd, "Ptr", -1,
            "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x13)
}
