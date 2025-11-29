#Requires AutoHotkey v2.0
ListLines false
KeyHistory 0
Persistent
CoordMode "Pixel", "Client"

; Global configuration for game automation
global Config := {
    ConfirmDelay: 1500,       ; Delay before auto-confirming match (ms)
    MainInterval: 1000,       ; Main loop interval (ms)
    WinUpdateInterval: 60,    ; Window size update interval (loop counts)
    RefRes: [1920, 1080],     ; Reference resolution (base for scaling)
    GameWinTitle: "StreetFighter6.exe",  ; Target game process
    Region: {                 ; Color detection area for match status
        X1: 810, Y1: 942, X2: 813, Y2: 945,
        QueueColor: 0xE62A2E, ; Color for "in queue" state
        ConfirmColor: 0x36074F, ; Color for "need confirm" state
        Tolerance: 4          ; Color matching tolerance
    },
    Network: {                ; Network status detection positions
        EthPx: [939, 528],    ; Wired network icon position
        WifiPx: [939, 501],   ; Wifi network icon position
        BgColor: 0x111111     ; Background color of network area
    },
    Controller: {             ; Gamepad button settings
        LaunchBtn: "Joy8",    ; Button to launch game
        ActivateBtn: "Joy7",  ; Button to activate game window
        MaxScan: 16           ; Max gamepad devices to scan
    }
}

; Runtime state tracking
global State := {
    ConfirmTimer: 0,          ; Auto-confirm countdown timer
    ClientW: 0, ClientH: 0,   ; Game window client size
    BorderH: 0,               ; Black border height (aspect ratio fix)
    IsInQueue: false,         ; Whether in match queue
    IsRunning: false,         ; Whether game is running
    IsFirstRun: true,         ; First loop flag
    ControllerNum: 0          ; Detected gamepad number
}

global Scale := { X: 1.0, Y: 1.0 }  ; Resolution scaling factors
global Counter := 0                 ; Loop counter for window updates

; Admin privilege check - restart with admin if missing
if !(A_IsAdmin || RegExMatch(DllCall("GetCommandLine", "str"), " /restart(?!\S)")) {
    try {
        if A_IsCompiled {
            Run '*RunAs "' A_ScriptFullPath '" /restart'
        } else {
            Run '*RunAs "' A_AhkPath '" /restart "' A_ScriptFullPath '"'
        }
    }
    ExitApp
}

DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")  ; High-DPI compatibility

SetTimer(HandleControllerInput, 100)     ; Gamepad input handler
SetTimer(MainLoop, Config.MainInterval)  ; Main automation loop

; Main loop - core game state handling
MainLoop() {
    global Config, State, Counter, Scale
    Counter++

    ; Check if game window exists
    if !WinExist("ahk_exe " . Config.GameWinTitle) {
        State.IsRunning := false
        return
    }

    ; Update window size periodically
    if (State.IsFirstRun || Mod(Counter, Config.WinUpdateInterval) = 0) {
        UpdateClientSize()
    }

    ; Recalculate scale if window size changed
    currentWin := GetClientSize()
    if (!State.IsRunning || State.ClientW != currentWin.W || State.ClientH != currentWin.H) {
        CalcScale()
        State.IsRunning := true
    }

    ; Process matchmaking logic if game is active
    if WinActive("ahk_exe " . Config.GameWinTitle) {
        HandleMachmaking()
    }
}

; Get game window client size (excludes borders)
GetClientSize() {
    WinGetClientPos(, , &w, &h, "ahk_exe " . Config.GameWinTitle)
    return { W: w, H: h }
}

; Update window size in state
UpdateClientSize() {
    global State
    winSize := GetClientSize()
    State.ClientW := winSize.W
    State.ClientH := winSize.H
    State.IsFirstRun := false
}

; Calculate resolution scaling for different window sizes
CalcScale() {
    global Config, State, Scale
    refW := Config.RefRes[1], refH := Config.RefRes[2]
    currW := State.ClientW, currH := State.ClientH

    static lastW := 0, lastH := 0
    if (currW = lastW && currH = lastH)
        return
    lastW := currW, lastH := currH

    Scale.X := currW / refW
    effectiveH := (refH / refW) * currW  ; Maintain 16:9 aspect ratio
    State.BorderH := (currH - effectiveH) / 2  ; Calculate black border
    Scale.Y := effectiveH / refH
}

