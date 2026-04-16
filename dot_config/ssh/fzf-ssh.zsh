# ══════════════════════════════════════════════
# ssh-fzf.plugin.zsh
# FZF-powered SSH host picker with live preview
#
# Usage:
#   ssh <Tab>          — trigger fzf picker via zsh completion
#   sshf [query]       — open picker directly, optional initial query
#
# SSH config annotations (optional):
#   #_Desc  your description here
#   #_Tags  prod,backend,aws
#
# Keybindings in picker:
#   Enter      — connect
#   Ctrl-E     — edit ~/.ssh/config
#   Ctrl-Y     — copy alias to clipboard
#   Ctrl-T     — open new tab/window (if supported by terminal)
#   ?          — toggle preview pane
# ══════════════════════════════════════════════

# ══════════════════════════════════════════════
# Guard: dependencies
# ══════════════════════════════════════════════
if ! command -v fzf >/dev/null 2>&1; then
    echo "[ssh-fzf] fzf not found — plugin disabled" >&2
    return 1
fi

# ══════════════════════════════════════════════
# Configuration (override in ~/.zshrc before sourcing this plugin)
# ══════════════════════════════════════════════
: "${SSH_FZF_DIR:=$HOME/.ssh}"
: "${SSH_FZF_CONFIG:=$SSH_FZF_DIR/config}"
: "${SSH_FZF_KNOWN_HOSTS:=$SSH_FZF_DIR/known_hosts}"
: "${SSH_FZF_CONNECT_TIMEOUT:=3}"
: "${SSH_FZF_PREVIEW_WIDTH:=55}"

# Clipboard command — auto-detect, override with SSH_FZF_CLIP
if [[ -z "${SSH_FZF_CLIP}" ]]; then
    if command -v pbcopy  >/dev/null 2>&1; then SSH_FZF_CLIP="pbcopy"
    elif command -v xclip >/dev/null 2>&1; then SSH_FZF_CLIP="xclip -selection clipboard"
    elif command -v xsel  >/dev/null 2>&1; then SSH_FZF_CLIP="xsel --clipboard --input"
    elif command -v wl-copy >/dev/null 2>&1; then SSH_FZF_CLIP="wl-copy"
    else SSH_FZF_CLIP="cat"
    fi
fi

# ══════════════════════════════════════════════
# Environment bootstrap
# ══════════════════════════════════════════════
_ssh_fzf_setup() {
    [[ ! -d "$SSH_FZF_DIR" ]]         && mkdir -p "$SSH_FZF_DIR"         && chmod 700 "$SSH_FZF_DIR"
    [[ ! -f "$SSH_FZF_CONFIG" ]]      && touch    "$SSH_FZF_CONFIG"      && chmod 600 "$SSH_FZF_CONFIG"
    [[ ! -f "$SSH_FZF_KNOWN_HOSTS" ]] && touch    "$SSH_FZF_KNOWN_HOSTS" && chmod 644 "$SSH_FZF_KNOWN_HOSTS"

    if ! ssh -G localhost >/dev/null 2>&1; then
        print -P "%F{yellow}[ssh-fzf] warning: ssh config parse error%f" >&2
    fi
}

_ssh_fzf_setup

