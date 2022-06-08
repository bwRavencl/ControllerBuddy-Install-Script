#!/bin/bash

: '
Copyright (C) 2022  Matteo Hausner

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
'

cat << 'EOF'
  _____          __           ____        ___          __   __
 / ___/__  ___  / /________  / / /__ ____/ _ )__ _____/ /__/ /_ __
/ /__/ _ \/ _ \/ __/ __/ _ \/ / / -_) __/ _  / // / _  / _  / // /
\___/\___/_//_/\__/_/  \___/_/_/\__/_/ /____/\_,_/\_,_/\_,_/\_, /
                  ____         __       ____               /___/
                 /  _/__  ___ / /____ _/ / /__ ____
                _/ // _ \(_-</ __/ _ `/ / / -_) __/
               /___/_//_/___/\__/\_,_/_/_/\__/_/

                      © 2022 Matteo Hausner

EOF

function log() {
    echo "$1"
    if [ -z "$LOG_FILE" ]
    then
        echo "$(date -R): $1" | grep . >> "$LOG_FILE"
    fi
}

function confirm_exit() {
    echo
    if [ "$REBOOT_REQUIRED" = true ]
    then
        log 'IMPORTANT: System configuration has been modified. Please reboot your system!'
    fi
    read -r -p 'Press enter to exit'
    exit 1
}

SCRIPT_NAME=$(basename "$0")

case "$OSTYPE" in
    msys)
        LOG_FILE="$TMP\\InstallControllerBuddy.log"
        VJOY_DESIRED_VERSION='2.1.9.1'
        CB_PARENT_DIR="$LOCALAPPDATA\\Programs"
        CB_DIR="$CB_PARENT_DIR\\ControllerBuddy"
        CB_BIN_DIR="$CB_DIR"
        CB_EXE=ControllerBuddy.exe
        CB_EXE_PATH="$CB_BIN_DIR\\$CB_EXE"
        CB_APP_DIR="$CB_DIR\\app"
        CB_PROFILES_DIR="$USERPROFILE\\Documents\\ControllerBuddy-Profiles"
        CB_SHORTCUTS_DIR="$APPDATA\\Microsoft\\Windows\\Start Menu\\Programs\\ControllerBuddy"
        SAVED_GAMES_DIR="$USERPROFILE\\Saved Games"
        DCS_STABLE_USER_DIR="$SAVED_GAMES_DIR\\DCS"
        DCS_OPEN_BETA_USER_DIR="$SAVED_GAMES_DIR\\DCS.openbeta"
        ;;
    linux-gnu)
        LOG_FILE="/tmp/InstallControllerBuddy.log"
        CB_PARENT_DIR="$HOME"
        CB_DIR="$CB_PARENT_DIR/ControllerBuddy"
        CB_BIN_DIR="$CB_DIR/bin"
        CB_LIB_DIR="$CB_DIR/lib"
        CB_APP_DIR="$CB_LIB_DIR/app"
        CB_EXE=ControllerBuddy
        CB_EXE_PATH="$CB_BIN_DIR/$CB_EXE"
        if which xdg-user-dir >/dev/null
        then
            CB_PROFILES_DIR="$(xdg-user-dir DOCUMENTS)/ControllerBuddy-Profiles"
        else
            CB_PROFILES_DIR="$HOME/ControllerBuddy-Profiles"
        fi
        CB_SHORTCUTS_DIR="$HOME/.local/share/applications/ControllerBuddy"
        ;;
     *)
    log 'Error: This script must be run in a Git Bash for Windows or GNU/Linux Bash environment'
    confirm_exit
esac

rm -rf "$LOG_FILE"

if [ "$(arch)" != x86_64 ]
then
    log 'Error: This script is intended to be run on x86_64 systems'
    confirm_exit
fi

if [ "$1" = uninstall ]
then
    UNINSTALL=true
fi

function check_retval() {
    if [ "$?" -eq 0 ]
    then
        log 'Done!'
        echo
    else
        log "$1"
        confirm_exit
    fi
}

