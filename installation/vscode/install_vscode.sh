#!/usr/bin/env bash

sourceable_script='false'

if [[ "$sourceable_script" != 'true' && ! "${BASH_SOURCE[0]}" -ef "$0" ]]
then
    echo "Do not source this script! Execute it with bash instead."
    return 1
fi
unset sourceable_script

########################
### Library sourcing ###
########################

library_sourcing()
{
    # Unset as only called once and most likely overwritten when sourcing libs
    unset -f library_sourcing

    local -r THIS_SCRIPT_PATH="$(tmp_find_script_path)"

    if [[ -z "$LIB_PATH" ]]
    then
        LIB_PATH="$(realpath "$THIS_SCRIPT_PATH/../../lib")"
        export LIB_PATH
    fi

    ### Source libraries ###
    source "$LIB_PATH/lib_core.bash" || exit 1
    source_lib "$LIB_PATH/lib_handle_input.bash"
}

# Minimal version of find_path(). Should only be used within this script to source library defining find_path().
tmp_find_script_path() {
    unset -f tmp_find_script_path; local s="${BASH_SOURCE[0]}"; local d
    while [[ -L "$s" ]]; do d=$(cd -P "$(dirname "$s")" &>/dev/null && pwd); s=$(readlink "$s"); [[ $s != /* ]] && s=$d/$s; done
    echo "$(cd -P "$(dirname "$s")" &>/dev/null && pwd)"
}

library_sourcing

##############################
### EXTRA GLOBAL VARIABLES ###
##############################

# Define the URL for the VSCode installer
readonly VSCODE_URL="https://update.code.visualstudio.com/latest/win32-x64-user/stable"

# Get the Windows TEMP directory path using wslvar
readonly TEMP_DIR="$(wslvar TEMP)"
# Convert Windows TEMP directory path to a Windows path
WIN_TEMP_DIR=$(wslpath -w "$TEMP_DIR")

# Define the installer path
installer_path="${TEMP_DIR}\\vscode_installer.exe"

############
### MAIN ###
############

register_help_text 'install_vscode.sh' \
"install_vscode.sh

<description>"

register_function_flags 'install_vscode.sh'

main()
{
    _handle_args 'install_vscode.sh' "$@"

    # Check if the installer file already exists and generate a unique name if necessary
    [[ -f "$(wslpath -u "$installer_path")" ]] &&
        installer_path="$(generate_unique_filename "${TEMP_DIR}\\vscode_installer")"
    
    # Download the installer
    download_installer "$installer_path"

    # Avoiding cmd error about UNC (WSL) cwd path not being supported
    pushd "$(wslpath "$TEMP_DIR")" >/dev/null
    echo_highlight "Start installing VSCode..."
    # Run the installer using cmd
    if cmd.exe /C "$installer_path /silent /mergetasks=!runcode" >/dev/null 2>&1
    then
        echo_success "Installed VSCode successfully"
    else
        echo_error "Failed with installing VSCode"
    fi
    popd >/dev/null

    # Clean up by removing the installer file
    rm "$(wslpath -u "$installer_path")"
}

###################
### END OF MAIN ###
###################

# Function to generate a unique filename
generate_unique_filename()
{
    local base_path="$1"

    local extension=".exe"
    local counter=1
    local new_path="${base_path}${extension}"

    while [[ -f "$(wslpath -u "$new_path")" ]] && (( counter < 100 ))
    do
        new_path="${base_path}_${counter}${extension}"
        ((counter++))
    done

    echo "$new_path"
}

# Function to download the VSCode installer
download_installer()
{
    local download_path="$(wslpath -u "$1")"

    echo "Start downloading the VSCode installer."
    if ! curl -# -Lo "$download_path" "$VSCODE_URL" 2>&1
    then
        echo "Could not download VSCode installer."
        exit 1
    fi
}

main_stderr_red()
{
    main "$@" 2> >(sed $'s|.*|\e[31m&\e[m|' >&2)
}

#################
### Call main ###
#################
main_stderr_red "$@"
#################
