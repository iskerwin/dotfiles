#!/usr/bin/env zsh

# 1. 依赖检查
if ! command -v fzf >/dev/null 2>&1; then
    echo "Error: fzf is required but not installed. Please install fzf first."
    return 1
fi

# 2. 基础变量定义
SSH_KEY_DIR="$HOME/.ssh"
SOCK_FILE="/tmp/ssh-agent-sock"
PID_FILE="/tmp/ssh-agent-pid"
PREVIEW_DIR=$(mktemp -d)
trap 'rm -rf "$PREVIEW_DIR"' EXIT

# 3. 颜色定义
COLOR_HEADER=$'\033[1;34m'    # Bold Blue
COLOR_SUCCESS=$'\033[1;32m'   # Bold Green
COLOR_WARNING=$'\033[1;33m'   # Bold Yellow
COLOR_ERROR=$'\033[1;31m'     # Bold Red
COLOR_INFO=$'\033[1;36m'      # Bold Cyan
COLOR_RESET=$'\033[0m'        # Reset
COLOR_DIM=$'\033[2m'          # Dim

# 4. 基础工具函数
print_separator() {
    printf "${COLOR_HEADER}%s${COLOR_RESET}\n" "============================================================"
}

print_section() {
    echo "${COLOR_HEADER}$1${COLOR_RESET}"
    print_separator
}

print_socket_path() {
    local socket_dir=$(dirname "$1")
    local socket_name=$(basename "$1")
    echo "${COLOR_DIM}$socket_dir/${COLOR_RESET}${COLOR_SUCCESS}$socket_name${COLOR_RESET}"
}

format_key_info() {
    local bits=$1 hash=$2 comment=$3
    echo "${COLOR_INFO}[$comment]${COLOR_RESET}"
    echo "  ${COLOR_DIM}Bits:${COLOR_RESET} $bits"
    echo "  ${COLOR_DIM}Hash:${COLOR_RESET} $hash"
    printf "${COLOR_DIM}%s${COLOR_RESET}\n" "────────────────────────────────────────────────────────────"
}

# 5. SSH 核心函数
find_ssh_keys() {
    find "$SSH_KEY_DIR" -type f -not -name "*.pub" \
        -not -name "known_hosts*" \
        -not -name "config" \
        -not -name "agent-env" \
        -not -name ".DS_Store" \
        -not -name "authorized_keys" | while read file; do
        if ssh-keygen -l -f "$file" &>/dev/null; then
            echo "$file"
        fi
    done
}

get_loaded_keys() {
    local loaded_keys=$(ssh-add -l 2>/dev/null)
    if [[ $? -eq 0 ]]; then
        echo "$loaded_keys"
    else
        return 1
    fi
}

format_loaded_keys() {
    local loaded_keys=$(get_loaded_keys)
    if [[ $? -eq 0 ]]; then
        echo "$loaded_keys" | while read -r bits hash comment; do
            format_key_info "$bits" "$hash" "$comment"
        done
    else
        echo "${COLOR_WARNING}None${COLOR_RESET}"
    fi
}

get_agent_status() {
    if [[ -S "$SSH_AUTH_SOCK" ]]; then
        echo "${COLOR_SUCCESS}Running${COLOR_RESET}"
        echo "${COLOR_INFO}PID:${COLOR_RESET}    $SSH_AGENT_PID"
        echo "${COLOR_INFO}Socket:${COLOR_RESET} $(print_socket_path "$SSH_AUTH_SOCK")"
        echo
        print_section "Loaded Keys"
        format_loaded_keys
    else
        echo "${COLOR_ERROR}✗ Not running${COLOR_RESET}"
        echo "${COLOR_DIM}SSH Agent is not started${COLOR_RESET}"
    fi
}

# 6. SSH Agent 操作函数
start_ssh_agent() {
    if [[ -S "$SSH_AUTH_SOCK" ]]; then
        echo "${COLOR_WARNING}SSH agent is already running${COLOR_RESET}"
        return 0
    fi

    eval $(ssh-agent -s)
    echo $SSH_AUTH_SOCK > $SOCK_FILE
    echo $SSH_AGENT_PID > $PID_FILE
    echo "${COLOR_SUCCESS}Started new SSH agent${COLOR_RESET}"
}

