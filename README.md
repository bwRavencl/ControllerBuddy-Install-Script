## ControllerBuddy-Install-Script

#### License Information:
GNU General Public License v3.0

#### Description:
This script streamlines installing and updating [ControllerBuddy](https://controllerbuddy.org) and the official [ControllerBuddy-Profiles](https://github.com/bwRavencl/ControllerBuddy-Profiles) on Windows and Linux x86-64 systems.  
It performs the following tasks:
- Ensures you have the correct version of [vJoy](https://github.com/jshafer817/vJoy) installed (*only on Windows*)
- Configures a vJoy device for ControllerBuddy (*only on Windows*)
- Ensures you have [libSDL2](https://www.libsdl.org/) installed (*only on Linux*)
- Configures [udev](https://www.freedesktop.org/software/systemd/man/udev.html) and [uinput](https://www.kernel.org/doc/html/latest/input/uinput.html) for ControllerBuddy (*only on Linux*)
- Downloads and installs the latest release of ControllerBuddy
- If missing creates the following Start menu shortcuts:
  - `ControllerBuddy` (launches ControllerBuddy with arguments: `-autostart local -tray`)
  - `Update ControllerBuddy` (performs the same steps as if you would run `InstallControllerBuddy.sh`)
  - `Uninstall ControllerBuddy` (removes ControllerBuddy (except the ControllerBuddy-Profiles repository by launching `InstallControllerBuddy.sh uninstall`)
- Ensures you have the latest version of the official [ControllerBuddy-Profiles](https://github.com/bwRavencl/ControllerBuddy-Profiles) installed into your user's `Documents` folder
- Sets up [ControllerBuddy-DCS-Integration](https://github.com/bwRavencl/ControllerBuddy-DCS-Integration) if [DCS World](https://www.digitalcombatsimulator.com) (Stable or OpenBeta) is present y (*only on Windows*)
- When updating: stops and relaunches ControllerBuddy (with arguments: `-autostart local -tray`) after updating is completed

#### Usage:
1. **On Windows only:** Make sure you have installed [Git for Windows](https://git-scm.com/download/win) first (if unsure use the default options during installation)
2. Right click and select *Save link as* [here](https://raw.githubusercontent.com/bwRavencl/ControllerBuddy-Install-Script/master/InstallControllerBuddy.sh) to download `InstallControllerBuddy.sh`
3. **On Linux only:** Make `InstallControllerBuddy.sh` executable with: `chmod +x InstallControllerBuddy.sh`
4. Double click the downloaded file `InstallControllerBuddy.sh` to start installing / updating
5. Regularly launch `Update ControllerBuddy` from the Start menu to receive latest updates for ControllerBuddy and the ControllerBuddy-Profiles
6. You may also want to come back to this page from time to time to get the updated versions of `InstallControllerBuddy.sh`
7. If you would like to remove ControllerBuddy from your system run `Uninstall ControllerBuddy` from the Start menu
