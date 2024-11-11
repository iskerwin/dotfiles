#!/usr/bin/env zsh

# SSH Agent Manager
# 设置样式
local CYAN='\033[0;36m'
local GREEN='\033[0;32m'
local YELLOW='\033[1;33m'
local RED='\033[0;31m'
local NC='\033[0m'

# 检查依赖
if ! command -v fzf >/dev/null 2>&1; then
    echo "${RED}Error: fzf is not installed${NC}"
    echo "Please install fzf first:"
    echo "  brew install fzf    # macOS"
    echo "  apt install fzf     # Ubuntu/Debian"
    return 1
fi

# 创建用于存储 SSH Agent 环境变量的文件
SSH_AGENT_ENV="$HOME/.ssh/agent.env"
SSH_DIR="$HOME/.ssh"

# 确保 .ssh 目录存在
[[ ! -d "$SSH_DIR" ]] && mkdir -p "$SSH_DIR"

# 初始化 SSH Agent
function init_ssh_agent() {
    echo "${CYAN}Initializing SSH agent...${NC}"
    ssh-agent -s | sed 's/^echo/#echo/' > "${SSH_AGENT_ENV}"
    chmod 600 "${SSH_AGENT_ENV}"
    source "${SSH_AGENT_ENV}" > /dev/null
    echo "${GREEN}SSH agent initialized${NC}"
}

# 检查 SSH Agent 是否正在运行
function check_ssh_agent() {
    if [ -f "${SSH_AGENT_ENV}" ]; then
        source "${SSH_AGENT_ENV}" > /dev/null
        ps -ef | grep ${SSH_AGENT_PID} | grep ssh-agent > /dev/null || {
            init_ssh_agent
        }
    else
        init_ssh_agent
    fi
}

