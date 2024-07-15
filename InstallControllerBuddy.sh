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
╔═════════════════════════════════════════════════════════════╗
║ █▀▀ █▀█ █▀█ ▀█▀ █▀▄ █▀█ █   █   █▀▀ █▀▄ █▀▄ █ █ █▀▄ █▀▄ █ █ ║
║ █   █ █ █ █  █  █▀▄ █ █ █   █   █▀▀ █▀▄ █▀▄ █ █ █ █ █ █  █  ║
║ ▀▀▀ ▀▀▀ ▀ ▀  ▀  ▀ ▀ ▀▀▀ ▀▀▀ ▀▀▀ ▀▀▀ ▀ ▀ ▀▀  ▀▀▀ ▀▀  ▀▀   ▀  ║
║             ▀█▀ █▀█ █▀▀ ▀█▀ █▀█ █   █   █▀▀ █▀▄             ║
║              █  █ █ ▀▀█  █  █▀█ █   █   █▀▀ █▀▄             ║
║             ▀▀▀ ▀ ▀ ▀▀▀  ▀  ▀ ▀ ▀▀▀ ▀▀▀ ▀▀▀ ▀ ▀             ║
║                    © 2022 Matteo Hausner                    ║
╚═════════════════════════════════════════════════════════════╝

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
        # shellcheck disable=SC2154
        if [ "$container" = flatpak ]
        then
            cb_dir=/app
        else
            cb_dir="$cb_parent_dir/ControllerBuddy"
        fi
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

tmp_dir=$(mktemp -d -q)
trap 'rm -rf $tmp_dir' EXIT

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

function verify_signature() {
    if [ "$OSTYPE" != msys ]
    then
        log 'Checking if GnuPG is installed...'
        if which gpg >/dev/null 2>/dev/null
        then
            log 'Yes'
        else
            log 'No - installing GnuPG...'
            install_package 'gnupg' 'gnupg2' 'gnupg' 'gpg2'
            check_retval 'Error: Failed to install GnuPG. Please restart this script after manually installing GnuPG.'
        fi
        echo
    fi

    log 'Verifying signature...'
    local tmp_signature_file &&
    tmp_signature_file=$(mktemp -p "$tmp_dir" -q) &&
    curl -o "$tmp_signature_file" -L "$2" &&
    local keyring_asc_content &&
    keyring_asc_content=$(cat << 'EOF'
-----BEGIN PGP PUBLIC KEY BLOCK-----

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
v/g=
=GnJF
-----END PGP PUBLIC KEY BLOCK-----
EOF
    ) &&
    local tmp_keyring_file &&
    tmp_keyring_file=$(mktemp -p "$tmp_dir" -q) &&
    echo "$keyring_asc_content" | gpg --dearmor > "$tmp_keyring_file" 2>/dev/null &&
    gpgv --keyring "$tmp_keyring_file" "$tmp_signature_file" "$1" >/dev/null 2>/dev/null
    check_retval 'Error: Bad signature'
}

case "$1" in
    '')
        install=true
        prepare=true
        profiles=true
        ;;
    prepare)
        prepare=true
        ;;
    profiles)
        profiles=true
        ;;
    uninstall)
        uninstall=true
        ;;
     *)
        log "Error: Invalid command-line argument '$1'"
        exit 1
        ;;
esac

