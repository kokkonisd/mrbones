fail() {
    echo -e "\e[1m\e[31mTEST FAIL: $*\e[0m" 1>&2
    exit 1
}
