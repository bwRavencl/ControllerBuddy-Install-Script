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

set +o history

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
    if [ -n "$log_file" ]
    then
        echo "$(date -R): $1" | grep . >> "$log_file"
    fi
}

function confirm_exit() {
    echo
    if [ "$reboot_required" = true ]
    then
        log 'IMPORTANT: System configuration has been modified. Please reboot your system!'
    fi
    read -rp 'Press enter to exit'
    exit "$1"
}

if [ -z "${BASH_SOURCE[0]}" ]
then
    log 'Error: Cannot determine script source'
    confirm_exit 1
fi

script_name=$(basename "${BASH_SOURCE[0]}")

case "$OSTYPE" in
    msys)
        log_file="$TMP\\InstallControllerBuddy.log"
        vjoy_desired_version='2.1.9.1'
        cb_parent_dir="$LOCALAPPDATA\\Programs"
        cb_dir="$cb_parent_dir\\ControllerBuddy"
        cb_bin_dir="$cb_dir"
        cb_exe=ControllerBuddy.exe
        cb_exe_path="$cb_bin_dir\\$cb_exe"
        cb_app_dir="$cb_dir\\app"
        cb_profiles_dir="$USERPROFILE\\Documents\\ControllerBuddy-Profiles"
        cb_shortcuts_dir="$APPDATA\\Microsoft\\Windows\\Start Menu\\Programs\\ControllerBuddy"
        saved_games_dir="$USERPROFILE\\Saved Games"
        dcs_stable_user_dir="$saved_games_dir\\DCS"
        dcs_open_beta_user_dir="$saved_games_dir\\DCS.openbeta"
        ;;
    linux*)
        log_file="/tmp/InstallControllerBuddy.log"
        cb_parent_dir="$HOME"
        cb_dir="$cb_parent_dir/ControllerBuddy"
        cb_bin_dir="$cb_dir/bin"
        cb_lib_dir="$cb_dir/lib"
        cb_app_dir="$cb_lib_dir/app"
        cb_exe=ControllerBuddy
        cb_exe_path="$cb_bin_dir/$cb_exe"
        if which xdg-user-dir >/dev/null 2>/dev/null
        then
            cb_profiles_dir="$(xdg-user-dir DOCUMENTS)/ControllerBuddy-Profiles"
        else
            cb_profiles_dir="$HOME/ControllerBuddy-Profiles"
        fi
        cb_shortcuts_dir="$HOME/.local/share/applications/ControllerBuddy"
        ;;
     *)
        log 'Error: This script must either be run in a Git Bash for Windows or a GNU/Linux Bash environment'
        confirm_exit 1
        ;;
esac

rm -rf "$log_file"

if [ "$(uname -m)" != x86_64 ]
then
    log 'Error: This script is intended to be run on x86_64 systems'
    confirm_exit 1
fi

function check_retval() {
    if [ "$?" -eq 0 ]
    then
        log 'Done!'
        echo
    else
        log "$1"
        confirm_exit 1
    fi
}

if [ "$1" = uninstall ]
then
    uninstall=true
else
    log 'Checking for the latest install script...'
    tmp_install_script_file=$(mktemp)
    if curl -o "$tmp_install_script_file" -L https://raw.githubusercontent.com/bwRavencl/ControllerBuddy-Install-Script/master/InstallControllerBuddy.sh
    then
        if cmp -s "${BASH_SOURCE[0]}" "$tmp_install_script_file"
        then
            log 'Install script is up-to-date!'
            rm -f "$tmp_install_script_file"
        else
            log 'Updating and restarting install script...'
            bash -c "mv '$tmp_install_script_file' '${BASH_SOURCE[0]}' && chmod +x '${BASH_SOURCE[0]}' && exec '${BASH_SOURCE[0]}' $1"
            check_retval 'Error: Failed to update and restart install script'
            rm -f "$tmp_install_script_file"
            exit 0
        fi
    else
        log 'Warning: Failed to obtain latest install script from GitHub'
    fi
    echo