stop_ssh_agent() {
    if [[ -f $PID_FILE ]]; then
        pid=$(cat $PID_FILE)
        if kill -0 $pid 2>/dev/null; then
            kill $pid
            rm -f $SOCK_FILE $PID_FILE
            echo "${COLOR_SUCCESS}Stopped SSH agent${COLOR_RESET}"
        fi
    fi
    unset SSH_AUTH_SOCK
    unset SSH_AGENT_PID
}

# 7. SSH 密钥管理函数
load_key() {
    local key_list=$(find_ssh_keys)
    if [[ -z "$key_list" ]]; then
        echo "${COLOR_ERROR}No valid SSH keys found in $SSH_KEY_DIR${COLOR_RESET}"
        return 1
    fi

    local selected_key=$(echo "$key_list" | fzf --prompt="Select SSH key to load: " \
        --preview="$PREVIEW_DIR/key_preview.sh {}" \
        --preview-window=right:60%:wrap \
        --color='hl:12,hl+:15,pointer:4,marker:4' \
        --border=rounded \
        --margin=1 \
        --padding=1 \
        --header="Load SSH Key" \
        --header-first)
    
    if [[ -n "$selected_key" ]]; then
        ssh-add "$selected_key"
        echo "${COLOR_SUCCESS}Loaded key: ${COLOR_RESET}$selected_key"
    fi
}

unload_key() {
    local loaded_keys=$(get_loaded_keys)
    if [[ $? -ne 0 ]]; then
        echo "${COLOR_ERROR}No keys loaded in SSH agent${COLOR_RESET}"
        return 1
    fi
    
    local selected_key=$(echo "$loaded_keys" | fzf --prompt="Select SSH key to unload: " \
        --preview="$PREVIEW_DIR/loaded_key_preview.sh {}" \
        --preview-window=right:60%:wrap \
        --color='hl:12,hl+:15,pointer:4,marker:4' \
        --border=rounded \
        --margin=1 \
        --padding=1 \
        --header="Unload SSH Key" \
        --header-first)
    
    if [[ -n "$selected_key" ]]; then
        local fingerprint=$(echo "$selected_key" | awk '{print $2}')
        local key_file=$(find_key_by_fingerprint "$fingerprint")
        
        if [[ -n "$key_file" ]]; then
            ssh-add -d "$key_file"
            echo "${COLOR_SUCCESS}Unloaded key: ${COLOR_RESET}$key_file"
        else
            ssh-add -d <<< ""
            if [[ $? -eq 0 ]]; then
                echo "${COLOR_SUCCESS}Unloaded key with fingerprint: ${COLOR_RESET}$fingerprint"
            else
                echo "${COLOR_ERROR}Failed to unload key. Could not find matching local file.${COLOR_RESET}"
            fi
        fi
    fi
}

find_key_by_fingerprint() {
    local target_fingerprint=$1
    local key_file=""
    
    while read -r file; do
        if [[ -f "$file" ]] && ssh-keygen -l -f "$file" &>/dev/null; then
            local file_fingerprint=$(ssh-keygen -l -f "$file" | awk '{print $2}')
            if [[ "$file_fingerprint" == "$target_fingerprint" ]]; then
                echo "$file"
                return 0
            fi
        fi
    done < <(find_ssh_keys)
    return 1
}

list_loaded_keys() {
    print_section "Currently Loaded SSH Keys"
    format_loaded_keys
    echo
    print_section "Agent Status"
    if [[ -S "$SSH_AUTH_SOCK" ]]; then
        echo "${COLOR_SUCCESS}Agent is running${COLOR_RESET}"
        echo "${COLOR_INFO}PID:${COLOR_RESET}    $SSH_AGENT_PID"
        echo "${COLOR_INFO}Socket:${COLOR_RESET} $(print_socket_path "$SSH_AUTH_SOCK")"
    else
        echo "${COLOR_ERROR}SSH Agent is not running${COLOR_RESET}"
    fi
}

