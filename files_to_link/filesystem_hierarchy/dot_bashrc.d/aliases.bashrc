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

# Go to Downloads
alias cdd="cd $HOME/Downloads"

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

git-li() {
  git log \
    --color=always \
    --graph \
    --decorate-refs-exclude='refs/heads/pull' \
    --decorate-refs-exclude='refs/remotes/origin/pull' \
    --format=format:'%C(#f0890c)%h%C(reset) - %C(bold green)(%ar)%C(reset) %C(white)%s%C(reset)%n%C(dim white)%d%C(reset)' \
    "$@" \
  | while IFS= read -r line; do
      # 1) skip any purely-blank lines (this removes the empty "%n" when no refs)
      [[ -z $line ]] && continue

      # 2) if this is the "(...)" line, split it...
      if [[ $line =~ ^[[:space:]]*\((.*)\)[[:space:]]*$ ]]; then
        refs="${BASH_REMATCH[1]}"
        IFS=',' read -ra parts <<< "$refs"
        for r in "${parts[@]}"; do
          # strip leading space from each ref
          r="${r# }"
          printf '    %s\n' "$r"
        done
      else
        # 3) otherwise, it's the commit+message line—print it
        echo "$line"
      fi
    done \
  | less -R
}
