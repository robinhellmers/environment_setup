#!/usr/bin/env bash

# Copied from https://gist.github.com/mikeboiko/b6e50210b4fb351b036f1103ea3c18a9#file-update_display-sh

# The problem:
# When you `ssh -X` into a machine and attach to an existing tmux session, the session
# contains the old $DISPLAY env variable. In order the x-server/client to work properly,
# you have to update $DISPLAY after connection. For example, the old $DISPLAY=:0 and
# you need to change to DISPLAY=localhost:10.0 for the ssh session to
# perform x-forwarding properly.

# The solution:
# When attaching to tmux session, update $DISPLAY for each tmux pane in that session
# This is performed by using tmux send-keys to the shell.
# This script handles updating $DISPLAY within vim also

XAUTH_DISPLAY_NUM=$(tmp="${DISPLAY#*:}"; echo ${tmp%.*})
XAUTH_HOST=$(xauth list "$DISPLAY" | grep "$HOSTNAME/unix:${XAUTH_DISPLAY_NUM}[[:space:]]\+MIT-MAGIC-COOKIE-1[[:space:]]\+[[:alnum:]]\+")
found_host_xauth=$?

if (( found_host_xauth == 0 ))
then
    XAUTH_HOST=$(echo $XAUTH_HOST | head -n 1)
fi

NEW_DISPLAY="$DISPLAY"

XAUTH_HOST="$(xauth list "$DISPLAY" | head -n 1)"
# NEW_DISPLAY=$(tmux show-env | sed -n 's/^DISPLAY=//p')

# Update $DISPLAY in bash, zsh and vim/nvim
tmux list-panes -s -F "#{session_name}:#{window_index}.#{pane_index} #{pane_current_command}" | \
while read pane_process
do
    IFS=' ' read -ra pane_process <<< "$pane_process"
    if [[ "${pane_process[1]}" == "zsh" || "${pane_process[1]}" == "bash" ]]; then
        tmux send-keys -t ${pane_process[0]} "export DISPLAY=$NEW_DISPLAY" Enter
        if (( found_host_xauth == 0 ))
        then
            tmux send-keys -t ${pane_process[0]} "xauth add $XAUTH_HOST" Enter
        fi
    elif [[ "${pane_process[1]}" == *"vi"* ]]; then
        tmux send-keys -t ${pane_process[0]} Escape
        tmux send-keys -t ${pane_process[0]} ":let \$DISPLAY = \"$NEW_DISPLAY\"" Enter
        tmux send-keys -t ${pane_process[0]} ":silent! xrestore" Enter
    fi
done