# 获取所有可用的 SSH 密钥
function get_available_keys() {
    local keys=()
    # 查找常见的私钥模式
    local patterns=("id_*" "*.pem" "*_rsa" "*_ed25519" "*_ecdsa" "*_dsa" "identity")
    
    for pattern in "${patterns[@]}"; do
        while IFS= read -r key; do
            # 排除 .pub 文件和其他非私钥文件
            if [[ -f "$key" && ! "$key" =~ \.pub$ && ! "$key" =~ known_hosts && ! "$key" =~ config ]]; then
                # 提取文件名
                local key_name=$(basename "$key")
                keys+=("$key_name")
            fi
        done < <(find "$SSH_DIR" -maxdepth 1 -type f -name "$pattern" 2>/dev/null)
    done
    
    # 如果找到了密钥，打印它们
    if (( ${#keys[@]} > 0 )); then
        printf "%s\n" "${keys[@]}" | sort -u
    else
        echo "${YELLOW}No SSH keys found in $SSH_DIR${NC}" >&2
        return 1
    fi
}

# 获取当前已加载的密钥指纹和路径
function get_loaded_keys() {
    ssh-add -l | while read -r bits fingerprint comment; do
        echo "$bits $fingerprint $comment"
    done
}

# 添加 SSH 密钥
function add_key() {
    check_ssh_agent
    local key_file
    if [ -z "$1" ]; then
        # 使用 fzf 显示可用的密钥及其详细信息
        key_file=$(get_available_keys | fzf --height 40% \
            --reverse \
            --prompt="Select key to add: " \
            --preview "echo 'Key: {}'; echo 'Path: $SSH_DIR/{}'; 
                      if [[ -f '$SSH_DIR/{}' ]]; then
                          ssh-keygen -l -f '$SSH_DIR/{}'
                      fi")
    else
        key_file="$1"
    fi
    
    if [ -n "$key_file" ]; then
        local full_path="$SSH_DIR/$key_file"
        if [[ -f "$full_path" ]]; then
            echo "${CYAN}Adding key: $key_file${NC}"
            ssh-add "$full_path"
        else
            echo "${RED}Key file not found: $full_path${NC}"
        fi
    fi
}

# 删除指定的 SSH 密钥
function remove_key() {
    check_ssh_agent
    local key_info
    
    # 首先检查是否有密钥已加载
    if ! ssh-add -l &>/dev/null; then
        echo "${YELLOW}No keys currently loaded in the SSH agent${NC}"
        return 1
    fi

    if [ -z "$1" ]; then
        # 使用 fzf 显示已加载的密钥及其详细信息
        key_info=$(ssh-add -l | fzf --height 40% \
            --reverse \
            --prompt="Select key to remove: " \
            --preview "echo 'Selected key:'; echo '-------------'; 
                      echo 'Bits: {1}'; 
                      echo 'Fingerprint: {2}'; 
                      echo 'Comment: {3}'")
        
        if [ -n "$key_info" ]; then
            # 从注释中提取密钥文件名
            local key_comment=$(echo "$key_info" | awk '{$1=""; $2=""; sub(/^[ \t]+/, ""); print}')
            
            # 查找匹配的私钥文件
            local key_file
            local found=0
            
            # 搜索 SSH_DIR 中的私钥文件
            for file in "$SSH_DIR"/*; do
                if [[ -f "$file" && ! "$file" =~ \.pub$ && ! "$file" =~ known_hosts && ! "$file" =~ config ]]; then
                    # 获取此文件的公钥信息
                    local key_info_from_file=$(ssh-keygen -l -f "$file" 2>/dev/null)
                    if echo "$key_info_from_file" | grep -q "$key_comment"; then
                        key_file="$file"
                        found=1
                        break
                    fi
                fi
            done
            
            if [[ $found -eq 1 ]]; then
                echo "${YELLOW}Removing key: $key_comment${NC}"
                ssh-add -d "$key_file"
            else
                # 如果找不到匹配的文件，尝试直接删除
                echo "${YELLOW}Could not find key file, attempting to remove using comment: $key_comment${NC}"
                ssh-add -d
            fi
        fi
    else
        local full_path="$SSH_DIR/$1"
        if [[ -f "$full_path" ]]; then
            echo "${YELLOW}Removing key: $1${NC}"
            ssh-add -d "$full_path"
        else
            echo "${RED}Key file not found: $full_path${NC}"
        fi
    fi
}

# 列出所有已加载的密钥
function list_keys() {
    check_ssh_agent
    echo "${CYAN}Currently loaded SSH keys:${NC}"
    local output=$(ssh-add -l)
    if [[ $? -eq 0 ]]; then
        echo "$output" | while read -r bits fingerprint comment; do
            echo "  Bits: $bits"
            echo "  Fingerprint: $fingerprint"
            echo "  Comment: $comment"
            echo "  ---"
        done
    else
        echo "${YELLOW}No keys currently loaded${NC}"
    fi
}

# 删除所有密钥
function remove_all_keys() {
    check_ssh_agent
    echo "${YELLOW}Removing all SSH keys...${NC}"
    ssh-add -D
    echo "${GREEN}All keys removed${NC}"
}

# 关闭 SSH Agent
function kill_agent() {
    if [ -f "${SSH_AGENT_ENV}" ]; then
        source "${SSH_AGENT_ENV}" > /dev/null
        echo "${YELLOW}Killing SSH agent...${NC}"
        eval $(ssh-agent -k)
        rm -f "${SSH_AGENT_ENV}"
        echo "${GREEN}SSH agent terminated${NC}"
    else
        echo "${RED}No SSH agent found${NC}"
    fi
}

# 主菜单
function ssh_manager() {
    local choice
    choice=$(echo -e "1. Start SSH Agent\n2. Add Key\n3. List Keys\n4. Remove Key\n5. Remove All Keys\n6. Kill SSH Agent" | \
        fzf --height 40% \
            --reverse \
            --prompt="SSH Agent Manager > " \
            --header="Select an option:" \
            --header-lines=0 \
            --preview 'echo "Current Status:"; echo "-------------"; 
                      ps aux | grep "[s]sh-agent" || echo "No SSH agent running";
                      echo "\nLoaded Keys:"; echo "-------------";
                      ssh-add -l 2>/dev/null || echo "No keys loaded"')

    case $choice in
        "1. Start SSH Agent")
            check_ssh_agent
            ;;
        "2. Add Key")
            add_key
            ;;
        "3. List Keys")
            list_keys
            ;;
        "4. Remove Key")
            remove_key
            ;;
        "5. Remove All Keys")
            remove_all_keys
            ;;
        "6. Kill SSH Agent")
            kill_agent
            ;;
    esac
}

# 设置命令别名
alias sshag="ssh_manager"