#!/bin/bash

: '
This script facilitates updating the GPG signature file.
It can either be run manually or as a Git pre-commit hook.

To set-up the Git hook run:
> ln sign.sh .git/hooks/pre-commit
'

set +o history

install_script_file=InstallControllerBuddy.sh
signature_file="$install_script_file.sig"

if [ "$(dirname "$0")" = .git/hooks ]
then
    if git diff --cached --quiet "$install_script_file"
    then
        exit 0
    fi

    if ! git diff --quiet "$install_script_file"
    then
        echo "Error: Cannot continue with partially staged changes for: $install_script_file"
        exit 1
    fi

    git_hook=true
fi

tmp_signature_file=$(mktemp) &&
sed 's/\r$//' "$install_script_file" | gpg --local-user 8590BB74C0F559F8AC911C1D8058553A1FD36B23 --detach-sig --output "$tmp_signature_file" --yes &&
mv "$tmp_signature_file" "$signature_file" &&
echo "Updated $signature_file" &&
[ "$git_hook" = true ] &&
git add "$signature_file"
