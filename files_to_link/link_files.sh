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
    readonly REPO_FILESYSTEM_HIERARCHY="${THIS_SCRIPT_PATH}/filesystem_hierarchy"

    if [[ -z "$LIB_PATH" ]]
    then
        LIB_PATH="$(realpath "$THIS_SCRIPT_PATH/../lib")"
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

readonly WINDOWS_PATH_INDICATOR='[WIN]'

############
### MAIN ###
############

main()
{
    find_kernel
    find_os

    guard_os

    mappings=()
    add_filesystem_hierarchy_files_to_mappings_array

    find_vscode_settings_path

    echo "VSCODE_USER_SETTINGS_PATH:            '$VSCODE_USER_SETTINGS_PATH'"
    echo "VSCODE_USER_KEYBINDINGS_PATH:         '$VSCODE_USER_KEYBINDINGS_PATH'"
    echo "VSCODEINSIDERS_USER_SETTINGS_PATH:    '$VSCODEINSIDERS_USER_SETTINGS_PATH'"
    echo "VSCODEINSIDERS_USER_KEYBINDINGS_PATH: '$VSCODEINSIDERS_USER_KEYBINDINGS_PATH'"

    echo
    echo "mappings array entries:"
    for mapping in "${mappings[@]}"
    do
        echo "- '$mapping'"
    done
}

###################
### END OF MAIN ###
###################

register_help_text 'find_kernel' \
"find_kernel

Finds which kernel that is used. Native linux or
Windows Subsystem for Linux (WSL).

Output variables:
* found_kernel:
    - 'native' if native Linux
    - 'wsl' if Windows Subsystem for Linux (WSL)"

register_function_flags 'find_kernel'

find_kernel()
{
    _handle_args 'find_kernel' "$@"

    found_kernel='native'
    uname -r | grep -qEi "microsoft|wsl" && found_kernel='wsl'
}

register_help_text 'find_os' \
"find_os

Finds which operating system that is used.

Output variables:
* found_os:
    Example:
    - 'debian' if Debian
    - 'ubuntu' if Ubuntu"

register_function_flags 'find_os'

find_os()
{
    _handle_args 'find_os' "$@"

    if ! [[ -f /etc/os-release ]]
    then
        echo "Found no OS information."
        exit 1
    fi

    # $ID stores information e.g. ubuntu/debian/
    . /etc/os-release

    found_os="$ID"
}

register_help_text 'guard_os' \
"guard_os

Checks if OS is supported by the script. Exits if not.

Requires 'found_os' to be set using e.g. find_os()"

register_function_flags 'guard_os'

guard_os()
{
    _handle_args 'guard_os' "$@"

    case "$found_os" in
        'ubuntu') ;;
        'debian') ;;
        *)
            echo_error "The OS '$found_os' have not been specified as supported"
            exit 1
            ;;
    esac
}

register_help_text 'add_filesystem_hierarchy_files_to_mappings_array' \
"add_filesystem_hierarchy_files_to_mappings_array

Finds all files under the 'REPO_FILESYSTEM_HIERARCHY' path and adds entries for
each in the array 'mappings'.

Output array:
* mappings:
    Entry structure:
        '<repo file>:<new symlink file>'

        Where <new symlink file> is the name of the symlink file which will
        point to <repo file>. The <new symlink file> is created by replacing
        'REPO_FILESYSTEM_HIERARCHY' in <repo file> with 'HOME' as well as
        replacing filename prefix 'dot_' with and actual dot '.'."

register_function_flags 'add_filesystem_hierarchy_files_to_mappings_array'

add_filesystem_hierarchy_files_to_mappings_array()
{
    _handle_args 'add_filesystem_hierarchy_files_to_mappings_array' "$@"

    # Find files in 'filesystem_hierarchy/' and store in array 'repo_files'
    mapfile -t repo_files < <(find "${REPO_FILESYSTEM_HIERARCHY}" -type f)

    # Add 'repo_files' to array 'mappings' with '<repo_file>:<destination_symlink>'
    for repo_file in "${repo_files[@]}"
    do
        # Replace REPO_FILESYSTEM_HIERARCHY with HOME
        new_symlink="${repo_file/#${REPO_FILESYSTEM_HIERARCHY}/$HOME}"
        # Replace prefix 'dot_' with '.'
        new_symlink="${new_symlink//dot_/\.}"

        mappings+=("${repo_file}:${new_symlink}")
    done
}

