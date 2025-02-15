#!/usr/bin/env bash


## mrbones --- a bare-bones static site generator
## mrbones by Dimitri Kokkonis  is licensed under a Creative Commons Attribution-ShareAlike 4.0
## International License. See the accompanying LICENSE file for more info.


VERSION="0.1.0-dev"
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
            # `-t 1` tests if we're in a TTY.
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
        echo -e "\e[1m[mrbones]\e[0m  \e[31mERROR: $@\e[0m" 1>&2
    else
        echo "[mrbones]  ERROR: $@" 1>&2
    fi
}


# Print an error message to `stderr` and exit with code 1.
error() {
    error_message "$@"
    rm -rf $SITE_DIR/
    exit 1
}


# Print an info message to `stderr`.
info_message() {
    if should_use_color
    then
        echo -e "\e[1m[mrbones]\e[0m  \e[32m$@\e[0m" 1>&2
    else
        echo "[mrbones]  $@" 1>&2
    fi
}


# Print a verbose message to `stderr`.
verbose_message() {
    local message

    if [[ $VERBOSE -ne 1 ]]
    then
        return
    fi

    if should_use_color
    then
        echo -e "\e[1m[mrbones]\e[0m  \e[38;5;244m$@\e[0m" 1>&2
    else
        echo "[mrbones]  $@" 1>&2
    fi
}


# Escape newlines and slashes from a string.
#
# This is used to be able to use strings (potentially containing newlines and slashes) in `sed`.
escape_sensitive_characters() {
    # Since `sed` works on a per-line basis, we can't directly replace newlines with their escaped
    # counterpart. So, we do it in two steps: first we use `tr` to transform '\n's to '\\'s, and
    # then we use `sed` to finish the job by transforming '\\'s to '\\n's.
    #
    # We also have to escape '/'s (used in closing HTML tags), as `sed` will mistake them to be
    # separators in the regular expression.
    echo -n "$(echo -n "$@" | tr '\n' '\\' | sed 's/\\/\\n/g' | sed 's/\//\\\//g')"
}


