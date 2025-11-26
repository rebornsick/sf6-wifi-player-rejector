#Requires AutoHotkey v2.0
ListLines false
KeyHistory 0
Persistent
CoordMode "Pixel", "Client"

; Configuration object containing game parameters, UI regions, and control settings
global config := {
    ProcessName: "StreetFighter6.exe",  ; Target game executable
    ReferenceResolution: [1920, 1080],   ; Base resolution for pixel coordinate scaling
    Tolerance: 4,                        ; Color matching tolerance (0-255)
    ConfirmationDelay: 1500,             ; Delay before confirming match (ms)
    MainTimerInterval: 1000,             ; Main loop interval (ms)
    WindowUpdateInterval: 60,            ; Window dimension update frequency
    Regions: {
        Queue: {           ; Pixel region for queue status indicator
            X1: 810, Y1: 942,
            X2: 813, Y2: 945,
            TargetColor: 0xE62A2E
        },
        Confirm: {         ; Pixel region for match confirmation button
            X1: 999, Y1: 903,
            X2: 1002, Y2: 906,
            TargetColor: 0xD04769
        }
    },
    Network: {        ; Network type detection pixels
        EthernetPixel: [939, 528],   ; Coordinate for Ethernet icon
        WifiPixel: [939, 501],       ; Coordinate for WiFi icon
        BackgroundColor: 0x111111    ; Background color
    },
    Controller: {     ; Game controller button mappings
        LaunchGameButton: "Joy8",     ; Button to launch game
        ActivateWindowButton: "Joy7", ; Button to focus game window
        MaxScanNumber: 16             ; Max controllers to scan
    }
}

; Game state tracking variables
global gameState := {
    ConfirmationTimer: 0,   ; Timestamp for confirmation delay
    WindowWidth: 0,         ; Current game window width
    WindowHeight: 0,        ; Current game window height
    BorderHeight: 0,        ; Top/bottom border height for aspect ratio
    IsInQueue: false,       ; Match queue status
    IsGameRunning: false,   ; Game process status
    IsFirstLaunch: true,    ; First execution flag
    ControllerNumber: 0     ; Detected controller number
}

; Resolution scaling factors for different window sizes
global scale := { X: 1.0, Y: 1.0 }
global timerCounter := 0

; Restart with administrator privileges if not already running as admin
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

; Enable DPI awareness for accurate pixel coordinates on high-DPI displays
DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")

; Start timer loops
SetTimer(ControllerInputHandler, 100)
SetTimer(MainLoop, config.MainTimerInterval)

; Main detection loop - runs every MainTimerInterval milliseconds
MainLoop() {
    global config, gameState, timerCounter, scale

    timerCounter++

    ; Check if game is still running
    if !WinExist("ahk_exe " . config.ProcessName) {
        gameState.IsGameRunning := false
        return
    }

    ; Periodically update window dimensions
    if (gameState.IsFirstLaunch || Mod(timerCounter, config.WindowUpdateInterval) = 0) {
        UpdateGameWindowDimensions()
    }

    ; Update scaling if window size changed
    currentWindow := GetGameWindowDimensions()
    if (!gameState.IsGameRunning ||
        gameState.WindowWidth != currentWindow.Width ||
        gameState.WindowHeight != currentWindow.Height) {
        UpdateResolutionScaling()
        gameState.IsGameRunning := true
    }

    ; Detect match state when game window is active
    if WinActive("ahk_exe " . config.ProcessName) {
        DetectMatchState()
    }
}

; Get current game window dimensions
GetGameWindowDimensions() {
    WinGetClientPos(, , &width, &height, "ahk_exe " . config.ProcessName)
    return { Width: width, Height: height }
}

; Update stored window dimensions
UpdateGameWindowDimensions() {
    global gameState
    windowSize := GetGameWindowDimensions()
    gameState.WindowWidth := windowSize.Width
    gameState.WindowHeight := windowSize.Height
    gameState.IsFirstLaunch := false
}

; Calculate scaling factors and border height for resolution adaptation
UpdateResolutionScaling() {
    global config, gameState, scale
    refWidth := config.ReferenceResolution[1], refHeight := config.ReferenceResolution[2]
    currWidth := gameState.WindowWidth, currHeight := gameState.WindowHeight

    static lastWidth := 0, lastHeight := 0
    if (currWidth = lastWidth && currHeight = lastHeight)
        return

    lastWidth := currWidth
    lastHeight := currHeight
    scale.X := currWidth / refWidth

    effectiveGameHeight := (refHeight / refWidth) * currWidth
    gameState.BorderHeight := (currHeight - effectiveGameHeight) / 2
    scale.Y := effectiveGameHeight / refHeight
}

