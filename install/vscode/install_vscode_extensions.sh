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

############
### MAIN ###
############

main()
{
    local -r cmd="$1"

    local -r THIS_SCRIPT_PATH="$(find_path 'this' "${#BASH_SOURCE[@]}" "${BASH_SOURCE[@]}")"
    local -r EXTENSION_LIST_FILE="${THIS_SCRIPT_PATH}/extensions.list"

    filter_input "$cmd"

    if ! command_exists "$cmd"
    then
        echo_error "Command '$cmd' does not exist."
        exit 1
    fi

    find_vscode_server_path "$cmd"

    local -r INSTALLED_EXTENSIONS_FILE="$vscode_server_path/extensions/extensions.json"

    create_extensions_array "$EXTENSION_LIST_FILE"

    create_extensions_to_be_installed_array "${extensions_array[@]}"

    install_extensions "$cmd" "${extensions_to_be_installed_array[@]}"
}

###################
### END OF MAIN ###
###################

create_extensions_to_be_installed_array()
{
    local extensions_array=("$@")

    extensions_to_be_installed_array=()

    for extension in "${extensions_array[@]}"
    do
        if ! check_if_installed_extension "$extension" "$INSTALLED_EXTENSIONS_FILE"
        then
            extensions_to_be_installed_array+=("$extension")
        fi
    done
}

command_exists()
{
    local cmd="$1"

    # 'hash' ignores aliases
    hash "$1" >/dev/null 2>&1
}

filter_input()
{
    local cmd="$1"

    case "$cmd" in
        'code')
            echo_highlight "Installing extensions for VSCode using \
the list '$EXTENSION_LIST_FILE'."
            ;;
        'code-insiders')
            echo_highlight "Installing extensions for VSCode Insiders using \
the list '$EXTENSION_LIST_FILE'."
            ;;
        *)
            echo_error "Cannot install VSCode extensions for the \
command '$cmd', choose between 'code' and 'code-insiders'."
            exit 1
            ;;
    esac
}

find_vscode_server_path()
{
    local cmd="$1"

    local vscode_server_dir_name

    case "$cmd" in
        'code')
            vscode_server_dir_name=".vscode-server"
            ;;
        'code-insiders')
            vscode_server_dir_name=".vscode-server-insiders"
            ;;
        *)
            echo_error "Invalid input to find_vscode_server_path(): '$cmd'"
            exit 1
            ;;
    esac
    
    vscode_server_path="$HOME/$vscode_server_dir_name"
}

create_extensions_array()
{
    local -r extensions_list_file="$1"

    extensions_array=()

    if [[ ! "$extensions_list_file" ]]
    then
        echo_error "Extension list file does not exist: '$extensions_list_file'"
        exit 1
    fi
    
    # Read the file line by line
    while IFS= read -r extension
    do
        # Ignore empty lines and comments starting with #
        [[ -z "$extension" || "$extension" =~ ^# ]] && continue

        extensions_array+=("$extension")

    done < "$extensions_list_file"
}

check_if_installed_extension()
{
    local extension="$1"
    local installed_extensions_file="$2"

    if grep -q "\"id\":\"${extension}\"" "$installed_extensions_file"
    then
        echo -e "    ${COLOR_ORANGE}Already installed${COLOR_END} - ${extension##*.}"
        return 0
    else
        echo -e "    ${COLOR_ORANGE}To be installed${COLOR_END}  - ${extension##*.}"
        return 1
    fi

}

install_extensions()
{
    local -r vscode_command="$1"
    shift
    local -r extensions_array=("$@")

    if (( ${#extensions_array[@]} == 0 ))
    then
        echo_highlight "No extensions to install"
        return 0
    fi

    echo_highlight "Installing extensions."

    # Read the file line by line
    for extension in "${extensions_array[@]}"
    do
        # Ignore empty lines and comments starting with #
        [[ -z "$extension" || "$extension" =~ ^# ]] && continue
        
        local output
        output="$(command "$vscode_command" --install-extension "$extension")"
        exit_status=$?

        if (( exit_status == 0)) &&
           grep -q 'is already installed' <<< "$output"
        then
            echo -e "    ${COLOR_ORANGE}Already installed${COLOR_END} - ${extension##*.}"
            continue
        fi

        # Attempt to install the extension
        if (( exit_status == 0 ))
        then
            echo -e "    ${COLOR_GREEN}SUCCESS${COLOR_END} - ${extension##*.}"
        else
            echo -e "    ${COLOR_RED}FAILURE${COLOR_END} - ${extension##*.}"
        fi
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