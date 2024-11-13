#!/usr/bin/env zsh

# Check for required dependencies
if ! command -v fzf >/dev/null 2>&1; then
    echo "Error: fzf is required but not installed. Please install fzf first."
    return 1
fi

# Initialize variables
SSH_KEY_DIR="$HOME/.ssh"
SOCK_FILE="/tmp/ssh-agent-sock"
PID_FILE="/tmp/ssh-agent-pid"

# Color definitions
COLOR_HEADER=$'\033[1;34m'    # Bold Blue
COLOR_SUCCESS=$'\033[1;32m'   # Bold Green
COLOR_WARNING=$'\033[1;33m'   # Bold Yellow
COLOR_ERROR=$'\033[1;31m'     # Bold Red
COLOR_INFO=$'\033[1;36m'      # Bold Cyan
COLOR_RESET=$'\033[0m'        # Reset
COLOR_DIM=$'\033[2m'          # Dim
COLOR_BOLD=$'\033[1m'         # Bold

# Separator function
print_separator() {
    echo "\033[0;36m═══════════════════════════════════════════\033[0m"
}

# Section header function
print_section() {
    echo "${COLOR_HEADER}$1${COLOR_RESET}"
    print_separator
}

# Create a temporary directory for preview scripts
PREVIEW_DIR=$(mktemp -d)
trap 'rm -rf "$PREVIEW_DIR"' EXIT

# Previous functions remain the same until the preview scripts...

# Create key details preview script with enhanced formatting
cat > "$PREVIEW_DIR/key_details.sh" << 'EOF'
#!/usr/bin/env zsh

# Color definitions
COLOR_HEADER=$'\033[1;34m'    # Bold Blue
COLOR_SUCCESS=$'\033[1;32m'   # Bold Green
COLOR_WARNING=$'\033[1;33m'   # Bold Yellow
COLOR_ERROR=$'\033[1;31m'     # Bold Red
COLOR_INFO=$'\033[1;36m'      # Bold Cyan
COLOR_RESET=$'\033[0m'        # Reset
COLOR_DIM=$'\033[2m'          # Dim
COLOR_BOLD=$'\033[1m'         # Bold

print_separator() {
    echo "\033[0;36m═══════════════════════════════════════════\033[0m"
}

print_section() {
    echo "${COLOR_HEADER}$1${COLOR_RESET}"
    print_separator
}

key=$1

if [[ -f "$key" ]]; then
    print_section "🔑 Key Information"
    key_info=$(ssh-keygen -l -f "$key" 2>/dev/null)
    bits=$(echo "$key_info" | awk '{print $1}')
    fingerprint=$(echo "$key_info" | awk '{print $2}')
    echo "${COLOR_INFO}Bits:${COLOR_RESET}        $bits"
    echo "${COLOR_INFO}Fingerprint:${COLOR_RESET} $fingerprint"
    echo

    if [[ -f "${key}.pub" ]]; then
        print_section "📄 Public Key"
        echo "${COLOR_SUCCESS}$(cat "${key}.pub")${COLOR_RESET}"
        echo
        print_section "📋 File Details"
        pub_perms=$(ls "${key}.pub")
        echo "${COLOR_INFO}Public Key:${COLOR_RESET}  $pub_perms"
    else
        print_section "⚠️  Warning"
        echo "${COLOR_WARNING}No public key file found${COLOR_RESET}"
    fi # Fixed: Changed 'end' to 'fi'

    priv_perms=$(ls "$key")
    echo "${COLOR_INFO}Private Key:${COLOR_RESET} $priv_perms"
    echo
    
    created=$(stat -f "%Sm" "$key")
    print_section "📅 Timestamp"
    echo "${COLOR_INFO}Created:${COLOR_RESET}     $created"
else
    print_section "❌ Error"
    echo "${COLOR_ERROR}Invalid SSH key file${COLOR_RESET}"
fi
EOF
chmod +x "$PREVIEW_DIR/key_details.sh"

cat > "$PREVIEW_DIR/loaded_key_details.sh" << 'EOF'
#!/usr/bin/env zsh

# Color definitions
COLOR_HEADER=$'\033[1;34m'    # Bold Blue
COLOR_SUCCESS=$'\033[1;32m'   # Bold Green
COLOR_WARNING=$'\033[1;33m'   # Bold Yellow
COLOR_ERROR=$'\033[1;31m'     # Bold Red
COLOR_INFO=$'\033[1;36m'      # Bold Cyan
COLOR_RESET=$'\033[0m'        # Reset
COLOR_DIM=$'\033[2m'          # Dim
COLOR_BOLD=$'\033[1m'         # Bold

