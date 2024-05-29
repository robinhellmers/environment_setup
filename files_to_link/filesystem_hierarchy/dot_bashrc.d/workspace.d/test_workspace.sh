#!/usr/bin/env bash

unalias rm 2>&1 >/dev/null

# Temporary file for error output
tmp_file=$(mktemp)

echo
echo "****************************"
echo "*** Sourcing test env ***"
echo "****************************"
echo

source_lib "$test_script_path" 2>"$tmp_file"

grep "ModuleNotFoundError: No module named 'pip'" "$tmp_file" >/dev/null
sourcing_error="$?"

(( sourcing_error != 0 )) && cat "$tmp_file"
rm "$tmp_file"

echo
echo "*********************************"
echo "*** Done sourcing test env ***"
echo "*********************************"
echo

if (( sourcing_error == 0 ))
then
    echo do stuff
fi

unset sourcing_error tmp_file

TESTING_ENV='true'

cd "$tests_path"

