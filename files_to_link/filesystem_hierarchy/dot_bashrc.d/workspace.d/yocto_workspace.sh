#!/usr/bin/env bash

# Source oe-setup.sh for build tools
echo
echo "****************************"
echo "*** Sourcing yocto env ***"
echo "****************************"
echo

source_lib "/path/yocto_env.h" || return

echo
echo "*********************************"
echo "*** Done sourcing yocto env  ***"
echo "*********************************"
echo

# Passed by workspace script when entering distrobox
[[ -z "$yocto_machine" ]] && { echo "'yocto_machine' not given."; exit 1; }
# Passed by workspace script when entering distrobox
[[ -z "$yocto_path" ]] && { echo "'yocto_path' not given."; exit 1; }

cd "$yocto_path"

myscript "$yocto_machine" >/dev/null || exit
YOCTO_ENV_SOURCED='true'

[[ -d "workspace/sources" ]] && cd "workspace/sources"
