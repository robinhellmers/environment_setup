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
    readonly REPO_UNKNOWN_PATHS="${THIS_SCRIPT_PATH}/unknown_paths"

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

    mappings+=(
        "${REPO_UNKNOWN_PATHS}/vscode/user/settings.json:${VSCODE_USER_SETTINGS_PATH}/settings.json"
        "${REPO_UNKNOWN_PATHS}/vscode/user/keybindings.json:${VSCODE_USER_KEYBINDINGS_PATH}/keybindings.json"
        "${REPO_UNKNOWN_PATHS}/vscode_insiders/user/settings.json:${VSCODEINSIDERS_USER_SETTINGS_PATH}/settings.json"
        "${REPO_UNKNOWN_PATHS}/vscode_insiders/user/keybindings.json:${VSCODEINSIDERS_USER_KEYBINDINGS_PATH}/keybindings.json"
    )

    # Process mappings to create backups and symlinks
    for file_mapping in "${mappings[@]}"
    do
        # Split string into 2 parts using the : as separator
        IFS=':' read -r repo_file new_symlink <<< "$file_mapping"

        echo
        echo "Checking symlink for repository file '$(basename "$repo_file")'"

        # Check if Windows symlink
        [[ "$new_symlink" == "$WINDOWS_PATH_INDICATOR"* ]] &&
            is_windows_symlink='true' ||
            is_windows_symlink='false'

        if [[ "$is_windows_symlink" == 'true' ]]
        then
            handle_windows_symlink "$repo_file" "$new_symlink"
        else
            handle_linux_symlink "$repo_file" "$new_symlink"
        fi
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

register_help_text 'handle_windows_symlink' \
"handle_windows_symlink <repo_file> <new_symlink>

Handles everything related to check, backup and create a Windows symlink to a
Linux path.

Arguments:
<repo_file>:
    Path and filename of Linux file which symlink shall point to.
<new_symlink>:
    Path and filename of Windows symlink to create.

Exit code:
    0 - No special indication
"

register_function_flags 'handle_windows_symlink'

handle_windows_symlink()
{
    _handle_args 'handle_windows_symlink' "$@"

    local repo_file="${non_flagged_args[0]}"
    local new_symlink="${non_flagged_args[1]}"

    validate_linux_file "$repo_file"

    case "$return_code" in
        0)  ;;
        1)
            echo_warning "Skipped"
            return 0
            ;;
        *)
            unhandled_return_code
            return 0
            ;;
    esac

    validate_windows_file_path "$new_symlink" # Creates 'windows_file_repaired'
    new_symlink="$windows_file_repaired"

    case "$return_code" in
        0)  ;;
        1)
            echo_warning "Skipped"
            return 0
            ;;
        *)
            unhandled_return_code
            return 0
            ;;
    esac

    backup_and_create_windows_symlink "$repo_file" "$new_symlink"

    case "$return_code" in
        0)
            echo_success "Created symlink '$new_symlink' -> '$repo_file'"
            ;;
        1)
            echo_warning "Already done. No action taken."
            return 0
            ;;
        2)  ;;
        *)
            unhandled_return_code "$return_code"
            return 0
            ;;
    esac

    return 0
}

register_help_text 'handle_linux_symlink' \
"handle_linux_symlink <repo_file> <new_symlink>

Handles everything related to check and create a Linux symlink to a Linux path.

Arguments:
<repo_file>:
    Path and filename of Linux file which symlink shall point to.
<new_symlink>:
    Path and filename of Linux symlink to create.

Exit code:
    0 - No special indication
"

register_function_flags 'handle_linux_symlink'

handle_linux_symlink()
{
    _handle_args 'handle_linux_symlink' "$@"

    local repo_file="${non_flagged_args[0]}"
    local new_symlink="${non_flagged_args[1]}"

    validate_linux_file "$repo_file"

    case "$return_code" in
        0)  ;;
        1)
            echo_warning "Skipped"
            return 0
            ;;
        *)
            unhandled_return_code
            return 0
            ;;
    esac

    validate_linux_file_path "$new_symlink"

    case "$return_code" in
        0)  ;;
        1)
            echo_warning "Skipped"
            return 0
            ;;
        *)
            unhandled_return_code
            return 0
            ;;
    esac

    backup_and_create_linux_symlink "$repo_file" "$new_symlink"

    case "$return_code" in
        0)
            echo_success "Created symlink '$new_symlink' -> '$repo_file'"
            ;;
        1)
            echo_warning "Already done. No action taken."
            ;;
        2)  ;;
        *)
            unhandled_return_code "$return_code"
            ;;
    esac
}

register_help_text 'validate_linux_file' \
"validate_linux_file <linux_file>

Checks that given linux file exists. Prints error if not.

Arguments:
<linux_file>:
    Path and filename of linux file.

Output variables:
* return_code:
    0: File exists
    1: File does not exist

Exit code:
    0 - Always
"

register_function_flags 'validate_linux_file'

validate_linux_file()
{
    _handle_args 'validate_linux_file' "$@"
    local linux_file="${non_flagged_args[0]}"

    if [[ ! -e "$linux_file" ]]
    then
        echo_error "Error: File '$linux_file' does not exist."
        return_code=1
        return 0
    fi

    return_code=0
    return 0
}