# 8. 预览脚本生成函数
create_preview_scripts() {
    # 保留原有的 key_preview.sh 生成代码
    cat > "$PREVIEW_DIR/key_preview.sh" << 'EOF'
#!/usr/bin/env zsh
key=$1

COLOR_HEADER=$'\033[1;34m'    # Bold Blue
COLOR_SUCCESS=$'\033[1;32m'   # Bold Green
COLOR_WARNING=$'\033[1;33m'   # Bold Yellow
COLOR_ERROR=$'\033[1;31m'     # Bold Red
COLOR_INFO=$'\033[1;36m'      # Bold Cyan
COLOR_RESET=$'\033[0m'        # Reset
COLOR_DIM=$'\033[2m'          # Dim

# 4. 基础工具函数
print_separator() {
    printf "${COLOR_HEADER}%s${COLOR_RESET}\n" "============================================================"
}

print_section() {
    echo "${COLOR_HEADER}$1${COLOR_RESET}"
    print_separator
}

if [[ ! -f "$key" ]]; then
    print_section "❌ Error"
    echo "${COLOR_ERROR}Invalid SSH key file${COLOR_RESET}"
    exit 1
fi

print_section "🔑 Key Information"
key_info=$(ssh-keygen -l -f "$key" 2>/dev/null)
if [[ $? -eq 0 ]]; then
    bits=$(echo "$key_info" | awk '{print $1}')
    fingerprint=$(echo "$key_info" | awk '{print $2}')
    echo "${COLOR_INFO}Bits:${COLOR_RESET}        $bits"
    echo "${COLOR_INFO}Fingerprint:${COLOR_RESET} $fingerprint"
fi

if [[ -f "${key}.pub" ]]; then
    echo
    print_section "📄 Public Key"
    echo "${COLOR_SUCCESS}$(cat "${key}.pub")${COLOR_RESET}"
fi
EOF
    chmod +x "$PREVIEW_DIR/key_preview.sh"

    # 保留原有的 loaded_key_preview.sh 生成代码
    cat > "$PREVIEW_DIR/loaded_key_preview.sh" << 'EOF'
#!/usr/bin/env zsh
key_info="$@"

COLOR_HEADER=$'\033[1;34m'    # Bold Blue
COLOR_SUCCESS=$'\033[1;32m'   # Bold Green
COLOR_WARNING=$'\033[1;33m'   # Bold Yellow
COLOR_ERROR=$'\033[1;31m'     # Bold Red
COLOR_INFO=$'\033[1;36m'      # Bold Cyan
COLOR_RESET=$'\033[0m'        # Reset
COLOR_DIM=$'\033[2m'          # Dim

print_section() {
    echo "${COLOR_HEADER}$1${COLOR_RESET}"
    printf "${COLOR_HEADER}%s${COLOR_RESET}\n" "============================================================"
}

print_section "🔑 Key Details"
echo "${COLOR_INFO}$key_info${COLOR_RESET}"

fingerprint=$(echo "$key_info" | awk '{print $2}')
echo
print_section "📂 Local Key File"
for key in $(find ~/.ssh -type f -not -name "*.pub"); do
    if [[ -f "$key" ]] && ssh-keygen -l -f "$key" &>/dev/null; then
        key_fp=$(ssh-keygen -l -f "$key" | awk '{print $2}')
        if [[ "$fingerprint" == "$key_fp" ]]; then
            echo "${COLOR_SUCCESS}Path:${COLOR_RESET} $key"
            echo "${COLOR_INFO}Permissions:${COLOR_RESET} $(ls -l "$key")"
            exit 0
        fi
    fi
done
echo "${COLOR_WARNING}No matching local key file found${COLOR_RESET}"
EOF
    chmod +x "$PREVIEW_DIR/loaded_key_preview.sh"

    # 添加新的 menu_preview.sh 生成代码
    cat > "$PREVIEW_DIR/menu_preview.sh" << 'EOF'
#!/usr/bin/env zsh
selected=$1
ssh_sock=$2
ssh_pid=$3

COLOR_HEADER=$'\033[1;34m'    # Bold Blue
COLOR_SUCCESS=$'\033[1;32m'   # Bold Green
COLOR_WARNING=$'\033[1;33m'   # Bold Yellow
COLOR_ERROR=$'\033[1;31m'     # Bold Red
COLOR_INFO=$'\033[1;36m'      # Bold Cyan
COLOR_RESET=$'\033[0m'        # Reset
COLOR_DIM=$'\033[2m'          # Dim

print_section() {
    echo "${COLOR_HEADER}$1${COLOR_RESET}"
    printf "${COLOR_HEADER}%s${COLOR_RESET}\n" "============================================================"
}

print_section "📌 Current Selection"
echo "${COLOR_INFO}$selected${COLOR_RESET}"
echo

print_section "🔄 SSH Agent Status"
if [[ -S "$ssh_sock" ]]; then
    echo "${COLOR_SUCCESS}✓ Agent is running${COLOR_RESET}"
    echo "${COLOR_INFO}PID:${COLOR_RESET}    $ssh_pid"
    echo "${COLOR_INFO}Socket:${COLOR_RESET} $ssh_sock"
    
    echo
    print_section "🔑 Loaded Keys"
    loaded_keys=$(ssh-add -l 2>/dev/null)
    if [[ $? -eq 0 ]]; then
        while read -r bits hash comment; do
            if [[ -n "$bits" ]]; then
                echo "${COLOR_SUCCESS}[$comment]${COLOR_RESET}"
                echo "  ${COLOR_DIM}Bits:${COLOR_RESET} $bits"
                echo "  ${COLOR_DIM}Hash:${COLOR_RESET} $hash"
                printf "${COLOR_HEADER}%s${COLOR_RESET}\n" "────────────────────────────────────────────────────────────"
            fi
        done <<< "$loaded_keys"
    else
        echo "${COLOR_WARNING}No keys currently loaded${COLOR_RESET}"
    fi
else
    echo "${COLOR_ERROR}✗ Agent is not running${COLOR_RESET}"
fi
EOF
    chmod +x "$PREVIEW_DIR/menu_preview.sh"
}

