#!/usr/bin/env bash


TMP_DIR=/tmp
DEPENDENCIES=(sed realpath curl)

MRBONES="$(realpath .)/mrbones.sh"
TESTS_DIR="$(realpath .)/tests"
BASELINE_DIR="$TESTS_DIR/baseline"
HAD_FAILURES=0


run_baseline_tests() {
    tests_passed=0
    tests_failed=0

    for test_dir in $(ls -d "$BASELINE_DIR"/*)
    do
        echo -en "\e[1mRunning\e[0m \e[38;5;244m$test_dir\e[0m \e[1m...\e[0m " 1>&2
        passed=1

        baseline_out=$(cat "$test_dir/baseline.out" 2>/dev/null || echo "")
        baseline_err=$(cat "$test_dir/baseline.err" 2>/dev/null || echo "")

        # Replace $TEST_DIR with the actual test directory in baselines.
        test_dir_escaped_slashes="$(echo "$test_dir" | sed -E 's/\//\\\//g')"
        baseline_out=$(echo "$baseline_out" | sed -E "s/\\\$TEST_DIR/$test_dir_escaped_slashes/g")
        baseline_err=$(echo "$baseline_err" | sed -E "s/\\\$TEST_DIR/$test_dir_escaped_slashes/g")

        tmp_out_file="$TMP_DIR/mrbones.test.out"
        tmp_err_file="$TMP_DIR/mrbones.test.err"

        bash "$MRBONES" --color never "$test_dir/src" 1>"$tmp_out_file" 2>"$tmp_err_file"

        actual_out="$(cat "$tmp_out_file")"
        actual_err="$(cat "$tmp_err_file")"

        # Cleanup build artifacts.
        rm -rf "$tmp_out_file" "$tmp_err_file" "$test_dir/src/_site"

        diff_out="$(diff --color=always <(echo "$baseline_out") <(echo "$actual_out"))"
        diff_err="$(diff --color=always <(echo "$baseline_err") <(echo "$actual_err"))"

        if [[ "$diff_out$diff_err" != "" ]]
        then
            echo -e "\e[1m\e[31mFAIL\e[0m" 1>&2
            tests_failed=$((tests_failed + 1))

            if [[ -n $diff_out ]]
            then
                echo -e "  \e[1m\e[91mStdout does not match baseline:\e[0m" 1>&2
                echo "$diff_out" 1>&2
            else
                echo -e "  \e[1m\e[91mStderr does not match baseline:\e[0m" 1>&2
                echo "$diff_err" 1>&2
            fi
        else
            echo -e "\e[1m\e[32mPASS\e[0m" 1>&2
            tests_passed=$((tests_passed + 1))
        fi

        echo "" 1>&2
    done

    echo -e "┏━━━━━━━━━━━━━━━━━━┓" \
            "\n┃ \e[1mBASELINE SUMMARY\e[0m ┃" \
            "\n┣━━━━━━━┯━━━━━━━━━━┫" \
            "\n┃ \e[1m\e[32mPASS\e[0m  │ \e[1m\e[32m$(printf '%-8d' $tests_passed)\e[0m ┃" \
            "\n┠───────┼──────────┨" \
            "\n┃ \e[1m\e[31mFAIL\e[0m  │ \e[1m\e[31m$(printf '%-8d' $tests_failed)\e[0m ┃" \
            "\n┠───────┼──────────┨" \
            "\n┃ \e[1mTotal\e[0m │ \e[1m$(printf '%-8d' $((tests_passed + tests_failed)))\e[0m ┃" \
            "\n┗━━━━━━━┷━━━━━━━━━━┛" 1>&2

    if [[ $tests_failed > 0 ]]
    then
        HAD_FAILURES=1
    fi
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

check_dependencies
run_baseline_tests

if [[ $HAD_FAILURES == 1 ]]
then
    exit 1
fi