print_separator() {
    echo "\033[0;36m═══════════════════════════════════════════\033[0m"
}

print_section() {
    echo "${COLOR_HEADER}$1${COLOR_RESET}"
    print_separator
}

key_info="$@"
print_section "🔑 Key Details"
echo "${COLOR_INFO}$key_info${COLOR_RESET}"
echo

fingerprint=$(echo "$key_info" | awk '{print $2}')
print_section "📂 Local Key File"

found=false
find "$HOME/.ssh" -type f -not -name "*.pub" \
    -not -name "known_hosts*" \
    -not -name "config" \
    -not -name "agent-env" \
    -not -name ".DS_Store" \
    -not -name "authorized_keys" | while read key; do
    if ssh-keygen -l -f "$key" &>/dev/null; then
        key_fp=$(ssh-keygen -l -f "$key" 2>/dev/null | awk '{print $2}')
        if [[ "$fingerprint" == "$key_fp" ]]; then
            echo "${COLOR_SUCCESS}Path:${COLOR_RESET} $key"
            echo "${COLOR_INFO}Permissions:${COLOR_RESET} $(ls -l "$key")"
            found=true
            break
        fi
    fi
done

if [[ $found == false ]]; then
    echo "${COLOR_WARNING}No matching local key file found${COLOR_RESET}"
fi
EOF
chmod +x "$PREVIEW_DIR/loaded_key_details.sh"

cat > "$PREVIEW_DIR/menu_preview.sh" << 'EOF'
#!/usr/bin/env zsh

# Color definitions for consistent styling
COLOR_HEADER=$'\033[1;34m'    # Bold Blue
COLOR_SUCCESS=$'\033[1;32m'   # Bold Green
COLOR_WARNING=$'\033[1;33m'   # Bold Yellow
COLOR_ERROR=$'\033[1;31m'     # Bold Red
COLOR_INFO=$'\033[1;36m'      # Bold Cyan
COLOR_RESET=$'\033[0m'        # Reset
COLOR_DIM=$'\033[2m'          # Dim
COLOR_BOLD=$'\033[1m'         # Bold

# 打印分隔线
print_separator() {
    echo "\033[0;36m═══════════════════════════════════════════\033[0m"
}

# 打印带有标题的区块
print_section() {
    echo "${COLOR_HEADER}$1${COLOR_RESET}"
    print_separator
}

# 格式化显示已加载的密钥
format_loaded_keys() {
    local loaded_keys=$(ssh-add -l 2>/dev/null)
    if [[ $? -eq 0 ]]; then
        echo "$loaded_keys" | while read -r bits hash comment; do
            echo "${COLOR_INFO}[$comment]${COLOR_RESET}"
            echo "  ${COLOR_DIM}Bits:${COLOR_RESET} $bits"
            echo "  ${COLOR_DIM}Hash:${COLOR_RESET} $hash"
            echo "${COLOR_DIM}────────────────────${COLOR_RESET}"
        done
    else
        echo "${COLOR_WARNING}None${COLOR_RESET}"
    fi
}

# 列出可用的 SSH 密钥
list_available_keys() {
    find "$HOME/.ssh" -type f -not -name "*.pub" \
        -not -name "known_hosts*" \
        -not -name "config" \
        -not -name "agent-env" \
        -not -name ".DS_Store" \
        -not -name "authorized_keys" | while read file; do
        if ssh-keygen -l -f "$file" &>/dev/null; then
            echo "${COLOR_SUCCESS}$file${COLOR_RESET}"
        fi
    done
}

# 获取 SSH Agent 状态
get_status() {
    if [[ -S "$SSH_AUTH_SOCK" ]]; then
        echo "${COLOR_SUCCESS}Running${COLOR_RESET}"
        echo "${COLOR_INFO}PID:${COLOR_RESET}    $SSH_AGENT_PID"
        echo "${COLOR_INFO}Socket:${COLOR_RESET} $SSH_AUTH_SOCK"
        echo
        print_section "🔑 Loaded Keys"
        format_loaded_keys
    else
        echo "${COLOR_ERROR}✗ Not running${COLOR_RESET}"
        echo "${COLOR_DIM}SSH Agent is not started${COLOR_RESET}"
    fi
}

# 菜单项处理
item=$1
SSH_AUTH_SOCK=$2
SSH_AGENT_PID=$3