# 9. 交互式菜单函数
ssh_menu() {
    local options=(
        "Start SSH Agent"
        "Stop SSH Agent"
        "Load Key"
        "Unload Key"
        "List Loaded Keys"
        "Exit"
    )
    
    local selected=$(printf "%s\n" "${options[@]}" | fzf --prompt="SSH Agent Management > " \
        --preview="$PREVIEW_DIR/menu_preview.sh {} \"$SSH_AUTH_SOCK\" \"$SSH_AGENT_PID\"" \
        --preview-window=right:60%:wrap \
        --color='hl:12,hl+:15,pointer:4,marker:4' \
        --border=rounded \
        --margin=1 \
        --padding=1 \
        --header="SSH Agent Management Tool" \
        --header-first)
    
    case $selected in
        "Start SSH Agent") start_ssh_agent ;;
        "Stop SSH Agent") stop_ssh_agent ;;
        "Load Key") load_key ;;
        "Unload Key") unload_key ;;
        "List Loaded Keys") list_loaded_keys ;;
        "Exit") return 0 ;;
    esac
}

# 10. 自动启动和初始化
auto_start() {
    [[ -f $SOCK_FILE ]] && export SSH_AUTH_SOCK=$(cat $SOCK_FILE)
    [[ -f $PID_FILE ]] && export SSH_AGENT_PID=$(cat $PID_FILE)
    
    if ! ssh-add -l &>/dev/null; then
        echo "${COLOR_DIM}Auto-starting SSH agent...${COLOR_RESET}"
        start_ssh_agent
    fi
}

# 11. 主函数和命令补全
ssh-management() {
    case $1 in
        start) start_ssh_agent ;;
        stop) stop_ssh_agent ;;
        load) load_key ;;
        unload) unload_key ;;
        list) list_loaded_keys ;;
        menu) ssh_menu ;;
        help)
            print_section "SSH Management Tool Help"
            echo "${COLOR_INFO}Usage:${COLOR_RESET} ssh-management [command]"
            echo
            print_section "Available Commands"
            echo "${COLOR_INFO}start${COLOR_RESET}    Start SSH agent"
            echo "${COLOR_INFO}stop${COLOR_RESET}     Stop SSH agent"
            echo "${COLOR_INFO}load${COLOR_RESET}     Load SSH key"
            echo "${COLOR_INFO}unload${COLOR_RESET}   Unload SSH key"
            echo "${COLOR_INFO}list${COLOR_RESET}     List loaded keys"
            echo "${COLOR_INFO}menu${COLOR_RESET}     Show interactive menu"
            echo "${COLOR_INFO}help${COLOR_RESET}     Show this help message"
            ;;
        *)
            if [[ -n "$1" ]]; then
                echo "${COLOR_ERROR}Unknown command: $1${COLOR_RESET}"
                echo "Run ${COLOR_INFO}ssh-management help${COLOR_RESET} for usage information"
                return 1
            fi
            ssh_menu
            ;;
    esac
}

# 初始化
create_preview_scripts
auto_start
alias ssha='ssh-management'

# 命令补全
_ssh_management() {
    local commands=(
        'start:Start SSH agent'
        'stop:Stop SSH agent'
        'load:Load SSH key'
        'unload:Unload SSH key'
        'list:List loaded keys'
        'menu:Show interactive menu'
        'help:Show help message'
    )
    _describe 'command' commands
}

compdef _ssh_management ssh-management