; Search for target color in a scaled region and return the found color
SearchPixelInRegion(region) {
    global scale, gameState, config

    ; Scale region coordinates to match current window size and aspect ratio
    x1 := region.X1 * scale.X
    y1 := region.Y1 * scale.Y + gameState.BorderHeight
    x2 := region.X2 * scale.X
    y2 := region.Y2 * scale.Y + gameState.BorderHeight

    ; Search for target color in region
    if PixelSearch(&matchX, &matchY, x1, y1, x2, y2, region.TargetColor, config.Tolerance) {
        return PixelGetColor(matchX, matchY)
    }
    return 0
}

; Check if two colors match within tolerance
ColorsMatch(color1, color2, tolerance) {
    r1 := (color1 >> 16) & 0xFF, g1 := (color1 >> 8) & 0xFF, b1 := color1 & 0xFF
    r2 := (color2 >> 16) & 0xFF, g2 := (color2 >> 8) & 0xFF, b2 := color2 & 0xFF

    return (Abs(r1 - r2) <= tolerance &&
        Abs(g1 - g2) <= tolerance &&
        Abs(b1 - b2) <= tolerance)
}

; Detect if player is in queue or match confirmation screen
DetectMatchState() {
    global config, gameState

    ; Search for queue and confirm indicators
    queueColor := SearchPixelInRegion(config.Regions.Queue)
    confirmColor := SearchPixelInRegion(config.Regions.Confirm)

    ; Check if colors match target values
    gameState.IsInQueue := ColorsMatch(queueColor, config.Regions.Queue.TargetColor, config.Tolerance)
        || ColorsMatch(confirmColor, config.Regions.Confirm.TargetColor, config.Tolerance)

    ; Handle confirmation if in queue
    if (gameState.IsInQueue) {
        HandleMatchConfirmation(queueColor, confirmColor)
    }
}

; Handle match confirmation with delay
HandleMatchConfirmation(queueColor, confirmColor) {
    global config, gameState, scale

    ; Check if match confirmation screen is active
    needConfirmation := !ColorsMatch(queueColor, config.Regions.Queue.TargetColor, config.Tolerance)
        && ColorsMatch(confirmColor, config.Regions.Confirm.TargetColor, config.Tolerance)

    if (needConfirmation) {
        ; Start timer on first detection
        if (gameState.ConfirmationTimer = 0) {
            gameState.ConfirmationTimer := A_TickCount
        }

        ; Execute actions after delay to ensure detection is stable
        if (A_TickCount - gameState.ConfirmationTimer >= config.ConfirmationDelay) {
            ExecuteConfirmationActions()
            gameState.ConfirmationTimer := 0
        }
    } else {
        gameState.ConfirmationTimer := 0
    }
}

; Execute match confirmation or rejection based on opponent's network type
ExecuteConfirmationActions() {
    global config, scale, gameState

    ; Press Tab to open network info
    SendKey("Tab")

    Sleep 500

    ; Get scaled coordinates for network icons
    ethX := config.Network.EthernetPixel[1] * scale.X
    ethY := config.Network.EthernetPixel[2] * scale.Y + gameState.BorderHeight
    wifiX := config.Network.WifiPixel[1] * scale.X
    wifiY := config.Network.WifiPixel[2] * scale.Y + gameState.BorderHeight

    ; Check network type
    ethColor := PixelGetColor(ethX, ethY)
    wifiColor := PixelGetColor(wifiX, wifiY)
    bgColor := config.Network.BackgroundColor

    ; Confirm if Ethernet, Reject if WiFi
    if (ethColor != bgColor && wifiColor = bgColor) {
        SendKey("f")
    } else {
        SendKey("s")
        SendKey("f")
    }
}

; Send a key with configurable delay
SendKey(key, delay := 50) {
    Send "{" key " Down}"
    Sleep delay
    Send "{" key " Up}"
    Sleep delay
}

; Handle controller input for launching game or activating window
ControllerInputHandler() {
    global config, gameState

    ; Detect connected controller
    if (gameState.ControllerNumber <= 0) {
        gameState.ControllerNumber := GetConnectedControllerNumber()
        return
    }

    ; Build button names with controller prefix
    controllerPrefix := gameState.ControllerNumber
    launchButton := controllerPrefix . config.Controller.LaunchGameButton
    activateButton := controllerPrefix . config.Controller.ActivateWindowButton

    ; Launch game if not running and button pressed
    if (!WinExist("ahk_exe " . config.ProcessName) && GetKeyState(launchButton)) {
        Run "steam://rungameid/1364780"
    }
    ; Focus window if running but not active and button pressed
    else if (WinExist("ahk_exe " . config.ProcessName) && !WinActive("ahk_exe " . config.ProcessName) && GetKeyState(activateButton)) {
        WinActivate("ahk_exe " . config.ProcessName)
    }
}

; Detect connected controller number (1-16)
GetConnectedControllerNumber() {
    global config
    loop config.Controller.MaxScanNumber {
        if GetKeyState(A_Index "JoyName") {
            return A_Index
        }
    }
    return 0
}
