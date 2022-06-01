## ControllerBuddy-Install-Script

#### License Information:
GNU General Public License v3.0

#### Description:
This script streamlines installing and updating [ControllerBuddy](https://controllerbuddy.org) and the official [ControllerBuddy-Profiles](https://github.com/bwRavencl/ControllerBuddy-Profiles).  
It performs the following tasks:
- Ensures you have the correct version of [vJoy](https://github.com/jshafer817/vJoy) installed
- Configures a vJoy device for ControllerBuddy
- Downloads and installs the latest release of ControllerBuddy into your user's `%LOCALAPPDATA%/Programs` folder
- If missing creates the following Start menu shortcuts:
  - `ControllerBuddy` (launches ControllerBuddy with arguments: `-autostart local -tray`)
  - `Update ControllerBuddy` (performs the same steps as if you would run `InstallControllerBuddy.sh`)
- Ensures you have the latest version of the official [ControllerBuddy-Profiles](https://github.com/bwRavencl/ControllerBuddy-Profiles) installed into your user's `Documents` folder
- Creates the `%CONTROLLER_BUDDY_PROFILE_DIR%` and `%CONTROLLER_BUDDY_EXECUTABLE%` environment variables (required for [ControllerBuddy-DCS-Integration](https://github.com/bwRavencl/ControllerBuddy-DCS-Integration))
- When updating: stops and relaunches ControllerBuddy (with arguments: `-autostart local -tray`) after updating is completed

#### Requirements:
- Windows x64
- [Git for Windows](https://git-scm.com/download/win)

#### Usage:
1. Make sure you have installed [Git for Windows](https://git-scm.com/download/win) first (if unsure use the default options during installation)
2. Right click and select *Save link as* [here](https://raw.githubusercontent.com/bwRavencl/ControllerBuddy-Install-Script/master/InstallControllerBuddy.sh) to download `InstallControllerBuddy.sh`
3. Double click the downloaded file `InstallControllerBuddy.sh` to start installing / updating
4. Regularly launch `Update ControllerBuddy` from the Start menu to receive current updates for ControllerBuddy and the ControllerBuddy-Profiles
5. You may also want to come back to this page from time to time to get the updated versions of `InstallControllerBuddy.sh`
