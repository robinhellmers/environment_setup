#!/bin/bash

alias reboot='echo "Rethink what you are doing. If you want to reboot your host machine, use \\reboot" '
alias git=git-override
alias db=distrobox

DEFAULT_BOLD_COLOR='\033[1;39m'
DEFAULT_UNDERLINE_COLOR='\033[4;39m'
RED_COLOR='\033[0;31m'
GREEN_COLOR='\033[0;32m'
ORANGE_COLOR='\033[0;33m'
MAGENTA_COLOR='\033[0;35m'
END_COLOR='\033[0m'

alias c=command

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

pdfsearch()
{
    # Usage: search_pdf [-o] "search_term" file.pdf
    local open_pdf='false'

    # Check for the -o flag
    if [[ "$1" == "-o"* ]]
    then
        open_pdf='true'
        local flag_rest="${1#-o}"
        shift

        local open_pdf_found_num
        local number_regex='^[0-9]+$'

        if [[ -z "$flag_rest" ]]
        then
            open_pdf_found_num=1
        elif [[ $flag_rest =~ $number_regex ]]
        then
            open_pdf_found_num="$flag_rest"
            echo "open_pdf_found_num: '$open_pdf_found_num'"
        else
            echo "Usage: search_pdf [-o<num>] \"search_term\" file.pdf|file.txt"
            return 1
        fi
    fi

    local search_term
    local pdf_file

    if (( $# == 1 ))
    then
        if ! [[ -f "$LAST_PDF_SEARCHED" ]]
        then
            echo "If 1 argument used, it must be the content to search for."
            echo "Then \$LAST_PDF_SEARCHED must be set, e.g. by doing a search with pdf file specified before."
            return 1
        fi

        pdf_file="$LAST_PDF_SEARCHED"

    elif (( $# == 2 ))
    then
        pdf_file="$2"
    else
        echo "Error: No arguments given."
        return 1
    fi

    search_term="$1"

    if [[ -z "$search_term" || ! -f "$pdf_file" ]]
    then
        echo "Usage: search_pdf [-o] \"search_term\" file.pdf|file.txt"
        return 1
    fi

    # Check if pdftotext is installed
    if ! command -v pdftotext &> /dev/null
    then
        echo "Error: pdftotext is not installed. Please install it and try again."
        return 1
    fi

    LAST_PDF_SEARCHED="$pdf_file"

    # Get the directory and base name, then build the .txt file path
    local dir
    dir=$(dirname "$pdf_file")
    local base
    base=$(basename "$pdf_file" .pdf)
    local txt_file="$dir/$base.txt"

    # If the text file doesn't exist, generate it
    if [[ ! -f "$txt_file" ]]
    then
        echo -e "Text version of pdf not found. Generating it:\n   '$txt_file'\n"

        pdftotext "$pdf_file" "$txt_file"

        echo -e "Done generating\n    '$txt_file'.\nSearching..."
    fi

    # Search the text file for the search term and formfeed characters, then print page numbers
    local output
    output="$(grep -F -o -e $'\f' -e "$search_term" "$txt_file" | \
        awk 'BEGIN { page = 1 }
            /\f/ { ++page; next }
            { printf "%d: %s\n", page, $0 }')"

    echo -e "\n$output"

    if [[ "$open_pdf" == 'true' ]]
    then
        local first_line
        first_line="$(echo "$output" | head -n 1)"

        local line
        line="$(echo "$output" | sed -n "${open_pdf_found_num}p")"


        if [[ -z "$first_line" ]]
        then
            echo "No occurrence of '$search_term' found."
            return 1
        elif [[ -z "$line" ]]
        then
            local num_occurances
            num_occurances="$(echo "$output" | wc -l)"

            echo "Only $num_occurances occurances exist. Cannot open occurance $open_pdf_found_num."
            echo "Opening first occurance."

            line="$first_line"
        fi

        local page
        page="$(echo "$line" | cut -d: -f1)"

        echo -e "\nOpening page: '$page'"

        pdfopen "$pdf_file" "$page"
    fi
}

pdfopen()
{
    local pdf_file
    local page

    local number_regex='^[0-9]+$'

    if (( $# == 0 ))
    then
        if ! [[ -f "$LAST_PDF_SEARCHED" ]]
        then
            echo "Could not find file from '\$LAST_PDF_SEARCHED'"
            return 1
        fi

        pdf_file="$LAST_PDF_SEARCHED"
        page="1"

    elif (( $# == 1 ))
    then
        if [[ -f "$1" ]]
        then
            pdf_file="$1"
        elif [[ $1 =~ $number_regex ]]
        then
            if ! [[ -f "$LAST_PDF_SEARCHED" ]]
            then
                echo "Could not find file from '\$LAST_PDF_SEARCHED'"
                return 1
            fi
            pdf_file="$LAST_PDF_SEARCHED"
            page=$1
        else
            echo "Invalid input."
            return 1
        fi
    elif (( $# == 2 ))
    then
        pdf_file="$1"
        page="$2"
    else
        echo "Invalid input."
        return 1
    fi

    if [[ ! -f "$pdf_file" ]]
    then
        echo "Error: File '$pdf_file' not found."
        return 1
    fi

    if ! [[ $page =~ $number_regex ]]
    then
        echo "Error: Given page number, not a number '$page'"
        return 1
    fi

    # Convert the PDF file path to Windows format using wslpath
    local win_path
    win_path=$(wslpath -w "$pdf_file")

    # Path to Foxit Reader executable (adjust if necessary)
    local foxit_exe="/mnt/c/Program Files (x86)/Foxit Software/Foxit PDF Reader/FoxitPDFReader.exe"

    if [[ ! -x "$foxit_exe" ]]
    then
        echo -e "Error: FoxitPDFReader.exe not found at\n    '$foxit_exe'\nPlease check your installation."
        return 1
    fi

    echo -e "\nOpening PDF:\n$pdf_file\n"
    # Open the PDF at the specified page using Foxit
    nohup "$foxit_exe" /A "page=$page" "$win_path" </dev/null >/dev/null 2>&1 &
}

alias print_path='echo $PATH | tr ":" "\n"'

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