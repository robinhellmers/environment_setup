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

main_stderr_red()
{
    main "$@" 2> >(sed $'s|.*|\e[31m&\e[m|' >&2)
}

#################
### Call main ###
#################
main_stderr_red "$@"
#################
