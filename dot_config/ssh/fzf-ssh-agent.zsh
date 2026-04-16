#!/usr/bin/env zsh
# ══════════════════════════════════════════════
# ssha.zsh — SSH Agent Management Tool
# Usage: source ssha.zsh   (loads functions + alias into current shell)
#        ./ssha.zsh [cmd]  (direct run)
# Commands: start | stop | load | unload | list | menu | status | help
# ══════════════════════════════════════════════

# ══════════════════════════════════════════════
# Configuration
# ══════════════════════════════════════════════
SSH_KEY_DIR="${SSH_KEY_DIR:-$HOME/.ssh}"
SOCK_FILE="${TMPDIR:-/tmp}/ssh-agent-sock"
PID_FILE="${TMPDIR:-/tmp}/ssh-agent-pid"

# Temporary directory for fzf preview scripts; cleaned up on exit
_SSHA_PREVIEW_DIR=""

# ══════════════════════════════════════════════
# Colors
# ══════════════════════════════════════════════
_ssha_colors() {
    COLOR_HEADER=$'\033[1;35m'    # Bold Magenta/Purple
    COLOR_SUCCESS=$'\033[1;32m'   # Bold Green
    COLOR_WARNING=$'\033[1;33m'   # Bold Yellow
    COLOR_ERROR=$'\033[1;31m'     # Bold Red
    COLOR_INFO=$'\033[1;36m'      # Bold Cyan
    COLOR_DIM=$'\033[2m'          # Dim
    COLOR_RESET=$'\033[0m'
}
_ssha_colors   # initialise immediately

# ══════════════════════════════════════════════
# Utilities
# ══════════════════════════════════════════════
_ssha_sep()     { printf "${COLOR_HEADER}%s${COLOR_RESET}\n" "──────────────────────────────────────"; }
_ssha_section() { echo "${COLOR_HEADER}${1}${COLOR_RESET}"; _ssha_sep; }

# Portable stat: works on macOS and Linux
_ssha_perms() {
    if stat -f '%Lp' "$1" &>/dev/null; then
        stat -f '%Lp' "$1"          # macOS
    else
        stat -c '%a' "$1"           # GNU/Linux
    fi
}

_ssha_mtime() {
    if stat -f '%Sm' -t '%Y-%m-%d %H:%M:%S' "$1" &>/dev/null; then
        stat -f '%Sm' -t '%Y-%m-%d %H:%M:%S' "$1"   # macOS
    else
        stat -c '%y' "$1" | cut -d'.' -f1             # GNU/Linux
    fi
}

_ssha_filesize() {
    if stat -f '%z' "$1" &>/dev/null; then
        stat -f '%z' "$1"       # macOS
    else
        stat -c '%s' "$1"       # GNU/Linux
    fi
}