if [ "$install" = true ]
then
    if [ "$OSTYPE" != msys ]
    then
        log 'Checking if cURL is installed...'
        if which curl >/dev/null 2>/dev/null
        then
            log 'Yes'
        else
            log 'No - installing cURL...'
            install_package 'curl' 'curl' 'curl' 'curl'
            check_retval 'Error: Failed to install cURL. Please restart this script after manually installing cURL.'
        fi
        echo
    fi

    log 'Checking for the latest install script...'
    if install_script_json=$(curl https://api.github.com/repos/bwRavencl/ControllerBuddy-Install-Script/releases/latest) &&
        tag_name=$(grep tag_name <<< "$install_script_json" | cut -d : -f 2 | tr -d \",' ') &&
        install_script_url=https://github.com/bwRavencl/ControllerBuddy-Install-Script/releases/download/$tag_name/InstallControllerBuddy.sh &&
        tmp_install_script_file=$(mktemp -p "$tmp_dir" -q) &&
        curl -o "$tmp_install_script_file" -L "$install_script_url"
    then
        if cmp -s "${BASH_SOURCE[0]}" "$tmp_install_script_file"
        then
            log 'Install script is already up-to-date!'
            echo
        else
            log 'New install script available!'
            echo
            verify_signature "$tmp_install_script_file" "$install_script_url.sig"
            log 'Updating and restarting install script...'
            bash -c "mv '$tmp_install_script_file' '${BASH_SOURCE[0]}' && chmod +x '${BASH_SOURCE[0]}' && exec '${BASH_SOURCE[0]}' $1"
            check_retval 'Error: Failed to update and restart install script'
            exit 0
        fi
    else
        log 'Warning: Failed to obtain latest install script from GitHub'
    fi
fi

function check_vjoy_installed() {
    log "Checking if vJoy $vjoy_desired_version is installed..."
    local vjoy_uninstall_registry_key='HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{8E31F76F-74C3-47F1-9550-E041EEDC5FBB}_is1'
    vjoy_dir=$(REG QUERY "$vjoy_uninstall_registry_key" //V InstallLocation 2>/dev/null | grep InstallLocation | sed -n -e 's/^.*REG_SZ    //p' | sed 's/\\*$//')
    vjoy_config_exe_path="$vjoy_dir\\x64\\vJoyConfig.exe"
    vjoy_current_version=$(REG QUERY "$vjoy_uninstall_registry_key" //V DisplayVersion 2>/dev/null | grep DisplayVersion | sed -n -e 's/^.*REG_SZ    //p')
    if [ -n "$vjoy_dir" ] &&
        [ -d "$vjoy_dir" ] &&
        [ -f "$vjoy_config_exe_path" ] &&
        [ "$vjoy_current_version" = "$vjoy_desired_version" ]
    then
        vjoy_installed=true
    fi
}

function get_vjoy_config_value() {
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
    if [ "$vjoy_config_device" = 1 ] &&
        [ "$vjoy_config_buttons" = 128 ] &&
        [ "$vjoy_config_descrete_povs" = 0 ] &&
        [ "$vjoy_config_continuous_povs" = 0 ] &&
        [ "$vjoy_config_axes" = 'X Y Z Rx Ry Rz Sl0 Sl1' ] &&
        [ "$vjoy_config_ffb_effects" = 'None' ]
    then
        vjoy_configured=true
    fi
}

function check_cb_installed_version {
    if [ -d "$cb_dir" ]
    then
        cb_installed_version=$(find "$cb_app_dir" -iname 'controllerbuddy-*.jar' -maxdepth 2 -print0 2>/dev/null | xargs -0 -I filename basename -s .jar filename | cut -d - -f 2,3)
        auto_exit=true
    fi
}

function remove_controller_buddy() {
    if [ -d "$cb_dir" ]
    then
        log 'Stopping any old ControllerBuddy process...'
        if { [ "$OSTYPE" = msys ] && taskkill -F -IM $cb_exe >/dev/null 2>/dev/null ; } ||
            { [ "$OSTYPE" = linux-gnu ] && killall ControllerBuddy 2>/dev/null ; }
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
            mkdir -p "$cb_shortcuts_dir" && echo -e "[Desktop Entry]\nType=Application\nName=$1\nIcon=$icon_value\nExec=$exec_value\nPath=$4\nTerminal=$terminal_value\nCategories=Game" > "$shortcut_path"
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
    if [ "$prepare" = true ]
    then
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
                if tmp_vjoy_setup=$(mktemp -p "$tmp_dir" -q --suffix=.exe) &&
                    curl -o "$tmp_vjoy_setup" -L https://github.com/jshafer817/vJoy/releases/download/v2.1.9.1/vJoySetup.exe &&
                    echo "f103ced4e7ff7ccb49c8415a542c56768ed4da4fea252b8f4ffdac343074654a $tmp_vjoy_setup" | sha256sum --check --status
                then
                    log "Installing vJoy $vjoy_desired_version..."
                    "$tmp_vjoy_setup" //VERYSILENT
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
            if [ "$install" = true ]
            then
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

        if [ "$install" != true ] && [ "$reboot_required" != true ]
        then
            echo
            log 'All done!'
            exit 0
        fi
    fi

    if [ "$install" = true ]
    then
        echo
        log 'Checking for the latest ControllerBuddy release...'
        cb_json=$(curl https://api.github.com/repos/bwRavencl/ControllerBuddy/releases/latest)
        check_retval 'Error: Failed to obtain ControllerBuddy release information from GitHub'

        cb_latest_version=$(grep tag_name <<< "$cb_json" | cut -d : -f 2 | cut -d - -f 2,3 | tr -d \",' ')
        if [ -z "$cb_latest_version" ]
        then
            log 'Error: Failed to determine latest ControllerBuddy version'
            confirm_exit 1
        fi

        check_cb_installed_version

        if [ "$cb_installed_version" = "$cb_latest_version" ]
        then
            log "ControllerBuddy $cb_installed_version is up-to-date!"
            echo
        else
            log "Downloading ControllerBuddy $cb_latest_version..."
            if [ "$OSTYPE" = msys ]
            then
                grep_string=windows-x86-64
            else
                grep_string=linux-x86-64
            fi

            log "Determining download URL..."
            archive_url=$(grep browser_download_url <<< "$cb_json" | grep "$grep_string" | grep -v .sig | cut -d : -f 2,3 | tr -d \",' ')
            check_retval "Error: Failed to determine download URL for $cb_latest_version"

            log "Starting download..."
            tmp_archive_file=$(mktemp -p "$tmp_dir" -q) &&
            curl -o "$tmp_archive_file" -L "$archive_url"
            check_retval "Error: Failed to obtain ControllerBuddy $cb_latest_version from GitHub"

            verify_signature "$tmp_archive_file" "$archive_url.sig"

            if [ -d "$cb_dir" ]
            then
                remove_controller_buddy
            fi

            log 'Decompressing archive...'
            if [ "$OSTYPE" = msys ]
            then
                mkdir -p "$cb_parent_dir" && unzip -d "$cb_parent_dir" "$tmp_archive_file"
            else
                mkdir -p "$cb_parent_dir" && tar xzf "$tmp_archive_file" -C "$cb_parent_dir"
            fi
            # shellcheck disable=SC2181
            if [ "$?" -eq 0 ]
            then
                log 'Done!'
                echo
            else
                log 'Error: Failed to decompress archive'
                confirm_exit 1
            fi
        fi

        create_shortcut ControllerBuddy "$cb_exe_path" '-autostart local -tray' "$cb_dir"
    fi

    if [ "$profiles" = true ]
    then
        check_cb_installed_version
        if [ -z "$cb_installed_version" ]
        then
            log 'Error: Failed to determine installed ControllerBuddy version'
            confirm_exit 1
        fi

        cb_profiles_branch=$(cut -d '.' -f -2 <<< "$cb_installed_version")

        if [ -d "$cb_profiles_dir" ]
        then
            log 'Pulling ControllerBuddy-Profiles repository...'
            git -C "$cb_profiles_dir" fetch origin &&
            git -C "$cb_profiles_dir" checkout "$cb_profiles_branch" &&
            git -C "$cb_profiles_dir" pull origin "$cb_profiles_branch"
            check_retval 'Error: Failed to pull ControllerBuddy-Profiles repository'
        else
            log 'Cloning ControllerBuddy-Profiles repository...'
            git clone https://github.com/bwRavencl/ControllerBuddy-Profiles.git "$cb_profiles_dir" --branch "$cb_profiles_branch"
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
                echo If you plan to use the official profiles, it is recommended that you let the scripts make the necessary changes.
                echo 'Warning: You may want to backup your current input settings now, if you do not want to lose them.'
                echo Note: If you answer 'always', all scripts will be executed from now on whenever ControllerBuddy is updated, without individual prompts.
                echo

                while true;
                do
                    read -rp 'Would you like to run the ControllerBuddy-Profiles configuration scripts? [yes/no/always/never] ' response
                    case $response in
                        always)
                            add_environment_variable CONTROLLER_BUDDY_RUN_CONFIG_SCRIPTS true
                            export CONTROLLER_BUDDY_RUN_CONFIG_SCRIPTS=true
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
                find "$cb_profiles_dir/configs" -mindepth 2 -maxdepth 2 -name 'Configure.ps1' -exec sh -c "\
                if [ \"\$CONTROLLER_BUDDY_RUN_CONFIG_SCRIPTS\" != true ]
                then
                    echo
                    while true;
                    do
                        read -rp \"Would you like to run the configuration script for \$(echo \"\$1\" | cut -d / -f 3 | tr _ ' ')? [yes/no] \" response
                        case \$response in
                            [Yy]*)
                                break
                                ;;
                            [Nn]*)
                                exit
                                ;;
                            *)
                                echo \"Invalid input. Please answer with 'yes' or 'no'.\"
                                echo
                                ;;
                        esac
                    done
                fi
                echo
                powershell -ExecutionPolicy Bypass -File \"\$1\"\
                " shell {} \;

                log 'Done!'
                echo
            fi

            install_dcs_integration "$dcs_stable_user_dir"
            install_dcs_integration "$dcs_open_beta_user_dir"
        fi

        if [ "$install" != true ] && [ "$reboot_required" != true ]
        then
            log 'All done!'
            exit 0
        fi
    fi

    if [ "$install" = true ]
    then
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