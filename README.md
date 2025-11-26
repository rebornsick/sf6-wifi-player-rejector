# SF6 WiFi Player Rejector

This project is an AutoHotkey v2 script designed to automate the process of rejecting WiFi players in the PC version of Street Fighter 6. It works by monitoring the game's matchmaking screen, detecting the network type of the opponent, and automatically confirming or rejecting matches based on whether the opponent is using a wired (Ethernet) or wireless (WiFi) connection.

## Features
- **Automatic Detection:** Monitors the Street Fighter 6 matchmaking screen for incoming matches.
- **Network Type Check:** Uses pixel color detection to determine if the opponent is on Ethernet or WiFi.
- **Auto-Confirm/Reject:** Automatically confirms matches with Ethernet players and rejects those with WiFi players.
- **Controller Support:** Allows launching the game or activating the game window using controller buttons.
- **Resolution Scaling:** Supports different window sizes and aspect ratios by dynamically scaling pixel search regions.
- **Admin Privileges:** Automatically restarts the script with administrator rights if not already running as admin.

## How It Works
1. **Game Detection:** The script checks if `StreetFighter6.exe` is running and active.
2. **Pixel Search:** It searches specific screen regions for color values that indicate matchmaking and confirmation dialogs.
3. **Network Check:** When a match is found, it checks the color of pixels associated with Ethernet and WiFi icons.
4. **Action Automation:**
	- If the opponent is on Ethernet, the script confirms the match (sends `f` key).
	- If the opponent is on WiFi, the script rejects the match (sends `s` then `f` keys).
5. **Controller Integration:** You can launch the game or bring it to the foreground using designated controller buttons.

## Usage
1. Install [AutoHotkey v2](https://www.autohotkey.com/download/).
2. Run `WiFiRejector.ahk` as administrator (the script will auto-restart as admin if needed).
3. Start Street Fighter 6.
4. The script will run in the background and handle matchmaking automatically.

## Configuration
You can adjust settings such as pixel regions, color tolerances, controller buttons, and delays by editing the `config` object at the top of the script.

## Disclaimer
This script is provided for educational purposes. Use at your own risk. The author is not responsible for any bans or issues resulting from its use.