register_help_text 'find_vscode_settings_path' \
"find_vscode_settings_path

Finds VSCode path for settings files. Uses 'found_kernel' to know if to look in
Windows when using WSL or in Linux if running native Linux.

Output variables:
* VSCODE_USER_SETTINGS_PATH:
    - User settings path for Default VSCode, not Insiders edition.
    - Does not include filename 'settings.json'
    - If a Windows path, with the form 'C:\\Users\\...', a prefix from the
      variable 'WINDOWS_PATH_INDICATOR' is added for easy identification.
        - Example: '[WIN]C:\\Users\\...'
    - If path is not found, the text 'UNKNOWN_WINDOWS_APPDATA_VSCODE' is stored.
* VSCODE_USER_KEYBINDINGS_PATH:
    - Same as VSCODE_USER_SETTINGS_PATH but for 'keybindings.json'.
* VSCODEINSIDERS_USER_SETTINGS_PATH:
    - Same as VSCODE_USER_SETTINGS_PATH but for VSCode Insiders edition.
    - If path is not found, the text 'UNKNOWN_WINDOWS_APPDATA_VSCODEINSIDERS'
      is stored.
* VSCODEINSIDERS_USER_KEYBINDINGS_PATH:
    - Same as VSCODEINSIDERS_USER_SETTINGS_PATH but for 'keybindings.json'."

register_function_flags 'find_vscode_settings_path'

find_vscode_settings_path()
{
    _handle_args 'find_vscode_settings_path' "$@"

    case "$found_kernel" in
        'wsl')
            if ! command -v wslvar 2>&1 >/dev/null
            then
                echo_error "To have access to 'wslvar' command, you need to install 'wslu'."
                echo_error "Install it with: 'sudo apt install wslu'"
                echo_error "Then re-run this script."
                exit 1
            fi

            readonly WINDOWS_APPDATA="$(wslvar APPDATA)"
            readonly WINDOWS_APPDATA_VSCODE="${WINDOWS_APPDATA}\\Code"
            readonly WINDOWS_APPDATA_VSCODEINSIDERS="${WINDOWS_APPDATA}\\Code - Insiders"
            ;;
        'native')
            echo_error "Native kernel while finding vscode settings path - TODO"
            exit 1
            ;;
        *)
            echo_error "Unknown kernel while finding vscode settings path"
            exit 1
            ;;
    esac

    if [[ -d "$(wslpath "$WINDOWS_APPDATA_VSCODE")" ]]
    then
        readonly VSCODE_USER_SETTINGS_PATH="${WINDOWS_PATH_INDICATOR}${WINDOWS_APPDATA_VSCODE}\\user"
        readonly VSCODE_USER_KEYBINDINGS_PATH="${WINDOWS_PATH_INDICATOR}${WINDOWS_APPDATA_VSCODE}\\user"
    else
        readonly VSCODE_USER_SETTINGS_PATH="UNKNOWN_WINDOWS_APPDATA_VSCODE"
        readonly VSCODE_USER_KEYBINDINGS_PATH="UNKNOWN_WINDOWS_APPDATA_VSCODE"
    fi

    if [[ -d "$(wslpath "$WINDOWS_APPDATA_VSCODEINSIDERS")" ]]
    then
        readonly VSCODEINSIDERS_USER_SETTINGS_PATH="${WINDOWS_PATH_INDICATOR}${WINDOWS_APPDATA_VSCODEINSIDERS}\\user"
        readonly VSCODEINSIDERS_USER_KEYBINDINGS_PATH="${WINDOWS_PATH_INDICATOR}${WINDOWS_APPDATA_VSCODEINSIDERS}\\user"
    else
        readonly VSCODEINSIDERS_USER_SETTINGS_PATH="UNKNOWN_WINDOWS_APPDATA_VSCODEINSIDERS"
        readonly VSCODEINSIDERS_USER_KEYBINDINGS_PATH="UNKNOWN_WINDOWS_APPDATA_VSCODEINSIDERS"
    fi

    # Check if any VSCode settings path found
    if ! [[ -d "$(wslpath "$WINDOWS_APPDATA_VSCODE")" ]] && ! [[ -d "$(wslpath "$WINDOWS_APPDATA_VSCODE")" ]]
    then
        echo_warning ">>> Did not find 'VSCode' or 'VSCode Insiders' settings location. <<<"
        return 1
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
