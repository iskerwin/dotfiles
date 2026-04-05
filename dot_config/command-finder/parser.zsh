# ---------- theme ----------
CF_COLOR_ALIAS=$'\033[38;2;255;121;198m'
CF_COLOR_FUNC=$'\033[38;2;80;250;123m'
CF_COLOR_NAME=$'\033[38;2;139;233;253m'
CF_COLOR_HEADER=$'\033[38;2;189;147;249m'
CF_COLOR_ARROW=$'\033[38;2;189;147;249m'
CF_COLOR_RESET=$'\033[0m'
CF_ARROW="→"
CF_COLOR_HEADER_ALIAS=$'\033[38;2;255;121;198m'   # 粉
CF_COLOR_HEADER_FUNC=$'\033[38;2;80;250;123m'     # 绿
CF_COLOR_HEADER_HISTORY=$'\033[38;2;139;233;253m' # 蓝

# ---------- layout ----------
cf::get_widths() {
    local term_width=${COLUMNS:-80}

    typeset -g CF_TYPE_WIDTH=10
    typeset -g CF_NAME_WIDTH=$(( term_width / 4 ))

    (( CF_NAME_WIDTH > 30 )) && CF_NAME_WIDTH=30
    (( CF_NAME_WIDTH < 12 )) && CF_NAME_WIDTH=12

    typeset -g CF_DESC_WIDTH=$(( term_width - CF_NAME_WIDTH - CF_TYPE_WIDTH - 10 ))
    (( CF_DESC_WIDTH < 20 )) && CF_DESC_WIDTH=20
}

cf::truncate() {
    local str="$1"
    local max="$2"

    (( ${#str} > max )) && print "${str[1,$((max-1))]}…" || print "$str"
}

cf::pad() {
    local str="$1"
    local width="$2"

    printf "%-${width}s" "$str"
}

# ---------- history ranking ----------
cf::rank_history() {
    awk '{count[$0]++} END {for (cmd in count) print count[cmd]"\t"cmd}'
}

# ---------- format ----------
cf::format_row() {
    local name="$1"
    local type="$2"
    local desc="$3"
    local weight="$4"

    local type_color

    case "$type" in
        alias) type_color="$CF_COLOR_ALIAS" ;;
        function) type_color="$CF_COLOR_FUNC" ;;
        history) type_color="$CF_COLOR_NAME" ;;
    esac

    name=$(cf::truncate "$name" $CF_NAME_WIDTH)
    desc=$(cf::truncate "$desc" $CF_DESC_WIDTH)

    name=$(cf::pad "$name" $CF_NAME_WIDTH)
    type=$(cf::pad "$type" $CF_TYPE_WIDTH)

    printf "%s\t%s\t%s\t%s\n" \
        "${CF_COLOR_NAME}${name}${CF_COLOR_RESET}" \
        "${type_color}${type}${CF_COLOR_RESET}" \
        "${CF_COLOR_ARROW}${CF_ARROW}${CF_COLOR_RESET}" \
        "$desc"
}

cf::header() {
    local title="$1"
    local color="$2"

    local term_width=${COLUMNS:-80}
    local clean_title="${title//\033\[*m/}"
    local title_len=${#clean_title}

    local line_char="═"

    local padding=$(( term_width - title_len - 2 ))
    (( padding < 0 )) && padding=0

    local left=$(( padding / 2 ))
    local right=$(( padding - left ))

    local left_line=$(printf "%*s" "$left" "" | tr ' ' "$line_char")
    local right_line=$(printf "%*s" "$right" "" | tr ' ' "$line_char")

    printf "%s%s %s %s%s\n" \
        "$color" \
        "$left_line" \
        "$title" \
        "$right_line" \
        "$CF_COLOR_RESET"
}

# ---------- parsers ----------
cf::parse_aliases() {

    while IFS='=' read -r name value; do
        name=${name#alias }
        value=${value//\'/}
        value=${value//$'\n'/ }

        cf::format_row "$name" "alias" "$value" 2
    done < <(alias)
}

cf::parse_functions() {
    local file="$HOME/.config/aliases/functions.zsh"
    [[ -f "$file" ]] || return

    local last_comment=""

    while IFS= read -r line; do
        if [[ "$line" == \#* ]]; then
            last_comment="${line#\# }"
            continue
        fi

        if [[ "$line" == (#b)([a-zA-Z0-9_]##)'()'* ]]; then
            local fn="${match[1]}"
            local desc="${last_comment:-No description}"

            cf::format_row "$fn" "function" "$desc" 3
            last_comment=""
        fi
    done < "$file"
}