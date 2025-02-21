#!/usr/bin/env bash


## mrbones --- a bare-bones static site generator
## mrbones by Dimitri Kokkonis  is licensed under a Creative Commons Attribution-ShareAlike 4.0
## International License. See the accompanying LICENSE file for more info.


VERSION="0.2.0"
# Do not edit this field. It is automatically populated during installation.
BUILD="unknown"
DEPENDENCIES=(sed realpath find)
set -e

TEMPLATES_DIR_NAME="_templates"
SITE_DIR_NAME="_site"
VERBOSE=0
# The following values are used for color:
# - 0: never
# - 1: auto (sensible defaults)
# - 2: always
USE_COLOR=1
WORKING_DIR=$PWD
USE_CACHE=1
MRBONES_CACHE="${TMP_DIR:-/tmp}/.mrbones.cache"

TEMPLATES_DIR="$WORKING_DIR/$TEMPLATES_DIR_NAME"
SITE_DIR="$WORKING_DIR/$SITE_DIR_NAME"

# Check globally if we're in a tty. This should be done here because inside a function the context
# at the callsite may change the result.
IS_TTY=0
if [ -t 1 ]
then
    IS_TTY=1
fi


# Decide if we should use colors in the output.
#
# This follows the standard described in http://bixense.com/clicolors/.
should_use_color() {
    case $USE_COLOR in
        0)
            return 1  # False
            ;;
        1)
            if [[ $NO_COLOR ]]
            then
                return 1  # False
            elif [[ ($CLICOLOR_FORCE) || ($IS_TTY == 1) ]]
            then
                return 0  # True
            else
                return 1  # False
            fi
            ;;
        2)
            return 0  # True
            ;;
        *)
            error "(INTERNAL): invalid value '$USE_COLOR' for \$USE_COLOR."
            ;;
    esac
}

# Print an error message to `stderr`.
error_message() {
    if should_use_color
    then
        echo -e "\e[1m[mrbones]\e[0m  \e[31mERROR: $*\e[0m" 1>&2
    else
        echo "[mrbones]  ERROR: $*" 1>&2
    fi
}


# Print an error message to `stderr` and exit with code 1.
error() {
    error_message "$@"
    rm -rf "${SITE_DIR:?}/"
    exit 1
}


# Print an info message to `stderr`.
info_message() {
    if should_use_color
    then
        echo -e "\e[1m[mrbones]\e[0m  \e[32m$*\e[0m" 1>&2
    else
        echo "[mrbones]  $*" 1>&2
    fi
}


# Print a verbose message to `stderr`.
verbose_message() {
    if [[ $VERBOSE -ne 1 ]]
    then
        return
    fi

    if should_use_color
    then
        echo -e "\e[1m[mrbones]\e[0m  \e[38;5;244m$*\e[0m" 1>&2
    else
        echo "[mrbones]  $*" 1>&2
    fi
}


