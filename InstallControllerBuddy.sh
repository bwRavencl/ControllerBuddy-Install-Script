#!/bin/bash

if [ ! "$OSTYPE" = msys ]
then
    echo -e '\nError: This script can only be run in a MSYS/MinGW (Git Bash for Windows) environment.\n'
    exit 1
fi

TEMP_FILE="$TMP/ControllerBuddy.temp.zip"
DEST_DIR="$LOCALAPPDATA/Programs"
CB_DIR="$DEST_DIR/ControllerBuddy"
CB_EXE=ControllerBuddy.exe
CB_EXE_PATH="$CB_DIR/$CB_EXE"
CB_LNK_PATH="$APPDATA/Microsoft/Windows/Start Menu/Programs/ControllerBuddy.lnk"
CB_ARGUMENTS='-autostart local -tray'

echo -e '\nQuerying GitHub for the latest ControllerBuddy release:\n'

JSON=$(curl https://api.github.com/repos/bwRavencl/ControllerBuddy/releases/latest)
if [ "$?" -ne 0 ]
then
    echo -e '\nError: Could not obtain ControllerBuddy release information from GitHub\n'
    exit 1
fi

CB_VERSION=$(grep tag_name <<< "$JSON" | cut -d : -f 2 | tr -d \",' ')

echo -e "\nDownloading $CB_VERSION:\n"

grep browser_download_url <<< "$JSON" | grep windows | cut -d : -f 2,3 | tr -d \",' ' | xargs -n 1 curl -o $TEMP_FILE -L

if [ "$?" -ne 0 ]
then
    echo -e '\nError: Could not obtain ControllerBuddy from GitHub\n'
    exit 1
fi

if [ -d "$CB_DIR" ]
then
    echo -e '\nStopping any old ControllerBuddy process:\n'
    taskkill -F -IM $CB_EXE
    if [ "$?" -eq 0 ]
    then
        sleep 2
        RESTART=true
    fi
fi

echo -e '\nExtracting ZIP archive:\n'

rm -rf "$CB_DIR" && mkdir -p "$DEST_DIR" && unzip -d "$DEST_DIR" "$TEMP_FILE"
EXTRACTED="$?"

rm -rf $TEMP_FILE

if [ "$EXTRACTED" -ne 0 ]
then
    echo -e '\nError: Could not extract ZIP archive\n'
    exit 1
fi

if [ ! -f "$CB_LNK_PATH" ]
then
    echo -e '\nCreating Start menu shortcut...\n'
    create-shortcut --arguments "$CB_ARGUMENTS" --work-dir "$CB_DIR" "$CB_EXE_PATH" "$CB_LNK_PATH"
    if [ "$?" -ne 0 ]
    then
        echo -e '\nError: Could not create Start menu shortcut\n'
        exit 1
    fi
fi

if [ "$RESTART" = true ]
then
    echo -e '\nLaunching ControllerBuddy...\n'
    "$CB_EXE_PATH" $CB_ARGUMENTS &
fi