# Handle `@use` directives.
#
# `@use` directives are defined in page or template files, and dictate which template file to use
# as a basis, replacing the `@content` directive in it with the content of the page using the
# `@use` directive.
#
# For example, consider the following pages and templates as well as their content:
# - `_templates/skeleton.html`: "<html>@content</html>"
# - `_templates/main.html`: "@use skeleton.html\n<body>@content</body>"
# - `index.html`: "@use main.html\n<p>Hello!</p>"
#
# The generated `_site/index.html` file will have the following content:
#     "<html><body><p>Hello!</p></body></html>"
#
# A few ground rules:
# - At most one `@use` per line;
# - Only the last `@use` in a file is taken into account;
# - At least one `@content` in the template referenced by `@use`;
# - `@use` directives can be stacked across templates (like in the example above).
handle_use_directive() {
    local page_content src_page_path use_template use_template_content

    if [[ $# -ne 2 ]]
    then
        error \
            "(INTERNAL): incorrect arguments to" \
            "\`handle_use_directive(page_content, src_page_path)\`."
    fi

    page_content="$1"
    src_page_path="$2"
    verbose_message "    Handling \`@use\`s for '$src_page_path'..."

    # If there are multiple `@use`s, only the last one will be taken into account.
    use_template="$( \
        echo "$page_content" | sed -nE 's/@use (.+)/\1/p' | tail -n1 \
    )"

    # No `@use`s, so nothing to do.
    if [[ -z $use_template ]]
    then
        echo "$page_content"
        return
    fi

    # Remove any `@use`s from the file.
    page_content="$(echo "$page_content" | sed -E '/@use .+/d')"

    use_template_path="$TEMPLATES_DIR/$use_template"
    # Load the template.
    if [[ ! -f $use_template_path ]]
    then
        error "$src_page_path: file '$use_template_path' does not exist (missing \`@use\` target.)"
    fi

    use_template_content="$(cat $use_template_path)"
    # Make sure to handle any `@include`s in the template.
    use_template_content="$( \
        handle_include_directive "$use_template_content" "$use_template_path" \
    )"
    # Handle `@use`s recursively.
    use_template_content="$(handle_use_directive "$use_template_content" "$use_template_path")"

    # Replace "@content" by the current page content in the template. This becomes the content of
    # the final page.
    page_content="$(escape_sensitive_characters "$page_content")"
    page_content="$(echo "$use_template_content" | sed -E "s/@content/$page_content/g")"

    echo -e "$page_content"
}


# Handle `@include` directives.
#
# `@include` directives are defined in page or template files, and lead to a verbatim copy of the
# content of the referenced template to be put in the page or template issuing the `@include`.
#
# For example, consider the following pages and templates as well as their content:
# - `_templates/one.html`: "<p>One</p>"
# - `_templates/two.html`: "@include one.html\n<p>Two</p>"
# - `index.html`: "@include two.html\n<p>Three</p>"
#
# The generated `_site/index.html` file will have the following content:
#     "<p>One</p>\n<p>Two</p>\n<p>Three<\p>"
#
# A few ground rules:
# - At most one `@include` per line;
# - `@include` directives can be stacked across templates (like in the example above).
handle_include_directive() {
    local page page_content include_body


    if [[ $# -ne 2 ]]
    then
        error \
            "(INTERNAL): incorrect arguments to " \
            "\`handle_include_directive(page_content, src_page_path)\`."
    fi

    page_content="$1"
    src_page_path="$2"
    verbose_message "    Handling \`@include\`s for '$src_page_path'..."

    for include in $(echo "$page_content" | sed -nE 's/@include (.+)/\1/p')
    do
        include_path="$TEMPLATES_DIR/$include"
        # Check if include exists.
        if [[ ! -f $include_path ]]
        then
            error "$src_page_path: file '$include_path' does not exist (missing \`@include\`" \
                "target.)"
        fi

        include_body="$(cat "$include_path")"
        # We need to handle includes recursively.
        include_body=$(handle_include_directive "$include_body" "$include_path")
        # Replace the `"@include (.+)"` string by the file in the captured group.
        include_body="$(escape_sensitive_characters "$include_body")"
        include="$(escape_sensitive_characters "$include")"
        page_content="$(echo "$page_content" | sed -E "s/@include $include/$include_body/g")"
    done

    echo -e "$page_content"
}


# Generate a page for the final site.
#
# All HTML pages (with extension ".html" or ".htm") are taken into account. Directives understood
# by `mrbones` are expanded.
generate_page() {
    local src_page_path rel_src_page_path dest_page_dir dest_page_path rel_dest_page_path \
        page_content

    if [[ $# -ne 1 ]]
    then
        error "(INTERNAL) incorrect arguments to \`generate_page(src_page_path)\`."
    fi

    src_page_path="$1"
    rel_src_page_path="$(realpath --relative-to=$WORKING_DIR $src_page_path)"
    dest_page_path="$SITE_DIR/$rel_src_page_path"
    verbose_message "  Generating page '$rel_src_page_path'..."
    page_content=$(cat $src_page_path)

    verbose_message "    Resolving destination (permalink)..."
    # Handle permalinks.
    #
    # Permalinks are registered via `@permalink <LINK>`. `<LINK>` needs to be an absolute path with
    # regards to the site root (i.e., needs to start with '/'). If there are multiple permalinks,
    # only the last one will be taken into account.
    raw_permalink="$( \
        echo "$page_content" | sed -nE 's/@permalink (.+)/\1/p' | tail -n1 \
    )"
    # Remove any permalink(s) from the file.
    page_content="$(echo "$page_content" | sed -E '/@permalink .+/d')"
    permalink="$raw_permalink"
    # Make sure the permalink is an absolute path (i.e., starts with slash).
    if [[ -n $permalink ]] && [[ $(echo $permalink | cut -b1) != "/" ]]
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

    dest_page_path="$(if [[ -n $permalink ]]
        then
            echo "$SITE_DIR/$permalink"
        else
            echo "$dest_page_path"
        fi)"

    # Handle any `@use`s in the page.
    page_content="$(handle_use_directive "$page_content" "$src_page_path")"
    # Make sure to handle any `@include`s in the final result.
    # We need to do this, as the source page file itself might have some `@include`s.
    page_content="$(handle_include_directive "$page_content" "$src_page_path")"

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
    dest_page_dir="$(dirname $dest_page_path)"
    mkdir -p $dest_page_dir/
    # Finally check that the permalink does not escape the $SITE_DIR.
    if [[ -n $permalink ]] && \
        [[ \
            $(realpath -L \
                $SITE_DIR/$(realpath --relative-to=$SITE_DIR $SITE_DIR/$permalink) \
            )/ != $SITE_DIR/* \
        ]]
    then
        # Roll back the temporary directory creation.
        rm -rf $dest_page_dir/
        error "$src_page_path: permalink '$raw_permalink' escapes the generated site directory" \
            "'$SITE_DIR'."
    fi

    rel_dest_page_path="$(realpath --relative-to=$SITE_DIR $dest_page_path)"
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
    if [[ $(basename $rel_dest_page_path) != "index.html" ]]
    then
        page_name="$(basename $dest_page_path)"
        dest_copy_path="$dest_page_dir/${page_name%.*}/index.html"
        dest_copy_dir="$(dirname $dest_copy_path)"
        mkdir -p $dest_copy_dir/

        rel_dest_copy_path="$(realpath --relative-to=$SITE_DIR $dest_copy_path)"
        verbose_message "    Creating page copy in '$SITE_DIR_NAME/$rel_dest_copy_path'..."
        echo "$page_content" > "$dest_copy_path"
    fi
}


# Parse arguments to `mrbones`.
parse_arguments() {
    while [[ $# > 0 ]]
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
            "-v" | "--verbose")
                VERBOSE=1
                # Skip over `-v`/`--verbose`.
                shift
                ;;
            "-V" | "--version")
                echo "mrbones $VERSION"
                exit 0
                ;;
            -* | --*)
                error "unrecognized option '$1'." \
                    "Try \`mrbones --help\` for more information."
                ;;
            *)
                WORKING_DIR="$(realpath $1)"
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
        if [[ ! $(command -v $dependency) ]]
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

    info_message "Copying site content..."
    # Make sure to *not* copy templates and the output site directory.
    # We are also *not* copying HTML files, since we have already treated them before and put them
    # where they belong (according to the permalinks).
    rsync -a "$WORKING_DIR"/* "$SITE_DIR" \
        --exclude "$TEMPLATES_DIR_NAME" --exclude "$SITE_DIR_NAME" \
        --exclude *.html --exclude *.htm \
        --prune-empty-dirs

    info_message "Generating pages..."
    for src_page in $( \
        find $WORKING_DIR -name "*.html" \
            -not -path "$SITE_DIR/*" \
            -not -path "$TEMPLATES_DIR/*" \
        | sort \
    )
    do
        generate_page "$src_page"
    done

    info_message "Done! Site is ready at '$SITE_DIR'."
}

main "$@"
