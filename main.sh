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

    # Store $THIS_SCRIPT_PATH as unique or local variables
    # LIB_PATH is needed by sourced libraries as well
    readonly PROJECT_BASE_PATH="$THIS_SCRIPT_PATH"
    export PROJECT_BASE_PATH
    readonly LIB_PATH="$THIS_SCRIPT_PATH/lib"
    export LIB_PATH

    ### Source libraries ###
    source "$LIB_PATH/lib_core.bash" || exit 1
    source_lib "$LIB_PATH/lib_handle_input.bash"
    source_lib "$LIB_PATH/lib.bash"
}

# Minimal version of find_path(). Should only be used within this script to source library defining find_path().
tmp_find_script_path() {
    unset -f tmp_find_script_path; local s="${BASH_SOURCE[0]}"; local d
    while [[ -L "$s" ]]; do d=$(cd -P "$(dirname "$s")" &>/dev/null && pwd); s=$(readlink "$s"); [[ $s != /* ]] && s=$d/$s; done
    echo "$(cd -P "$(dirname "$s")" &>/dev/null && pwd)"
}

library_sourcing

########################
### GLOBAL CONSTANTS ###
########################

# readonly <var>

############
### MAIN ###
############

############
### MAIN ###
############

main()
{
    _handle_args_main "$@"

    local this_file="$(find_path 'this_file' "${#BASH_SOURCE[@]}" "${BASH_SOURCE[@]}")"

    [[ "$verbose" == 'true' ]] &&
        echo -e "\nthis_file: $this_file"

    func_lib 123
}

###################
### END OF MAIN ###
###################

register_help_text 'script name' \
'<script name> [arg1]

<description>

[arg1] (Optional): The content of arg1'

register_function_flags 'script name' \
                        '-v' '--verbose' 'false' \
                        'Verbose output.' \
                        '-e' '--echo' 'true' \
                        'Echo string given after flag.'

_handle_args_main()
{
    _handle_args 'script name' "$@"

    ###
    # Non-flagged arguments
    if (( ${#non_flagged_args[@]} != 0 ))
    then
        # Optional argument 1
        main_input_dir=${non_flagged_args[0]}
        if ! [[ -d "$main_input_dir" ]]
        then
            define error_info << END_OF_ERROR_INFO
Given [ DIR ] is not a directory: '$main_input_dir'
END_OF_ERROR_INFO
            invalid_function_usage 2 'script name' "$error_info"
            exit 1
        fi
    fi
    ###

    ###
    # -e, --echo
    if [[ "$echo_flag" == 'true' ]]
    then
        echo
        echo "$echo_flag_value"
    fi
    ###

    ###
    # -v --verbose
    if [[ "$verbose_flag" == 'true' ]]
    then
        verbose='true'
    fi
    ###

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