fi

function check_vjoy_installed() {
    log "Checking if vJoy $vjoy_desired_version is installed..."
    local vjoy_uninstall_registry_key='HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{8E31F76F-74C3-47F1-9550-E041EEDC5FBB}_is1'
    vjoy_dir=$(REG QUERY "$vjoy_uninstall_registry_key" //V InstallLocation 2>/dev/null | grep InstallLocation | sed -n -e 's/^.*REG_SZ    //p' | sed 's/\\*$//')
    vjoy_config_exe_path="$vjoy_dir\\x64\\vJoyConfig.exe"
    vjoy_current_version=$(REG QUERY "$vjoy_uninstall_registry_key" //V DisplayVersion 2>/dev/null | grep DisplayVersion | sed -n -e 's/^.*REG_SZ    //p')
    if [ -n "$vjoy_dir" ] && [ -d "$vjoy_dir" ] && [ -f "$vjoy_config_exe_path" ] && [ "$vjoy_current_version" = "$vjoy_desired_version" ]
    then
        vjoy_installed=true
    fi
}

function  get_vjoy_config_value() {
    grep "$2" <<< "$1" | cut -d : -f 2 | sed 's/^[ \t]*//;s/[ \t]*$//' | xargs
}

function check_vjoy_configured() {
    log 'Checking if vJoy is configured correctly...'
    local vjoy_config
    vjoy_config=$("$vjoy_config_exe_path" -t 1)
    local vjoy_config_device
    vjoy_config_device=$(get_vjoy_config_value "$vjoy_config" Device)
    local vjoy_config_buttons
    vjoy_config_buttons=$(get_vjoy_config_value "$vjoy_config" Buttons)
    local vjoy_config_descrete_povs
    vjoy_config_descrete_povs=$(get_vjoy_config_value "$vjoy_config" 'Descrete POVs')
    local vjoy_config_continuous_povs
    vjoy_config_continuous_povs=$(get_vjoy_config_value "$vjoy_config" 'Continous POVs')
    local vjoy_config_axes
    vjoy_config_axes=$(get_vjoy_config_value "$vjoy_config" Axes)
    local vjoy_config_ffb_effects
    vjoy_config_ffb_effects=$(get_vjoy_config_value "$vjoy_config" 'FFB Effects')
    if [ "$vjoy_config_device" = 1 ] && [ "$vjoy_config_buttons" = 128 ] && [ "$vjoy_config_descrete_povs" = 0 ] && [ "$vjoy_config_continuous_povs" = 0 ] && [ "$vjoy_config_axes" = 'X Y Z Rx Ry Rz Sl0 Sl1' ] && [ "$vjoy_config_ffb_effects" = 'None' ]
    then
        vjoy_configured=true
    fi
}

function remove_controller_buddy() {
if [ -d "$cb_dir" ]
then
    log 'Stopping any old ControllerBuddy process...'
    if { [ "$OSTYPE" = msys ] && taskkill -F -IM $cb_exe >/dev/null 2>/dev/null ; } || { [ "$OSTYPE" = linux-gnu ] && killall ControllerBuddy 2>/dev/null ; }
    then
        log 'Done!'
        sleep 2
        if [ "$uninstall" != true ]
        then
            restart=true
        fi
    fi

    log 'Removing ControllerBuddy'
    find "$cb_dir" -mindepth 1 -not -name "$script_name" -not -path "$cb_bin_dir" -delete
    check_retval 'Error: Failed to remove ControllerBuddy'
fi
}

function check_sudo_privileges() {
if [ "$has_sudo_privileges" != true ]
then
    if ! which sudo >/dev/null 2>/dev/null
    then
        log 'Error: sudo is not installed. Please restart this script after manually installing sudo.'
        confirm_exit 1
    fi

    if sudo -v
    then
        has_sudo_privileges=true
    else
        log 'Error: User does not have sudo privileges. Please restart this script after manually adding the necessary permissions.'
        confirm_exit 1
    fi
fi
}

function install_package() {
if which apt-get >/dev/null 2>/dev/null
then
    check_sudo_privileges
    sudo -- sh -c "apt-get update && apt-get install -y $1"
elif which yum >/dev/null 2>/dev/null
then
    check_sudo_privileges
    sudo yum -y install "$2"
elif which pacman >/dev/null 2>/dev/null
then
    check_sudo_privileges
    sudo pacman -S --noconfirm "$3"
elif which zypper >/dev/null 2>/dev/null
then
    check_sudo_privileges
    sudo zypper --non-interactive install "$4"
else
    false
fi
}

function add_line_if_missing() {
if [ ! -f "$1" ] || ! grep -qxF "$2" "$1"
then
    log "Adding missing line '$2' to file '$1'..."
    check_sudo_privileges
    echo "$2" | sudo tee -a "$1" >/dev/null 2>/dev/null
    check_retval "Error: Failed to write $1"
    reboot_required=true
fi
}

function create_shortcut() {
if [ "$OSTYPE" = msys ]
then
    local shortcut_path="$cb_shortcuts_dir\\$1.lnk"
else
    local shortcut_path="$cb_shortcuts_dir/$1.desktop"
fi

if [ ! -f "$shortcut_path" ]
then
    log "Creating '$1' shortcut..."
    if [ "$OSTYPE" = msys ]
    then
        mkdir -p "$cb_shortcuts_dir" && create-shortcut --arguments "$3" --work-dir "$4" "$2" "$shortcut_path"
    else
        local exec_value=$2
        if [ -n "$3" ]
        then
            exec_value="$exec_value $3"
        fi
        if [ "$1" = ControllerBuddy ]
        then
            local icon_value="$cb_lib_dir/ControllerBuddy.png"
            local terminal_value=false
        else
            local icon_value='text-x-script'
            local terminal_value=true
        fi
        mkdir -p "$cb_shortcuts_dir" && echo -e "[Desktop Entry]\nType=Application\nName=$1\nIcon=$icon_value\nExec=$exec_value\nPath=$4\nTerminal=$terminal_value\nCategories=Game" >> "$shortcut_path"
    fi
    check_retval "Error: Failed to create '$1' shortcut"
fi
}

function add_environment_variable() {
    log "Adding $1 environment variable..."
    setx "$1" "$2"
    check_retval "Error: Failed to add $1 environment variable"
}

function install_dcs_integration() {
if [ -d "$1" ]
then
    log "Found DCS World user directory $1"
    local dcs_scirpts_dir="$1\\Scripts"

    local cb_dcs_integration_dir="$dcs_scirpts_dir\\ControllerBuddy-DCS-Integration"
    if [ -d "$cb_dcs_integration_dir" ]
    then
        if [ "$uninstall" = true ]
        then
            rm -rf "$cb_dcs_integration_dir"
        else
            log 'Pulling ControllerBuddy-DCS-Integration repository...'
            git -C "$cb_dcs_integration_dir" pull origin master
            check_retval 'Error: Failed to pull ControllerBuddy-DCS-Integration repository'
        fi
    elif [ "$uninstall" != true ]
    then
        log 'Cloning ControllerBuddy-DCS-Integration repository...'
        git clone https://github.com/bwRavencl/ControllerBuddy-DCS-Integration.git "$cb_dcs_integration_dir"
        check_retval 'Error: Failed to clone ControllerBuddy-DCS-Integration repository'
    fi

    local export_lua_path="$dcs_scirpts_dir\\Export.lua"
    log "Updating $export_lua_path for ControllerBuddy-DCS-Integration"
    if [ "$uninstall" = true ]
    then
        sed -i "/\ControllerBuddy\b/d" "$export_lua_path"
        check_retval "Error: Failed to remove ControllerBuddy-DCS-Integration from $export_lua_path"
    else
        touch -a "$export_lua_path"
        local export_lua_line='dofile(lfs.writedir()..[[Scripts\ControllerBuddy-DCS-Integration\ControllerBuddy.lua]])'
        # shellcheck disable=SC1003
        grep -qxF "$export_lua_line" "$export_lua_path" || { sed -i '$a\' "$export_lua_path" && echo "$export_lua_line" >> "$export_lua_path" && unix2dos -q "$export_lua_path" ; }
        check_retval "Error: Failed to add ControllerBuddy-DCS-Integration to $export_lua_path"
    fi

    if REG QUERY 'HKCU\Environment' //V CONTROLLER_BUDDY_EXECUTABLE >/dev/null 2>/dev/null
    then
        if [ "$uninstall" = true ]
        then
            log 'Removing CONTROLLER_BUDDY_EXECUTABLE environment variable...'
            REG DELETE 'HKCU\Environment' //F //V CONTROLLER_BUDDY_EXECUTABLE
            check_retval 'Error: Failed to remove CONTROLLER_BUDDY_EXECUTABLE environment variable'
        fi
    elif [ "$uninstall" != true ]
    then
        add_environment_variable CONTROLLER_BUDDY_EXECUTABLE "$cb_exe_path"
    fi

    if REG QUERY 'HKCU\Environment' //V CONTROLLER_BUDDY_PROFILES_DIR >/dev/null 2>/dev/null
    then
        if [ "$uninstall" = true ]
        then
            log 'Removing CONTROLLER_BUDDY_PROFILES_DIR environment variable...'
            REG DELETE 'HKCU\Environment' //F //V CONTROLLER_BUDDY_PROFILES_DIR
            check_retval 'Error: Failed to remove CONTROLLER_BUDDY_PROFILES_DIR environment variable'
        fi
    elif [ "$uninstall" != true ]
    then
        add_environment_variable CONTROLLER_BUDDY_PROFILES_DIR "$cb_profiles_dir"
    fi
fi
}

if [ "$uninstall" = true ]
then
    while true;
    do
        read -rp 'Are you sure you want to uninstall ControllerBuddy? [y/N] ' response
        case $response in
            [Yy]*)
                remove_controller_buddy

                if [ -d "$cb_shortcuts_dir" ]
                then
                    log 'Removing ControllerBuddy shortcuts...'
                    rm -rf "$cb_shortcuts_dir"
                    check_retval 'Error: Failed to remove ControllerBuddy shortcuts'
                fi

                if [ "$OSTYPE" = msys ]
                then
                    if REG QUERY 'HKCU\Environment' //V CONTROLLER_BUDDY_RUN_CONFIG_SCRIPTS >/dev/null 2>/dev/null
                    then
                        log 'Removing CONTROLLER_BUDDY_RUN_CONFIG_SCRIPTS environment variable...'
                        REG DELETE 'HKCU\Environment' //F //V CONTROLLER_BUDDY_RUN_CONFIG_SCRIPTS
                        check_retval 'Error: Failed to remove CONTROLLER_BUDDY_RUN_CONFIG_SCRIPTS environment variable'
                    fi

                    install_dcs_integration "$dcs_stable_user_dir" uninstall
                    install_dcs_integration "$dcs_open_beta_user_dir" uninstall
                fi

                rm -rf "$cb_dir" 2>/dev/null
                ;;
            [Nn]* | '')
                log 'Bye-bye!'
                exit 0
                ;;
            *)
                log "Invalid input. Please answer with 'yes' or 'no'."
                echo
                ;;
        esac
    done
