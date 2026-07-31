#!/bin/bash

alias reboot='echo "Rethink what you are doing. If you want to reboot your host machine, use \\reboot" '

alias db=distrobox

DEFAULT_BOLD_COLOR='\033[1;39m'
DEFAULT_UNDERLINE_COLOR='\033[4;39m'
RED_COLOR='\033[0;31m'
GREEN_COLOR='\033[0;32m'
ORANGE_COLOR='\033[0;33m'
MAGENTA_COLOR='\033[0;35m'
END_COLOR='\033[0m'

debug_bash_enable()
{
    old_ps4="$PS4"

    local nesting_level='+ '
    local linenumber='${LINENO}'
    local fullfile='${BASH_SOURCE}'
    local filename='${BASH_SOURCE##*/}'

    # '${LINENO}:' always evaluates to '123:'
    #
    # If 'func' does NOT exist:
    #     '${func:- }' evaluates to ' '
    #     '${func:+(): }' evaluates to ''
    # Meaning
    #     linenumber_w_funcname='123: '
    #
    # If 'func' DOES exist, e.g. func='myfunc'
    #     '${func:- }' evaluates to 'myfunc'
    #     '${func:+(): }' evaluates to '(): '
    # Meaning
    #     * linenumber_w_funcname='123:myfunc(): '
    local linenumber_part="${linenumber}:"
    local filename_part="${filename:+${filename}:}"
    local fullfile_part="${fullfile:+${fullfile}:}"
    local funcname_part='${FUNCNAME[0]:- }${FUNCNAME[0]:+(): }'

    local ps4_construct_wo_file="${nesting_level}${linenumber_part}${funcname_part}"
    local ps4_construct_w_filename="${nesting_level}${linenumber_part}${filename_part}${funcname_part}"
    local ps4_construct_w_fullfile="${nesting_level}${linenumber_part}${fullfile_part}${funcname_part}"

    export PS4="$ps4_construct_w_filename"

    set -x
    export SHELLOPTS
}

debug_bash_disable()
{
    set +x
    export PS4="$old_ps4"
    export -n SHELLOPTS
}

copy_function()
{
    if ! [[ -n "$(declare -f "$1")" ]]
    then
        echo "ERROR copy_function(): Could not declare function name: '$1'" >&2
        return 1
    fi
    eval "${_/$1/$2}"
}

rename_function()
{
    copy_function "$@" || return
    unset -f "$1"
}

#####
# Have oe-initenv set a variable as well, without changing source code
# Backup function and execute that to not run in a loop
if [[ "$(type -t oe-initenv)" == 'function' ]]
then
    backup_function_name='oe-initenv-original'
    rename_function oe-initenv "$backup_function_name"

    oe-initenv() {
        local command="OE_INITENV_EXECUTED=true; $backup_function_name $@"

        [[ "$login_session" == 'true' ]] && bash_opts='-il' || bash_opts='-i'
        # Create another bash subshell, run the command and keep the shell alive
        bash $bash_opts  <<< "$command; echo -e \"\n\"; exec </dev/tty"
    }
fi
#####

if command -v trash &>/dev/null
then
    alias rt=trash
    alias rm="echo \"Don't use rm, use trash/rt (trash-cli package) instead.\"; false"
fi

#####
# Override 'exit' for tmux. If you run subshells in the tmux session by e.g.
# running 'bash', you can exit that subshell with 'exit'. But if in the top
# shell, that command will exit the tmux pane instead. Override to check the
# variable to identify this top shell. The variable is set in .bash_profile and
# is not exported to only keep it in this shell and not the subshells.
if (( SHLVL == TMUX_TOP_SHELL_LEVEL ))
then
    exit()
    {
        while true
        do
            read -n 1 -p "Do you really want to exit the tmux pane? [y/n]: " answer
            case "$answer" in
                [Yy])
                    command exit
                    ;;
                [Nn])
                    echo -e "\nNot exiting.";
                    break
                    ;;
                *)
                    echo -e "\nPlease answer y/n"
                    ;;
            esac
        done
    }
fi

alias wget='wget -q --show-progress --progress=bar:force:noscroll'

if hash code-insiders &>/dev/null &&
   ! hash code &>/dev/null
then
    alias code=code-insiders
fi

