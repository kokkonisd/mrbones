#!/usr/bin/env bash


## mrbones --- a bare-bones static site generator
## mrbones by Dimitri Kokkonis  is licensed under a Creative Commons Attribution-ShareAlike 4.0
## International License. See the accompanying LICENSE file for more info.


VERSION="0.2.2-dev"
# Do not edit this field. It is automatically populated during installation.
BUILD="unknown"
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
            echo "(INTERNAL): invalid value '$USE_COLOR' for \$USE_COLOR." 1>&2
            exit 1
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
    if [[ $VERBOSE == 0 ]]
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


# Parse arguments to `mrbones`.
parse_arguments() {
    while [[ $# -gt 0 ]]
    do
        case $1 in
            --color=*)
                # In case the user passed `--color=WHEN`, split on the `=`.
                local color_args=""
                IFS='=' read -ra color_args <<< "$1"
                # Skip the `--color=WHEN` argument now that we've parsed it.
                shift;
                # Add the parsed (separated) `--color WHEN` at the front of the arguments and fall
                # through to the "normal" `--color WHEN` case.
                set -- "${color_args[@]}" "$@"
                ;&
            "--color")
                case "$2" in
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
                    "\n  --no-cache      disable template page caching" \
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


main() {
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
        --exclude "*.html" --exclude "*.htm" \
        --prune-empty-dirs

    info_message "Generating pages..."

    src_pages=$( \
        find "$WORKING_DIR" -name "*.html" \
            -not -path "$SITE_DIR/*" \
            -not -path "$TEMPLATES_DIR/*" \
        | sort \
    )

    declare -A cache
    for src_page_path in $src_pages
    do
        rel_src_page_path="${src_page_path##"$WORKING_DIR/"}"
        dest_page_path="$SITE_DIR/$rel_src_page_path"
        verbose_message "  Generating page '$rel_src_page_path'..."

        page_content="$(cat "$src_page_path")"

        permalink=""
        permalink_regex="(^@permalink|[ \t]+@permalink) ([^"$'\n'" ]+)"
        if [[ $page_content =~ $permalink_regex ]]
        then
            permalink="${BASH_REMATCH[2]}"
            # Remove any `@permalink <PERMALINK>`s.
            page_content="${page_content//"${BASH_REMATCH[0]}"}"
        fi

        if [[ -n $permalink ]]
        then
            verbose_message "    Resolving destination (permalink)..."
            if [[ ${permalink:0:1} != "/" ]]
            then
                error "$src_page_path: permalink must be an absolute path (starting with '/')."
            fi

            # Make sure to normalize the permalink, ensuring that it ends in ".html"/".htm".
            if [[ ($permalink != *.htm) && ($permalink != *.html) ]]
            then
                permalink="$permalink.html"
            fi

            # ".." is not allowed in the permalink.
            if [[ $permalink == *..* ]]
            then
                error "$src_page_path: permalink '$permalink' could be escaping the generated site" \
                    "directory '$SITE_DIR'."
            fi

            # Remove the leading '/' of the permalink.
            dest_page_path="$SITE_DIR/${permalink#/*}"
        fi


        # Handle `@use`s.
        # TODO: fix regex to handle `\@use`.
        use_regex="@use ([^"$'\n'" ]+)"
        while [[ $page_content =~ $use_regex ]]
        do
            use_target="${BASH_REMATCH[1]}"
            verbose_message "    Handling \`@use $use_target\`..."

            # Check that the use target exists.
            if [[ ! -f "$TEMPLATES_DIR/$use_target" ]]
            then
                error "$src_page_path: \`@use\` target '$use_target' not found in $TEMPLATES_DIR."
            fi

            # Possibly look at the cache for the `@use` target.
            if [[ $USE_CACHE == 1 ]]
            then
                use_template_content="${cache[$use_target]}"
                if [[ -z $use_template_content ]]
                then
                    use_template_content="$(cat "$TEMPLATES_DIR/$use_target")"
                    cache["$use_target"]="$use_template_content"
                fi
            else
                use_template_content="$(cat "$TEMPLATES_DIR/$use_target")"
            fi

            # Parse the `@use` content from the current file.
            declare -A content_sections
            # TODO: fix regex to handle `\@begin`.
            begin_regex="@begin ([0-9a-zA-Z_]+)"
            while [[ $page_content =~ $begin_regex ]]
            do
                begin_match="${BASH_REMATCH[0]}"
                section_name="${BASH_REMATCH[1]}"

                # TODO: fix regex to handle `\@end`.
                end_regex="@end $section_name"

                if [[ $page_content =~ $end_regex ]]
                then
                    end_match="${BASH_REMATCH[0]}"
                    section_regex="$begin_match"$'\n'"(.+)"$'\n'"$end_match"

                    if [[ $page_content =~ $section_regex ]]
                    then
                        section_match="${BASH_REMATCH[0]}"
                        section_content="${BASH_REMATCH[1]}"

                        content_sections["$section_name"]="$section_content"
                        # Eat the section.
                        page_content="${page_content//"$section_match"}"
                    else
                        error "INTERNAL: should be able to find section: $section_regex"
                    fi

                else
                    error "$src_page_path: can't find matching \`@end $section_name\`."
                fi
            done

            # Apply the discovered content sections.
            # TODO handle `\@content`.
            content_regex="@content\.([0-9a-zA-Z_-]+)($|[^0-9a-zA-Z_-]+)"
            while [[ $use_template_content =~ $content_regex ]]
            do
                content_match="${BASH_REMATCH[0]}"
                content_key="${BASH_REMATCH[1]}"
                post_content="${BASH_REMATCH[2]}"
                content="${content_sections[$content_key]}"

                # If the key exists in the page, then replace it with the actual contents.
                # Otherwise, just delete the `@content.$key` part.
                if [[ -n $content ]]
                then
                    replacement="$content$post_content"
                else
                    replacement="$post_content"
                fi

                use_template_content="${use_template_content//"$content_match"/"$replacement"}"
            done

            page_content="$use_template_content"
        done

        # Handle `@include`s.
        # TODO: fix regex to handle `\@include`.
        include_regex="@include ([^"$'\n'" ]+)"
        while [[ $page_content =~ $include_regex ]]
        do
            include_match="${BASH_REMATCH[0]}"
            include_target="${BASH_REMATCH[1]}"
            verbose_message "    Handling \`@include $include_target\`..."

            # Check that the include target exists.
            if [[ ! -f "$TEMPLATES_DIR/$include_target" ]]
            then
                error "$src_page_path: \`@include\` target '$include_target' not found in $TEMPLATES_DIR."
            fi

            # Possibly look at the cache for the `@include` target.
            if [[ $USE_CACHE == 1 ]]
            then
                include_template_content="${cache[$include_target]}"
                if [[ -z $use_template_content ]]
                then
                    include_template_content="$(cat "$TEMPLATES_DIR/$include_target")"
                    cache["$include_target"]="$include_template_content"
                fi
            else
                include_template_content="$(cat "$TEMPLATES_DIR/$include_target")"
            fi

            page_content="${page_content//"$include_match"/"$include_template_content"}"
        done

        verbose_message "    Putting page in '$dest_page_path'..."
        dest_page_dir="${dest_page_path%/*}"
        mkdir -p "$dest_page_dir"
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
        if [[ $rel_src_page_path != "index.html" ]]
        then
            page_filename="${dest_page_path##*/}"
            page_name="${page_filename%%.*}"
            page_name_dir="$dest_page_dir/$page_name"
            mkdir -p "$page_name_dir"
            echo "$page_content" > "$page_name_dir/index.html"
        fi

    done

    info_message "Done! Site is ready at '$SITE_DIR'."
}


# If the script is `source`d (as is the case during unit tests), do not run `main()`.
if ! (return 0 2>/dev/null)
then
    main "$@"
fi
