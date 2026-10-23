#!/bin/bash

source_lib "$HOME/.bashrc.d/aliases.d/ls.alias" || return 
source_lib "$HOME/.bashrc.d/aliases.d/airpods.alias" || return 
source_lib "$HOME/.bashrc.d/aliases.d/pdf.alias" || return 
source_lib "$HOME/.bashrc.d/aliases.d/stm32cubemx.alias" || return
source_lib "$HOME/.bashrc.d/aliases.d/debug_bash.alias" || return
source_lib "$HOME/.bashrc.d/aliases.d/function_handling.alias" || return
source_lib "$HOME/.bashrc.d/aliases.d/openembedded.alias" || return
source_lib "$HOME/.bashrc.d/aliases.d/ssh.alias" || return
source_lib "$HOME/.bashrc.d/aliases.d/tmux_exit.alias" || return
source_lib "$HOME/.bashrc.d/aliases.d/less.alias" || return
source_lib "$HOME/.bashrc.d/aliases.d/rm_whitespace.alias" || return
source_lib "$HOME/.bashrc.d/aliases.d/cd.alias" || return

alias reboot='echo "Rethink what you are doing. If you want to reboot your host machine, use \\reboot" '

alias db=distrobox

alias print_path='echo $PATH | tr ":" "\n"'

DEFAULT_BOLD_COLOR='\033[1;39m'
DEFAULT_UNDERLINE_COLOR='\033[4;39m'
RED_COLOR='\033[0;31m'
GREEN_COLOR='\033[0;32m'
ORANGE_COLOR='\033[0;33m'
MAGENTA_COLOR='\033[0;35m'
END_COLOR='\033[0m'

if command -v trash &>/dev/null
then
    alias rt=trash
    alias rm="echo \"Don't use rm, use trash/rt (trash-cli package) instead.\"; false"
fi

alias wget='wget -q --show-progress --progress=bar:force:noscroll'

if hash code-insiders &>/dev/null &&
   ! hash code &>/dev/null
then
    alias code=code-insiders
fi

eog()
{
    command eog "$1" &
    disown
}