ssh-repeat()
{
    while ! ssh "$1" true >/dev/null 2>&1; do
        sleep 5
    done; echo "Host is back up at $(date)!"
}

symlink_ssh_repeat_completion()
{
    local ssh_repeat_symlink
    ssh_repeat_symlink='/usr/share/bash-completion/completions/ssh-repeat'

    if [[ -L "$ssh_repeat_symlink" ]] && \
       [[ -e "$ssh_repeat_symlink" ]]
    then # Symlink and not broken
        :
    elif [[ -f "$ssh_repeat_symlink" ]]
    then # Regular file
        :
    else
        # Connect ssh completion with ssh-repeat
        sudo ln -sf '/usr/share/bash-completion/completions/ssh' "$ssh_repeat_symlink"
    fi

    complete -p ssh-repeat >/dev/null 2>&1 || complete -F _ssh 'ssh-repeat'
}

#####
# Enable bash completion in interactive shells, for e.g. ssh
#
# Autocomplete as 'ssh'. '_ssh' is used as 'ssh' use that as seen
# with 'complete -p ssh'
# . /usr/share/bash-completion/bash_completion
#
if ! shopt -oq posix; then
    if [ -f /usr/share/bash-completion/bash_completion ]; then
        . /usr/share/bash-completion/bash_completion
        symlink_ssh_repeat_completion
    elif [ -f /etc/bash_completion ]; then
        . /etc/bash_completion
        symlink_ssh_repeat_completion
    fi
fi

unset -f symlink_ssh_repeat_completion
#####

evince()
{
    command evince "$1" &
    disown
}

eog()
{
    command eog "$1" &
    disown
}

rmws()
{
    sed -i 's/[[:space:]]\+$//' $1
}

rmwsdir()
{
    local thedepth=0

    local re='^[0-9]+$'

    if [[ -n "$1" ]]
    then
        if ! [[ "$1" =~ $re ]]
        then
            echo "Error: Input not a number" >&2
            return 1
        else
            thedepth="$1"
        fi
    fi

    echo "Removing trailing whitespace recursively $thedepth directories down."
    # The following part excludes hidden directories
    # -not -path '*/.*'
    # The following part excludes .md (markdown) files
    # -not -path '*.md'
    # The following part excludes binaries
    # -exec grep -Il '.' {} \;
    # The following part removes trailing whitespace
    # -exec sed -i 's/[[:space:]]\+$//' {} \+
    find . -maxdepth "$((thedepth + 1))" \
           -type f \
           -not -path '*/.*' \
           -not -path '*.md' \
           -exec grep -qIl '.' {} \; \
           -exec sed -i 's/[[:space:]]\+$//' {} \+
}

# Highlight code
if command -v highlight &>/dev/null
then
    # Highlight 'less'
    # Line numbers; add the flags --line-numbers --line-numer-length=3
    export LESSOPEN="| $(which highlight) %s --out-format xterm256 --force -s candy --no-trailing-nl"
    export LESS=" -R"

    # Highlight 'cat'
    alias cat="highlight --out-format xterm256 --line-numbers --line-number-length=3 --force -s zenburn --no-trailing-nl"
fi

# List all recipes when run from the top directory of a build tree
alias ls-recipes="ls meta*/recipes*/*/*.bb"


export BOARD='board_nucleo_g4'
export B="$BOARD"