_ssha_format_size() {
    local -i size=$1 i=0
    local -a suffix=(B KB MB GB TB)
    while (( size > 1024 && i < ${#suffix} - 1 )); do
        (( size = size / 1024 ))
        (( i++ ))
    done
    echo "${size}${suffix[i+1]}"
}

_ssha_check_perms() {
    local p; p=$(_ssha_perms "$1")
    if [[ $p == 600 ]]; then
        echo "${COLOR_SUCCESS}OK (600)${COLOR_RESET}"
    else
        echo "${COLOR_ERROR}Warning ($p)${COLOR_RESET}"
    fi
}

# ══════════════════════════════════════════════
# Key Discovery
# ══════════════════════════════════════════════
_ssha_find_keys() {
    # Only files that contain a PRIVATE KEY header
    # Use -e to prevent grep from treating the leading dashes as option flags
    find "$SSH_KEY_DIR" -type f \
        ! -name '*.pub' \
        ! -name 'known_hosts*' \
        ! -name 'config' \
        ! -name '.DS_Store' \
        -exec grep -le 'BEGIN.*PRIVATE KEY' {} \;
}

_ssha_loaded_keys() {
    # Returns raw ssh-add -l output; exits 1 when agent has no keys / not running
    ssh-add -l 2>/dev/null
}

# Given a fingerprint, return the matching local private key path
_ssha_find_key_by_fp() {
    local target=$1 fp file
    while IFS= read -r file; do
        ssh-keygen -l -f "$file" &>/dev/null || continue
        fp=$(ssh-keygen -l -f "$file" | awk '{print $2}')
        [[ $fp == "$target" ]] && { echo "$file"; return 0; }
    done < <(_ssha_find_keys)
    return 1
}

# ══════════════════════════════════════════════
# Agent Management
# ══════════════════════════════════════════════
_ssha_agent_live() {
    # True when the current env points to a working agent
    [[ -n $SSH_AUTH_SOCK && -S $SSH_AUTH_SOCK ]] && ssh-add -l &>/dev/null
}

start_ssh_agent() {
    if _ssha_agent_live; then
        echo "${COLOR_WARNING}SSH agent already running (PID $SSH_AGENT_PID)${COLOR_RESET}"
        return 0
    fi

    # Try reconnecting to a previously persisted agent
    if [[ -f $SOCK_FILE && -f $PID_FILE ]]; then
        local s p
        s=$(< "$SOCK_FILE")
        p=$(< "$PID_FILE")
        if kill -0 "$p" 2>/dev/null; then
            export SSH_AUTH_SOCK=$s SSH_AGENT_PID=$p
            if ssh-add -l &>/dev/null; then
                echo "${COLOR_DIM}Reconnected to existing SSH agent (PID $p)${COLOR_RESET}"
                return 0
            fi
        fi
        rm -f "$SOCK_FILE" "$PID_FILE"
    fi

    local out
    out=$(ssh-agent -s) || { echo "${COLOR_ERROR}Failed to start SSH agent${COLOR_RESET}"; return 1; }
    eval "$out"
    echo "$SSH_AUTH_SOCK" > "$SOCK_FILE"
    echo "$SSH_AGENT_PID" > "$PID_FILE"
    chmod 600 "$SOCK_FILE" "$PID_FILE"
    echo "${COLOR_SUCCESS}Started SSH agent (PID $SSH_AGENT_PID)${COLOR_RESET}"
}

stop_ssh_agent() {
    local stopped=0

    if [[ -f $PID_FILE ]]; then
        local p; p=$(< "$PID_FILE")
        if kill -0 "$p" 2>/dev/null; then
            kill "$p" && (( stopped++ ))
        fi
        rm -f "$SOCK_FILE" "$PID_FILE"
    elif [[ -n $SSH_AGENT_PID ]] && kill -0 "$SSH_AGENT_PID" 2>/dev/null; then
        kill "$SSH_AGENT_PID" && (( stopped++ ))
    fi

    unset SSH_AUTH_SOCK SSH_AGENT_PID

    if (( stopped )); then
        echo "${COLOR_SUCCESS}SSH agent stopped${COLOR_RESET}"
    else
        echo "${COLOR_WARNING}No running SSH agent found${COLOR_RESET}"
    fi
}

get_agent_status() {
    _ssha_section "SSH Agent Status"
    if [[ -S $SSH_AUTH_SOCK ]]; then
        echo "${COLOR_SUCCESS}✓ Running${COLOR_RESET}"
        echo "${COLOR_INFO}PID:${COLOR_RESET}    $SSH_AGENT_PID"
        echo "${COLOR_INFO}Socket:${COLOR_RESET} ${COLOR_DIM}$(dirname "$SSH_AUTH_SOCK")/${COLOR_RESET}${COLOR_SUCCESS}$(basename "$SSH_AUTH_SOCK")${COLOR_RESET}"
        echo
        _ssha_section "Loaded Keys"
        local keys; keys=$(_ssha_loaded_keys)
        if [[ -n $keys ]]; then
            echo "$keys" | while read -r bits hash comment rest; do
                echo "${COLOR_SUCCESS}[$comment]${COLOR_RESET}"
                echo "  ${COLOR_DIM}Bits:${COLOR_RESET} $bits  ${COLOR_DIM}Hash:${COLOR_RESET} $hash  ${COLOR_DIM}Type:${COLOR_RESET} $rest"
            done
        else
            echo "${COLOR_WARNING}No keys loaded${COLOR_RESET}"
        fi
    else
        echo "${COLOR_ERROR}✗ Not running${COLOR_RESET}"
    fi
}

auto_start() {
    _ssha_agent_live && return 0
    echo "${COLOR_DIM}Auto-starting SSH agent...${COLOR_RESET}"
    start_ssh_agent
}

# ══════════════════════════════════════════════
# fzf Preview Scripts
# Written once to $_SSHA_PREVIEW_DIR; each script sources a tiny header
# instead of embedding color/function strings via eval.
# ══════════════════════════════════════════════

# The shared header sourced by every preview script
_ssha_write_header() {
    cat > "$_SSHA_PREVIEW_DIR/_header.zsh" <<'HEADER'
#!/usr/bin/env zsh
COLOR_HEADER=$'\033[1;35m'    # Bold Magenta/Purple — section titles
COLOR_SUCCESS=$'\033[1;32m'   # Bold Green          — [comment], ✓, Set
COLOR_WARNING=$'\033[1;33m'   # Bold Yellow         — warnings / notices
COLOR_ERROR=$'\033[1;31m'     # Bold Red            — errors
COLOR_INFO=$'\033[1;36m'      # Bold Cyan           — field labels
COLOR_DIM=$'\033[2m'          # Dim                 — field values
COLOR_RESET=$'\033[0m'

# Purple underline separator (matches screenshot)
sep() { printf "${COLOR_HEADER}%s${COLOR_RESET}\n" "──────────────────────────────────────"; }

# Section: bold purple title + underline
section() {
    echo "${COLOR_HEADER}${1}${COLOR_RESET}"
    sep
}

# Dim short separator between key blocks
key_sep() { echo "${COLOR_DIM}──────────────────────────────${COLOR_RESET}"; }

# Format one key block:
#   [comment]
#   Type: (ED25519)
#   Bits: 256
#   Hash: SHA256:...
#   ──────────────────────────────
format_key_info() {
    local bits=$1 hash=$2 comment=$3 type=$4
    echo "${COLOR_SUCCESS}[$comment]${COLOR_RESET}"
    [[ -n $type ]] && echo "${COLOR_DIM}Type:${COLOR_RESET} $type"
    echo "${COLOR_DIM}Bits:${COLOR_RESET} $bits"
    echo "${COLOR_DIM}Hash:${COLOR_RESET} $hash"
    key_sep
}

perms() {
    stat -f '%Lp' "$1" 2>/dev/null || stat -c '%a' "$1" 2>/dev/null
}
check_perms() {
    local p; p=$(perms "$1")
    [[ $p == 600 ]] \
        && echo "${COLOR_SUCCESS}OK (600)${COLOR_RESET}" \
        || echo "${COLOR_ERROR}Warning ($p)${COLOR_RESET}"
}
mtime() {
    stat -f '%Sm' -t '%Y-%m-%d %H:%M:%S' "$1" 2>/dev/null \
        || stat -c '%y' "$1" 2>/dev/null | cut -d'.' -f1
}
filesize() {
    stat -f '%z' "$1" 2>/dev/null || stat -c '%s' "$1" 2>/dev/null
}
fmt_size() {
    local -i sz=$1 i=0
    local -a sfx=(B KB MB GB)
    while (( sz > 1024 && i < 3 )); do (( sz/=1024, i++ )); done
    if (( i == 0 )); then
        echo "${sz}B"
    else
        printf "%.2f%s\n" "$sz" "${sfx[i+1]}"
    fi
}
HEADER
}

# Preview: local private key file
_ssha_write_key_preview() {
    cat > "$_SSHA_PREVIEW_DIR/key_preview.zsh" <<'SCRIPT'
#!/usr/bin/env zsh
source "${0:h}/_header.zsh"
key=$1

[[ -f $key ]] || { section " Error"; echo "${COLOR_ERROR}File not found${COLOR_RESET}"; exit 1; }

section " Key Information"
info=$(ssh-keygen -l -f "$key" 2>/dev/null) || {
    echo "${COLOR_ERROR}Cannot read key${COLOR_RESET}"; exit 1
}
bits=${${(z)info}[1]}
fp=${${(z)info}[2]}
comment=${${(z)info}[3]}
type=${${(z)info}[4,-1]}

echo "${COLOR_INFO}Type:${COLOR_RESET}        $type"
echo "${COLOR_INFO}Bits:${COLOR_RESET}        $bits"
echo "${COLOR_INFO}Created:${COLOR_RESET}     $(mtime "$key")"
echo "${COLOR_INFO}Comment:${COLOR_RESET}     $comment"
echo "${COLOR_INFO}Fingerprint:${COLOR_RESET} $fp"
echo "${COLOR_INFO}Permissions:${COLOR_RESET} $(check_perms "$key")"

if [[ -f ${key}.pub ]]; then
    echo
    section "󱆄 Public Key"
    pub=$(< "${key}.pub")
    echo "${COLOR_INFO}Type:${COLOR_RESET}    ${${(z)pub}[1]}"
    echo "${COLOR_INFO}Comment:${COLOR_RESET} ${${(z)pub}[-1]}"
    echo
    echo "${COLOR_SUCCESS}Full Public Key:${COLOR_RESET}"
    echo "$pub"
fi
SCRIPT
    chmod +x "$_SSHA_PREVIEW_DIR/key_preview.zsh"
}

# Preview: entry from ssh-add -l (bits fp comment [type])
_ssha_write_loaded_preview() {
    cat > "$_SSHA_PREVIEW_DIR/loaded_preview.zsh" <<'SCRIPT'
#!/usr/bin/env zsh
source "${0:h}/_header.zsh"
line="$*"
bits=${${(z)line}[1]}
fp=${${(z)line}[2]}
comment=${${(z)line}[3]}
type=${${(z)line}[4,-1]}

section " Loaded Key Details"
format_key_info "$bits" "$fp" "$comment" "$type"

echo
section "󰈔 Local Key File"
found=0
while IFS= read -r f; do
    [[ -f $f ]] && ssh-keygen -l -f "$f" &>/dev/null || continue
    kfp=$(ssh-keygen -l -f "$f" | awk '{print $2}')
    if [[ $fp == $kfp ]]; then
        created=$(mtime "$f")
        echo "${COLOR_INFO}Path:${COLOR_RESET}        $f"
        echo "${COLOR_INFO}Created:${COLOR_RESET}     $created"
        echo "${COLOR_INFO}Size:${COLOR_RESET}        $(fmt_size $(filesize "$f"))"
        echo "${COLOR_INFO}Permissions:${COLOR_RESET} $(check_perms "$f")"
        if [[ -f ${f}.pub ]]; then
            echo
            echo "${COLOR_INFO}󱆄 Public Key:${COLOR_RESET}"
            cat "${f}.pub"
        fi
        found=1
        break
    fi
done < <(find ~/.ssh -type f ! -name '*.pub' ! -name 'known_hosts*' ! -name 'config' \
         -exec grep -le 'BEGIN.*PRIVATE KEY' {} \;)
(( found )) || echo "${COLOR_WARNING}No matching local file found${COLOR_RESET}"
SCRIPT
    chmod +x "$_SSHA_PREVIEW_DIR/loaded_preview.zsh"
}

# Preview: main menu items
_ssha_write_menu_preview() {
    cat > "$_SSHA_PREVIEW_DIR/menu_preview.zsh" <<'SCRIPT'
#!/usr/bin/env zsh
source "${0:h}/_header.zsh"
selected=$1
sock=$2
pid=$3

print_agent() {
    section "󰫢 SSH Agent Status"
    if [[ -S $sock ]]; then
        echo "${COLOR_SUCCESS} Agent is running${COLOR_RESET}"
        echo
        echo "${COLOR_INFO}Process:${COLOR_RESET}"
        echo "${COLOR_DIM}PID:${COLOR_RESET}    $pid"
        echo "${COLOR_DIM}Uptime:${COLOR_RESET} $(ps -o etime= -p "$pid" 2>/dev/null | tr -d ' ')"
        echo "${COLOR_DIM}Socket:${COLOR_RESET} $sock"
        echo
        echo "${COLOR_INFO}Environment:${COLOR_RESET}"
        echo "${COLOR_DIM}SSH_AUTH_SOCK:${COLOR_RESET} ${COLOR_SUCCESS}Set${COLOR_RESET}"
        echo "${COLOR_DIM}SSH_AGENT_PID:${COLOR_RESET} ${COLOR_SUCCESS}Set${COLOR_RESET}"
    else
        echo "${COLOR_ERROR}✗ Agent is not running${COLOR_RESET}"
        echo
        echo "${COLOR_INFO}Environment:${COLOR_RESET}"
        [[ -z $SSH_AUTH_SOCK ]] \
            && echo "${COLOR_DIM}SSH_AUTH_SOCK:${COLOR_RESET} ${COLOR_ERROR}Not Set${COLOR_RESET}" \
            || echo "${COLOR_DIM}SSH_AUTH_SOCK:${COLOR_RESET} ${COLOR_SUCCESS}Set${COLOR_RESET}"
        [[ -z $SSH_AGENT_PID ]] \
            && echo "${COLOR_DIM}SSH_AGENT_PID:${COLOR_RESET} ${COLOR_ERROR}Not Set${COLOR_RESET}" \
            || echo "${COLOR_DIM}SSH_AGENT_PID:${COLOR_RESET} ${COLOR_SUCCESS}Set${COLOR_RESET}"
    fi
}

print_loaded() {
    section " Loaded Keys"
    local keys; keys=$(ssh-add -l 2>/dev/null)
    if [[ -n $keys ]]; then
        local count=0
        while read -r bits fp comment rest; do
            [[ -z $bits ]] && continue
            (( count++ ))
            format_key_info "$bits" "$fp" "$comment" "$rest"
        done <<< "$keys"
        echo "${COLOR_INFO}Total Keys:${COLOR_RESET} $count"
    else
        echo "${COLOR_WARNING}No keys currently loaded${COLOR_RESET}"
    fi
}

print_available() {
    section " Available SSH Keys"
    local count=0 total_size=0
    while IFS= read -r f; do
        ssh-keygen -l -f "$f" &>/dev/null || continue
        (( count++ ))
        local sz; sz=$(filesize "$f")
        (( total_size += sz ))
        local info; info=$(ssh-keygen -l -f "$f")
        local bits=${${(z)info}[1]}
        local fp=${${(z)info}[2]}
        local type=${${(z)info}[4,-1]}
        local fname; fname=$(basename "$f")
        # comment from pubkey if available
        local pub_comment=""
        [[ -f ${f}.pub ]] && pub_comment=$(awk '{print $NF}' "${f}.pub" 2>/dev/null)

        format_key_info "$bits" "$fp" "$fname" "$type"
        echo "${COLOR_DIM}Path:${COLOR_RESET}    $f"
        echo "${COLOR_DIM}Size:${COLOR_RESET}    $(fmt_size $sz)"
        [[ -n $pub_comment ]] && echo "${COLOR_DIM}Comment:${COLOR_RESET} $pub_comment"
        echo "${COLOR_DIM}──────────────────────────────${COLOR_RESET}"
    done < <(find ~/.ssh -type f ! -name '*.pub' ! -name 'known_hosts*' ! -name 'config' \
             -exec grep -le 'BEGIN.*PRIVATE KEY' {} \;)
    echo "${COLOR_INFO}Total Keys:${COLOR_RESET} $count"
}

echo "${COLOR_INFO} Current Selection${COLOR_RESET}"
printf "${COLOR_HEADER}%s${COLOR_RESET}\n" "──────────────────────────────────────"
echo "${COLOR_HEADER}$selected${COLOR_RESET}"
echo

case $selected in
    "Start SSH Agent")
        [[ -S $sock ]] && echo "${COLOR_WARNING}󰼆 Notice: SSH Agent is already running${COLOR_RESET}\n"
        print_agent
        echo
        print_available
        ;;
    "Stop SSH Agent")
        print_agent
        echo
        print_loaded
        ;;
    "Load Key")
        print_agent
        echo
        print_available
        ;;
    "Unload Key")
        print_agent
        echo
        print_loaded
        ;;
    "List Loaded Keys")
        print_agent
        echo
        print_loaded
        ;;
    "Status")
        print_agent
        echo
        print_loaded
        ;;
    *)
        print_agent
        ;;
