#!/usr/bin/env bash

source "$COMMON"
source "$MRBONES"

USE_COLOR=0

# The `VERBOSE` variable should control the verbosity of the output.
VERBOSE=0
[[ "$(verbose_message "test" 2>&1)" == "" ]] \
    || fail "\`verbose_message()\` should not output anything when \`VERBOSE=0\`."
VERBOSE=1
[[ "$(verbose_message "test" 2>&1)" == "[mrbones]  test" ]] \
    || fail "\`verbose_message()\` should output something when \`VERBOSE=1\`."