# 菜单选项处理
case $item in
    "Start SSH Agent")
        # 启动 SSH Agent，显示启动前的状态
        print_section "🚀 Start SSH Agent"
        echo "${COLOR_DIM}Start a new SSH agent or connect to an existing one${COLOR_RESET}"
        echo
        print_section "🟢 Current Status"
        get_status
        ;;
        
    "Stop SSH Agent")
        # 停止 SSH Agent，显示停止前的状态
        print_section "🛑 Stop SSH Agent"
        echo "${COLOR_DIM}Stop the running SSH agent and remove all loaded keys${COLOR_RESET}"
        echo
        print_section "🟢 Current Status"
        get_status
        ;;
        
    "Load Key")
        # 加载新的 SSH 密钥
        print_section "📥 Load SSH Key"
        echo "${COLOR_DIM}Add a new SSH key to the agent${COLOR_RESET}"
        echo
        print_section "🉑 Available Keys"
        list_available_keys
        echo
        print_section "✅ Currently Loaded"
        format_loaded_keys
        ;;
        
    "Unload Key")
        # 卸载已加载的 SSH 密钥
        print_section "📤 Unload SSH Key"
        echo "${COLOR_DIM}Remove a loaded SSH key from the agent${COLOR_RESET}"
        echo
        print_section "🔑 Currently Loaded Keys"
        format_loaded_keys
        ;;
        
    "List Loaded Keys")
        # 显示已加载的密钥列表和代理状态
        print_section "📋 Loaded Keys List"
        echo "${COLOR_DIM}View all keys currently loaded in the agent${COLOR_RESET}"
        echo
        print_section "🔍 Agent Details"
        get_status
        ;;
        
    "Exit")
        # 退出程序，显示退出前的状态
        print_section "👋 Exit Program"
        echo "${COLOR_DIM}Exit the SSH key management tool${COLOR_RESET}"
        echo
        print_section "🟢 Current Status"
        get_status
        ;;
esac
EOF
chmod +x "$PREVIEW_DIR/menu_preview.sh"


list_loaded_keys() {
    print_section "Currently Loaded SSH Keys"
    
    local loaded_keys=$(ssh-add -l 2>/dev/null)
    if [[ $? -eq 0 ]]; then
        echo "$loaded_keys" | while read -r bits hash comment; do
            echo "${COLOR_INFO}[$comment]${COLOR_RESET}"
            echo "  ${COLOR_DIM}Bits:${COLOR_RESET} $bits"
            echo "  ${COLOR_DIM}Hash:${COLOR_RESET} $hash"
            echo "${COLOR_DIM}────────────────────${COLOR_RESET}"
        done
    else
        echo "${COLOR_WARNING}No keys currently loaded in SSH agent${COLOR_RESET}"
    fi
    
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

# 添加一个新函数来处理 socket 路径的显示
print_socket_path() {
    local socket_path=$1
    local socket_dir=$(dirname "$socket_path")
    local socket_name=$(basename "$socket_path")
    echo "${COLOR_DIM}$socket_dir/${COLOR_RESET}${COLOR_SUCCESS}$socket_name${COLOR_RESET}"
}

# Update the ssh_menu function to use new FZF options
ssh_menu() {
    local options=(
        "Start SSH Agent"
        "Stop SSH Agent"
        "Load Key"
        "Unload Key"
        "List Loaded Keys"
        "Exit"
    )
    
    local selected=$(printf "%s\n" "${options[@]}" | \
        fzf --prompt="SSH Agent Management > " \
        --preview="$PREVIEW_DIR/menu_preview.sh {} $SSH_AUTH_SOCK $SSH_AGENT_PID" \
        --preview-window=right:60%:wrap \
        --color='hl:12,hl+:15,pointer:4,marker:4' \
        --border=rounded \
        --margin=1 \
        --padding=1 \
        --header="SSH Agent Management Tool" \
        --header-first)
    
    case $selected in
        "Start SSH Agent")
            start_ssh_agent
            ;;
        "Stop SSH Agent")
            stop_ssh_agent
            ;;
        "Load Key")
            load_key
            ;;
        "Unload Key")
            unload_key
            ;;
        "List Loaded Keys")
            list_loaded_keys
            ;;
        "Exit")
            return 0
            ;;
    esac
}

# Update the load_key and unload_key functions to use new FZF options
load_key() {
    local selected_key=$(list_keys | fzf --prompt="Select SSH key to load: " \
        --preview="$PREVIEW_DIR/key_details.sh {}" \
        --preview-window=right:60%:wrap \
        --color='hl:12,hl+:15,pointer:4,marker:4' \
        --border=rounded \
        --margin=1 \
        --padding=1 \
        --header="Load SSH Key" \
        --header-first)
    
    if [[ -n $selected_key ]]; then
        ssh-add $selected_key
        echo "${COLOR_SUCCESS}Loaded key: ${COLOR_RESET}$selected_key"
    fi
}

