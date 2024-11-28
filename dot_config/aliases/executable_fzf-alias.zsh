#!/usr/bin/env zsh

# Color palette using ANSI 24-bit color
COLOR_HEADER='\033[38;2;189;147;249m'     # Purple
COLOR_NAME='\033[38;2;80;250;123m'        # Green
COLOR_ARROW='\033[38;2;255;121;198m'      # Pink
COLOR_RESET='\033[0m'                     # Default
COLOR_CMD='\033[38;2;98;114;164m'         # Comment
COLOR_FUNC='\033[38;2;241;250;140m'       # Yellow

# Configuration
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/command-finder"
CACHE_FILE="$CONFIG_DIR/command_cache"

# Ensure the config directory exists
mkdir -p "$CONFIG_DIR"

# Command descriptions
typeset -A CMD_DESCRIPTIONS=(
    [ip]="IP info (Usage: ip [internal|external])"
    [ipw]="IP where (Usage: ipw [HOST])"
    [srun]="Run the command in a new screen window (Usage: srun [CMD])"
    [proxy]="Proxy settings (Usage: proxy [on|off])"
    [czsync]="Execute the complete chezmoi sync workflow"
    [sattach]="Smart screen session management tool"
    [clean_ds]="Recursively clean .DS_Store (Usage: clean_ds [PATH])"
    [portcheck]="Check host port (Usage: portcheck [HOST] [PORT])"
    [install_missing]="Install missing packages using Homebrew"
)

# Check dependencies
_check_dependencies() {
    local deps=("fzf" "awk")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            echo "${COLOR_ARROW}Error:${COLOR_RESET} $dep is required but not installed." >&2
            return 1
        fi
    done
}

# Generate cache with colorized content
_generate_command_cache() {
    {
        echo "${COLOR_CMD}╔═════════════════════════════════════════════ 󰘓 Aliases ════════════════════════════════════════════════╗${COLOR_RESET}"
        alias | awk -v name_color="$COLOR_NAME" -v arrow_color="$COLOR_ARROW" -v cmd_color="$COLOR_RESET" '
        {
        eq_pos = index($0, "=")
        alias_name = substr($0, 1, eq_pos - 1)
        sub(/^alias /, "", alias_name)
        alias_value = substr($0, eq_pos + 1)
        gsub(/^[ \t"'\'']+|[ \t"'\'']+$/, "", alias_value)
        printf("%s%-20s%s ➜ %s%s\n", name_color, alias_name, arrow_color, cmd_color, alias_value)
        }'
        echo "${COLOR_CMD}╚════════════════════════════════════════════════════════════════════════════════════════════════════════╝${COLOR_RESET}"

        echo "${COLOR_CMD}╔═════════════════════════════════════════════ 󰊕 Functions ══════════════════════════════════════════════╗${COLOR_RESET}"
        for key in "${(@k)CMD_DESCRIPTIONS}"; do
            printf "${COLOR_FUNC}%-20s${COLOR_ARROW} ➜ ${COLOR_RESET}%s\n" "$key" "${CMD_DESCRIPTIONS[$key]}"
        done
        echo "${COLOR_CMD}╚════════════════════════════════════════════════════════════════════════════════════════════════════════╝${COLOR_RESET}"
    } > "$CACHE_FILE"
}

# Main command finder
command_finder() {
    _check_dependencies || return 1
    _generate_command_cache 

    local tmp_file="$(mktemp)"
    trap "rm -f $tmp_file" EXIT

    local header_text="
    ╭───────────────────────────────────────────────────────────╮
    │ Controls │ ENTER: input command • CTRL-E: show definition │
    ╰───────────────────────────────────────────────────────────╯"

    cat "$CACHE_FILE" | fzf \
        --ansi \
        --cycle \
        --reverse \
        --border double \
        --prompt ' 󰘧 ' \
        --pointer ' 󰮺' \
        --marker ' 󰄲' \
        --header "$header_text" \
        --preview 'echo {}' \
        --preview-window "${PREVIEW_WINDOW_SIZE}:hidden" \
        --bind "ctrl-e:execute(echo -n {3..} | tr -d '\n' > $tmp_file)+abort" \
        --bind "enter:execute(echo -n {1} > $tmp_file)+abort" \
        --color='bg+:#44475a,fg+:#f8f8f2,hl:#50fa7b,hl+:#50fa7b,border:#6272a4' \
        --color='header:#bd93f9,info:#50fa7b,prompt:#bd93f9,pointer:#ff79c6,marker:#ff79c6'

    if [[ -s "$tmp_file" ]]; then
        local result
        result=$(<"$tmp_file")
        print -z "$result"
    fi
}

# Run the command finder
command_finder
