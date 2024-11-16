#!/usr/bin/env zsh

# SSH Management Tool
# This script provides a comprehensive interface for managing SSH keys and agents,
# featuring an interactive menu system with colorized output and detailed previews.

# Shared Function Generators
generate_color_definitions() {
    cat << 'EOF'
# 颜色定义
COLOR_HEADER=$'\033[1;34m'    # Bold Blue
COLOR_SUCCESS=$'\033[1;32m'   # Bold Green
COLOR_WARNING=$'\033[1;33m'   # Bold Yellow
COLOR_ERROR=$'\033[1;31m'     # Bold Red
COLOR_INFO=$'\033[1;36m'      # Bold Cyan
COLOR_RESET=$'\033[0m'        # Reset
COLOR_DIM=$'\033[2m'          # Dim
EOF
}

generate_common_functions() {
    cat << 'EOF'
# 通用函数
print_separator() {
    printf "${COLOR_HEADER}%s${COLOR_RESET}\n" "============================================================"
}

print_section() {
    echo "${COLOR_HEADER}$1${COLOR_RESET}"
    print_separator
}

check_permissions() {
    local file=$1
    local perms=$(stat -f %Lp "$file")
    if [[ $perms -eq 600 ]]; then
        echo "${COLOR_SUCCESS}OK (600)${COLOR_RESET}"
    else
        echo "${COLOR_ERROR}Warning ($perms)${COLOR_RESET}"
    fi
}

format_key_info() {
    local bits=$1 hash=$2 comment=$3 type=$4
    echo "${COLOR_SUCCESS}[$comment]${COLOR_RESET}"
    [[ -n "$type" ]] && echo "${COLOR_DIM}Type:${COLOR_RESET} $type"
    echo "${COLOR_DIM}Bits:${COLOR_RESET} $bits"
    echo "${COLOR_DIM}Hash:${COLOR_RESET} $hash"
    echo "${COLOR_DIM}────────────────────────────────────────────────────────────${COLOR_RESET}"
}

format_size() {
    local size=$1
    local scale=1
    local suffix=('B' 'KB' 'MB' 'GB' 'TB')
    local i=0
    
    while ((size > 1024 && i < ${#suffix[@]}-1)); do
        size=$(echo "scale=$scale;$size/1024" | bc)
        ((i++))
    done
    
    size=$(printf "%.2f" $size)
    echo "$size${suffix[$i]}"
}
EOF
}

# 1. Dependency Check
# Verify that fzf (fuzzy finder) is installed, as it's required for the interactive menu
if ! command -v fzf >/dev/null 2>&1; then
    echo "Error: fzf is required but not installed. Please install fzf first."
    return 1
fi

# 2. Base Variables
# Define essential paths and files used throughout the script
SSH_KEY_DIR="$HOME/.ssh"              # Directory containing SSH keys
SOCK_FILE="/tmp/ssh-agent-sock"       # File storing SSH agent socket path
PID_FILE="/tmp/ssh-agent-pid"         # File storing SSH agent process ID
PREVIEW_DIR=$(mktemp -d)              # Temporary directory for preview scripts
trap 'rm -rf "$PREVIEW_DIR"' EXIT     # Clean up preview directory on script exit


# Format socket path with colors for better readability
print_socket_path() {
    local socket_dir=$(dirname "$1")
    local socket_name=$(basename "$1")
    echo "${COLOR_DIM}$socket_dir/${COLOR_RESET}${COLOR_SUCCESS}$socket_name${COLOR_RESET}"
}

# 5. Core SSH Functions
# Find all valid SSH private keys in the SSH directory
find_ssh_keys() {
    # Use grep to filter out non-SSH key files based on typical key headers
    find "$SSH_KEY_DIR" -type f -exec grep -l "^-----BEGIN.*PRIVATE KEY-----" {} \;
}

# Get list of keys currently loaded in the SSH agent
get_loaded_keys() {
    local loaded_keys=$(ssh-add -l 2>/dev/null)
    if [[ $? -eq 0 ]]; then
        echo "$loaded_keys"
    else
        return 1
    fi
}

# Format the list of loaded keys for display
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

# Check and display current SSH agent status
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

# 6. SSH Agent Control Functions
# Start a new SSH agent if none is running
start_ssh_agent() {
    # 如果已经有正在运行的 agent，先检查其有效性
    if [[ -n "$SSH_AUTH_SOCK" ]] && [[ -n "$SSH_AGENT_PID" ]]; then
        if ssh-add -l &>/dev/null; then
            echo "${COLOR_WARNING}SSH agent is already running and working${COLOR_RESET}"
            return 0
        fi
    fi

    # 启动新的 agent
    local agent_output
    agent_output=$(ssh-agent -s)
    if [[ $? -eq 0 ]]; then
        eval "$agent_output"
        echo "$SSH_AUTH_SOCK" > "$SOCK_FILE"
        echo "$SSH_AGENT_PID" > "$PID_FILE"
        chmod 600 "$SOCK_FILE" "$PID_FILE"
        echo "${COLOR_SUCCESS}Started new SSH agent${COLOR_RESET}"
        return 0
    else
        echo "${COLOR_ERROR}Failed to start SSH agent${COLOR_RESET}"
        return 1
    fi
}

# Stop the running SSH agent and clean up files
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

# 7. SSH Key Management Functions
# Interactive key loading function using fzf
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

# Interactive key unloading function using fzf
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

# Find a local key file matching a given fingerprint
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

# Display all currently loaded SSH keys and agent status
list_loaded_keys() {
    local loaded_keys=$(get_loaded_keys)
    if [[ $? -ne 0 ]]; then
        echo "${COLOR_ERROR}No keys loaded in SSH agent${COLOR_RESET}"
        return 1
    fi

    local selected_key=$(echo "$loaded_keys" | fzf --prompt="Currently loaded SSH keys: " \
        --preview="$PREVIEW_DIR/loaded_key_preview.sh {}" \
        --preview-window=right:60%:wrap \
        --color='hl:12,hl+:15,pointer:4,marker:4' \
        --border=rounded \
        --margin=1 \
        --padding=1 \
        --header="Loaded SSH Keys" \
        --header-first \
        --no-select-1)
    
    if [[ -n "$selected_key" ]]; then
        local fingerprint=$(echo "$selected_key" | awk '{print $2}')
        local key_file=$(find_key_by_fingerprint "$fingerprint")
        
        if [[ -n "$key_file" ]]; then
            echo "${COLOR_INFO}Selected key details:${COLOR_RESET}"
            echo "File: $key_file"
            echo "Fingerprint: $fingerprint"
            ssh-keygen -l -f "$key_file"
        else
            echo "${COLOR_WARNING}Could not find matching local key file${COLOR_RESET}"
        fi
    fi
}

# Create preview scripts for fzf
create_preview_scripts() {
    local color_definitions=$(generate_color_definitions)
    local common_functions=$(generate_common_functions)

    # key_preview.sh - Shows detailed information about an SSH key file    
    {
        echo "#!/usr/bin/env zsh"
        echo "$color_definitions"
        echo "$common_functions"
        cat << 'EOF'
key=$1

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
    comment=$(echo "$key_info" | awk '{print $3}')
    type=$(echo "$key_info" | awk '{$1=$2=$3=""; print substr($0,4)}')
    created=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$key")
    
    echo "${COLOR_INFO}Type:${COLOR_RESET}        $type"
    echo "${COLOR_INFO}Bits:${COLOR_RESET}        $bits"
    echo "${COLOR_INFO}Fingerprint:${COLOR_RESET} $fingerprint"
    echo "${COLOR_INFO}Comment:${COLOR_RESET}     $comment"
    echo "${COLOR_INFO}Created:${COLOR_RESET}     $created"
    echo "${COLOR_INFO}Permissions:${COLOR_RESET} $(check_permissions "$key")"
fi

if [[ -f "${key}.pub" ]]; then
    echo
    print_section "📄 Public Key"
    pubkey=$(cat "${key}.pub")
    key_type=$(echo "$pubkey" | awk '{print $1}')
    key_comment=$(echo "$pubkey" | awk '{$1=$2=""; print substr($0,3)}')
    
    echo "${COLOR_INFO}Type:${COLOR_RESET}    $key_type"
    echo "${COLOR_INFO}Comment:${COLOR_RESET} $key_comment"
    echo
    echo "${COLOR_SUCCESS}Full Public Key:${COLOR_RESET}"
    echo "$pubkey"
fi
EOF
    } > "$PREVIEW_DIR/key_preview.sh"
    chmod +x "$PREVIEW_DIR/key_preview.sh"

    local color_definitions=$(generate_color_definitions)
    local common_functions=$(generate_common_functions)

    # loaded_key_preview.sh - Shows information about currently loaded keys
    {
        echo "#!/usr/bin/env zsh"
        echo "$color_definitions"
        echo "$common_functions"
        cat << 'EOF'
key_info="$@"

print_section "🔑 Loaded Key Details"
bits=$(echo "$key_info" | awk '{print $1}')
fingerprint=$(echo "$key_info" | awk '{print $2}')
comment=$(echo "$key_info" | awk '{print $3}')
type=$(echo "$key_info" | awk '{$1=$2=$3=""; print substr($0,4)}')

echo "${COLOR_INFO}Type:${COLOR_RESET}        $type"
echo "${COLOR_INFO}Bits:${COLOR_RESET}        $bits"
echo "${COLOR_INFO}Fingerprint:${COLOR_RESET} $fingerprint"
echo "${COLOR_INFO}Comment:${COLOR_RESET}     $comment"

echo
print_section "📂 Local Key File"
for key in $(find ~/.ssh -type f -not -name "*.pub"); do
    if [[ -f "$key" ]] && ssh-keygen -l -f "$key" &>/dev/null; then
        key_fp=$(ssh-keygen -l -f "$key" | awk '{print $2}')
        if [[ "$fingerprint" == "$key_fp" ]]; then
            created=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$key")
            echo "${COLOR_INFO}Path:${COLOR_RESET}        $key"
            echo "${COLOR_INFO}Created:${COLOR_RESET}     $created"
            echo "${COLOR_INFO}Permissions:${COLOR_RESET} $(check_permissions "$key")"
            
            if [[ -f "${key}.pub" ]]; then
                echo
                echo "${COLOR_INFO}Public Key:${COLOR_RESET}"
                cat "${key}.pub"
            fi
            exit 0
        fi
    fi
done
echo "${COLOR_WARNING}No matching local key file found${COLOR_RESET}"
EOF
    } > "$PREVIEW_DIR/loaded_key_preview.sh"
    chmod +x "$PREVIEW_DIR/loaded_key_preview.sh"

    local color_definitions=$(generate_color_definitions)
    local common_functions=$(generate_common_functions)
    
    # menu_preview.sh - Shows context-sensitive information in the main menu
    {
        echo "#!/usr/bin/env zsh"
        echo "$color_definitions"
        echo "$common_functions"
        cat << 'EOF'
selected=$1
ssh_sock=$2
ssh_pid=$3

print_agent_status() {
    print_section "🔄 SSH Agent Status"
    if [[ -S "$ssh_sock" ]]; then
        echo "${COLOR_SUCCESS}✓ Agent is running${COLOR_RESET}"
        echo "${COLOR_INFO}PID:${COLOR_RESET}    $ssh_pid"
        echo "${COLOR_INFO}Uptime:${COLOR_RESET} $(ps -o etime= -p "$ssh_pid" 2>/dev/null || echo "N/A")"
        echo "${COLOR_INFO}Socket:${COLOR_RESET} $ssh_sock"
        
        echo
        echo "${COLOR_INFO}Environment:${COLOR_RESET}"
        echo "${COLOR_DIM}SSH_AUTH_SOCK:${COLOR_RESET} ${COLOR_SUCCESS}Set${COLOR_RESET}"
        echo "${COLOR_DIM}SSH_AGENT_PID:${COLOR_RESET} ${COLOR_SUCCESS}Set${COLOR_RESET}"
    else
        echo "${COLOR_ERROR}✗ Agent is not running${COLOR_RESET}"
        echo
        echo "${COLOR_INFO}Environment:${COLOR_RESET}"
        [[ -z "$SSH_AUTH_SOCK" ]] && echo "${COLOR_DIM}SSH_AUTH_SOCK:${COLOR_RESET} ${COLOR_ERROR}Not Set${COLOR_RESET}" || echo "${COLOR_DIM}SSH_AUTH_SOCK:${COLOR_RESET} ${COLOR_SUCCESS}Set${COLOR_RESET}"
        [[ -z "$SSH_AGENT_PID" ]] && echo "${COLOR_DIM}SSH_AGENT_PID:${COLOR_RESET} ${COLOR_ERROR}Not Set${COLOR_RESET}" || echo "${COLOR_DIM}SSH_AGENT_PID:${COLOR_RESET} ${COLOR_SUCCESS}Set${COLOR_RESET}"
    fi
}

print_loaded_keys() {
    print_section "🔑 Loaded Keys"
    loaded_keys=$(ssh-add -l 2>/dev/null)
    if [[ $? -eq 0 ]]; then
        local key_count=0
        local preview_content=""
        
        while read -r bits hash comment type; do
            if [[ -n "$bits" ]]; then
                ((key_count++))
                preview_content+="${COLOR_SUCCESS}[$comment]${COLOR_RESET}\n"
                preview_content+="${COLOR_DIM}Type:${COLOR_RESET} $type\n"
                preview_content+="${COLOR_DIM}Bits:${COLOR_RESET} $bits\n"
                preview_content+="${COLOR_DIM}Hash:${COLOR_RESET} $hash\n"
                preview_content+="${COLOR_DIM}────────────────────────────────────────────────────────────${COLOR_RESET}\n"
            fi
        done <<< "$loaded_keys"
        
        echo -e "$preview_content"
        echo "${COLOR_INFO}Total Keys:${COLOR_RESET} $key_count"
    else
        echo "${COLOR_WARNING}No keys currently loaded${COLOR_RESET}"
    fi
}

format_size() {
    local size=$1
    local scale=1
    local suffix=('B' 'KB' 'MB' 'GB' 'TB')
    local i=0
    
    while ((size > 1024 && i < ${#suffix[@]}-1)); do
        size=$(echo "scale=$scale;$size/1024" | bc)
        ((i++))
    done
    
    size=$(printf "%.2f" $size)
    echo "$size${suffix[$i]}"
}

print_available_keys() {
    print_section "📂 Available SSH Keys"
    local key_count=0
    local total_size=0
    local preview_content=""
    
    while read -r key; do
        if [[ -f "$key" ]] && ssh-keygen -l -f "$key" &>/dev/null; then
            ((key_count++))
            total_size=$((total_size + $(stat -f %z "$key")))
            
            key_info=$(ssh-keygen -l -f "$key")
            local bits=$(echo "$key_info" | awk '{print $1}')
            local hash=$(echo "$key_info" | awk '{print $2}')
            local type=$(echo "$key_info" | awk '{$1=$2=$3=""; print substr($0,4)}')
            
            local comment=""
            if [[ -f "${key}.pub" ]]; then
                comment=$(awk '{print $NF}' "${key}.pub" 2>/dev/null)
            fi
            
            preview_content+="${COLOR_SUCCESS}[$(basename "$key")]${COLOR_RESET}\n"
            preview_content+="${COLOR_DIM}Type:${COLOR_RESET} $type\n"
            preview_content+="${COLOR_DIM}Bits:${COLOR_RESET} $bits\n"
            preview_content+="${COLOR_DIM}Hash:${COLOR_RESET} $hash\n"
            preview_content+="${COLOR_DIM}Path:${COLOR_RESET} $key\n"
            preview_content+="${COLOR_DIM}Size:${COLOR_RESET} $(format_size $(stat -f %z "$key"))\n"
            if [[ -n "$comment" ]]; then
                preview_content+="${COLOR_DIM}Comment:${COLOR_RESET} $comment\n"
            fi
            preview_content+="${COLOR_DIM}────────────────────────────────────────────────────────────${COLOR_RESET}\n"
        fi
    done < <(find ~/.ssh -type f -not -name "*.pub" -not -name "known_hosts*" -not -name "config" -not -name ".DS_Store")
    
    echo -e "$preview_content"
    echo "${COLOR_INFO}Total Keys:${COLOR_RESET} $key_count"
    echo "${COLOR_INFO}Total Size:${COLOR_RESET} $(format_size $total_size)"
}

print_section "📌 Current Selection"
echo "${COLOR_INFO}$selected${COLOR_RESET}"
echo

case $selected in
    "Start SSH Agent")
        if [[ -S "$ssh_sock" ]]; then
            echo "${COLOR_WARNING}Notice: SSH Agent is already running${COLOR_RESET}"
            echo
        fi
        print_agent_status
        ;;
    "Stop SSH Agent")
        print_agent_status
        echo
        print_loaded_keys
        ;;
    "Load Key")
        print_agent_status
        echo
        print_available_keys
        ;;
    "Unload Key")
        print_agent_status
        echo
        print_loaded_keys
        ;;
    "List Loaded Keys")
        print_agent_status
        echo
        print_loaded_keys
        ;;
    *)
        # 默认视图
        print_agent_status
        echo
        print_loaded_keys
        ;;
esac
EOF
    } > "$PREVIEW_DIR/menu_preview.sh"
    chmod +x "$PREVIEW_DIR/menu_preview.sh"
}