esac
SCRIPT
    chmod +x "$_SSHA_PREVIEW_DIR/menu_preview.zsh"
}

_ssha_init_previews() {
    [[ -n $_SSHA_PREVIEW_DIR && -d $_SSHA_PREVIEW_DIR ]] && return
    _SSHA_PREVIEW_DIR=$(mktemp -d)
    _ssha_write_header
    _ssha_write_key_preview
    _ssha_write_loaded_preview
    _ssha_write_menu_preview
}

_ssha_cleanup() { [[ -n $_SSHA_PREVIEW_DIR ]] && rm -rf "$_SSHA_PREVIEW_DIR"; }

# ══════════════════════════════════════════════
# Interactive fzf Actions
# ══════════════════════════════════════════════

_fzf_common=(
    --color='hl:12,hl+:15,pointer:4,marker:4'
    --border=rounded
    --margin=1
    --padding=1
    --preview-window=right:60%:wrap
    --ansi
)

load_key() {
    _ssha_init_previews
    local keys; keys=$(_ssha_find_keys)
    [[ -z $keys ]] && { echo "${COLOR_ERROR}No SSH keys found in $SSH_KEY_DIR${COLOR_RESET}"; return 1; }

    local sel
    sel=$(echo "$keys" | fzf "${_fzf_common[@]}" \
        --prompt="Load key › " \
        --header="Select a key to load" \
        --header-first \
        --preview="$_SSHA_PREVIEW_DIR/key_preview.zsh {}") || return 0

    ssh-add "$sel" && echo "${COLOR_SUCCESS}Loaded: ${COLOR_RESET}$sel"
}