; Search for target color in scaled region
SearchColor(Color, Region) {
    global Scale, State
    x1 := Region.X1 * Scale.X
    y1 := Region.Y1 * Scale.Y + State.BorderH
    x2 := Region.X2 * Scale.X
    y2 := Region.Y2 * Scale.Y + State.BorderH

    if PixelSearch(&matchX, &matchY, x1, y1, x2, y2, Color, Region.Tolerance) {
        return PixelGetColor(matchX, matchY)
    }
    return 0
}

; Check if two colors match within tolerance
ColorsMatch(Color1, Color2, Tolerance) {
    r1 := (Color1 >> 16) & 0xFF, g1 := (Color1 >> 8) & 0xFF, b1 := Color1 & 0xFF
    r2 := (Color2 >> 16) & 0xFF, g2 := (Color2 >> 8) & 0xFF, b2 := Color2 & 0xFF
    return (Abs(r1 - r2) <= Tolerance && Abs(g1 - g2) <= Tolerance && Abs(b1 - b2) <= Tolerance)
}

; Handle matchmaking state detection and auto-confirm
HandleMachmaking() {
    global Config, State
    currQueueColor := SearchColor(Config.Region.QueueColor, Config.Region)
    currConfirmColor := SearchColor(Config.Region.ConfirmColor, Config.Region)

    isQueue := ColorsMatch(currQueueColor, Config.Region.QueueColor, Config.Region.Tolerance)
    isConfirm := ColorsMatch(currConfirmColor, Config.Region.ConfirmColor, Config.Region.Tolerance)

    State.IsInQueue := isQueue || isConfirm

    ; Trigger auto-confirm if needed
    if (State.IsInQueue) {
        needConfirm := !isQueue && isConfirm
        if (needConfirm) {
            if (State.ConfirmTimer = 0) {
                State.ConfirmTimer := A_TickCount
            }
            if (A_TickCount - State.ConfirmTimer >= Config.ConfirmDelay) {
                ExecuteConfirm()
                State.ConfirmTimer := 0
            }
        } else {
            State.ConfirmTimer := 0
        }
    }
}

; Execute match confirmation keystrokes
ExecuteConfirm() {
    global Config, Scale, State
    SendKey("Tab")  ; Focus confirm button
    Sleep 500

    ; Check network type (wired/wifi)
    ethX := Config.Network.EthPx[1] * Scale.X
    ethY := Config.Network.EthPx[2] * Scale.Y + State.BorderH
    wifiX := Config.Network.WifiPx[1] * Scale.X
    wifiY := Config.Network.WifiPx[2] * Scale.Y + State.BorderH

    ethColor := PixelGetColor(ethX, ethY)
    wifiColor := PixelGetColor(wifiX, wifiY)
    bgColor := Config.Network.BgColor

    ; Send confirm keys based on network
    if (ethColor != bgColor && wifiColor = bgColor) {
        SendKey("f")
    } else {
        SendKey("s")
        SendKey("f")
    }
}

; Simulate key press with delay
SendKey(Key, Delay := 50) {
    Send "{" Key " Down}"
    Sleep Delay
    Send "{" Key " Up}"
    Sleep Delay
}

; Handle gamepad input (launch/activate game)
HandleControllerInput() {
    global Config, State
    ; Detect gamepad if not found
    if (State.ControllerNum <= 0) {
        State.ControllerNum := FindController()
        return
    }

    prefix := State.ControllerNum
    launchBtn := prefix . Config.Controller.LaunchBtn
    activateBtn := prefix . Config.Controller.ActivateBtn

    ; Launch game via Steam if button pressed
    if (!State.IsRunning && GetKeyState(launchBtn)) {
        Run "steam://rungameid/1364780"  ; SF6 Steam AppID
    }
    ; Activate game window if button pressed
    if (State.IsRunning && !WinActive("ahk_exe " . Config.GameWinTitle) && GetKeyState(activateBtn)) {
        WinActivate("ahk_exe " . Config.GameWinTitle)
    }
}

; Find connected gamepad device
FindController() {
    global Config
    loop Config.Controller.MaxScan {
        if GetKeyState(A_Index "JoyName") {
            return A_Index
        }
    }
    return 0
}
