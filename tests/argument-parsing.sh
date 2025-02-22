#!/usr/bin/env bash

source "$COMMON"
source "$MRBONES"
# Reset the color to 0.
USE_COLOR=0

# `-h`/`--help` should parse correctly.
(parse_arguments "-h") || fail "valid option \`-h\` should parse."
(parse_arguments "--help") || fail "valid \`--help\` should parse."

# `-V`/`--version` should parse correctly.
(parse_arguments "-V") || fail "valid option \`-V\` should parse."
(parse_arguments "--version") || fail "valid option \`--version\` should parse."

# Unrecognized options should fail.
! (parse_arguments "-X") || fail "unrecognized option \`-X\` should fail to parse."
! (parse_arguments "--invalid") || fail "unrecognized option \`--invalid\` should fail to parse."

# Both `--color never` and `--color=never` should work.
USE_COLOR=1
parse_arguments "--color" "never" || fail "valid option \`--color never\` should parse."
[[ $USE_COLOR == 0 ]] || fail "\`--color never\` should work."
USE_COLOR=1
parse_arguments "--color=never" || fail "valid option \`--color=never\` should parse."
[[ $USE_COLOR == 0 ]] || fail "\`--color=never\` should work."

# Both `--color auto` and `--color=auto` should work.
USE_COLOR=0
parse_arguments "--color" "auto" || fail "valid option \`--color auto\` should parse."
[[ $USE_COLOR == 1 ]] || fail "\`--color auto\` should work."
USE_COLOR=0
parse_arguments "--color=auto" || fail "valid option \`--color=auto\` should parse."
[[ $USE_COLOR == 1 ]] || fail "\`--color=auto\` should work."

# Both `--color always` and `--color=always` should work.
USE_COLOR=1
parse_arguments "--color" "always" || fail "valid option \`--color always\` should parse."
[[ $USE_COLOR == 2 ]] || fail "\`--color always\` should work."
USE_COLOR=1
parse_arguments "--color=always" || fail "valid option \`--color=always\` should parse."
[[ $USE_COLOR == 2 ]] || fail "\`--color=always\` should work."
# Reset the color to 0.
USE_COLOR=0

# Any other value to `--color` should be rejected.
! (parse_arguments "--color" "yes") || fail "invalid option \`--color yes\` should fail to parse."
! (parse_arguments "--color=yes") || fail "invalid option \`--color=yes\` should fail to parse."
