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
   hash code &>/dev/null
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