unload_key() {
    _ssha_init_previews
    local keys; keys=$(_ssha_loaded_keys)
    [[ -z $keys ]] && { echo "${COLOR_ERROR}No keys loaded in SSH agent${COLOR_RESET}"; return 1; }

    local sel
    sel=$(echo "$keys" | fzf "${_fzf_common[@]}" \
        --prompt="Unload key › " \
        --header="Select a key to unload" \
        --header-first \
        --preview="$_SSHA_PREVIEW_DIR/loaded_preview.zsh {}") || return 0

    local fp; fp=$(echo "$sel" | awk '{print $2}')
    local file; file=$(_ssha_find_key_by_fp "$fp")

    if [[ -n $file ]]; then
        ssh-add -d "$file" && echo "${COLOR_SUCCESS}Unloaded: ${COLOR_RESET}$file"
    else
        # Agent holds a key with no local file (e.g. forwarded); remove by fp
        # ssh-add -d requires a file, so we use a temp pubkey extracted from agent
        local tmp; tmp=$(mktemp)
        ssh-add -L | grep "$fp" > "$tmp" 2>/dev/null
        if [[ -s $tmp ]]; then
            ssh-add -d "$tmp" && echo "${COLOR_SUCCESS}Unloaded key ${COLOR_RESET}$fp"
        else
            echo "${COLOR_ERROR}Could not unload: no matching local file or public key${COLOR_RESET}"
        fi
        rm -f "$tmp"
    fi
}

