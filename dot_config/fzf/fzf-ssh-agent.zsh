#!/usr/bin/env zsh

# SSH Management Tool
# A comprehensive interface for managing SSH keys and agents with:
# - Interactive menu system with colorized output
# - Detailed key information previews
# - Automated agent management
# - Command-line and interactive modes

#-----------------------------------------------------------------------------
# 1. Base Configuration
#-----------------------------------------------------------------------------
SSH_KEY_DIR="$HOME/.ssh"              # Directory containing SSH keys
SOCK_FILE="/tmp/ssh-agent-sock"       # Socket file location
PID_FILE="/tmp/ssh-agent-pid"         # PID file location
PREVIEW_DIR=$(mktemp -d)              # Temporary directory for preview scripts
trap 'rm -rf "$PREVIEW_DIR"' EXIT     # Clean up preview directory on exit

#-----------------------------------------------------------------------------
# 2. Color Definitions and Common Utilities
#-----------------------------------------------------------------------------
COLOR_DEFINITIONS='
# ANSI color codes for output formatting
COLOR_HEADER=$'"'"'\033[1;34m'"'"'    # Bold Blue
COLOR_SUCCESS=$'"'"'\033[1;32m'"'"'   # Bold Green
COLOR_WARNING=$'"'"'\033[1;33m'"'"'   # Bold Yellow
COLOR_ERROR=$'"'"'\033[1;31m'"'"'     # Bold Red
COLOR_INFO=$'"'"'\033[1;36m'"'"'      # Bold Cyan
COLOR_RESET=$'"'"'\033[0m'"'"'        # Reset
COLOR_DIM=$'"'"'\033[2m'"'"'          # Dim
'

COMMON_FUNCTIONS='
# Utility functions for formatting and displaying information

# Print a horizontal separator line
print_separator() {
    printf "${COLOR_HEADER}%s${COLOR_RESET}\n" "============================================================"
}

# Print a section header with separator
print_section() {
    echo "${COLOR_HEADER}$1${COLOR_RESET}"
    print_separator
}

# Check and format file permissions
check_permissions() {
    local file=$1
    local perms=$(stat -f %Lp "$file")
    if [[ $perms -eq 600 ]]; then
        echo "${COLOR_SUCCESS}OK (600)${COLOR_RESET}"
    else
        echo "${COLOR_ERROR}Warning ($perms)${COLOR_RESET}"
    fi
}

# Format key information for display
format_key_info() {
    local bits=$1 hash=$2 comment=$3 type=$4
    echo "${COLOR_SUCCESS}[$comment]${COLOR_RESET}"
    [[ -n "$type" ]] && echo "${COLOR_DIM}Type:${COLOR_RESET} $type"
    echo "${COLOR_DIM}Bits:${COLOR_RESET} $bits"
    echo "${COLOR_DIM}Hash:${COLOR_RESET} $hash"
    echo "${COLOR_DIM}────────────────────────────────────────────────────────────${COLOR_RESET}"
}