unload_key() {
    local key_list=$(ssh-add -l)
    if [[ $? -ne 0 ]]; then
        echo "${COLOR_ERROR}No keys loaded in SSH agent${COLOR_RESET}"
        return 1
    fi
    
    local selected_key=$(echo "$key_list" | fzf --prompt="Select SSH key to unload: " \
        --preview="$PREVIEW_DIR/loaded_key_details.sh {}" \
        --preview-window=right:60%:wrap \
        --color='hl:12,hl+:15,pointer:4,marker:4' \
        --border=rounded \
        --margin=1 \
        --padding=1 \
        --header="Unload SSH Key" \
        --header-first)
    
    if [[ -n $selected_key ]]; then
        local fingerprint=$(echo "$selected_key" | awk '{print $2}')
        local key_file=""
        
        while read -r file; do
            if [[ -f "$file" ]] && ssh-keygen -l -f "$file" &>/dev/null; then
                local file_fingerprint=$(ssh-keygen -l -f "$file" | awk '{print $2}')
                if [[ "$file_fingerprint" == "$fingerprint" ]]; then
                    key_file="$file"
                    break
                fi
            fi
        done < <(find "$SSH_KEY_DIR" -type f -not -name "*.pub" \
            -not -name "known_hosts*" \
            -not -name "config" \
            -not -name "agent-env" \
            -not -name ".DS_Store" \
            -not -name "authorized_keys")
        
        if [[ -n "$key_file" ]]; then
            ssh-add -d "$key_file"
            echo "${COLOR_SUCCESS}Unloaded key: ${COLOR_RESET}$key_file"
        else
            sshssh-add -d <<< ""
            if [[ $? -eq 0 ]]; then
                echo "${COLOR_SUCCESS}Unloaded key with fingerprint: ${COLOR_RESET}$fingerprint"
            else
                echo "${COLOR_ERROR}Failed to unload key. Could not find matching local file.${COLOR_RESET}"
            fi
        fi
    fi
}

# Update status display function
get_agent_status() {
    local status=""
    if [[ -S "$SSH_AUTH_SOCK" ]]; then
        status="${COLOR_SUCCESS}● Running${COLOR_RESET}\n"
        status+="${COLOR_INFO}PID:${COLOR_RESET}    $SSH_AGENT_PID\n"
        status+="${COLOR_INFO}Socket:${COLOR_RESET} $SSH_AUTH_SOCK\n\n"
        print_section "Loaded Keys"
        local loaded_keys=$(ssh-add -l 2>/dev/null)
        if [[ $? -eq 0 ]]; then
            status+=$(echo "$loaded_keys" | while read -r line; do
                echo "${COLOR_SUCCESS}$line${COLOR_RESET}"
            done)
        else
            status+="${COLOR_WARNING}No keys loaded${COLOR_RESET}"
        fi
    else
        status="${COLOR_ERROR}✗ Not running${COLOR_RESET}\n"
        status+="${COLOR_DIM}SSH Agent is not started${COLOR_RESET}"
    fi
    echo $status
}

# Update message functions
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

# Function to list available SSH keys
list_keys() {
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

# Update the load_key function for clarity
load_key() {
    # First check if we have any valid keys
    local key_list=$(list_keys)
    if [[ -z "$key_list" ]]; then
        echo "${COLOR_ERROR}No valid SSH keys found in $SSH_KEY_DIR${COLOR_RESET}"
        return 1
    fi

    local selected_key=$(echo "$key_list" | fzf --prompt="Select SSH key to load: " \
        --preview="$PREVIEW_DIR/key_details.sh {}" \
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

# Add help function with nice formatting
show_help() {
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
    echo
    print_section "Quick Usage"
    echo "Use ${COLOR_INFO}ssha${COLOR_RESET} as an alias for ssh-management"
    echo "Run without arguments to enter interactive menu mode"
}

# Update main command function
ssh-management() {
    case $1 in
        start)
            start_ssh_agent
            ;;
        stop)
            stop_ssh_agent
            ;;
        load)
            load_key
            ;;
        unload)
            unload_key
            ;;
        list)
            list_loaded_keys
            ;;
        menu)
            ssh_menu
            ;;
        help)
            show_help
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

# Update auto-start functionality with status messages
auto_start() {
    if [[ -f $SOCK_FILE ]]; then
        export SSH_AUTH_SOCK=$(cat $SOCK_FILE)
    fi
    
    if [[ -f $PID_FILE ]]; then
        export SSH_AGENT_PID=$(cat $PID_FILE)
    fi
    
    if ! ssh-add -l &>/dev/null; then
        echo "${COLOR_DIM}Auto-starting SSH agent...${COLOR_RESET}"
        start_ssh_agent
    fi
}

# Initialize
auto_start

# Create alias
alias ssha='ssh-management'

# Add completion for the new help command
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