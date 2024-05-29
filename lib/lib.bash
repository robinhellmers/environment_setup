#####################
### Guard library ###
#####################
guard_source_max_once() {
    local file_name="$(basename "${BASH_SOURCE[0]}")"
    local guard_var="guard_${file_name%.*}" # file_name wo file extension

    [[ "${!guard_var}" ]] && return 1
    [[ "$guard_var" =~ ^[_a-zA-Z][_a-zA-Z0-9]*$ ]] \
        || { echo "Invalid guard: '$guard_var'"; exit 1; }
    declare -gr "$guard_var=true"
}

guard_source_max_once || return 0

##############################
### Library initialization ###
##############################
init_lib()
{
    # Unset as only called once and most likely overwritten when sourcing libs
    unset -f init_lib

    if ! [[ -d "$LIB_PATH" ]]
    then
        echo "LIB_PATH is not defined to a directory for the sourced script."
        echo "LIB_PATH: '$LIB_PATH'"
        exit 1
    fi

    ### Source libraries ###
    #
    # Always start with 'lib_core.bash'
    source "$LIB_PATH/lib_core.bash" || exit 1
}

init_lib

#####################
### Library start ###
#####################

register_help_text 'func_lib' \
"Usage: func_lib <num>
    <num>: A number to output to stdout"

func_lib()
{
    local num=$1

    _validate_input_func_lib

    echo -e "\nFunction input number: $num"
}

_validate_input_func_lib()
{

    define function_usage <<'END_OF_FUNCTION_USAGE'
Usage: func_lib <num>
    <num>: A number to output to stdout
END_OF_FUNCTION_USAGE

    case $num in
        ''|*[!0-9]*)
define error_info <<END_OF_ERROR_INFO
Invalid input <num>, not a number: '$num'
END_OF_ERROR_INFO
            invalid_function_usage 2 'func_lib' "$error_info"
            exit 1
            ;;
        *)  ;;
    esac
}