cubemx() {
    # config
    local config_dir="$HOME/.config/cubemx"
    local config_file="$config_dir/default_version"

    # load saved default or fallback
    if [[ -f "$config_file" ]]; then
        version="$(<"$config_file")"
    else
        version="6.15.0"
    fi

    local ioc_file=""
    local list_only=false
    local set_default=false
    local version_set=false

    # Reset getopts
    OPTIND=1

    # parse flags: -l (list), -v <version>, -d (set default)
    while getopts ":lv:d" opt; do
        case "$opt" in
            l) list_only=true ;; 
            v) version="$OPTARG"; version_set=true ;; 
            d) set_default=true ;; 
            :)  # missing option argument
                if [[ "$OPTARG" == "v" ]]; then
                    echo "Error: -v requires a version argument." >&2
                else
                    echo "Usage: cubemx [-l] [-v version] [-d] [ioc-file]" >&2
                fi
                return 1
                ;;
            \?)
                echo "Usage: cubemx [-l] [-v version] [-d] [ioc-file]" >&2
                return 1
                ;;
        esac
    done
    shift $((OPTIND -1))

    # If requesting to set default without specifying a version
    if [[ "$set_default" = true && "$version_set" = false ]]; then
        echo "Error: must specify -v <version> to set a new default." >&2
        return 1
    fi

    # list versions
    if [[ "$list_only" = true ]]; then
        echo "Available STM32CubeMX versions under /opt/st/:"
        for dir in /opt/st/stm32cubemx_*; do
            [[ -d "$dir" ]] || continue
            echo "  ${dir##*/stm32cubemx_}"
        done
        return
    fi

    # verify install dir for the chosen version
    local install_dir="/opt/st/stm32cubemx_${version}"
    if [[ ! -d "$install_dir" ]]; then
        # error for both run and default-setting modes
        if [[ "$set_default" = true ]]; then
            echo "Error: cannot set default; version '$version' not found under /opt/st." >&2
        else
            echo "Error: CubeMX version directory not found: $install_dir" >&2
        fi
        return 1
    fi

    # set default and exit
    if [[ "$set_default" = true ]]; then
        mkdir -p "$config_dir"
        echo "$version" > "$config_file"
        echo "Default CubeMX version set to $version"
        return
    fi

    # optional .ioc file
    if [[ -n "$1" ]]; then
        if [[ ! -f "$1" ]]; then
            echo "Given argument is not a file: $1" >&2
            return 1
        fi
        ioc_file="$(realpath "$1")"
    fi

    # launch CubeMX
    local logfile="$HOME/.local/log/STM32CubeMX/output.log"
    pushd "$install_dir" >/dev/null || return

    if [[ -n "$ioc_file" ]]; then
        nohup ./STM32CubeMX "$ioc_file" >> "$logfile" 2>&1 &
    else
        nohup ./STM32CubeMX >> "$logfile" 2>&1 &
    fi

    popd >/dev/null
}

cubemxx() {
    local logfile="$HOME/.local/log/STM32CubeMX/output.log"
    nohup bash -lc "
        # 1) switch into the CubeMX directory
        cd /opt/st/stm32cubemx_6.14.0 || exit 1

        # 2) run CubeMX (foreground)—output to your log
        ./STM32CubeMX >> \"$logfile\" 2>&1
        status=\$?

        # 3) now that it’s done, run whatever follow-up you need:
        echo \"[ \$(date '+%Y-%m-%d %H:%M:%S') ] HELLMERS CubeMX exited with status \$status\" >> \"$logfile\"
        # ← replace the line above with your “after exit” command(s), e.g.:
        # notify-send \"CubeMX has finished (status \$status)\"
        # ~/scripts/post_cube_task.sh \$status

    " >> "$logfile" 2>&1 &

    # disown so your shell never tracks it
    disown
}

cubemxxx() {
    # 1) Use setsid to start a new session (so bash never registers it as a job)
    # 2) Wrap everything in one bash -c, redirecting stdin from /dev/null
    setsid nohup bash -c '
        local logfile="$HOME/.local/log/STM32CubeMX/output.log"
        cd /opt/st/stm32cubemx_6.14.0 || exit 1
        ./STM32CubeMX >> "'"$logfile"'" 2>&1
        status=$?
        echo "[ $(date "+%F %T") ] CubeMX exited with status $status" >> "'"$logfile"'"
        # …your post-exit commands here…
    ' >/dev/null 2>&1 </dev/null &

    # nothing left to disown—setsid means Bash never saw it as a job
}


cubemx-kill()
{
    pkill -f STM32CubeMX
}

cubemx-list()
{
    local numcols=150
    [[ -n "$1" ]] && numcols="$1"
    ps aux --cols "$numcols" | grep --color=always -iE "cubemx|%CPU"
}

alias stm32cubemx=cubemx

cdp()
{
    # Get the last argument of the previous command
    local last_arg="$_"

    # Check if the last argument is a directory
    if [ -d "$last_arg" ]
    then
        cd "$last_arg"
    elif [ -f "$last_arg" ]
    then
        cd "$(dirname "$last_arg")"
    else
        echo "The last argument is neither a directory nor a file: '$last_arg'"
    fi
}