list_loaded_keys() {
    _ssha_init_previews
    local keys; keys=$(_ssha_loaded_keys)
    [[ -z $keys ]] && { echo "${COLOR_ERROR}No keys loaded in SSH agent${COLOR_RESET}"; return 1; }

    local sel
    sel=$(echo "$keys" | fzf "${_fzf_common[@]}" \
        --prompt="Loaded keys › " \
        --header="Loaded SSH Keys (enter to inspect)" \
        --header-first \
        --no-select-1 \
        --preview="$_SSHA_PREVIEW_DIR/loaded_preview.zsh {}") || return 0

    local fp; fp=$(echo "$sel" | awk '{print $2}')
    local file; file=$(_ssha_find_key_by_fp "$fp")
    if [[ -n $file ]]; then
        echo "${COLOR_INFO}Key file:${COLOR_RESET} $file"
        ssh-keygen -l -v -f "$file"
    else
        echo "${COLOR_WARNING}No local file found for fingerprint $fp${COLOR_RESET}"
    fi
}

# ══════════════════════════════════════════════
# Main Menu
# ══════════════════════════════════════════════
ssha_menu() {
    _ssha_init_previews
    local options=(
        "Status"
        "Start SSH Agent"
        "Stop SSH Agent"
        "Load Key"
        "Unload Key"
        "List Loaded Keys"
        "Exit"
    )

    local sel
    sel=$(printf '%s\n' "${options[@]}" | fzf "${_fzf_common[@]}" \
        --prompt="SSH Agent › " \
        --header="SSH Agent Management" \
        --header-first \
        --cycle \
        --preview="$_SSHA_PREVIEW_DIR/menu_preview.zsh {} \"$SSH_AUTH_SOCK\" \"$SSH_AGENT_PID\"") || return 0

    case $sel in
        "Status")           get_agent_status ;;
        "Start SSH Agent")  start_ssh_agent ;;
        "Stop SSH Agent")   stop_ssh_agent ;;
        "Load Key")         load_key ;;
        "Unload Key")       unload_key ;;
        "List Loaded Keys") list_loaded_keys ;;
        "Exit")             return 0 ;;
    esac
}

