## ControllerBuddy-Install-Script

#### License Information:
GNU General Public License v3.0

#### Description:
This bash script for the Windows x64 platform simplifies installing and updating [ControllerBuddy](https://controllerbuddy.org).
It performs the following tasks:
- Downloads the latest release of ControllerBuddy for Windows from GitHub
- And extracts it into your user's `%LOCALAPPDATA%/Programs` folder
- If missing creates a Start menu shortcut for ControllerBuddy (with arguments: `-autostart local -tray`)
- When updating: stops and relaunches ControllerBuddy (with arguments: `-autostart local -tray`) after updating is completed

Please note that the script will **not** install and configure vJoy for usage with ControllerBuddy.

#### Requirements:
- Windows x64
- [Git for Windows](https://git-scm.com/download/win)