register_help_text 'validate_windows_file_path' \
"validate_windows_file_path <windows_file>

Validates the Windows file path. Included check for previously unknown paths
marked in <windows_file>.

Arguments:
<windows_file>:
    Path and filename of Windows file. Can be prefixed with value of
    WINDOWS_PATH_INDICATOR.

Output variables:
* return_code:
    0: Path of file exists
    1: Path of file does not exist

Exit code:
    0 - Always
"

register_function_flags 'validate_windows_file_path'

validate_windows_file_path()
{
    _handle_args 'validate_windows_file_path' "$@"
    local windows_file="${non_flagged_args[0]}"

    return_code=255

    # Remove potential Windows path indicator prefix
    windows_file="${windows_file#"$WINDOWS_PATH_INDICATOR"}"

    # Check if path is empty indicating ':' might be missing or there's no target path
    if [[ -z "$windows_file" ]]
    then
        echo_error "Error: Invalid format of mapping, path empty. Check mapping array."
        return_code=1
        return 0
    fi

    # Convert potential / to \
    windows_file_repaired="${windows_file//\//\\}"
    windows_file="$windows_file_repaired"

    # Ensure the directory exists
    local windows_dir_linux_path
    windows_dir_linux_path=$(dirname "$(wslpath "$windows_file")")

    if ! [[ -d "$windows_dir_linux_path" ]]
    then
        case "$windows_dir_linux_path" in
            "UNKNOWN_WINDOWS_APPDATA_VSCODE"*)
                echo_highlight "VSCode target directory don't exist and thereby probably not VSCode itself."
                return_code=1
                return 0
                ;;
            "UNKNOWN_WINDOWS_APPDATA_VSCODEINSIDERS"*)
                echo_highlight "VSCode Insiders target directory don't exist and thereby probably not VSCode Insiders itself."
                return_code=1
                return 0
                ;;
            *)
                echo_error "Windows directory does not exist: $windows_dir_linux_path"
                return_code=1
                return 0
                ;;
        esac
    fi

    return_code=0
    return 0
}

register_help_text 'validate_linux_file_path' \
"validate_linux_file_path <linux_file>

Validates the Linux file path. Tries to create directory if within \$HOME.

Arguments:
<linux_file>:
    Path and filename of Linux file.

Output variables:
* return_code:
    0: Path of file exists
    1: Path of file does not exist

Exit code:
    0 - Always
"

register_function_flags 'validate_linux_file_path'

validate_linux_file_path()
{
    _handle_args 'validate_linux_file_path' "$@"
    local linux_file="${non_flagged_args[0]}"

    return_code=255

    # Check if symlink is empty indicating ':' might be missing or there's no target path
    if [[ -z "$linux_file" ]]
    then
        echo_error "Error: Invalid format or missing target path for mapping."
        return_code=1
        return 0
    fi

    # Ensure the target directory exists
    local linux_dir_path
    linux_dir_path=$(dirname "$linux_file")

    if ! [[ -d "$linux_dir_path" ]]
    then
        local tried_creating_dir='false'
        # If path follows given specification, try to create it
        case "$linux_dir_path" in
            "$HOME"*)
                mkdir -p "$linux_dir_path"
                tried_creating_dir='true'
                ;;
            *)  ;;
        esac

        if ! [[ -d "$linux_dir_path" ]]
        then
            if [[ "$tried_creating_dir" == 'true' ]]
            then
                echo_error "Error: The directory for '$new_symlink' does not exist and could not be created."
            else
                echo_error "Error: The directory for '$new_symlink' does not exist but did not try to create it."
            fi

            return_code=1
            return 0
        fi
    fi

    # Check if the source file exists
    if [[ ! -e "$repo_file" ]]
    then
        echo_error "Error: Source file '$repo_file' does not exist."
        return_code=1
        return 0
    fi

    return_code=0
    return 0
}

register_help_text 'backup_file' \
"backup_file <file>

Ensures that file is backed up at the same location of <file> but with a suffix
including a number. This is done without overwriting any existing backup.

Arguments:
<file>:
    Path and filename of Linux file which symlink shall point to.

Exit code:
    0: Successful backup
    1: Failed with backup
"

register_function_flags 'backup_file'

backup_file()
{
    _handle_args 'backup_file' "$@"
    local file="${non_flagged_args[0]}"

    local backup_base="${file}.backup"
    local backup_file=""
    for (( i=1; i <= 100; i++ ))
    do
        backup_file="${backup_base}-${i}"
        if [[ ! -e "$backup_file" ]]; then
            mv "$file" "$backup_file"
            echo_highlight "Backed up '$file' to '$backup_file'"
            return 0  # Successful backup
        fi
    done
    echo_error "Error: Could not create backup for '$file', more than 100 backups exist."
    return 1  # Failed to create backup
}

register_help_text 'backup_and_create_windows_symlink' \
"backup_and_create_windows_symlink <repo_file> <windows_symlink>