# ══════════════════════════════════════════════
# Host listing
# Outputs tab-separated: alias  hostname  port  user  desc  tags
# ══════════════════════════════════════════════
_ssh_fzf_list_hosts() {
    [[ ! -r "$SSH_FZF_CONFIG" ]] && return 1

    awk '
    BEGIN { IGNORECASE=1; RS=""; FS="\n" }
    {
        alias=hostname=user=port=desc=tags=""
        for (i=1; i<=NF; i++) {
            line=$i
            gsub(/^[ \t]+|[ \t]+$/, "", line)

            if      (line ~ /^Host [^*?]/)      { alias    = substr(line,6);  gsub(/^[ \t]+|[ \t]+$/, "", alias) }
            else if (line ~ /^HostName /)        { hostname = substr(line,10); gsub(/^[ \t]+|[ \t]+$/, "", hostname) }
            else if (line ~ /^User /)            { user     = substr(line,6);  gsub(/^[ \t]+|[ \t]+$/, "", user) }
            else if (line ~ /^Port /)            { port     = substr(line,6);  gsub(/^[ \t]+|[ \t]+$/, "", port) }
            else if (line ~ /^#_Desc /)          { desc     = substr(line,8);  gsub(/^[ \t]+|[ \t]+$/, "", desc) }
            else if (line ~ /^#_Tags /)          { tags     = substr(line,8);  gsub(/^[ \t]+|[ \t]+$/, "", tags) }
        }

        if (alias && hostname) {
            printf "%s\t%s\t%s\t%s\t%s\t%s\n",
                alias,
                hostname,
                (port  ? port  : "22"),
                (user  ? user  : "-"),
                (desc  ? desc  : ""),
                (tags  ? tags  : "")
        }
    }
    ' "$SSH_FZF_CONFIG" 2>/dev/null
}

# Format host list for fzf display
# Outputs aligned columns: ALIAS  HOST  PORT  USER  TAGS  DESC
_ssh_fzf_format_hosts() {
    _ssh_fzf_list_hosts | awk -F'\t' '
    BEGIN {
        # Header row (will be hidden by --header-lines=1 but used by column)
        printf "%-20s  %-26s  %-6s  %-12s  %-16s  %s\n",
            "ALIAS", "HOST", "PORT", "USER", "TAGS", "DESC"
    }
    {
        printf "%-20s  %-26s  %-6s  %-12s  %-16s  %s\n",
            $1, $2, $3, $4, $6, $5
    }'
}

# ══════════════════════════════════════════════
# Preview script (runs inside fzf, executed as a separate shell)
# ══════════════════════════════════════════════
# We write this to a tempfile so it can be sourced by fzf --preview
# and avoids the quoting nightmare of inline heredocs.
_ssh_fzf_write_preview() {
    local preview_script="${TMPDIR:-/tmp}/ssh-fzf-preview-$$.sh"

    cat > "$preview_script" << 'PREVIEW_EOF'
#!/usr/bin/env bash

# ── Dracula-inspired ANSI palette ────────────────────────────────────────────
R=$'\033[0m'
BOLD=$'\033[1m'
C_PURPLE=$'\033[38;2;189;147;249m'
C_PINK=$'\033[38;2;255;121;198m'
C_YELLOW=$'\033[38;2;241;250;140m'
C_GREEN=$'\033[38;2;80;250;123m'
C_RED=$'\033[38;2;255;85;85m'
C_ORANGE=$'\033[38;2;255;184;108m'
C_CYAN=$'\033[38;2;139;233;253m'
C_DIM=$'\033[38;2;98;114;164m'

ICON_OK="${C_GREEN}✓${R}"
ICON_WARN="${C_ORANGE}!${R}"
ICON_ERR="${C_RED}✗${R}"
ICON_INFO="${C_CYAN}ℹ${R}"

# ── Helpers ───────────────────────────────────────────────────────────────────
section() { printf "\n${C_PINK}%s${R}\n${C_DIM}%s${R}\n" "$1" "─────────────────────────────────────────────"; }
kv()      { printf "  ${C_CYAN}%-10s${R} ${C_YELLOW}%s${R}\n" "$1" "$2"; }

# ── Parse fzf selection (first field = alias) ─────────────────────────────────
alias_name=$(echo "$@" | awk '{print $1}')
[[ -z "$alias_name" ]] && exit 0

# ── Load config via ssh -G (canonical, handles Include etc.) ─────────────────
ssh_config=$(ssh -G "$alias_name" 2>/dev/null)
hostname=$(awk '/^hostname /  {print $2; exit}' <<< "$ssh_config")
user=$(    awk '/^user /      {print $2; exit}' <<< "$ssh_config")
port=$(    awk '/^port /      {print $2; exit}' <<< "$ssh_config")
keyfile=$( awk '/^identityfile / {print $2; exit}' <<< "$ssh_config")

[[ -z "$hostname" ]] && hostname="$alias_name"
[[ -z "$port"     ]] && port=22

# Load annotations from raw config
config_file="${SSH_FZF_CONFIG:-$HOME/.ssh/config}"
desc=$(awk -v h="$alias_name" '
    $1=="Host" { in_block=($2==h) }
    in_block && /^[[:space:]]*#_Desc[[:space:]]/ {
        sub(/^[[:space:]]*#_Desc[[:space:]]*/, ""); print; exit
    }
' "$config_file" 2>/dev/null)

tags=$(awk -v h="$alias_name" '
    $1=="Host" { in_block=($2==h) }
    in_block && /^[[:space:]]*#_Tags[[:space:]]/ {
        sub(/^[[:space:]]*#_Tags[[:space:]]*/, ""); print; exit
    }
' "$config_file" 2>/dev/null)

# ── Section: Summary ──────────────────────────────────────────────────────────
section "󰋼 SUMMARY"
kv "alias"    "$alias_name"
kv "hostname" "$hostname"
kv "user"     "${user:--}"
kv "port"     "$port"
[[ -n "$keyfile" ]] && kv "key"  "$keyfile"
[[ -n "$tags"    ]] && kv "tags" "$tags"
[[ -n "$desc"    ]] && printf "\n  ${C_DIM}%s${R}\n" "$desc"

# ── Section: Connectivity ─────────────────────────────────────────────────────
section "󱘖 CONNECTIVITY"

# Cross-platform nc timeout: macOS uses -G, Linux uses -w
_nc_check() {
    local host=$1 port=$2 timeout=${3:-3}
    nc -z -w "$timeout" "$host" "$port" >/dev/null 2>&1 ||
    nc -z -G "$timeout" "$host" "$port" >/dev/null 2>&1
}

if _nc_check "$hostname" "$port" "${SSH_FZF_CONNECT_TIMEOUT:-3}"; then
    printf "  %s Port %s reachable\n" "$ICON_OK" "$port"

    # Grab banner (1-second read)
    banner=$(timeout 1s bash -c "exec 3<>/dev/tcp/$hostname/$port && cat <&3" 2>/dev/null | head -1)
    if [[ "$banner" == SSH-* ]]; then
        version=$(echo "$banner" | cut -d'-' -f1-2)
        printf "  %s Server: ${C_YELLOW}%s${R}\n" "$ICON_INFO" "$version"
    fi
else
    printf "  %s Cannot reach %s:%s\n" "$ICON_ERR" "$hostname" "$port"

    # DNS fallback
    if command -v dig >/dev/null 2>&1; then
        resolved=$(dig +short "$hostname" 2>/dev/null | head -1)
    elif command -v host >/dev/null 2>&1; then
        resolved=$(host "$hostname" 2>/dev/null | awk '/has address/{print $4; exit}')
    fi

    if [[ -n "$resolved" ]]; then
        printf "  %s DNS OK → ${C_DIM}%s${R}\n" "$ICON_WARN" "$resolved"
        printf "  %s Port %s appears closed or filtered\n" "$ICON_ERR" "$port"
    else
        printf "  %s DNS resolution failed\n" "$ICON_ERR"
    fi
fi

# ── Section: Identity Key ─────────────────────────────────────────────────────
if [[ -n "$keyfile" ]]; then
    section " IDENTITY KEY"
    expanded="${keyfile/#\~/$HOME}"

    if [[ ! -f "$expanded" ]]; then
        printf "  %s Key not found: ${C_YELLOW}%s${R}\n" "$ICON_ERR" "$keyfile"
        for k in id_ed25519 id_ecdsa id_rsa; do
            [[ -f "$HOME/.ssh/$k" ]] && printf "  %s Fallback available: ${C_DIM}~/.ssh/%s${R}\n" "$ICON_INFO" "$k"
        done
    else
        # Permissions — cross-platform stat
        if perms=$(stat -c "%a" "$expanded" 2>/dev/null) || perms=$(stat -f "%Lp" "$expanded" 2>/dev/null); then
            if [[ "$perms" == "600" ]]; then
                printf "  %s Permissions ${C_GREEN}600${R}\n" "$ICON_OK"
            else
                printf "  %s Permissions ${C_RED}%s${R} (want 600) — fix: chmod 600 %s\n" "$ICON_ERR" "$perms" "$expanded"
            fi
        fi

        # Key info
        if key_info=$(ssh-keygen -l -f "$expanded" 2>/dev/null); then
            bits=$(awk '{print $1}' <<< "$key_info")
            fp=$(  awk '{print $2}' <<< "$key_info")
            ktype=$(grep -o '([^)]*)' <<< "$key_info" | head -1)
            printf "  %s Valid key  ${C_DIM}%s bits %s %s${R}\n" "$ICON_OK" "$bits" "$ktype" "$fp"
        else
            printf "  %s Could not read key metadata\n" "$ICON_WARN"
        fi
    fi
fi

# ── Section: Authentication ───────────────────────────────────────────────────
section " AUTH"

TO="-o ConnectTimeout=${SSH_FZF_CONNECT_TIMEOUT:-3}"
BM="-o BatchMode=yes"

if [[ "$hostname" == "github.com" ]]; then
    out=$(ssh -T git@github.com $TO 2>&1)
    if grep -q "successfully authenticated" <<< "$out"; then
        printf "  %s GitHub auth OK\n" "$ICON_OK"
    else
        printf "  %s GitHub auth failed\n" "$ICON_ERR"
    fi
    printf "  ${C_DIM}%s${R}\n" "$out"
else
    if ssh $BM $TO "$alias_name" true 2>/dev/null; then
        printf "  %s Passwordless auth OK\n" "$ICON_OK"

        # Sudo check
        if ssh $BM $TO "$alias_name" "sudo -n true" 2>/dev/null; then
            printf "  %s Passwordless sudo available\n" "$ICON_OK"
        fi

        # Remote uname
        uname_out=$(ssh $BM $TO "$alias_name" "uname -srm" 2>/dev/null)
        [[ -n "$uname_out" ]] && printf "  %s Remote OS: ${C_YELLOW}%s${R}\n" "$ICON_INFO" "$uname_out"
    else
        printf "  %s Key auth not available\n" "$ICON_WARN"

        # Show what auth methods the server accepts
        banner_out=$(ssh $TO -o PreferredAuthentications=none "$alias_name" 2>&1)
        methods=$(grep -i "authentication methods" <<< "$banner_out" | cut -d: -f2-)
        [[ -n "$methods" ]] && printf "  %s Accepted:%s\n" "$ICON_INFO" "$methods"
    fi
fi

printf "\n"
PREVIEW_EOF

    chmod +x "$preview_script"
    echo "$preview_script"
}

# ══════════════════════════════════════════════
# Core picker
# ══════════════════════════════════════════════
_ssh_fzf_picker() {
    local query="${1:-}"
    local preview_script
    preview_script=$(_ssh_fzf_write_preview)

    # Cleanup on exit
    trap "rm -f '$preview_script'" EXIT INT

    local selected
    selected=$(
        _ssh_fzf_format_hosts | fzf \
            --ansi \
            --border=rounded \
            --cycle \
            --height=100% \
            --reverse \
            --header-lines=1 \
            --header=$'  \033[38;2;189;147;249mCtrl-E\033[0m edit config  \033[38;2;189;147;249mCtrl-Y\033[0m copy  \033[38;2;189;147;249m?\033[0m toggle preview' \
            --prompt="  ssh › " \
            --pointer="▶" \
            --marker="✓" \
            --query="$query" \
            --bind="ctrl-e:execute(${EDITOR:-vi} '$SSH_FZF_CONFIG' </dev/tty >/dev/tty)" \
            --bind="ctrl-y:execute-silent(echo {1} | ${SSH_FZF_CLIP})" \
            --bind="?:toggle-preview" \
            --preview="SSH_FZF_CONFIG='$SSH_FZF_CONFIG' SSH_FZF_CONNECT_TIMEOUT='$SSH_FZF_CONNECT_TIMEOUT' bash '$preview_script' {}" \
            --preview-window="right:${SSH_FZF_PREVIEW_WIDTH}%:wrap" \
            2>/dev/tty
    )

    rm -f "$preview_script"
    trap - EXIT INT

    [[ -n "$selected" ]] && awk '{print $1}' <<< "$selected"
}

# ══════════════════════════════════════════════
# Public command: sshf [query]
# ══════════════════════════════════════════════
sshf() {
    local host
    host=$(_ssh_fzf_picker "$*")
    [[ -n "$host" ]] && ssh "$host"
}

# ══════════════════════════════════════════════
# FZF tab completion integration
# ══════════════════════════════════════════════
_fzf_complete_ssh() {
    local preview_script
    preview_script=$(_ssh_fzf_write_preview)
    trap "rm -f '$preview_script'" EXIT INT

    _fzf_complete \
        --ansi \
        --border=rounded \
        --cycle \
        --height=100% \
        --reverse \
        --header-lines=1 \
        --header=$'  \033[38;2;189;147;249mCtrl-E\033[0m edit config  \033[38;2;189;147;249mCtrl-Y\033[0m copy  \033[38;2;189;147;249m?\033[0m toggle preview' \
        --prompt="  ssh › " \
        --pointer="▶" \
        --marker="✓" \
        --bind="ctrl-e:execute(${EDITOR:-vi} '$SSH_FZF_CONFIG' </dev/tty >/dev/tty)" \
        --bind="ctrl-y:execute-silent(echo {1} | ${SSH_FZF_CLIP})" \
        --bind="?:toggle-preview" \
        --preview="SSH_FZF_CONFIG='$SSH_FZF_CONFIG' SSH_FZF_CONNECT_TIMEOUT='$SSH_FZF_CONNECT_TIMEOUT' bash '$preview_script' {}" \
        --preview-window="right:${SSH_FZF_PREVIEW_WIDTH}%:wrap" \
        -- "$@" < <(_ssh_fzf_format_hosts)

    rm -f "$preview_script"
    trap - EXIT INT
}

_fzf_complete_ssh_post() {
    awk '{print $1}'
}