# ControllerBuddy-Install-Script

## Description

This script streamlines installing and updating [ControllerBuddy](https://controllerbuddy.org) and the official [ControllerBuddy-Profiles](https://github.com/bwRavencl/ControllerBuddy-Profiles) on Windows and Linux x86-64 systems.  
It performs the following tasks:

- Checks for the latest version of `InstallControllerBuddy.sh` and updates itself when necessary
- Ensures you have the correct version of [vJoy](https://github.com/jshafer817/vJoy) installed (*only on Windows*)
- Configures a vJoy device for ControllerBuddy (*only on Windows*)
- Ensures you have [cUrl](https://curl.se/) and [libSDL2](https://www.libsdl.org/) installed (*only on Linux*)
- Configures [udev](https://www.freedesktop.org/software/systemd/man/udev.html) and [uinput](https://www.kernel.org/doc/html/latest/input/uinput.html) for ControllerBuddy
  (*only on Linux*)
- Downloads and installs the latest release of ControllerBuddy
- If missing creates the following Start menu shortcuts:
    - `ControllerBuddy` (launches ControllerBuddy with arguments: `-autostart local -tray`)
    - `Update ControllerBuddy` (performs the same steps as if you would run `InstallControllerBuddy.sh`)
    - `Uninstall ControllerBuddy` (removes ControllerBuddy by launching `InstallControllerBuddy.sh uninstall`)
- Ensures you have the latest version of the official [ControllerBuddy-Profiles](https://github.com/bwRavencl/ControllerBuddy-Profiles) installed into your user's `Documents` folder
- Executes the `Configure.ps1` scripts to configure your applications for usage with the official ControllerBuddy-Profiles
  (*only on Windows*)
- Sets up [ControllerBuddy-DCS-Integration](https://github.com/bwRavencl/ControllerBuddy-DCS-Integration) if [DCS World](https://www.digitalcombatsimulator.com) is present
  (*only on Windows*)
- When updating stops and later relaunches ControllerBuddy (with arguments: `-autostart local -tray`)

## Installing

1. Right click [here](https://raw.githubusercontent.com/bwRavencl/ControllerBuddy-Install-Script/master/InstallControllerBuddy.sh)
   and select *Save link as* to download `InstallControllerBuddy.sh`
2. Depending on your operating system:

    - **On Windows:** Make sure you have installed [Git for Windows](https://git-scm.com/download/win)
      (if unsure use the default options during installation)

    - **On Linux:** Make `InstallControllerBuddy.sh` executable with: `chmod +x InstallControllerBuddy.sh`
3. Make sure your gamepad is connected
4. Double-click the downloaded file `InstallControllerBuddy.sh` to start installing / updating

## Updating

Launch `Update ControllerBuddy` from the Start menu to receive the latest updates for ControllerBuddy and the ControllerBuddy-Profiles.

**Important:** Always check that your gamepad is connected before starting the script!

## Uninstalling

If you would like to remove ControllerBuddy from your system run `Uninstall ControllerBuddy` from the Start menu.

## License Information

GNU General Public License v3.0