# Format file sizes with appropriate units
format_size() {
    local size=$1
    local scale=1
    local suffix=('"'"'B'"'"' '"'"'KB'"'"' '"'"'MB'"'"' '"'"'GB'"'"' '"'"'TB'"'"')
    local i=0
    
    while ((size > 1024 && i < ${#suffix[@]}-1)); do
        size=$(echo "scale=$scale;$size/1024" | bc)
        ((i++))
    done
    
    size=$(printf "%.2f" $size)
    echo "$size${suffix[$i]}"
}

# Format socket path with highlighting
print_socket_path() {
    local socket_dir=$(dirname "$1")
    local socket_name=$(basename "$1")
    echo "${COLOR_DIM}$socket_dir/${COLOR_RESET}${COLOR_SUCCESS}$socket_name${COLOR_RESET}"
}
'

#-----------------------------------------------------------------------------
# 3. Core SSH Functions
#-----------------------------------------------------------------------------

# Find all SSH private keys in the SSH directory
find_ssh_keys() {
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

# Format and display loaded keys
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

#-----------------------------------------------------------------------------
# 4. SSH Agent Management
#-----------------------------------------------------------------------------

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

# Start a new SSH agent if none is running
start_ssh_agent() {
    if [[ -n "$SSH_AUTH_SOCK" ]] && [[ -n "$SSH_AGENT_PID" ]]; then
        if ssh-add -l &>/dev/null; then
            echo "${COLOR_WARNING}SSH agent is already running and working${COLOR_RESET}"
            return 0
        fi
    fi

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

# Auto-start SSH agent if needed
auto_start() {
    if [[ -n "$SSH_AUTH_SOCK" ]] && [[ -n "$SSH_AGENT_PID" ]]; then
        if ssh-add -l &>/dev/null; then
            echo "${COLOR_DIM}SSH agent already running and working${COLOR_RESET}"
            return 0
        fi
    fi

    if [[ -f "$SOCK_FILE" && -f "$PID_FILE" ]]; then
        local stored_sock=$(cat "$SOCK_FILE")
        local stored_pid=$(cat "$PID_FILE")
        
        local old_sock=$SSH_AUTH_SOCK
        local old_pid=$SSH_AGENT_PID
        export SSH_AUTH_SOCK=$stored_sock
        export SSH_AGENT_PID=$stored_pid
        
        if kill -0 "$stored_pid" 2>/dev/null && ssh-add -l &>/dev/null; then
            echo "${COLOR_DIM}Reconnected to existing SSH agent${COLOR_RESET}"
            return 0
        fi
        
        export SSH_AUTH_SOCK=$old_sock
        export SSH_AGENT_PID=$old_pid
    fi

    echo "${COLOR_DIM}Auto-starting SSH agent...${COLOR_RESET}"
    start_ssh_agent
}

#-----------------------------------------------------------------------------
# 5. SSH Key Management Functions
#-----------------------------------------------------------------------------

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

#-----------------------------------------------------------------------------
# 5. SSH Key Management Functions (continued)
#-----------------------------------------------------------------------------

# Interactive key loading function using fzf
load_key() {
    local key_list=$(find_ssh_keys)
    if [[ -z "$key_list" ]]; then
        echo "${COLOR_ERROR}No valid SSH keys found in $SSH_KEY_DIR${COLOR_RESET}"
        return 1
    fi

    # Display interactive key selection menu
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
    
    # Display interactive key unloading menu
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

# Display and manage loaded SSH keys
list_loaded_keys() {
    local loaded_keys=$(get_loaded_keys)
    if [[ $? -ne 0 ]]; then
        echo "${COLOR_ERROR}No keys loaded in SSH agent${COLOR_RESET}"
        return 1
    fi

    # Display interactive key listing menu
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

#-----------------------------------------------------------------------------
# 6. Preview Script Generation
#-----------------------------------------------------------------------------

# Generate preview script from content
generate_preview_script() {
    local script_path=$1
    local script_content=$2
    
    {
        echo "#!/usr/bin/env zsh"
        echo "$COLOR_DEFINITIONS"
        echo "$COMMON_FUNCTIONS"
        echo "$script_content"
    } > "$script_path"
    chmod +x "$script_path"
}

# Create all preview scripts for fzf interface
create_preview_scripts() {
    # Key Preview Script - Shows detailed information about an SSH key file
    local key_preview_content='
key=$1

if [[ ! -f "$key" ]]; then
    print_section "❌ Error"
    echo "${COLOR_ERROR}Invalid SSH key file${COLOR_RESET}"
    exit 1
fi

print_section "🔑 Key Information"
key_info=$(ssh-keygen -l -f "$key" 2>/dev/null)
if [[ $? -eq 0 ]]; then
    bits=$(echo "$key_info" | awk '"'"'{print $1}'"'"')
    fingerprint=$(echo "$key_info" | awk '"'"'{print $2}'"'"')
    comment=$(echo "$key_info" | awk '"'"'{print $3}'"'"')
    type=$(echo "$key_info" | awk '"'"'{$1=$2=$3=""; print substr($0,4)}'"'"')
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
    key_type=$(echo "$pubkey" | awk '"'"'{print $1}'"'"')
    key_comment=$(echo "$pubkey" | awk '"'"'{$1=$2=""; print substr($0,3)}'"'"')
    
    echo "${COLOR_INFO}Type:${COLOR_RESET}    $key_type"
    echo "${COLOR_INFO}Comment:${COLOR_RESET} $key_comment"
    echo
    echo "${COLOR_SUCCESS}Full Public Key:${COLOR_RESET}"
    echo "$pubkey"
fi'
    generate_preview_script "$PREVIEW_DIR/key_preview.sh" "$key_preview_content"

    # Loaded Key Preview Script - Shows information about currently loaded keys
    local loaded_key_preview_content='
key_info="$@"

print_section "🔑 Loaded Key Details"
bits=$(echo "$key_info" | awk '"'"'{print $1}'"'"')
fingerprint=$(echo "$key_info" | awk '"'"'{print $2}'"'"')
comment=$(echo "$key_info" | awk '"'"'{print $3}'"'"')
type=$(echo "$key_info" | awk '"'"'{$1=$2=$3=""; print substr($0,4)}'"'"')

echo "${COLOR_INFO}Type:${COLOR_RESET}        $type"
echo "${COLOR_INFO}Bits:${COLOR_RESET}        $bits"
echo "${COLOR_INFO}Fingerprint:${COLOR_RESET} $fingerprint"
echo "${COLOR_INFO}Comment:${COLOR_RESET}     $comment"

echo
print_section "📂 Local Key File"
for key in $(find ~/.ssh -type f -not -name "*.pub"); do
    if [[ -f "$key" ]] && ssh-keygen -l -f "$key" &>/dev/null; then
        key_fp=$(ssh-keygen -l -f "$key" | awk '"'"'{print $2}'"'"')
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
echo "${COLOR_WARNING}No matching local key file found${COLOR_RESET}"'
    generate_preview_script "$PREVIEW_DIR/loaded_key_preview.sh" "$loaded_key_preview_content"

    # Menu Preview Script - Shows context-sensitive information in the main menu
    local menu_preview_content='
selected=$1
ssh_sock=$2
ssh_pid=$3

# Display current SSH agent status
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

# Display information about loaded keys
print_loaded_keys() {
    print_section "🔑 Loaded Keys"
    loaded_keys=$(ssh-add -l 2>/dev/null)
    if [[ $? -eq 0 ]]; then
        local key_count=0
        local preview_content=""
        
        while read -r bits hash comment type; do
            if [[ -n "$bits" ]]; then
                ((key_count++))
                format_key_info "$bits" "$hash" "$comment" "$type"
            fi
        done <<< "$loaded_keys"
        
        echo "${COLOR_INFO}Total Keys:${COLOR_RESET} $key_count"
    else
        echo "${COLOR_WARNING}No keys currently loaded${COLOR_RESET}"
    fi
}

# Display information about available SSH keys
print_available_keys() {
    print_section "📂 Available SSH Keys"
    local key_count=0
    local total_size=0
    
    while read -r key; do
        # 首先检查文件是否是私钥格式
        if [[ -f "$key" ]] && grep -q "BEGIN.*PRIVATE KEY" "$key" 2>/dev/null; then
            if ssh-keygen -l -f "$key" &>/dev/null; then
                ((key_count++))
                total_size=$((total_size + $(stat -f %z "$key")))
                
                key_info=$(ssh-keygen -l -f "$key")
                local bits=$(echo "$key_info" | awk '"'"'{print $1}'"'"')
                local hash=$(echo "$key_info" | awk '"'"'{print $2}'"'"')
                local type=$(echo "$key_info" | awk '"'"'{$1=$2=$3=""; print substr($0,4)}'"'"')
                
                local comment=""
                if [[ -f "${key}.pub" ]]; then
                    comment=$(awk '"'"'{print $NF}'"'"' "${key}.pub" 2>/dev/null)
                fi
                
                format_key_info "$bits" "$hash" "$(basename "$key")" "$type"
                echo "${COLOR_DIM}Path:${COLOR_RESET} $key"
                echo "${COLOR_DIM}Size:${COLOR_RESET} $(format_size $(stat -f %z "$key"))"
                [[ -n "$comment" ]] && echo "${COLOR_DIM}Comment:${COLOR_RESET} $comment"
                echo "${COLOR_DIM}────────────────────────────────────────────────────────────${COLOR_RESET}"
            fi
        fi
    done < <(find ~/.ssh -type f -not -name "*.pub" -not -name "known_hosts*" -not -name "config" -not -name ".DS_Store")
    
    echo "${COLOR_INFO}Total Keys:${COLOR_RESET} $key_count"
    echo "${COLOR_INFO}Total Size:${COLOR_RESET} $(format_size $total_size)"
}

print_section "📌 Current Selection"
echo "${COLOR_INFO}$selected${COLOR_RESET}"
echo

# Show context-sensitive preview based on selected menu item
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
        print_agent_status
        echo
        print_loaded_keys
        ;;
esac'
    generate_preview_script "$PREVIEW_DIR/menu_preview.sh" "$menu_preview_content"
}

#-----------------------------------------------------------------------------
# 7. Interactive Menu Interface
#-----------------------------------------------------------------------------

# Main menu interface using fzf
ssha_menu() {
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

#-----------------------------------------------------------------------------
# Auto-start and Initialization
#-----------------------------------------------------------------------------

# Automatically start SSH agent if needed
auto_start() {
    if [[ -n "$SSH_AUTH_SOCK" ]] && [[ -n "$SSH_AGENT_PID" ]]; then
        if ssh-add -l &>/dev/null; then
            echo "${COLOR_DIM}SSH agent already running and working${COLOR_RESET}"
            return 0
        fi
    fi

    if [[ -f "$SOCK_FILE" && -f "$PID_FILE" ]]; then
        local stored_sock=$(cat "$SOCK_FILE")
        local stored_pid=$(cat "$PID_FILE")
        
        local old_sock=$SSH_AUTH_SOCK
        local old_pid=$SSH_AGENT_PID
        export SSH_AUTH_SOCK=$stored_sock
        export SSH_AGENT_PID=$stored_pid
        
        if kill -0 "$stored_pid" 2>/dev/null && ssh-add -l &>/dev/null; then
            echo "${COLOR_DIM}Reconnected to existing SSH agent${COLOR_RESET}"
            return 0
        fi
        
        export SSH_AUTH_SOCK=$old_sock
        export SSH_AGENT_PID=$old_pid
    fi

    echo "${COLOR_DIM}Auto-starting SSH agent...${COLOR_RESET}"
    start_ssh_agent
}

#-----------------------------------------------------------------------------
# Main Function and Command Completion
#-----------------------------------------------------------------------------

# Main command interface function
ssha-management() {
    case $1 in
        start) start_ssh_agent ;;
        stop) stop_ssh_agent ;;
        load) load_key ;;
        unload) unload_key ;;
        list) list_loaded_keys ;;
        menu) ssha_menu ;;
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
            ssha_menu
            ;;
    esac
}

# Initialize the script
create_preview_scripts

# ZSH command completion configuration
_ssha_management() {
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
    ssha-management "$@"
else
    create_preview_scripts
    auto_start
    alias ssha='ssha-management'
fi