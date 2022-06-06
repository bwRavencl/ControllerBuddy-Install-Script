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
  _____          __           ____        ___          __   __         ____         __       ____
 / ___/__  ___  / /________  / / /__ ____/ _ )__ _____/ /__/ /_ ______/  _/__  ___ / /____ _/ / /__ ____
/ /__/ _ \/ _ \/ __/ __/ _ \/ / / -_) __/ _  / // / _  / _  / // /___// // _ \(_-</ __/ _ `/ / / -_) __/
\___/\___/_//_/\__/_/  \___/_/_/\__/_/ /____/\_,_/\_,_/\_,_/\_, /   /___/_//_/___/\__/\_,_/_/_/\__/_/
                                                           /___/

                                        © 2022 Matteo Hausner

EOF

LOG_FILE="$TMP\\InstallControllerBuddy.log"
rm -rf "$LOG_FILE"

function log() {
    echo "$1"
    echo "$(date -R): $1" | grep . >> "$LOG_FILE"
}

function confirm_exit() {
    echo
    read -r -p 'Press enter to exit'
    exit 1
}

if [ "$OSTYPE" != msys ]
then
    log 'Error: This script must be run in a Git Bash for Windows environment'
    confirm_exit
fi

if [ "$(arch)" != x86_64 ]
then
    log 'Error: This script is intended to be run on x86_64 systems'
    confirm_exit
fi

if [ "$1" = uninstall ]
then
    UNINSTALL=true
fi

VJOY_UNINSTALL_REGISTRY_KEY='HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{8E31F76F-74C3-47F1-9550-E041EEDC5FBB}_is1'
VJOY_DESIRED_VERSION='2.1.9.1'
PROGRAMS_DIR="$LOCALAPPDATA\\Programs"
CB_DIR="$PROGRAMS_DIR\\ControllerBuddy"
CB_PROFILES_DIR="$USERPROFILE\\Documents\\ControllerBuddy-Profiles"
CB_EXE=ControllerBuddy.exe
CB_EXE_PATH="$CB_DIR\\$CB_EXE"
CB_LNK_DIR="$APPDATA\\Microsoft\\Windows\\Start Menu\\Programs\\ControllerBuddy"
CB_LNK_PATH="$CB_LNK_DIR\\ControllerBuddy.lnk"
SCRIPT_NAME=$(basename "$0")
UPDATE_LNK_PATH="$CB_LNK_DIR\\Update ControllerBuddy.lnk"
UNINSTALL_LNK_PATH="$CB_LNK_DIR\\Uninstall ControllerBuddy.lnk"
SCRIPT_PATH="$CB_DIR/$SCRIPT_NAME"
SAVED_GAMES_DIR="$USERPROFILE\\Saved Games"
DCS_STABLE_USER_DIR="$SAVED_GAMES_DIR\\DCS"
DCS_OPEN_BETA_USER_DIR="$SAVED_GAMES_DIR\\DCS.openbeta"

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
    if taskkill -F -IM $CB_EXE >/dev/null 2>/dev/null
    then
        log 'Done!'
        sleep 2
        if [ "$UNINSTALL" != true ]
        then
            RESTART=true
        fi
    fi

    log 'Removing ControllerBuddy'
    find "$CB_DIR" -mindepth 1 -not -name "$SCRIPT_NAME" -delete
    check_retval 'Error: Failed to remove ControllerBuddy'
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

    if [ -d "$CB_LNK_DIR" ]
    then
        log 'Removing ControllerBuddy Start menu shortcuts...'
        rm -rf "$CB_LNK_DIR"
        check_retval 'Error: Failed to remove ControllerBuddy Start menu shortcuts'
    fi

    install_dcs_integration "$DCS_STABLE_USER_DIR" uninstall
    install_dcs_integration "$DCS_OPEN_BETA_USER_DIR" uninstall

    rm -rf "$CB_DIR" 2>/dev/null
else
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

    if [ -d "$CB_DIR" ]
    then
        CB_CURRENT_VERSION=$(find "$CB_DIR"/app/ControllerBuddy-*.jar -maxdepth 1 -print0 2>/dev/null | xargs -0 -I filename basename -s .jar filename | cut -d - -f 2,3)
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
        CB_ZIP_FILE="$TMP\\ControllerBuddy.zip"
        grep browser_download_url <<< "$JSON" | grep windows-x86-64 | cut -d : -f 2,3 | tr -d \",' ' | xargs -n 1 curl -o "$CB_ZIP_FILE" -L
        check_retval "Error: Failed to obtain ControllerBuddy $CB_LATEST_VERSION from GitHub"

        if [ -d "$CB_DIR" ]
        then
            remove_controller_buddy
        fi

        log 'Decompressing archive...'
        mkdir -p "$PROGRAMS_DIR" && unzip -d "$PROGRAMS_DIR" "$CB_ZIP_FILE"
        EXTRACTED="$?"
        rm -rf "$CB_ZIP_FILE"
        if [ "$EXTRACTED" -eq 0 ]
        then
            log 'Done!'
            echo
        else
            log 'Error: Failed to decompress archive'
            confirm_exit
        fi
    fi

    if [ ! -f "$CB_LNK_PATH" ]
    then
        log 'Creating ControllerBuddy Start menu shortcut...'
        mkdir -p "$CB_LNK_DIR" && create-shortcut --arguments '-autostart local -tray' --work-dir "$CB_DIR" "$CB_EXE_PATH" "$CB_LNK_PATH"
        check_retval 'Error: Failed to create ControllerBuddy Start menu shortcut'
    fi

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

    install_dcs_integration "$DCS_STABLE_USER_DIR"
    install_dcs_integration "$DCS_OPEN_BETA_USER_DIR"

    if [ ! "$(dirname "$0")" -ef "$CB_DIR" ]
    then
        log "Updating local copy of $SCRIPT_NAME..."
        cp "$0" "$SCRIPT_PATH"
        check_retval "Error: Failed to copy $SCRIPT_NAME to $SCRIPT_PATH"
    fi

    if [ ! -f "$UPDATE_LNK_PATH" ]
    then
        log "Creating 'Update ControllerBuddy' Start menu shortcut..."
        mkdir -p "$CB_LNK_DIR" && create-shortcut --work-dir %TMP% "$SCRIPT_PATH" "$UPDATE_LNK_PATH"
        check_retval "Error: Failed to create 'Update ControllerBuddy' Start menu shortcut"
    fi

    if [ ! -f "$UNINSTALL_LNK_PATH" ]
    then
        log "Creating 'Uninstall ControllerBuddy' Start menu shortcut..."
        mkdir -p "$CB_LNK_DIR" && create-shortcut --arguments 'uninstall' --work-dir %TMP% "$SCRIPT_PATH" "$UNINSTALL_LNK_PATH"
        check_retval "Error: Failed to create 'Uninstall ControllerBuddy' Start menu shortcut"
    fi

    if [ "$RESTART" = true ]
    then
        log 'Launching ControllerBuddy...'
        start //B "" "$CB_EXE_PATH" '-autostart' 'local' '-tray' &
    fi
fi

log 'All done! Have a nice day!'

if [ "$AUTO_EXIT" = true ]
then
    for i in $(seq 5 -1 1)
    do
        echo -ne "\rExiting in $i second(s)..."
        sleep 1
    done
else
    confirm_exit
fi