else
    if [ "$OSTYPE" = msys ]
    then
        if REG QUERY 'HKLM\SYSTEM\CurrentControlSet\Services\steamxbox' >/dev/null 2>/dev/null
        then
            log "Error: Steam's 'Xbox Extended Feature Support Driver' is installed on your system. Please restart this script after uninstalling this driver via the 'Steam Settings' dialog and rebooting your system."
            confirm_exit 1
        fi

        check_vjoy_installed
        if [ "$vjoy_installed" != true ]
        then
            log "No valid vJoy $vjoy_desired_version installation was found - downloading installer..."
            vjoy_setup_exe_path="$TMP\\vJoySetup.exe"
            if curl -o "$vjoy_setup_exe_path" -L https://github.com/jshafer817/vJoy/releases/download/v2.1.9.1/vJoySetup.exe
            then
                log "Installing vJoy $vjoy_desired_version..."
                "$vjoy_setup_exe_path" //VERYSILENT
                rm -rf "$vjoy_setup_exe_path"
                check_vjoy_installed
            else
                log 'Error: Failed to obtain vJoy from GitHub'
                confirm_exit 1
            fi
        fi

        if [ "$vjoy_installed" = true ]
        then
            log "Found vJoy $vjoy_current_version in $vjoy_dir"
            check_vjoy_configured
            if [ "$vjoy_configured" = true ]
            then
                log 'Yes'
            else
                log 'No - starting elevated vJoyConfig process...'
                powershell -Command "Start-Process '$vjoy_config_exe_path' '1 -f -b 128' -Verb Runas -Wait"
                check_retval 'Error: Failed to start elevated vJoyConfig process'
                check_vjoy_configured
                if [ "$vjoy_configured" != true ]
                then
                    log 'Error: Failed to configure vJoy device'
                    confirm_exit 1
                fi
            fi
        else
            log "Error: Still failed to find vJoy $vjoy_desired_version. Please restart this script after downloading and installing vJoy $vjoy_desired_version manually."
            confirm_exit 1
        fi
    else
        log 'Checking if cURL is installed...'
        if which curl >/dev/null 2>/dev/null
        then
            log 'Yes'
        else
            log 'No - installing cURL...'
            install_package 'curl' 'curl' 'curl' 'curl'
            check_retval 'Error: Failed to install cURL. Please restart this script after manually installing cURL.'
        fi

        log 'Checking if libSDL2 is installed...'
        if which ldconfig >/dev/null 2>/dev/null
        then
            if ldconfig -p | grep -q libSDL2
            then
                libsdl2_found=true
            fi
        else
            check_sudo_privileges
            if sudo which ldconfig >/dev/null 2>/dev/null
            then
                if sudo ldconfig -p | grep -q libSDL2
                then
                    libsdl2_found=true
                fi
            else
                log "Error: Unable to run ldconfig."
                confirm_exit 1
            fi
        fi

        if [ "$libsdl2_found" = true ]
        then
            log 'Yes'
        else
            log 'No - installing libSDL2...'
            install_package 'libsdl2-2.0-0' 'SDL2' 'sdl2' 'SDL2'
            check_retval 'Error: Failed to install libSDL2. Please restart this script after manually installing libSDL2.'
        fi

        log 'Checking if Git is installed...'
        if which git >/dev/null 2>/dev/null
        then
            log 'Yes'
        else
            log 'No - installing Git...'
            install_package 'git' 'git' 'git' 'git'
            check_retval 'Error: Failed to install Git. Please restart this script after manually installing Git.'
        fi

        log "Checking for 'uinput' group..."
        if getent group uinput >/dev/null
        then
            log 'Yes'
        else
            log "No - creating a 'uinput' group"
            sudo groupadd -f uinput
            check_retval "Error: Failed to create a 'uinput' group"
            reboot_required=true
        fi

        log "Checking if user '$USER' is in 'uinput' group..."
        if id -nGz "$USER" | grep -qzxF uinput
        then
            log  'Yes'
        else
            log "No - adding user '$USER' to the 'uinput' group"
            sudo gpasswd -a "$USER" uinput
            check_retval "Error: Failed to add user '$USER' to the 'uinput' group"
            reboot_required=true
        fi

        add_line_if_missing '/etc/udev/rules.d/99-input.rules' 'KERNEL=="uinput", SUBSYSTEM=="misc", MODE="0660", GROUP="uinput"'

        add_line_if_missing '/etc/udev/rules.d/99-input.rules' 'KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="054c", ATTRS{idProduct}=="05c4", MODE="0666"'
        add_line_if_missing '/etc/udev/rules.d/99-input.rules' 'KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="054c", ATTRS{idProduct}=="09cc", MODE="0666"'
        add_line_if_missing '/etc/udev/rules.d/99-input.rules' 'KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="054c", ATTRS{idProduct}=="0ba0", MODE="0666"'
        add_line_if_missing '/etc/udev/rules.d/99-input.rules' 'KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="054c", ATTRS{idProduct}=="0ce6", MODE="0666"'

        add_line_if_missing '/etc/modules-load.d/uinput.conf' 'uinput'
    fi

    if [ -d "$cb_dir" ]
    then
        cb_current_version=$(find "$cb_app_dir" -iname 'controllerbuddy-*.jar' -maxdepth 2 -print0 2>/dev/null | xargs -0 -I filename basename -s .jar filename | cut -d - -f 2,3)
        auto_exit=true
    fi

    echo
    log 'Checking for the latest ControllerBuddy release...'
    json=$(curl https://api.github.com/repos/bwRavencl/ControllerBuddy/releases/latest)
    check_retval 'Error: Failed to obtain ControllerBuddy release information from GitHub'

    cb_latest_version=$(grep tag_name <<< "$json" | cut -d : -f 2 | cut -d - -f 2,3 | tr -d \",' ')
    if [ -z "$cb_latest_version" ]
    then
        log 'Error: Failed to determine latest ControllerBuddy version'
        confirm_exit 1
    fi

    if [ "$cb_current_version" = "$cb_latest_version" ]
    then
        log "ControllerBuddy $cb_current_version is up-to-date!"
        echo
    else
        log "Downloading ControllerBuddy $cb_latest_version..."
        if [ "$OSTYPE" = msys ]
        then
            grep_string=windows-x86-64
            cb_archive_file="$TMP\\ControllerBuddy.zip"
        else
            grep_string=linux-x86-64
            cb_archive_file="/tmp/ControllerBuddy.tgz"
        fi
        grep browser_download_url <<< "$json" | grep $grep_string | cut -d : -f 2,3 | tr -d \",' ' | xargs -n 1 curl -o "$cb_archive_file" -L
        check_retval "Error: Failed to obtain ControllerBuddy $cb_latest_version from GitHub"

        if [ -d "$cb_dir" ]
        then
            remove_controller_buddy
        fi

        log 'Decompressing archive...'
        if [ "$OSTYPE" = msys ]
        then
            mkdir -p "$cb_parent_dir" && unzip -d "$cb_parent_dir" "$cb_archive_file"
        else
            mkdir -p "$cb_parent_dir" && tar xzf "$cb_archive_file" -C "$cb_parent_dir"
        fi
        extracted="$?"
        rm -rf "$cb_archive_file"
        if [ "$extracted" -eq 0 ]
        then
            log 'Done!'
            echo
        else
            log 'Error: Failed to decompress archive'
            confirm_exit 1
        fi
    fi

    create_shortcut ControllerBuddy "$cb_exe_path" '-autostart local -tray' "$cb_dir"

    if [ -d "$cb_profiles_dir" ]
    then
        log 'Pulling ControllerBuddy-Profiles repository...'
        git -C "$cb_profiles_dir" pull origin master
        check_retval 'Error: Failed to pull ControllerBuddy-Profiles repository'
    else
        log 'Cloning ControllerBuddy-Profiles repository...'
        git clone https://github.com/bwRavencl/ControllerBuddy-Profiles.git "$cb_profiles_dir"
        check_retval 'Error: Failed to clone ControllerBuddy-Profiles repository'
    fi

    if [ "$OSTYPE" = msys ]
    then
        if reg_query_output=$(REG QUERY 'HKCU\Environment' //V CONTROLLER_BUDDY_RUN_CONFIG_SCRIPTS 2>/dev/null)
        then
            run_config_scripts=$(echo "$reg_query_output" | awk '{print tolower($3)}' | xargs)
        fi

        if [ "$run_config_scripts" != true ] && [ "$run_config_scripts" != false ]
        then
            echo The ControllerBuddy-Profiles configuration scripts can automatically configure the input settings of the following applications for usage with the official profiles:
            find "$cb_profiles_dir/configs" -mindepth 2 -maxdepth 2 -name 'Configure.ps1' | cut -d / -f 3 | tr _ ' ' | xargs -I name echo - name
            echo
            echo If you plan on using the official profiles, it is recommended to let the scripts make the necessary modifications.
            echo 'Warning: You may want to backup your current input settings now, if you do not want to lose them.'
            echo

            while true;
            do
                read -rp 'Would you like to run the ControllerBuddy-Profiles configuration scripts? [yes/no/always/never] ' response
                case $response in
                    always)
                        add_environment_variable CONTROLLER_BUDDY_RUN_CONFIG_SCRIPTS true
                        ;&
                    [Yy]*)
                        run_config_scripts=true
                        break
                        ;;
                    never)
                        add_environment_variable CONTROLLER_BUDDY_RUN_CONFIG_SCRIPTS false
                        ;&
                    [Nn]*)
                        run_config_scripts=false
                        break
                        ;;
                    *)
                        log "Invalid input. Please answer with 'yes', 'no', 'always' or 'never'."
                        echo
                        ;;
                esac
            done
        fi

        if [ "$run_config_scripts" = true ]
        then
            log 'Running ControllerBuddy-Profiles configuration scripts...'
            find "$cb_profiles_dir\\configs" -mindepth 2 -maxdepth 2 -name 'Configure.ps1' -exec sh -c 'echo ; powershell -ExecutionPolicy Bypass -File "$1"' shell {} \;
            log 'Done!'
            echo
        fi

        install_dcs_integration "$dcs_stable_user_dir"
        install_dcs_integration "$dcs_open_beta_user_dir"
    fi

    script_path="$cb_bin_dir/$script_name"

    if [ ! "$(dirname "${BASH_SOURCE[0]}")" -ef "$cb_bin_dir" ]
    then
        log "Updating local copy of $script_name..."
        cp "${BASH_SOURCE[0]}" "$script_path"
        check_retval "Error: Failed to copy $script_name to $script_path"
    fi

    if [ "$OSTYPE" = msys ]
    then
        script_command="$script_path"
        script_work_dir=%TMP%
    else
        script_command="/bin/bash $script_path"
        script_work_dir=/tmp
    fi
    create_shortcut 'Update ControllerBuddy' "$script_command" '' "$script_work_dir"
    create_shortcut 'Uninstall ControllerBuddy' "$script_command" uninstall "$script_work_dir"

    if [ "$restart" = true ]
    then
        log 'Launching ControllerBuddy...'
        if [ "$OSTYPE" = msys ]
        then
            start //B "" "$cb_exe_path" '-autostart' 'local' '-tray' &
        else
            nohup "$cb_exe_path" -autostart local -tray >/dev/null 2>/dev/null &
        fi
    fi
fi

log 'All done! Have a nice day!'

if [ "$auto_exit" = true ] && [ "$reboot_required" != true ]
then
    for i in $(seq 5 -1 1)
    do
        echo -ne "\rExiting in $i second(s)..."
        sleep 1
    done
    echo
else
    confirm_exit 0
fi
