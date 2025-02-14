#!/usr/bin/env bash


TMP_DIR=/tmp
DEPENDENCIES=(sed realpath curl python3)
TEST_SERVER_PORT=4444

MRBONES="$(realpath .)/mrbones.sh"
TESTS_DIR="$(realpath .)/tests"
HAD_FAILURES=0


run_tests() {
    tests_passed=0
    tests_failed=0

    for test_dir in $(ls -d "$TESTS_DIR"/*)
    do
        echo -en "\e[1mRunning\e[0m \e[38;5;244m$test_dir\e[0m \e[1m...\e[0m " 1>&2

        baseline=$(cat "$test_dir/baseline.err" 2>/dev/null || echo "")

        # Replace $TEST_DIR with the actual test directory in baselines.
        test_dir_escaped_slashes="$(echo "$test_dir" | sed -E 's/\//\\\//g')"
        baseline=$(echo "$baseline" | sed -E "s/\\\$TEST_DIR/$test_dir_escaped_slashes/g")
        actual_output="$(bash "$MRBONES" --verbose --color never "$test_dir/src" 2>&1)"
        output_diff="$(diff --color=always <(echo "$baseline") <(echo "$actual_output"))"
        if [[ "$output_diff" != "" ]]
        then
            echo -e "\e[1m\e[31mFAIL\e[0m" 1>&2
            tests_failed=$((tests_failed + 1))

            echo -e "  \e[1m\e[91mbaseline\e[39m does not match \e[32mactual output\e[39m:\e[0m"
            echo "$output_diff" 1>&2
            echo "" 1>&2
            continue
        fi

        # Run curl tests.
        curl_tests_passed=1
        # We need to spin up a server first.
        python3 -m http.server $TEST_SERVER_PORT -d "$test_dir/src/_site" 1>/dev/null 2>&1 &
        # Capture its PID so we can stop it later.
        server_pid="$!"
        # Wait for the server to start up.
        sleep 0.5
        # Now, run the requests with curl and check against the baseline.
        for curl_baseline in $(ls "$test_dir"/*.curl)
        do
            request_baseline="$(cat $curl_baseline)"
            request_url="$(basename $curl_baseline | sed -E -e 's/\.curl//g' -e 's/__/\//g' )"
            request_actual_output=$( \
                curl http://localhost:$TEST_SERVER_PORT/"$request_url" 2>/dev/null \
            )
            request_diff="$( \
                diff --color=always <(echo "$request_baseline") <(echo "$request_actual_output") \
            )"
            if [[ "$request_diff" != "" ]]
            then
                echo -e "\e[1m\e[31mFAIL\e[0m" 1>&2
                tests_failed=$((tests_failed + 1))

                echo -e "  \e[1m/$request_url: \e[91mrequest baseline\e[39m does not match" \
                    "\e[32mactual output\e[39m:\e[0m"
                echo "$request_diff" 1>&2
                echo "" 1>&2
                curl_tests_passed=0
                break
            fi
        done
        # We're done with the curl tests, so we should terminate the server.
        kill "$server_pid"
        wait "$server_pid"

        if [[ $curl_tests_passed == 0 ]]
        then
            continue
        fi

        echo -e "\e[1m\e[32mPASS\e[0m" 1>&2
        tests_passed=$((tests_passed + 1))
        echo "" 1>&2

        # Clean up build artifacts.
        rm -rf "$test_dir/src/_site"
    done

    echo -e "┏━━━━━━━━━━━━━━━━━━┓" \
            "\n┃     \e[1mSUMMARY\e[0m      ┃" \
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
            echo -e "\e[1m\e[31mCannot run tests. Missing dependency: $dependency.\e[0m" 1>&2
            exit 1
        fi
    done
}

check_dependencies
run_tests

if [[ $HAD_FAILURES == 1 ]]
then
    exit 1
fi