# 9. Interactive Menu Function
# Main menu interface using fzf
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

# 10. Auto-start and Initialization
# Automatically start SSH agent if needed
auto_start() {
    # 首先检查是否已经有正在运行的 agent
    if [[ -n "$SSH_AUTH_SOCK" ]] && [[ -n "$SSH_AGENT_PID" ]]; then
        # 检查当前环境变量指向的 agent 是否可用
        if ssh-add -l &>/dev/null; then
            echo "${COLOR_DIM}SSH agent already running and working${COLOR_RESET}"
            return 0
        fi
    fi

    # 检查持久化的 socket 和 pid 文件
    if [[ -f "$SOCK_FILE" && -f "$PID_FILE" ]]; then
        local stored_sock=$(cat "$SOCK_FILE")
        local stored_pid=$(cat "$PID_FILE")
        
        # 临时设置环境变量测试存储的 agent
        local old_sock=$SSH_AUTH_SOCK
        local old_pid=$SSH_AGENT_PID
        export SSH_AUTH_SOCK=$stored_sock
        export SSH_AGENT_PID=$stored_pid
        
        # 验证存储的 agent 是否可用
        if kill -0 "$stored_pid" 2>/dev/null && ssh-add -l &>/dev/null; then
            echo "${COLOR_DIM}Reconnected to existing SSH agent${COLOR_RESET}"
            return 0
        fi
        
        # 如果存储的 agent 不可用，恢复原来的环境变量
        export SSH_AUTH_SOCK=$old_sock
        export SSH_AGENT_PID=$old_pid
    fi

    # 如果没有可用的 agent，启动新的
    echo "${COLOR_DIM}Auto-starting SSH agent...${COLOR_RESET}"
    start_ssh_agent
}

# 11. Main Function and Command Completion
# Main command interface function
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

# Initialize the script
create_preview_scripts

# ZSH command completion configuration
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

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # 直接执行脚本的情况
    ssh-management "$@"
else
    # 通过 source 加载脚本的情况
    create_preview_scripts
    auto_start
    alias ssha='ssh-management'
fi