#!/usr/bin/env bash


## mrbones --- a bare-bones static site generator
## mrbones by Dimitri Kokkonis is licensed under a Creative Commons Attribution-ShareAlike 4.0
## International License. See the accompanying LICENSE file for more info.


VERSION="0.3.1-dev"
# Do not edit this field. It is automatically populated during installation.
BUILD="unknown"
DEPENDENCIES=(realpath find sort)
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

ESCAPED_AT="{@@MRBONES@@}"

USE_TARGET_REGEX="[^[:space:]][^"$'\t'$'\r'$'\n'$'\f'$'\v'"]+"
INCLUDE_TARGET_REGEX="$USE_TARGET_REGEX"
PERMALINK_TARGET_REGEX="$USE_TARGET_REGEX"
CONTENT_SECTION_NAME_REGEX="[a-zA-Z0-9_-]+"
PERMALINK_REGEX="@permalink[[:blank:]]+($PERMALINK_TARGET_REGEX)[[:blank:]]*("$'\n'"|$)"
USE_REGEX="@use"
USE_REGEX_FULL="${USE_REGEX}[[:blank:]]+($USE_TARGET_REGEX)"
INCLUDE_REGEX="@include"
INCLUDE_REGEX_FULL="${INCLUDE_REGEX}[[:blank:]]+($INCLUDE_TARGET_REGEX)"
BEGIN_REGEX_FULL="@begin[[:blank:]]+($CONTENT_SECTION_NAME_REGEX)"
CONTENT_REGEX="@content\.($CONTENT_SECTION_NAME_REGEX)([^a-zA-Z0-9_-]?)"

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
            echo "INTERNAL: invalid value '$USE_COLOR' for \$USE_COLOR." 1>&2
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
    local color_args

    while [[ $# -gt 0 ]]
    do
        case $1 in
            --color=*)
                # In case the user passed `--color=WHEN`, split on the `=`.
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

main() {
    local site_content rel_file_path parent_dir_path src_pages cache src_page_path \
        rel_src_page_path dest_page_path page_content raw_permalink_target permalink_match \
        use_chain use_target use_template_content content_sections begin_match section_name \
        end_regex_full end_match section_regex section_match section_content content_match \
        content_key post_content content replacement include_chain include_match include_target \
        include_template_content rel_dest_page_path dest_page_dir page_filename page_name \
        page_name_dir

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
    mapfile -t site_content < <( \
        find "$WORKING_DIR" -type f \
        -not -name "*.html" \
        -not -name "*.htm" \
        -not -path "$SITE_DIR/*" \
        -not -path "$TEMPLATES_DIR/*" \
    )
    for file_path in "${site_content[@]}"
    do
        rel_file_path="${file_path##"$WORKING_DIR"}"
        parent_dir_path="$SITE_DIR/${rel_file_path%/*}"
        mkdir -p "$parent_dir_path"
        cp "$file_path" "$parent_dir_path"
    done

    info_message "Generating pages..."

    mapfile -t src_pages < <( \
        find "$WORKING_DIR" -type f \
            "(" -name "*.html" -or -name "*.htm" ")" \
            -not -path "$SITE_DIR/*" \
            -not -path "$TEMPLATES_DIR/*" \
        | sort \
    )

    declare -A cache=()
    for src_page_path in "${src_pages[@]}"
    do
        rel_src_page_path="${src_page_path##"$WORKING_DIR/"}"
        dest_page_path="$SITE_DIR/$rel_src_page_path"
        verbose_message "  Generating page '$rel_src_page_path'..."

        page_content="$(<"$src_page_path")"
        # We escape any literal `\@`s to avoid mistaking them for directives.
        # We will put them back at the end.
        page_content="${page_content//"\\@"/"$ESCAPED_AT"}"

        raw_permalink_target=""
        if [[ $page_content =~ $PERMALINK_REGEX ]]
        then
            raw_permalink_target="${BASH_REMATCH[1]}"

            # Remove any `@permalink <PERMALINK>`s.
            while [[ $page_content =~ $PERMALINK_REGEX ]]
            do
                permalink_match="${BASH_REMATCH[0]}"
                page_content="${page_content//"$permalink_match"}"
            done
        fi

        if [[ -n $raw_permalink_target ]]
        then
            verbose_message "    Resolving destination (permalink)..."
            if [[ ${raw_permalink_target:0:1} != "/" ]]
            then
                error "$src_page_path: \`@permalink $raw_permalink_target\`: permalinks must be" \
                    "absolute paths (starting with '/')."
            fi

            permalink_target="$raw_permalink_target"
            # Make sure to normalize the permalink, ensuring that it ends in ".html"/".htm".
            if [[ ($permalink_target != *.htm) && ($permalink_target != *.html) ]]
            then
                permalink_target="$permalink_target.html"
            fi

            # ".." is not allowed in the permalink.
            if [[ $permalink_target == *..* ]]
            then
                error "$src_page_path: \`@permalink $raw_permalink_target\`: '..' is not allowed" \
                    "in permalinks."
            fi

            # Remove the leading '/' of the permalink.
            dest_page_path="$SITE_DIR/${permalink_target#/*}"
        fi


        # Handle `@use`s.
        # Keep track of which `@use` targets have been already handled to identify recursion.
        declare -A use_chain=()
        while [[ $page_content =~ $USE_REGEX_FULL ]]
        do
            use_target="${BASH_REMATCH[1]}"
            verbose_message "    Handling \`@use $use_target\`..."

            # Check that the use target exists.
            if [[ ! -f "$TEMPLATES_DIR/$use_target" ]]
            then
                error "$src_page_path: \`@use\` target '$use_target' not found in $TEMPLATES_DIR."
            fi

            # Check if we've already seen the target.
            if [[ -v use_chain["$use_target"] ]]
            then
                error "$src_page_path: \`@use $use_target\`: recursive \`@use\`."
            else
                use_chain["$use_target"]=1
            fi

            # Look at the cache for the `@use` target.
            use_template_content="${cache[$use_target]}"
            if [[ -z $use_template_content ]]
            then
                use_template_content="$(<"$TEMPLATES_DIR/$use_target")"
                # We escape any literal `\@`s to avoid mistaking them for directives.
                # We will put them back at the end.
                use_template_content="${use_template_content//"\\@"/"$ESCAPED_AT"}"
                cache["$use_target"]="$use_template_content"
            fi

            # Parse the `@use` content from the current file.
            declare -A content_sections=()
            while [[ $page_content =~ $BEGIN_REGEX_FULL ]]
            do
                begin_match="${BASH_REMATCH[0]}"
                section_name="${BASH_REMATCH[1]}"

                end_regex_full="@end $section_name"

                if [[ $page_content =~ $end_regex_full ]]
                then
                    end_match="${BASH_REMATCH[0]}"
                    section_regex="$begin_match"$'\n'"(|.+)"$'\n'"$end_match"

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
            while [[ $use_template_content =~ $CONTENT_REGEX ]]
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

        # We should be done with `@use`s by now. If there are any left over, it means that their
        # targets are empty.
        if [[ $page_content =~ $USE_REGEX ]]
        then
            error "$src_page_path: empty \`@use\`."
        fi

        # Handle `@include`s.
        # Keep track of which `@include` targets have been already handled to identify recursion.
        declare -A include_chain=()
        while [[ $page_content =~ $INCLUDE_REGEX_FULL ]]
        do
            include_match="${BASH_REMATCH[0]}"
            include_target="${BASH_REMATCH[1]}"
            verbose_message "    Handling \`@include $include_target\`..."

            # Check that the include target exists.
            if [[ ! -f "$TEMPLATES_DIR/$include_target" ]]
            then
                error "$src_page_path: \`@include\` target '$include_target' not found in" \
                    "$TEMPLATES_DIR."
            fi

            # Check if we've already seen the target.
            if [[ -v include_chain["$include_target"] ]]
            then
                error "$src_page_path: \`@include $include_target\`: recursive \`@include\`."
            else
                include_chain["$include_target"]=1
            fi

            # Look at the cache for the `@include` target.
            include_template_content="${cache[$include_target]}"
            if [[ -z $include_template_content ]]
            then
                include_template_content="$(cat "$TEMPLATES_DIR/$include_target")"
                # We escape any literal `\@`s to avoid mistaking them for directives.
                # We will put them back at the end.
                include_template_content="${include_template_content//"\\@"/"$ESCAPED_AT"}"
                cache["$include_target"]="$include_template_content"
            fi

            page_content="${page_content//"$include_match"/"$include_template_content"}"
        done

        # We should be done with `@include`s by now. If there are any left over, it means that their
        # targets are empty.
        if [[ $page_content =~ $INCLUDE_REGEX ]]
        then
            error "$src_page_path: empty \`@include\`."
        fi

        rel_dest_page_path="${dest_page_path##"$SITE_DIR/"}"
        dest_page_dir="${dest_page_path%/*}"
        verbose_message "    Putting page in '$SITE_DIR_NAME/$rel_dest_page_path'..."
        mkdir -p "$dest_page_dir"
        # Since we potentially escaped some literal `\@`s to avoid mistaking them for directives,
        # it is now time to put them back.
        page_content="${page_content//"$ESCAPED_AT"/"\\@"}"
        echo "$page_content" > "$dest_page_path"

        # In order to support links that do not end in ".html"/".htm", we should generate dummy
        # `index.html` pages that enable directories to work as pages.
        #
        # For example, if there is a page `/stuff/things.html`, then `/stuff/things` will lead to a
        # 404 by default. By creating a copy of the same page in `/stuff/things/index.html`, we
        # enable that last URL to work as intended.
        #
        # This procedure shall be done on all pages except the ones titled 'index.html', since those
        # have a special meaning anyway (and creating an `index/` subdirectory would be redundant).
        page_filename="${dest_page_path##*/}"
        if [[ $page_filename != "index.html" && $page_filename != "index.htm" ]]
        then
            page_filename="${dest_page_path##*/}"
            page_name="${page_filename%%.*}"
            page_name_dir="$dest_page_dir/$page_name"
            rel_dest_page_path="${page_name_dir##"$SITE_DIR/"}/index.html"
            verbose_message "    Creating page copy in '$SITE_DIR_NAME/$rel_dest_page_path'..."
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