function check_vjoy_installed() {
    log "Checking if vJoy $VJOY_DESIRED_VERSION is installed..."
    local VJOY_UNINSTALL_REGISTRY_KEY='HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{8E31F76F-74C3-47F1-9550-E041EEDC5FBB}_is1'
    VJOY_DIR=$(REG QUERY "$VJOY_UNINSTALL_REGISTRY_KEY" //V InstallLocation | grep InstallLocation | sed -n -e 's/^.*REG_SZ    //p' | sed 's/\\*$//')
    VJOY_CONFIG_EXE_PATH="$VJOY_DIR\\x64\\vJoyConfig.exe"
    VJOY_CURRENT_VERSION=$(REG QUERY "$VJOY_UNINSTALL_REGISTRY_KEY" //V DisplayVersion | grep DisplayVersion | sed -n -e 's/^.*REG_SZ    //p')
    if [ -n "$VJOY_DIR" ] && [ -d "$VJOY_DIR" ] && [ -f "$VJOY_CONFIG_EXE_PATH" ] && [ "$VJOY_CURRENT_VERSION" = "$VJOY_DESIRED_VERSION" ]
    then
        VJOY_INSTALLED=true
    fi
}

function  get_vjoy_config_value() {
    grep "$2" <<< "$1" | cut -d : -f 2 | sed 's/^[ \t]*//;s/[ \t]*$//' | xargs
}

function check_vjoy_configured() {
    log 'Checking if vJoy is configured correctly...'
    local VJOY_CONFIG
    VJOY_CONFIG=$("$VJOY_CONFIG_EXE_PATH" -t 1)
    local VJOY_CONFIG_DEVICE
    VJOY_CONFIG_DEVICE=$(get_vjoy_config_value "$VJOY_CONFIG" Device)
    local VJOY_CONFIG_BUTTONS
    VJOY_CONFIG_BUTTONS=$(get_vjoy_config_value "$VJOY_CONFIG" Buttons)
    local VJOY_CONFIG_DESCRETE_POVS
    VJOY_CONFIG_DESCRETE_POVS=$(get_vjoy_config_value "$VJOY_CONFIG" 'Descrete POVs')
    local VJOY_CONFIG_CONTINUOUS_POVS
    VJOY_CONFIG_CONTINUOUS_POVS=$(get_vjoy_config_value "$VJOY_CONFIG" 'Continous POVs')
    local VJOY_CONFIG_AXES
    VJOY_CONFIG_AXES=$(get_vjoy_config_value "$VJOY_CONFIG" Axes)
    local VJOY_CONFIG_FFB_EFFECTS
    VJOY_CONFIG_FFB_EFFECTS=$(get_vjoy_config_value "$VJOY_CONFIG" 'FFB Effects')
    if [ "$VJOY_CONFIG_DEVICE" = 1 ] && [ "$VJOY_CONFIG_BUTTONS" = 128 ] && [ "$VJOY_CONFIG_DESCRETE_POVS" = 0 ] && [ "$VJOY_CONFIG_CONTINUOUS_POVS" = 0 ] && [ "$VJOY_CONFIG_AXES" = 'X Y Z Rx Ry Rz Sl0 Sl1' ] && [ "$VJOY_CONFIG_FFB_EFFECTS" = 'None' ]
    then
        VJOY_CONFIGURED=true
    fi
}

function remove_controller_buddy() {
if [ -d "$CB_DIR" ]
then
    log 'Stopping any old ControllerBuddy process...'
    if [ "$OSTYPE" = msys ] && taskkill -F -IM $CB_EXE >/dev/null 2>/dev/null || [ "$OSTYPE" = linux-gnu ] && killall ControllerBuddy 2>/dev/null
    then
        log 'Done!'
        sleep 2
        if [ "$UNINSTALL" != true ]
        then
            RESTART=true
        fi
    fi

    log 'Removing ControllerBuddy'
    find "$CB_DIR" -mindepth 1 -not -name "$SCRIPT_NAME" -not -path "$CB_BIN_DIR"  -delete
    check_retval 'Error: Failed to remove ControllerBuddy'
fi
}

function add_line_if_missing() {
if [ ! -f "$1" ] || ! grep -qxF "$2" "$1"
then
    echo "$2" | sudo tee -a "$1"
    check_retval "Error: Failed to write $1"
    REBOOT_REQUIRED=true
fi
}

function create_shortcut() {
if [ "$OSTYPE" = msys ]
then
    local SHORTCUT_PATH="$CB_SHORTCUTS_DIR\\$1.lnk"
else
    local SHORTCUT_PATH="$CB_SHORTCUTS_DIR/$1.desktop"
fi

if [ ! -f "$SHORTCUT_PATH" ]
then
    log "Creating '$1' shortcut..."
    if [ "$OSTYPE" = msys ]
    then
        mkdir -p "$CB_SHORTCUTS_DIR" && create-shortcut --arguments "$3" --work-dir "$4" "$2" "$SHORTCUT_PATH"
    else
        local EXEC_VALUE=$2
        if [ -n "$3" ]
        then
            EXEC_VALUE="$EXEC_VALUE $3"
        fi
        if [ "$1" = ControllerBuddy ]
        then
            local ICON_VALUE="$CB_LIB_DIR/ControllerBuddy.png"
            local TERMINAL_VALUE=false
        else
            local ICON_VALUE=''
            local TERMINAL_VALUE=true
        fi
        mkdir -p "$CB_SHORTCUTS_DIR" && echo -e "[Desktop Entry]\nType=Application\nName=$1\nIcon=$ICON_VALUE\nExec=$EXEC_VALUE\nPath=$4\nTerminal=$TERMINAL_VALUE\nCategories=Game" >> "$SHORTCUT_PATH"
    fi
    check_retval "Error: Failed to create '$1' shortcut"
fi
}

function install_dcs_integration() {
if [ -d "$1" ]
then
    log "Found DCS World user directory $1"
    local DCS_SCIRPTS_DIR="$1\\Scripts"

    local CB_DCS_INTEGRATION_DIR="$DCS_SCIRPTS_DIR\\ControllerBuddy-DCS-Integration"
    if [ -d "$CB_DCS_INTEGRATION_DIR" ]
    then
        if [ "$UNINSTALL" = true ]
        then
            rm -rf "$CB_DCS_INTEGRATION_DIR"
        else
            log 'Pulling ControllerBuddy-DCS-Integration repository...'
            git -C "$CB_DCS_INTEGRATION_DIR" pull origin master
            check_retval 'Error: Failed to pull ControllerBuddy-DCS-Integration repository'
        fi
    elif [ "$UNINSTALL" != true ]
    then
        log 'Cloning ControllerBuddy-DCS-Integration repository...'
        git clone https://github.com/bwRavencl/ControllerBuddy-DCS-Integration.git "$CB_DCS_INTEGRATION_DIR"
        check_retval 'Error: Failed to clone ControllerBuddy-DCS-Integration repository'
    fi

    local EXPORT_LUA_PATH="$DCS_SCIRPTS_DIR\\Export.lua"
    log "Updating $EXPORT_LUA_PATH for ControllerBuddy-DCS-Integration"
    if [ "$UNINSTALL" = true ]
    then
        sed -i "/\ControllerBuddy\b/d" "$EXPORT_LUA_PATH"
        check_retval "Error: Failed to remove ControllerBuddy-DCS-Integration from $EXPORT_LUA_PATH"
    else
        touch -a "$EXPORT_LUA_PATH"
        local EXPORT_LUA_LINE='dofile(lfs.writedir()..[[Scripts\ControllerBuddy-DCS-Integration\ControllerBuddy.lua]])'
        grep -qxF "$EXPORT_LUA_LINE" "$EXPORT_LUA_PATH" || { sed -i '$a\' "$EXPORT_LUA_PATH" && echo "$EXPORT_LUA_LINE" >> "$EXPORT_LUA_PATH" && unix2dos -q "$EXPORT_LUA_PATH" ; }
        check_retval "Error: Failed to add ControllerBuddy-DCS-Integration to $EXPORT_LUA_PATH"
    fi

    if REG QUERY 'HKCU\Environment' //V CONTROLLER_BUDDY_EXECUTABLE >/dev/null 2>/dev/null
    then
        if [ "$UNINSTALL" = true ]
        then
            log 'Removing CONTROLLER_BUDDY_EXECUTABLE environment variable...'
            REG delete 'HKCU\Environment' //F //V CONTROLLER_BUDDY_EXECUTABLE
            check_retval 'Error: Failed to remove CONTROLLER_BUDDY_EXECUTABLE environment variable'
        fi
    elif [ "$UNINSTALL" != true ]
    then
        log 'Adding CONTROLLER_BUDDY_EXECUTABLE environment variable...'
        setx CONTROLLER_BUDDY_EXECUTABLE "$CB_EXE_PATH"
        check_retval 'Error: Failed to add CONTROLLER_BUDDY_EXECUTABLE environment variable'
    fi

    if REG QUERY 'HKCU\Environment' //V CONTROLLER_BUDDY_PROFILES_DIR >/dev/null 2>/dev/null
    then
        if [ "$UNINSTALL" = true ]
        then
            log 'Removing CONTROLLER_BUDDY_PROFILES_DIR environment variable...'
            REG delete 'HKCU\Environment' //F //V CONTROLLER_BUDDY_PROFILES_DIR
            check_retval 'Error: Failed to remove CONTROLLER_BUDDY_PROFILES_DIR environment variable'
        fi
    elif [ "$UNINSTALL" != true ]
    then
        log 'Adding CONTROLLER_BUDDY_PROFILES_DIR environment variable...'
        setx CONTROLLER_BUDDY_PROFILES_DIR "$CB_PROFILES_DIR"
        check_retval 'Error: Failed to add CONTROLLER_BUDDY_PROFILES_DIR environment variable'
    fi
fi
}

if [ "$UNINSTALL" = true ]
then
    remove_controller_buddy

    if [ -d "$CB_SHORTCUTS_DIR" ]
    then
        log 'Removing ControllerBuddy shortcuts...'
        rm -rf "$CB_SHORTCUTS_DIR"
        check_retval 'Error: Failed to remove ControllerBuddy shortcuts'
    fi

    install_dcs_integration "$DCS_STABLE_USER_DIR" uninstall
    install_dcs_integration "$DCS_OPEN_BETA_USER_DIR" uninstall

    rm -rf "$CB_DIR" 2>/dev/null
else
    if [ "$OSTYPE" = msys ]
    then
        check_vjoy_installed
        if [ "$VJOY_INSTALLED" != true ]
        then
            log "No valid vJoy $VJOY_DESIRED_VERSION installation was found - downloading installer..."
            VJOY_SETUP_EXE_PATH="$TMP\\vJoySetup.exe"
            if curl -o "$VJOY_SETUP_EXE_PATH" -L https://github.com/jshafer817/vJoy/releases/download/v2.1.9.1/vJoySetup.exe
            then
                log "Installing vJoy $VJOY_DESIRED_VERSION..."
                "$VJOY_SETUP_EXE_PATH" //VERYSILENT
                rm -rf "$VJOY_SETUP_EXE_PATH"
                check_vjoy_installed
            else
                log 'Error: Failed to obtain vJoy from GitHub'
                confirm_exit
            fi
        fi

        if [ "$VJOY_INSTALLED" = true ]
        then
            log "Found vJoy $VJOY_CURRENT_VERSION in $VJOY_DIR"
            check_vjoy_configured
            if [ "$VJOY_CONFIGURED" = true ]
            then
                log 'Yes'
            else
                log 'No - starting elevated vJoyConfig process...'
                powershell -Command "Start-Process '$VJOY_CONFIG_EXE_PATH' '1 -f -b 128' -Verb Runas -Wait"
                check_retval 'Error: Failed to start elevated vJoyConfig process'
                check_vjoy_configured
                if [ "$VJOY_CONFIGURED" != true ]
                then
                    log 'Error: Failed to configure vJoy device'
                    confirm_exit
                fi
            fi
        else
            log "Error: Still failed to find vJoy $VJOY_DESIRED_VERSION, please restart this script after downloading and installing vJoy $VJOY_DESIRED_VERSION manually"
            confirm_exit
        fi
    else
        if ! ldconfig -p | grep -q libSDL2
        then
            log 'Installing libSDL2...'
            if which apt-get >/dev/null
            then
                sudo -- sh -c 'apt-get update && apt-get install -y libsdl2-2.0-0'
            elif which yum >/dev/null
            then
                sudo yum install SDL2
            elif which pacman >/dev/null
            then
                sudo pacman -S --noconfirm sdl2
            else
                false
            fi
            check_retval 'Error: Failed to install libSDL2, please restart this script after installing libSDL2 manually'
        fi

        if ! getent group uinput >/dev/null
        then
            log "Creating a 'uinput' group"
            sudo groupadd -f uinput
            check_retval "Error: Failed to create a 'uinput' group"
            REBOOT_REQUIRED=true
        fi

        if ! id -nGz "$USER" | grep -qzxF uinput
        then
            log "Adding user $USER to the 'uinput' group"
            sudo gpasswd -a "$USER" uinput
            check_retval "Error: Failed to add user $USER to the 'uinput' group"
            REBOOT_REQUIRED=true
        fi

        add_line_if_missing '/etc/udev/rules.d/99-input.rules' 'SUBSYSTEM=="misc", KERNEL=="uinput", MODE="0660", GROUP="uinput"'
        add_line_if_missing '/etc/modules-load.d/uinput.conf' 'uinput'
    fi

    if [ -d "$CB_DIR" ]
    then
        CB_CURRENT_VERSION=$(find "$CB_APP_DIR"/ControllerBuddy-*.jar -maxdepth 1 -print0 2>/dev/null | xargs -0 -I filename basename -s .jar filename | cut -d - -f 2,3)
        AUTO_EXIT=true
    fi

    log 'Checking for the latest ControllerBuddy release...'
    JSON=$(curl https://api.github.com/repos/bwRavencl/ControllerBuddy/releases/latest)
    check_retval 'Error: Failed to obtain ControllerBuddy release information from GitHub'

    CB_LATEST_VERSION=$(grep tag_name <<< "$JSON" | cut -d : -f 2 | cut -d - -f 2,3 | tr -d \",' ')
    if [ -z "$CB_LATEST_VERSION" ]
    then
        log 'Error: Failed to determine latest ControllerBuddy version'
        confirm_exit
    fi

    if [ "$CB_CURRENT_VERSION" = "$CB_LATEST_VERSION" ]
    then
        log "ControllerBuddy $CB_CURRENT_VERSION is up-to-date!"
        echo
    else
        log "Downloading ControllerBuddy $CB_LATEST_VERSION..."
        if [ "$OSTYPE" = msys ]
        then
            GREP_STRING=windows-x86-64
            CB_ARCHIVE_FILE="$TMP\\ControllerBuddy.zip"
        else
            GREP_STRING=linux-x86-64
            CB_ARCHIVE_FILE="/tmp/ControllerBuddy.tgz"
        fi
        grep browser_download_url <<< "$JSON" | grep $GREP_STRING | cut -d : -f 2,3 | tr -d \",' ' | xargs -n 1 curl -o "$CB_ARCHIVE_FILE" -L
        check_retval "Error: Failed to obtain ControllerBuddy $CB_LATEST_VERSION from GitHub"

        if [ -d "$CB_DIR" ]
        then
            remove_controller_buddy
        fi

        log 'Decompressing archive...'
        if [ "$OSTYPE" = msys ]
        then
            mkdir -p "$CB_PARENT_DIR" && unzip -d "$CB_PARENT_DIR" "$CB_ARCHIVE_FILE"
        else
            mkdir -p "$CB_PARENT_DIR" && tar xzf "$CB_ARCHIVE_FILE" -C "$CB_PARENT_DIR"
        fi
        EXTRACTED="$?"
        rm -rf "$CB_ARCHIVE_FILE"
        if [ "$EXTRACTED" -eq 0 ]
        then
            log 'Done!'
            echo
        else
            log 'Error: Failed to decompress archive'
            confirm_exit
        fi
    fi

    create_shortcut ControllerBuddy "$CB_EXE_PATH" '-autostart local -tray' "$CB_DIR"

    if [ -d "$CB_PROFILES_DIR" ]
    then
        log 'Pulling ControllerBuddy-Profiles repository...'
        git -C "$CB_PROFILES_DIR" pull origin master
        check_retval 'Error: Failed to pull ControllerBuddy-Profiles repository'
    else
        log 'Cloning ControllerBuddy-Profiles repository...'
        git clone https://github.com/bwRavencl/ControllerBuddy-Profiles.git "$CB_PROFILES_DIR"
        check_retval 'Error: Failed to clone ControllerBuddy-Profiles repository'
    fi

    if [ "$OSTYPE" = msys ]
    then
        install_dcs_integration "$DCS_STABLE_USER_DIR"
        install_dcs_integration "$DCS_OPEN_BETA_USER_DIR"
    fi

    SCRIPT_PATH="$CB_BIN_DIR/$SCRIPT_NAME"

    if [ ! "$(dirname "$0")" -ef "$CB_BIN_DIR" ]
    then
        log "Updating local copy of $SCRIPT_NAME..."
        cp "$0" "$SCRIPT_PATH"
        check_retval "Error: Failed to copy $SCRIPT_NAME to $SCRIPT_PATH"
    fi

    if [ "$OSTYPE" = msys ]
    then
        SCRIPT_COMMAND="$SCRIPT_PATH"
        SCRIPT_WORK_DIR=%TMP%
    else
        SCRIPT_COMMAND="/bin/bash $SCRIPT_PATH"
        SCRIPT_WORK_DIR=/tmp
    fi
    create_shortcut 'Update ControllerBuddy' "$SCRIPT_COMMAND" '' "$SCRIPT_WORK_DIR"
    create_shortcut 'Uninstall ControllerBuddy' "$SCRIPT_COMMAND" uninstall "$SCRIPT_WORK_DIR"

    if [ "$RESTART" = true ]
    then
        log 'Launching ControllerBuddy...'
        if [ "$OSTYPE" = msys ]
        then
            start //B "" "$CB_EXE_PATH" '-autostart' 'local' '-tray' &
        else
            "$CB_EXE_PATH" -autostart local -tray &
        fi
    fi
fi

log 'All done! Have a nice day!'

if [ "$AUTO_EXIT" = true ] && [ "$REBOOT_REQUIRED" != true ]
then
    for i in $(seq 5 -1 1)
    do
        echo -ne "\rExiting in $i second(s)..."
        sleep 1
    done
    echo
else
    confirm_exit
fi