# ══════════════════════════════════════════════
# Entry Point
# ══════════════════════════════════════════════
ssha-management() {
    case ${1:-} in
        start)  start_ssh_agent ;;
        stop)   stop_ssh_agent ;;
        status) get_agent_status ;;
        load)   load_key ;;
        unload) unload_key ;;
        list)   list_loaded_keys ;;
        menu)   ssha_menu ;;
        help|-h|--help)
            _ssha_section "SSH Management Tool"
            echo "${COLOR_INFO}Usage:${COLOR_RESET} ssha [command]"
            echo
            echo "  ${COLOR_INFO}start${COLOR_RESET}   Start SSH agent (reconnect if already exists)"
            echo "  ${COLOR_INFO}stop${COLOR_RESET}    Stop SSH agent"
            echo "  ${COLOR_INFO}status${COLOR_RESET}  Show agent status and loaded keys"
            echo "  ${COLOR_INFO}load${COLOR_RESET}    Interactively load a key"
            echo "  ${COLOR_INFO}unload${COLOR_RESET}  Interactively unload a key"
            echo "  ${COLOR_INFO}list${COLOR_RESET}    Browse loaded keys"
            echo "  ${COLOR_INFO}menu${COLOR_RESET}    Open interactive menu (default)"
            echo "  ${COLOR_INFO}help${COLOR_RESET}    Show this help"
            ;;
        "")     ssha_menu ;;
        *)
            echo "${COLOR_ERROR}Unknown command: $1${COLOR_RESET}"
            echo "Run ${COLOR_INFO}ssha help${COLOR_RESET} for usage"
            return 1
            ;;
    esac
}

# ══════════════════════════════════════════════
# Zsh Completion
# ══════════════════════════════════════════════
_ssha_complete() {
    local -a cmds=(
        'start:Start SSH agent'
        'stop:Stop SSH agent'
        'status:Show agent status'
        'load:Load a key interactively'
        'unload:Unload a key interactively'
        'list:Browse loaded keys'
        'menu:Open interactive menu'
        'help:Show help'
    )
    _describe 'command' cmds
}
compdef _ssha_complete ssha-management 2>/dev/null || true

# ══════════════════════════════════════════════
# Source vs Direct-run
# ══════════════════════════════════════════════
if [[ ${ZSH_EVAL_CONTEXT} == *:file* ]]; then
    # Being sourced — register alias and auto-start agent quietly
    alias ssha='ssha-management'
    trap '_ssha_cleanup' EXIT
    auto_start
else
    # Direct execution
    trap '_ssha_cleanup' EXIT
    ssha-management "$@"
fi