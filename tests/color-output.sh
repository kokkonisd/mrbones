#!/usr/bin/env bash

source "$COMMON"
source "$MRBONES"

VERBOSE=1

# Values outside the range [0, 2] should be invalid for `USE_COLOR`.
USE_COLOR=3
! (should_use_color) || fail "\`USE_COLOR=-1\` should fail."

# Setting `color=never` should result in no colors at all.
USE_COLOR=0
! should_use_color || fail "\`should_use_color()\` should be \`false\` when \`color=never\`."
# Also test `error_message()`.
[[ "$(error_message "test" 2>&1)" == "[mrbones]  ERROR: test" ]] \
    || fail "\`error_message()\` should not use color when \`color=never\`."
# Also test `info_message()`.
[[ "$(info_message "test" 2>&1)" == "[mrbones]  test" ]] \
    || fail "\`info_message()\` should not use color when \`color=never\`."
# Also test `verbose_message()`.
[[ "$(verbose_message "test" 2>&1)" == "[mrbones]  test" ]] \
    || fail "\`verbose_message()\` should not use color when \`color=never\`."

# Setting `color=always` should result in colors always being present.
USE_COLOR=2
should_use_color || fail "\`should_use_color()\` should be \`true\` when \`color=always\`."
# Also test `error_message()`.
[[ \
    "$(error_message "test" 2>&1)" == "$(echo -e "\e[1m[mrbones]\e[0m  \e[31mERROR: test\e[0m")" \
]] \
    || fail "\`error_message()\` should use color when \`color=always\`."
# Also test `info_message()`.
[[ \
    "$(info_message "test" 2>&1)" == "$(echo -e "\e[1m[mrbones]\e[0m  \e[32mtest\e[0m")" \
]] \
    || fail "\`info_message()\` should use color when \`color=always\`."
# Also test `verbose_message()`.
[[ \
    "$(verbose_message "test" 2>&1)" == "$(echo -e "\e[1m[mrbones]\e[0m  \e[38;5;244mtest\e[0m")" \
]] \
    || fail "\`verbose_message()\` should use color when \`color=always\`."


# When `color=never`, the use of `NO_COLOR` or `CLICOLOR_FORCE` should have no effect.
USE_COLOR=0
unset CLICOLOR_FORCE
NO_COLOR=0
! should_use_color \
    || fail "\`should_use_color()\` should be unaffected by \`NO_COLOR\` when \`color=never\`."
unset NO_COLOR
CLICOLOR_FORCE=1
! should_use_color \
    || fail "\`should_use_color()\` should be unaffected by \`CLICOLOR_FORCE\` when" \
        "\`color=never\`."

# When `color=always`, the use of `NO_COLOR` or `CLICOLOR_FORCE` should have no effect.
USE_COLOR=2
unset CLICOLOR_FORCE
NO_COLOR=1
should_use_color \
    || fail "\`should_use_color()\` should be unaffected by \`NO_COLOR\` when \`color=always\`."
unset NO_COLOR
CLICOLOR_FORCE=0
should_use_color \
    || fail "\`should_use_color()\` should be unaffected by \`CLICOLOR_FORCE\` when" \
        "\`color=always\`."

# When `color=auto`, `should_use_color()` should depend on the TTY status by default.
USE_COLOR=1
unset NO_COLOR CLICOLOR_FORCE
IS_TTY=1
should_use_color || fail "\`should_use_color()\` should be \`true\` by default when in a TTY."
IS_TTY=0
! should_use_color \
    || fail "\`should_use_color()\` should be \`false\` by default when not in a TTY."

# When `color=auto`, `CLICOLOR_FORCE` should win over the TTY status.
USE_COLOR=1
unset NO_COLOR
IS_TTY=0
CLICOLOR_FORCE=1
should_use_color \
    || fail "\`CLICOLOR_FORCE\` should win over \`IS_TTY\` when \`color=auto\`."

# When `color=auto`, `NO_COLOR` should win over the TTY status.
USE_COLOR=1
unset CLICOLOR_FORCE
IS_TTY=0
NO_COLOR=1
! should_use_color \
    || fail "\`NO_COLOR\` should win over \`IS_TTY\` when \`color=auto\`."

# When `color=auto`, `NO_COLOR` should win over `CLICOLOR_FORCE` no matter the TTY status.
USE_COLOR=1
NO_COLOR=1
CLICOLOR_FORCE=1
IS_TTY=0
! should_use_color \
    || fail "\`NO_COLOR\` should win over \`CLICOLOR_FORCE\` when \`color=auto\` (\`IS_TTY=0\`)."
IS_TTY=1
! should_use_color \
    || fail "\`NO_COLOR\` should win over \`CLICOLOR_FORCE\` when \`color=auto\` (\`IS_TTY=1\`)."
