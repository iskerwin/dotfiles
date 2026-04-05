command_finder() {
    emulate -L zsh
    setopt extendedglob

    cf::require fzf || return 1

    local CF_HISTORY="$HOME/.config/command-finder/history"
    mkdir -p "${CF_HISTORY:h}"

    cf::get_widths

    local history_block

    if [[ -f "$CF_HISTORY" ]]; then
        history_block=$(
            cf::rank_history < "$CF_HISTORY" |
            sort -nr |
            while IFS=$'\t' read -r count cmd; do
                cf::format_row "$cmd" "history" "used $count times" 1
            done
        )
    fi

    local result

    local input

    input=$(
        {
            cf::header "󰋚 History" "$CF_COLOR_HEADER_HISTORY"
            print "$history_block" | sort -t $'\t' -k1,1n -k2,2

            cf::header " Aliases" "$CF_COLOR_HEADER_ALIAS"
            cf::parse_aliases

            cf::header "󰊕 Functions" "$CF_COLOR_HEADER_FUNC"
            cf::parse_functions
        }
    )

    result=$(print -r -- "$input" | cf::fzf)

    [[ -z "$result" ]] && return
    [[ "$result" == __HEADER__* ]] && return

    local cmd_name
    cmd_name=${result%%$'\t'*}
    cmd_name=${cmd_name//$'\033'[\[\(][0-9\;]##[a-zA-Z]/}
    cmd_name=${cmd_name%%[[:space:]]#}

    echo "$cmd_name" >> "$CF_HISTORY"
    tail -n 1000 "$CF_HISTORY" > "$CF_HISTORY.tmp" && command mv -f "$CF_HISTORY.tmp" "$CF_HISTORY"
z
    if [[ -n $ZLE ]]; then
        LBUFFER+="$cmd_name"
    else
        print -z "$cmd_name"
    fi
}