cf::require() {
    for cmd in "$@"; do
        command -v "$cmd" >/dev/null || {
            print -P "%F{196}Missing dependency:%f $cmd"
            return 1
        }
    done
}

cf::strip_ansi() {
    sed 's/\x1b\[[0-9;]*m//g'
}

cf::display_width() {
    local str="$1"
    print ${#str}
}