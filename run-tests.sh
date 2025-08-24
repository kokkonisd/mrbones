#!/usr/bin/env bash


DEPENDENCIES=(realpath find sort curl python3)
TEST_SERVER_PORT=4444
TEST_SERVER_WAIT_TIME_SECONDS=0.5

MRBONES="$(realpath .)/mrbones.sh"
TESTS_DIR="$(realpath .)/tests"
COMMON="$TESTS_DIR/common.sh"
HAD_FAILURES=0


run_baseline_tests() {
    local tests_passed=0
    local tests_failed=0

    local baseline=""
    local actual_output=""
    local output_diff=""

    local curl_tests_passed=0
    local server_pid=""
    local request_url=""

    for test_dir in "$TESTS_DIR"/*/
    do
        # If no tests exist, then stop.
        [[ -e "$test_dir" ]] || break

        # Strip terminating '/' from the path.
        test_dir="${test_dir::-1}"
        echo -en "\e[1mRunning\e[0m \e[38;5;244m$test_dir\e[0m \e[1m...\e[0m " 1>&2

        baseline=$(cat "$test_dir/baseline.err" 2>/dev/null || echo "")
        # Replace $TEST_DIR with the actual test directory in baselines.
        baseline="${baseline//\$TEST_DIR/$test_dir}"
        actual_output="$(bash "$MRBONES" --verbose --color=never "$test_dir/src" 2>&1)"
        output_diff="$(diff --color=always <(echo "$baseline") <(echo "$actual_output"))"
        if [[ "$output_diff" != "" ]]
        then
            echo -e "\e[1m\e[31mFAIL\e[0m" 1>&2
            tests_failed=$((tests_failed + 1))

            echo -e "  \e[1m\e[91mbaseline\e[39m does not match \e[32mactual output\e[39m:\e[0m"
            echo "$output_diff" 1>&2
            # Clean up build artifacts.
            rm -rf "$test_dir/src/_site"
            continue
        fi

        # Run the dir test.
        baseline="$(cat "$test_dir/baseline.dir" 2>/dev/null || echo "")"
        # Replace $TEST_DIR with the actual test directory in baselines.
        baseline="${baseline//\$TEST_DIR/$test_dir}"
        actual_output="$( (find "$test_dir/src/_site" 2>/dev/null || echo "") | sort)"
        output_diff="$(diff --color=always <(echo "$baseline") <(echo "$actual_output"))"
        if [[ "$output_diff" != "" ]]
        then
            echo -e "\e[1m\e[31mFAIL\e[0m" 1>&2
            tests_failed=$((tests_failed + 1))

            echo -e "  \e[1m\e[91mbaseline site directory structure\e[39m does not match" \
                "\e[32mactual site directory structure\e[39m:\e[0m"
            echo "$output_diff" 1>&2
            # Clean up build artifacts.
            rm -rf "$test_dir/src/_site"
            continue
        fi

        # Run curl tests.
        curl_tests_passed=1
        # We need to spin up a server first.
        python3 -m http.server $TEST_SERVER_PORT -d "$test_dir/src/_site" 1>/dev/null 2>&1 &
        # Capture its PID so we can stop it later.
        server_pid="$!"
        # Wait for the server to start up.
        sleep $TEST_SERVER_WAIT_TIME_SECONDS
        # Now, run the requests with curl and check against the baseline.
        for curl_baseline in "$test_dir"/*.curl
        do
            # If no *.curl files exist, then stop.
            [[ -e "$curl_baseline" ]] || break

            baseline="$(cat "$curl_baseline")"
            request_url="$(basename "$curl_baseline")"
            request_url="${request_url//.curl/}"
            request_url="${request_url//__/\/}"

            actual_output=$( \
                curl http://localhost:$TEST_SERVER_PORT/"$request_url" 2>/dev/null \
            )
            output_diff="$(diff --color=always <(echo "$baseline") <(echo "$actual_output"))"
            if [[ "$output_diff" != "" ]]
            then
                echo -e "\e[1m\e[31mFAIL\e[0m" 1>&2
                tests_failed=$((tests_failed + 1))

                echo -e "  \e[1m/$request_url: \e[91mrequest baseline\e[39m does not match" \
                    "\e[32mactual output\e[39m:\e[0m"
                echo "$output_diff" 1>&2
                curl_tests_passed=0
                break
            fi
        done
        # We're done with the curl tests, so we should terminate the server.
        kill "$server_pid"
        wait "$server_pid"
        # Clean up build artifacts.
        rm -rf "$test_dir/src/_site"

        if [[ $curl_tests_passed == 0 ]]
        then
            continue
        fi

        echo -e "\e[1m\e[32mPASS\e[0m" 1>&2
        tests_passed=$((tests_passed + 1))

    done

    echo -e "\n┏━━━━━━━━━━━━━━━━━━┓" \
            "\n┃ \e[1mBASELINE SUMMARY\e[0m ┃" \
            "\n┣━━━━━━━┯━━━━━━━━━━┫" \
            "\n┃ \e[1m\e[32mPASS\e[0m  │ \e[1m\e[32m$(printf '%-8d' $tests_passed)\e[0m ┃" \
            "\n┠───────┼──────────┨" \
            "\n┃ \e[1m\e[31mFAIL\e[0m  │ \e[1m\e[31m$(printf '%-8d' $tests_failed)\e[0m ┃" \
            "\n┠───────┼──────────┨" \
            "\n┃ \e[1mTotal\e[0m │ \e[1m$(printf '%-8d' $((tests_passed + tests_failed)))\e[0m ┃" \
            "\n┗━━━━━━━┷━━━━━━━━━━┛" 1>&2

    if [[ $tests_failed -gt 0 ]]
    then
        HAD_FAILURES=1
    fi
}


# Run unit tests.
#
# These tests come in the form of Bash files in $TESTS_DIR.
run_unit_tests() {
    local tests_passed=0
    local tests_failed=0

    for unit_test in "$TESTS_DIR"/*.sh
    do
        # If no tests exist, then stop.
        [[ -e "$unit_test" ]] || break
        # Skip $COMMON (contains utilities shared among unit tests).
        [[ "$unit_test" == "$COMMON" ]] && continue

        echo -en "\e[1mRunning\e[0m \e[38;5;244m$unit_test\e[0m \e[1m...\e[0m " 1>&2

        local output=""
        if output="$(MRBONES="$MRBONES" COMMON="$COMMON" bash "$unit_test" 2>&1)"
        then
            echo -e "\e[1m\e[32mPASS\e[0m" 1>&2
            tests_passed=$((tests_passed + 1))
        else
            echo -e "\e[1m\e[31mFAIL\e[0m" 1>&2
            echo -e "  \e[1mtest output:\e[0m"
            echo "$output" 1>&2
            tests_failed=$((tests_failed + 1))
        fi
    done

    echo -e "\n┏━━━━━━━━━━━━━━━━━━┓" \
            "\n┃   \e[1mUNIT SUMMARY\e[0m   ┃" \
            "\n┣━━━━━━━┯━━━━━━━━━━┫" \
            "\n┃ \e[1m\e[32mPASS\e[0m  │ \e[1m\e[32m$(printf '%-8d' $tests_passed)\e[0m ┃" \
            "\n┠───────┼──────────┨" \
            "\n┃ \e[1m\e[31mFAIL\e[0m  │ \e[1m\e[31m$(printf '%-8d' $tests_failed)\e[0m ┃" \
            "\n┠───────┼──────────┨" \
            "\n┃ \e[1mTotal\e[0m │ \e[1m$(printf '%-8d' $((tests_passed + tests_failed)))\e[0m ┃" \
            "\n┗━━━━━━━┷━━━━━━━━━━┛" 1>&2

    if [[ $tests_failed -gt 0 ]]
    then
        HAD_FAILURES=1
    fi
}


# Check that the necessary dependencies exist.
check_dependencies() {
    for dependency in "${DEPENDENCIES[@]}"
    do
        if [[ ! $(command -v "$dependency") ]]
        then
            echo -e "\e[1m\e[31mCannot run tests. Missing dependency: $dependency.\e[0m" 1>&2
            exit 1
        fi
    done
}

check_dependencies
run_unit_tests
echo "" 1>&2
run_baseline_tests

if [[ $HAD_FAILURES == 1 ]]
then
    exit 1
fi
