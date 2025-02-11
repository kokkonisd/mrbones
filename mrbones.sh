#!/usr/bin/env bash


VERSION="0.1.0-dev"
set -e

TEMPLATES_DIR_NAME="_templates"
SITE_DIR_NAME="_site"
VERBOSE=0
WORKING_DIR=$PWD

TEMPLATES_DIR="$WORKING_DIR/$TEMPLATES_DIR_NAME"
SITE_DIR="$WORKING_DIR/$SITE_DIR_NAME"


error_message() {
    echo -e "\e[1m[mrbones]\e[0m  \e[31mERROR: $@\e[0m" 1>&2
}


error() {
    error_message "$@"
    rm -rf $SITE_DIR/
    exit 1
}


info_message() {
    echo -e "\e[1m[mrbones]\e[0m  \e[32m$@\e[0m" 1>&2
}


verbose_message() {
    local message

    if [[ $# -ne 1 ]]
    then
        error "(INTERNAL) incorrect arguments to \`verbose_message(message)\`."
    fi

    if [[ $VERBOSE -ne 1 ]]
    then
        return
    fi

    message=$1

    echo -e "\e[1m[mrbones]\e[0m  \e[38;5;244m$message\e[0m" 1>&2
}


escape_newlines_and_slashes() {
    # Since `sed` works on a per-line basis, we can't directly replace newlines with their escaped
    # counterpart. So, we do it in two steps: first we use `tr` to transform '\n's to '\\'s, and
    # then we use `sed` to finish the job by transforming '\\'s to '\\n's.
    #
    # We also have to escape '/'s (used in closing HTML tags), as `sed` will mistake them to be
    # separators in the regular expression.
    echo "$(echo "$@" | tr '\n' '\\' | sed 's/\\/\\n/g' | sed 's/\//\\\//g')"
}


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
    verbose_message "    Handling \`@use\`s for $src_page_path..."

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
    page_content="$(escape_newlines_and_slashes "$page_content")"
    page_content="$(echo "$use_template_content" | sed -E "s/@content/$page_content/g")"

    echo -e "$page_content"
}


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
    verbose_message "    Handling \`@include\`s for $src_page_path..."

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
        include_body="$(escape_newlines_and_slashes "$include_body")"
        page_content="$(echo "$page_content" | sed -E "s/@include $include/$include_body/g")"
    done

    echo -e "$page_content"
}


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
    # This procedure shall be done on all pages except the root '/' (as there already is an
    # `index.html` there).
    if [[ $rel_dest_page_path != "index.html" ]]
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


parse_arguments() {
    for argument in "$@"
    do
        case $argument in
            "-h" | "--help")
                echo -e "mrbones - a barebones static site generator\n" \
                    "\nusage: mrbones [option(s)]" \
                    "\n  -h, --help     print this help message" \
                    "\n  -v, --verbose  print more verbose messages" \
                    "\n  -V, --version  print this program's version number"
                exit 0
                ;;
            "-v" | "--verbose")
                VERBOSE=1
                ;;
            "-V" | "--version")
                echo "mrbones $VERSION"
                exit 0
                ;;
            *)
                WORKING_DIR="$(realpath $argument)"
                TEMPLATES_DIR="$WORKING_DIR/$TEMPLATES_DIR_NAME"
                SITE_DIR="$WORKING_DIR/$SITE_DIR_NAME"
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
    rsync -a "$WORKING_DIR"/* "$SITE_DIR" \
        --exclude "$TEMPLATES_DIR_NAME" --exclude "$SITE_DIR_NAME"

    info_message "Generating pages..."
    for src_page in $( \
        find $WORKING_DIR -name "*.html" \
            -not -path "$SITE_DIR/*" \
            -not -path "$TEMPLATES_DIR/*" \
    )
    do
        generate_page "$src_page"
    done

    info_message "Done! Site is ready at '$SITE_DIR'."
}

main "$@"
