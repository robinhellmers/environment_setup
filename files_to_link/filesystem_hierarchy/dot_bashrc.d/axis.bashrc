#
### Devices
#E
spell="172.25.11.230"
# ??? - C####
white=""

# Use rssh and then rcode . on the server
alias code=rcode

if [[ -z "$machine_name_work" ]]
then
    echo -e "${DEFAULT_BOLD_COLOR}Remember to define 'machine_name_work' in your '~/.bashrc' file.${END_COLOR}"
    echo -e "${DEFAULT_BOLD_COLOR}Define it to the name of your host machine, given by 'uname -n'${END_COLOR}"
fi

# 'work' sets this marker when it starts the remote Bash through rssh.
if [[ "$WORK_SSH_SESSION" == 'true' ]]
then
    # Source the setup so its environment and directory remain in this shell.
    if ! source "$HOME/work" yocto "$WORK_YOCTO_TREE" "$WORK_YOCTO_MACHINE"
    then
        unset WORK_SSH_SESSION WORK_YOCTO_TREE WORK_YOCTO_MACHINE
        return 1
    fi

    unset WORK_SSH_SESSION WORK_YEOCTO_TREE WORK_YOCTO_MACHINE
fi