# Get the cache of a source page (if it exists) via the page's absolute path.
#
# If caching is disabled, this function always results in a cache miss (by returning an empty
# string).
get_page_cache() {
    if [[ $# -ne 1 ]]
    then
        error "(INTERNAL): incorrect arguments to \`get_page_cache(src_page_path)\`."
    fi

    local src_page_path="$1"

    if [[ $USE_CACHE == 0 ]]
    then
        echo ""
        return
    fi

    # We can declare and use on the same line here since we ignore the return value.
    # shellcheck disable=SC2155
    local result="$(sed -nE "s/${src_page_path//\//\\/}=(.+)$/\\1/p" "$MRBONES_CACHE")"
    # Unescape any escaped characters.
    #
    # There is a subtlety here: we might have `\\n`s in the original source that will have become
    # `\\\\n`s after escaping. If we naively do `\\n` -> `\n`, then `\\\\n` -> `\\\n`, so we need
    # to take care to convert `\\\n`s back to `\\n`s.
    result="${result//\\n/$'\n'}"
    result="${result//\\$'\n'/\\n}"
    result="${result//\\\\/\\}"
    result="${result//\\=/=}"

    echo "$result"
}


# Set the cache of a source page.
#
# If caching is disabled, this function is a no-op.
set_page_cache() {
    if [[ $# -ne 2 ]]
    then
        error "(INTERNAL): incorrect arguments to \`set_page_cache(src_page_path, page_content)\`."
    fi

    local src_page_path="$1"
    local page_content="$2"

    if [[ $USE_CACHE == 0 ]]
    then
        return
    fi

    local result="$page_content"
    # Escape some sensitive characters.
    result="${result//\\/\\\\}"
    result="${result//$'\n'/\\n}"
    result="${result//=/\\=}"

    echo "$src_page_path=$result" >> "$MRBONES_CACHE"
}


handle_directives() {
    if [[ $# -ne 4 ]]
    then
        error \
            "(INTERNAL): incorrect arguments to" \
            "\`handle_directives(page_content, src_page_path,"\
            "visited_include_paths, visited_use_paths)\`."
    fi

    local page_content="$1"
    local src_page_path="$2"
    local visited_include_paths="$3"
    local visited_use_paths="$4"

    local cache=""


    verbose_message "    Handling \`@include\`s for '$src_page_path'..."

    for include in $(echo "$page_content" | sed -nE 's/(^@include|[\s]*[^\\]@include) (.+)/\2/p')
    do
        local include_path="$TEMPLATES_DIR/$include"

        # Check if include exists.
        if [[ (! -f $include_path) || "$include_path" == "$TEMPLATES_DIR/" ]]
        then
            error "$src_page_path: file '$include_path' does not exist (missing \`@include\`" \
                "target)."
        fi

        # If the current @include target is a path we've already visited, we're about to be stuck
        # in a recursive loop; we need to error out.
        if [[ $visited_include_paths == *$include_path* ]]
        then
            error "$src_page_path: recursive \`@include\` chain found" \
                "(via \`@include\` target '$include')."
        fi

        cache="$(get_page_cache "$include_path")"
        if [[ $cache == "" ]]
        then
            # We can declare and use on the same line here since we ignore the return value.
            # shellcheck disable=SC2155
            local include_body="$(cat "$include_path")"
            # We need to handle includes recursively.
            if ! include_body="$( \
                    handle_directives \
                        "$include_body" \
                        "$include_path" \
                        "$visited_include_paths:$include_path" \
                        "$visited_use_paths" \
                )"
            then
                exit 1
            fi

            set_page_cache "$include_path" "$include_body"
        else
            include_body="$cache"
        fi

        # Replace the `"@include (.+)"` string by the file in the captured group.
        #
        # Make sure to escape ampersands, as they have a different meaning (i.e., "replace with
        # search term", here "@content").
        local page_content="${page_content//@include $include/${include_body//$'&'/\\\&}}"
    done
    # At this point, no `@include`s should remain.
    if [[ $(echo "$page_content" | sed -nE 's/(^@include|[\s]*[^\\]@include)/\1/p') != "" ]]
    then
        error "$src_page_path: empty \`@include\`."
    fi

    verbose_message "    Handling \`@use\`s for '$src_page_path'..."
    # If there are multiple `@use`s, only the last one will be taken into account.
    #
    # We can declare and use on the same line here since we ignore the return value.
    # shellcheck disable=SC2155
    local use_template="$( \
        echo "$page_content" | sed -nE 's/(^@use|[\s]*[^\\]@use) (.+)/\2/p' | tail -n1 \
    )"

    if [[ -z $use_template ]]
    then
        # If the template name is empty but there are `@use`s, then it's an error.
        if [[ $(echo "$page_content" | sed -nE 's/(^@use|[\s]*[^\\]@use)/\1/p') != "" ]]
        then
            error "$src_page_path: empty \`@use\`."
        else
            # No `@use`s, so nothing to do.
            echo "$page_content"
            return
        fi
    fi

    # Check if the `@use` target is empty (whitespace).
    if [[ -z "${use_template// }" ]]
    then
        error "$src_page_path: empty \`@use\`."
    fi

    # Remove any `@use`s from the file.
    page_content="$(echo "$page_content" | sed -E '/(^@use|[\s]*[^\\]@use) .+/d')"

    local use_template_path="$TEMPLATES_DIR/$use_template"
    # Load the template.
    if [[ ! -f $use_template_path ]]
    then
        error "$src_page_path: file '$use_template_path' does not exist (missing \`@use\` target)."
    fi

    # If the current @use target is a path we've already visited, we're about to be stuck
    # in a recursive loop; we need to error out.
    if [[ $visited_use_paths == *$use_template_path* ]]
    then
        error "$src_page_path: recursive \`@use\` chain found" \
            "(via \`@use\` target '$use_template')."
    fi

    cache="$(get_page_cache "$use_template_path")"
    if [[ $cache == "" ]]
    then
        # We can declare and use on the same line here since we ignore the return value.
        # shellcheck disable=SC2155
        local use_template_content="$(cat "$use_template_path")"
        # Make sure to handle any `@include`s in the template.
        if ! use_template_content="$( \
                handle_directives \
                    "$use_template_content" \
                    "$use_template_path" \
                    "$visited_include_paths" \
                    "$visited_use_paths:$use_template_path" \
            )"
        then
            exit 1
        fi

        # At least one occurrence of "@content" must exist.
        if [[ "$(echo "$use_template_content" | sed -nE 's/(@content)/\1/p')" == "" ]]
        then
            error "$src_page_path: missing \`@content\` in \`@use\` template" \
                "'$use_template_path'. Maybe you meant to \`@include\` instead?"
        fi

        set_page_cache "$use_template_path" "$use_template_content"
    else
        use_template_content="$cache"
    fi

    # Replace "@content" by the current page content in the template. This becomes the content of
    # the final page.
    #
    # Note that we have to escape backslashes here, or else they are interpreted as part of the
    # pattern (and thus '\\' get converted to '\').
    local escaped_page_content="${page_content//\\/\\\\}"
    # Make sure to escape ampersands, as they have a different meaning (i.e., "replace with
    # search term", here "@content").
    escaped_page_content="${escaped_page_content//$'&'/\\\&}"
    page_content="${use_template_content//@content/$escaped_page_content}"

    echo "$page_content"
}


# Generate a page for the final site.
#
# All HTML pages (with extension ".html" or ".htm") are taken into account. Directives understood
# by `mrbones` are expanded.
generate_page() {
    if [[ $# -ne 1 ]]
    then
        error "(INTERNAL) incorrect arguments to \`generate_page(src_page_path)\`."
    fi

    local src_page_path="$1"
    # We can declare and use on the same line here since we ignore the return value.
    # shellcheck disable=SC2155
    local rel_src_page_path="$(realpath --relative-to="$WORKING_DIR" "$src_page_path")"
    local dest_page_path="$SITE_DIR/$rel_src_page_path"
    verbose_message "  Generating page '$rel_src_page_path'..."
    # We can declare and use on the same line here since we ignore the return value.
    # shellcheck disable=SC2155
    local page_content=$(cat "$src_page_path")

    verbose_message "    Resolving destination (permalink)..."
    # Handle permalinks.
    #
    # Permalinks are registered via `@permalink <LINK>`. `<LINK>` needs to be an absolute path with
    # regards to the site root (i.e., needs to start with '/'). If there are multiple permalinks,
    # only the last one will be taken into account.
    #
    # We can declare and use on the same line here since we ignore the return value.
    # shellcheck disable=SC2155
    local raw_permalink="$( \
        echo "$page_content" | sed -nE 's/@permalink (.+)/\1/p' | tail -n1 \
    )"
    # Remove any permalink(s) from the file.
    page_content="$(echo "$page_content" | sed -E '/@permalink .+/d')"
    local permalink="$raw_permalink"
    # Make sure the permalink is an absolute path (i.e., starts with slash).
    if [[ -n $permalink ]] && [[ $(echo "$permalink" | cut -b1) != "/" ]]
    then
        error "$src_page_path: permalink must be an absolute path (starting with '/')."
    fi
    # Make sure to normalize the permalink, by ensuring that it ends in ".html"/".htm".
    permalink="$(if [[ -n $permalink ]] && [[ $permalink != *.htm ]] && [[ $permalink != *.html ]]
        then
            echo "$permalink.html"
        else
            echo "$permalink"
        fi)"

    # We can declare and use on the same line here since we ignore the return value.
    # shellcheck disable=SC2155
    local dest_page_path="$(if [[ -n $permalink ]]
        then
            echo "$SITE_DIR/$permalink"
        else
            echo "$dest_page_path"
    fi)"

    page_content="$(handle_directives "$page_content" "$src_page_path" "" "")"

    # At this point, we still need to check if the permalink escapes the $SITE_DIR.
    # This is a quite obvious vulnerability: if someone uses `/../something` as a permalink, then
    # we will naively generate a file outside $SITE_DIR.
    #
    # In order to check that we are not doing this, we need to use `realpath` to resolve the final
    # path produced by the permalink. However, `realpath` will not work until the path is, well,
    # real.
    #
    # To get around that, we need to first *create the dest directory anyway*, and then test with
    # `realpath`. If it turns out that we have escaped $SITE_DIR, we can roll back that last action
    # by removing the directory we just created.
    #
    # This temporary directory should not be a security issue. Since it is created with `mkdir -p`,
    # it cannot overwrite existing data. At worst, an empty directory will be temporarily created
    # outside $SITE_DIR, and will almost immediately be cleaned up.
    #
    # We can declare and use on the same line here since we ignore the return value.
    # shellcheck disable=SC2155
    local dest_page_dir="$(dirname "$dest_page_path")"
    mkdir -p "$dest_page_dir"/
    # Finally check that the permalink does not escape the $SITE_DIR.
    if [[ -n $permalink ]] && \
        [[ \
            $(realpath -L \
                "$SITE_DIR/$(realpath --relative-to="$SITE_DIR" "$SITE_DIR/$permalink")" \
            )/ != $SITE_DIR/* \
        ]]
    then
        # Roll back the temporary directory creation.
        rm -rf "${dest_page_dir:?}"/
        error "$src_page_path: permalink '$raw_permalink' escapes the generated site directory" \
            "'$SITE_DIR'."
    fi

    # We can declare and use on the same line here since we ignore the return value.
    # shellcheck disable=SC2155
    local rel_dest_page_path="$(realpath --relative-to="$SITE_DIR" "$dest_page_path")"
    verbose_message "    Putting page in '$SITE_DIR_NAME/$rel_dest_page_path'..."

    echo "$page_content" > "$dest_page_path"
    # In order to support links that do not end in ".html"/".htm", we should generate dummy
    # `index.html` pages that enable directories to work as pages.
    #
    # For example, if there is a page `/stuff/things.html`, then `/stuff/things` will lead to a 404
    # by default. By creating a copy of the same page in `/stuff/things/index.html`, we enable that
    # last URL to work as intended.
    #
    # This procedure shall be done on all pages except the ones titled 'index.html', since those
    # have a special meaning anyway (and creating an `index/` subdirectory would be redundant).
    if [[ $(basename "$rel_dest_page_path") != "index.html" ]]
    then
        # We can declare and use on the same line here since we ignore the return value.
        # shellcheck disable=SC2155
        local page_name="$(basename "$dest_page_path")"
        local dest_copy_path="$dest_page_dir/${page_name%.*}/index.html"
        # We can declare and use on the same line here since we ignore the return value.
        # shellcheck disable=SC2155
        local dest_copy_dir="$(dirname "$dest_copy_path")"
        mkdir -p "$dest_copy_dir"/

        # We can declare and use on the same line here since we ignore the return value.
        # shellcheck disable=SC2155
        local rel_dest_copy_path="$(realpath --relative-to="$SITE_DIR" "$dest_copy_path")"
        verbose_message "    Creating page copy in '$SITE_DIR_NAME/$rel_dest_copy_path'..."
        echo "$page_content" > "$dest_copy_path"
    fi
}


# Parse arguments to `mrbones`.
parse_arguments() {
    while [[ $# -gt 0 ]]
    do
        case $1 in
            "--color")
                case $2 in
                    "always")
                        USE_COLOR=2
                        ;;
                    "auto")
                        USE_COLOR=1
                        ;;
                    "never")
                        USE_COLOR=0
                        ;;
                    *)
                        error "unrecognized value '$2' for option '--color'." \
                            "Try \`mrbones --help\` for more information."
                esac
                # Skip over `--color` and its argument.
                shift
                shift
                ;;
            "-h" | "--help")
                echo -e "mrbones - a barebones static site generator\n" \
                    "\nusage: mrbones [option(s)]" \
                    "\n  --color=<WHEN>  specify when color should be used:" \
                    "\n                  - never: color is never used" \
                    "\n                  - auto: sensible defaults apply" \
                    "\n                  - always: color is always used" \
                    "\n  -h, --help      print this help message" \
                    "\n  -v, --verbose   print more verbose messages" \
                    "\n  -V, --version   print this program's version number"
                exit 0
                ;;
            "--no-cache")
                USE_CACHE=0
                # Skip over `--no-cache`.
                shift
                ;;
            "-v" | "--verbose")
                VERBOSE=1
                # Skip over `-v`/`--verbose`.
                shift
                ;;
            "-V" | "--version")
                echo "mrbones $VERSION (build $BUILD)"
                exit 0
                ;;
            --* | -*)
                error "unrecognized option '$1'." \
                    "Try \`mrbones --help\` for more information."
                ;;
            *)
                WORKING_DIR="$(realpath "$1")"
                TEMPLATES_DIR="$WORKING_DIR/$TEMPLATES_DIR_NAME"
                SITE_DIR="$WORKING_DIR/$SITE_DIR_NAME"
                # Skip over the argument.
                shift
                ;;
        esac
    done
}


# Check that the necessary dependencies exist.
check_dependencies() {
    for dependency in "${DEPENDENCIES[@]}"
    do
        if [[ ! $(command -v "$dependency") ]]
        then
            error "missing dependency: $dependency."
        fi
    done
}


# Run `mrbones`.
main() {
    check_dependencies
    parse_arguments "$@"

    info_message "Setting up output directory '$SITE_DIR'..."
    verbose_message "  Removing '$SITE_DIR/'..."
    rm -rf "$SITE_DIR"
    verbose_message "  Creating '$SITE_DIR/'..."
    mkdir -p "$SITE_DIR"

    if [[ $USE_CACHE == 1 ]]
    then
        touch "$MRBONES_CACHE"
        truncate --size=0 "$MRBONES_CACHE"
    fi

    info_message "Copying site content..."
    # Make sure to *not* copy templates and the output site directory.
    # We are also *not* copying HTML files, since we have already treated them before and put them
    # where they belong (according to the permalinks).
    rsync -a "$WORKING_DIR"/* "$SITE_DIR" \
        --exclude "$TEMPLATES_DIR_NAME" --exclude "$SITE_DIR_NAME" \
        --exclude "*.html" --exclude "*.htm" \
        --prune-empty-dirs

    info_message "Generating pages..."

    src_pages=$( \
        find "$WORKING_DIR" -name "*.html" \
            -not -path "$SITE_DIR/*" \
            -not -path "$TEMPLATES_DIR/*" \
        | sort \
    )

    for src_page in $src_pages
    do
        generate_page "$src_page"
    done


    info_message "Done! Site is ready at '$SITE_DIR'."
}

main "$@"
