#!/bin/bash

#
### PS1 settings - PS1 controls what is shown in the prompt
#

#####
# COLORING: https://en.wikipedia.org/wiki/ANSI_escape_code#8-bit
#
# ESC[38:5:⟨n⟩m Select foreground color where 'n' is a number from the table
#
# START: \[\033[38;5;(n)m\]
# END:   \[\033[00m\]
#####

source "$HOME/.local/bin/bash_prompt/git-completion.bash" # ID git-completion
source "$HOME/.local/bin/bash_prompt/bash-prompt.sh" # ID bash-prompt

# After each command, set $BRANCH to current branch
PROMPT_COMMAND="${PROMPT_COMMAND:+"$PROMPT_COMMAND; "}"'BRANCH=$(git symbolic-ref HEAD 2>/dev/null | cut -d"/" -f 3-)'

# Function called in __git_ps1_custom() which is located in .../bash-prompt.sh.
# Is evaluated after every executed command in the terminal.
# Changing 'ps1_end' depending on environment variables.
_prompt_command_indicators()
{
    local color_end='\[\033[00m\]'
    local ps1_end_extra=' '

    #####
    # Example:
    # PS1 adding [CUSTOM] through PROMPT_COMMAND and __git_ps1_custom() depending on an
    # environmental variable.
    if [[ -n ${CUSTOM_BASH_PROMPT_INDICATION+x} ]]
    then
        local custom_bash_color='\[\033[1;38;5;214m\]'
        local custom_bash='[CUSTOM]'

        ps1_end_extra+="${custom_bash_color}${custom_bash}${end_color}"
    fi
    #####

    #####
    # Yocto environment indicator
    if [[ "$YOCTO_ENV_SOURCED" == 'true' ]]
    then
        local yocto_color='\[\033[1;38;5;214m\]'
        local yocto='[YOCTO]'

        ps1_end_extra+="${yocto_color}${yocto}${color_end}"

        # Yocto MACHINE indicator
        local yocto_machine
        yocto_machine=$(grep -Po '(?<=^MACHINE \?\= \").+(?=\")' $BBPATH/conf/local.conf 2>/dev/null)
        if [[ -n "$yocto_machine" ]]
        then
            local yocto_machine_color='\[\033[1;34m\]'

            ps1_end_extra+="${yocto_machine_color}[${yocto_machine}]${color_end}"
        fi
    fi
    #####

    #####
    # Test environment indicator
    if [[ "$TESTING_ENV" == 'true' ]]
    then
        local test_color='\[\033[1;38;5;214m\]'
        local test='[TEST]'

        ps1_end_extra+="${test_color}${test}${color_end}"
    fi
    #####

    # Put it all together
    [[ "$ps1_end_extra" == ' ' ]] && ps1_end_extra=""
    ps1pc_end="${ps1_end_extra}${ps1pc_end}"
}

# Evaluated with every new shell
_ps1_base_indicators()
{
    local ps1_base_1
    local ps1_base_2
    local ps1_machine_work

    # PS1 base split up in two
    ps1_base_1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u\[\033[00m\]'
    ps1_base_2=':\[\033[01;34m\]\w\[\033[00m\]'
    ps1_start="${ps1_base_first}${ps1_base_second}"
    ps1_end='\n\$ '
    # PS1 adding @work in orange
    ps1_machine_work='\[\033[38;5;214m\]@work\[\033[00m\]'

    local machine="$(uname -n)"

    [[ -n "$CONTAINER_ID" && -n "$DISTROBOX_ENTER_PATH" ]] \
        && in_distrobox='true'

    shopt -q login_shell && login_session='true' || login_session='false'
    [[ $- == *i* ]] && interactive_session='true' || interactive_session='false'

    [[ $(who am i) =~ \([-a-zA-Z0-9\.]+\)$ ]] \
        && remote_session='true' \
        || remote_session='false'

    if [[ "$in_distrobox" == 'true' ]]
    then
        ps1_machine_distrobox='\[\033[38;5;214m\]'@distrobox-$CONTAINER_ID'\[\033[00m\]'
        ps1_start="${ps1_base_1}${ps1_machine_distrobox}${ps1_base_2}"

    elif [[ "$remote_session" == 'true' ]]
    then # E.g. SSH session
        # PS1 machine dependent option
        if [[ "$machine" == "$machine_name_work" ]]
        then
            ps1_start="${ps1_base_1}${ps1_machine_work}${ps1_base_2}"
        else
            ps1_start="${ps1_base_1}${ps1_base_2}"
        fi
    else
        # Not an SSH session
        ps1_start="${ps1_base_1}${ps1_base_2}"
    fi
}

_ps1_base_indicators

# Number of directories to show in bash prompt
export PROMPT_DIRTRIM=3

# Git information
export GIT_PS1_SHOWCOLORHINTS=true
export GIT_PS1_SHOWDIRTYSTATE=true
export GIT_PS1_SHOWUNTRACKEDFILES=true
export GIT_PS1_SHOWUPSTREAM='auto'

# PROMPT_COMMAND is evaluated after every executed command in the terminal
# Here a custom __git_ps1() called __git_ps1_custom() is used to control part of
# what is shown in PS1 depending on environmental variables
# PROMPT_COMMAND="${PROMPT_COMMAND:+"$PROMPT_COMMAND; "}$(sed -r 's|^(.+)(\\\$\s*)$|__git_ps1_custom "\1" "\2 "|' <<< $PS1)"
PROMPT_COMMAND="${PROMPT_COMMAND:+"$PROMPT_COMMAND; "}"'__git_ps1_custom  "$ps1_start" "$ps1_end"'