Backup existing file at <windows_symlink> and creates a Windows symlink pointing
to the repository file.

Arguments:
<repo_file>:
    Path and filename of Linux file which symlink shall point to.
<windows_symlink>:
    Path and filename of Windows symlink to create.

Output variables:
* return_code:
    0: Successfully created symlink & potential backup
    1: Already existing symlink
    2: Error

Exit code:
    0 - Always
"

register_function_flags 'backup_and_create_windows_symlink'

backup_and_create_windows_symlink()
{
    _handle_args 'backup_and_create_windows_symlink' "$@"
    local repo_file="${non_flagged_args[0]}"
    local windows_symlink="${non_flagged_args[1]}"

    return_code=255

    # Remove potential Windows path indicator prefix
    windows_file="${windows_file#"$WINDOWS_PATH_INDICATOR"}"
    # Convert to Windows path
    repo_file_windows_path="$(wslpath -w "$repo_file")"

    # Windows symlink verification. Create expected output
    match_repo_file="$(realpath "$repo_file")" # Target file might be a symlink
    match_repo_file="${match_repo_file:1}" # Remove initial / and
    match_repo_file="${match_repo_file//\//\\}" # Convert rest of / to \ with windows path
    match_repo_file="\\${WSL_DISTRO_NAME}\\${match_repo_file}]"

    # Avoiding cmd error about UNC (WSL) cwd path not being supported
    pushd "$(dirname "$(wslpath "$windows_symlink")")" >/dev/null
    # Get info about potential already existing symlink
    symlink_info="$(cmd.exe /c dir /a:l "${windows_symlink}" 2>&1 | grep '<SYMLINK>')"
    popd >/dev/null

    # Check if symlink already exists and if pointing to correct location
    # -F to not evaluate \ in string
    if grep -qF "$match_repo_file" <<< "$symlink_info"
    then
        echo_highlight "Windows symlink '$windows_symlink' already points to '$repo_file'"
        return_code=1
        return 0
    fi

    # Check if file/symlink exists
    if [[ -e "$(wslpath "$windows_symlink")" ]] || [[ -n "$symlink_info" ]]
    then
        # Attempt to create a backup and continue to next file if backup fails
        if ! backup_file "$(wslpath "$windows_symlink")"
        then
            return_code=2
            return 0
        fi
    fi

    local info
    # Avoiding cmd error about UNC (WSL) cwd path not being supported
    pushd "$(dirname "$(wslpath "$windows_symlink")")" >/dev/null
    # Attempt to create the symlink
    info="$(cmd.exe /c mklink "$windows_symlink" "$repo_file_windows_path" 2>&1)"; exit_code=$?
    popd >/dev/null

    if (( exit_code != 0 ))
    then
        echo_error "Error: Failed to create symlink '$windows_symlink' -> '$repo_file'."

        if grep -q 'You do not have sufficient privilege to perform this operation.' <<< "$info"
        then
            echo_error "       Not sufficient Windows Command Prompt (cmd) privilege. Run WSL Windows as Admin and re-run script."
        else
            printf "Info:"
            [[ -n "$info" ]] && printf "\n$info\n" || printf " No extra information available\n"
        fi

        return_code=2
        return 0
    fi

    return_code=0
    return 0
}

register_help_text 'backup_and_create_linux_symlink' \
"backup_and_create_linux_symlink <repo_file> <linux_symlink>

Backup existing file at <linux_symlink> and creates a Linux symlink pointing
to the repository file.

Arguments:
<repo_file>:
    Path and filename of Linux file which symlink shall point to.
<linux_symlink>:
    Path and filename of Linux symlink to create.

Output variables:
* return_code:
    0: Successfully created symlink & potential backup
    1: Already existing symlink
    2: Error

Exit code:
    0 - Always
"

register_function_flags 'backup_and_create_linux_symlink'

backup_and_create_linux_symlink()
{
    _handle_args 'backup_and_create_linux_symlink' "$@"
    local repo_file="${non_flagged_args[0]}"
    local linux_symlink="${non_flagged_args[1]}"

    return_code=255

    repo_file="$(realpath "$repo_file")"

    # Check if symlink already exists
    if [[ -L "$new_symlink" ]]
    then
        local actual_target
        actual_target=$(readlink "$new_symlink")

        # Check if the symlink points to the correct path
        if [[ "$actual_target" == "$repo_file" ]]
        then
            echo_highlight "Symlink '$new_symlink' already points to '$repo_file'"
            return_code=1
            return 0
        fi
    fi

    # Check if file, directory or symlink
    if [[ -e "$new_symlink" ]]
    then
        # Attempt to create a backup and continue to next file if backup fails
        if ! backup_file "$new_symlink"
        then
            return_code=2
            return 0
        fi
    fi

    # Attempt to create the symlink and check if it succeeds
    if ! ln -sf "$repo_file" "$new_symlink"
    then
        echo_error "Error: Failed to create symlink '$new_symlink' -> '$repo_file'."
        return_code=2
        return 0
    fi

    return_code=0
    return 0
}

unhandled_return_code()
{
    echo_error "Unhandled return code. Check return code: '$return_code'"
    return 0
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
