# Global configurations
export FZF_DEFAULT_OPTS="$FZF_DEFAULT_OPTS
  --bind='ctrl-y:execute-silent(echo {+} | pbcopy)'
  --bind='ctrl-e:execute(${EDITOR:-vim} ~/.ssh/config)'
  --header='
╭─────────── Controls ──────────╮
│ CTRL-E: edit  •  CTRL-Y: copy │
╰───────────────────────────────╯'
"

# Configuration with validation
: "${SSH_DIR:="$HOME/.ssh"}"
: "${SSH_CONFIG_FILE:="$SSH_DIR/config"}"
: "${SSH_BACKUP_DIR:="$SSH_DIR/backups"}"
: "${SSH_KEY_DIR:="$SSH_DIR/keys"}"

# 增强的目录和权限检查
setup_ssh_environment() {
    local dirs=("$SSH_DIR" "$SSH_BACKUP_DIR" "$SSH_KEY_DIR")
    for dir in "${dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            mkdir -p "$dir"
            chmod 700 "$dir"
        fi
    done
    
    # 确保配置文件存在且权限正确
    [[ ! -f "$SSH_CONFIG_FILE" ]] && touch "$SSH_CONFIG_FILE"
    chmod 600 "$SSH_CONFIG_FILE"
}

# 增强的SSH配置解析
__fzf_list_hosts() {
    awk '
    BEGIN {
        IGNORECASE = 1
        RS=""
        FS="\n"
        print "Alias|Hostname|Port|Description"
        print "─────|────────|────|───────────"
    }
    {
        user = hostname = alias = port = desc = ""
        
        for (i = 1; i <= NF; i++) {
            line = $i
            gsub(/^[ \t]+|[ \t]+$/, "", line)
            
            if (line ~ /^Host / && line !~ /[*?]/) {
                alias = substr(line, 6)
                gsub(/^[ \t]+|[ \t]+$/, "", alias)  # 添加去除空格
            }
            else if (line ~ /^HostName /) {
                hostname = substr(line, 10)
                gsub(/^[ \t]+|[ \t]+$/, "", hostname)
            }
            else if (line ~ /^User /) {
                user = substr(line, 6)
                gsub(/^[ \t]+|[ \t]+$/, "", user)
            }
            else if (line ~ /^Port /) {
                port = substr(line, 6)
                gsub(/^[ \t]+|[ \t]+$/, "", port)
            }
            else if (line ~ /^#_Desc /) {
                desc = substr(line, 8)
                gsub(/^[ \t]+|[ \t]+$/, "", desc)
            }
        }
        
        if (alias && hostname) {
            printf "%s|%s|%s|%s\n", 
                  alias, 
                  hostname, 
                  (port ? port : "22"), 
                  (desc ? desc : "No description")
        }
    }    
    ' "$SSH_CONFIG_FILE" 2>/dev/null | column -t -s "|"
}

# Enhanced SSH completion
_fzf_complete_ssh() {
    _fzf_complete --ansi --border --cycle \
        --height 80% \
        --reverse \
        --header-lines=2 \
        --prompt="SSH Remote > " \
        --preview 'host=$(echo {} | awk "{print \$1}"); 
              echo -e "\033[1;34m=== SSH Config ===\033[0m";
              ssh -G $host 2>/dev/null | 
              grep -i -E "^(hostname|port|user|identityfile|controlmaster|forwardagent|localforward|remoteforward|proxycommand) " |  
              sed -E '\''
                  s/^hostname/HostName/;
                  s/^port/Port/;
                  s/^user/User/;
                  s/^identityfile/IdentityFile/;
                  s/^controlmaster/ControlMaster/;
                  s/^forwardagent/ForwardAgent/;
                  s/^localforward/LocalForward/;
                  s/^remoteforward/RemoteForward/;
                  s/^proxycommand/ProxyCommand/
                  '\'' | 
              column -t;
              echo -e "\n\033[1;34m=== DESCRIPTION ===\033[0m"
              desc=$(echo {} | awk "{print \$4}")
              echo "${desc:-No description available}"
              ' \
        --preview-window=right:50% \
        -- "$@" < <(__fzf_list_hosts)
}

_fzf_complete_ssh_post() {
    awk '{print $1}'
}

# Enhanced telnet completion
_fzf_complete_telnet() {
  _fzf_complete --ansi --border --cycle \
    --height 80% \
    --reverse \
    --header-lines=2 \
    --prompt='Telnet Remote > ' \
    --preview 'echo "Port: 23\nProtocol: TELNET\nHost: {1}"' \
    --preview-window=right:50% \
    -- "$@" < <(__fzf_list_hosts)
}

_fzf_complete_telnet_post() {
  awk '{print $1}'
}

# Utility functions
backup_ssh_config() {
    local backup_file="$SSH_BACKUP_DIR/config_$(date +%Y%m%d_%H%M%S)"
    cp "$SSH_CONFIG_FILE" "$backup_file" && echo "Backup created: $backup_file"
}

add_host_entry() {
    local alias="$1" hostname="$2" user="$3" desc="$4" port="${5:-22}"
    
    # 输入验证
    [[ -z "$alias" || -z "$hostname" ]] && {
        echo "Error: Alias and hostname are required"
        return 1
    }
    
    # 检查主机名是否已存在
    if grep -q "^Host[[:space:]]\+${alias}[[:space:]]*$" "$SSH_CONFIG_FILE"; then
        echo "Error: Host alias '$alias' already exists"
        return 1
    fi

    # 确保在添加新条目前进行备份
    backup_ssh_config

    # 确保添加空行分隔
    [[ -s "$SSH_CONFIG_FILE" ]] && echo "" >> "$SSH_CONFIG_FILE"
    
    cat >> "$SSH_CONFIG_FILE" << EOF
Host $alias
    HostName $hostname
    Port $port
    ${user:+User $user}
    #_Desc ${desc:-No description provided}
    ServerAliveInterval 60
    ServerAliveCountMax 3
EOF

    echo "Host entry added successfully"
    chmod 600 "$SSH_CONFIG_FILE"
}

add_ssh_host() {
    local alias hostname user desc port
    
    echo "Adding new SSH host configuration"
    echo "--------------------------------"
    
    while true; do
        echo -n "Enter host alias: "
        read alias
        [[ -n "$alias" ]] && break
        echo "Error: Alias cannot be empty"
    done
    
    while true; do
        echo -n "Enter hostname: "
        read hostname
        [[ -n "$hostname" ]] && break
        echo "Error: Hostname cannot be empty"
    done
    
    echo -n "Enter port [22]: "
    read port
    port=${port:-22}
    
    echo -n "Enter username: "
    read user
    
    echo -n "Enter description: "
    read desc
    
    add_host_entry "$alias" "$hostname" "$user" "$desc" "$port"
}

delete_host_entry() {
    local alias="$1"
    local temp_file="$(mktemp)"
    local in_host_block=0
    local deleted=0

    # 确保在删除前进行备份
    backup_ssh_config
    
    # 使用临时文件进行安全的文件修改
    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$line" =~ ^[[:space:]]*Host[[:space:]]+("$alias"|$alias)[[:space:]]*$ ]]; then
            in_host_block=1
            deleted=1
            continue
        elif [[ "$line" =~ ^[[:space:]]*Host[[:space:]]+ ]] && [[ $in_host_block -eq 1 ]]; then
            in_host_block=0
        fi
        
        [[ $in_host_block -eq 0 ]] && echo "$line" >> "$temp_file"
    done < "$SSH_CONFIG_FILE"
    
    if [[ $deleted -eq 1 ]]; then
        mv "$temp_file" "$SSH_CONFIG_FILE"
        chmod 600 "$SSH_CONFIG_FILE"
        echo "Host '$alias' has been deleted"
    else
        rm "$temp_file"
        echo "Host '$alias' not found"
        return 1
    fi
}

# Interactive host deletion with fzf
delete_ssh_host() {
    echo "Select a host to delete:"
    local selected=$(__fzf_list_hosts | fzf --header-lines=2 \
        --preview 'host=$(echo {} | awk "{print \$1}"); 
            echo -e "\033[1;31m=== Warning ===\033[0m"
            echo -e "You are about to delete this host configuration!\n"
            echo -e "Press Enter to confirm deletion, press ESC to cancel!\n"
            echo -e "\033[1;34m=== SSH Config ===\033[0m"
            ssh -G "$host" 2>/dev/null | 
            grep -i -E "^(hostname|port|user|identityfile|controlmaster|forwardagent|localforward|remoteforward|proxycommand) " |  
            sed -E '\''
                s/^hostname/HostName/;
                s/^port/Port/;
                s/^user/User/;
                s/^identityfile/IdentityFile/;
                s/^controlmaster/ControlMaster/;
                s/^forwardagent/ForwardAgent/;
                s/^localforward/LocalForward/;
                s/^remoteforward/RemoteForward/;
                s/^proxycommand/ProxyCommand/
                '\'' | 
            column -t' \
        --preview-window=right:50% \
        --prompt="Select host to delete > ")
    
    if [[ -n "$selected" ]]; then
        local alias=$(echo "$selected" | awk '{print $1}')
        echo -n "Are you sure you want to delete host '$alias'? [y/N] "
        read confirm
        if [[ "${confirm:0:1}" =~ [Yy] ]]; then
            delete_host_entry "$alias"
        else
            echo "Deletion cancelled"
        fi
    else
        echo "No host selected"
    fi
}

ssh_menu() {
    while true; do
        clear
        echo "╭─────────────────────────────╮"
        echo "│     SSH Host Management     │"
        echo "╰─────────────────────────────╯"
        echo
        echo "1. List all hosts    - Show configured SSH hosts with status"
        echo "2. Add new host      - Add a new SSH host configuration"
        echo "3. Delete host       - Remove an existing host"
        echo "4. Edit SSH config   - Open config file in editor"
        echo "5. Backup SSH config - Create timestamped backup"
        echo "6. Exit              - Return to shell"
        echo
        echo -n "Enter choice (1-6): "
        read choice
        echo
        
        case $choice in
            1) 
                echo "Listing all configured SSH hosts..."
                echo
                __fzf_list_hosts
                ;;
            2) 
                echo "Starting new host configuration..."
                add_ssh_host
                ;;
            3)
                echo "Starting host deletion..."
                delete_ssh_host
                ;;
            4)
                echo "Opening SSH config in ${EDITOR:-vim}..."
                ${EDITOR:-vim} "$SSH_CONFIG_FILE"
                ;;
            5)
                echo "Creating SSH config backup..."
                backup_ssh_config
                ;;
            6) 
                echo "Exiting SSH host management..."
                return
                ;;
            *)
                echo "Invalid choice. Please enter a number between 1 and 6."
                ;;
        esac
        
        echo
        echo -n "Press Enter to continue..."
        read
    done
}

# Aliases
alias ssm='ssh_menu'
alias ssha='add_ssh_host'
alias sshl='__fzf_list_hosts'
alias sshd='delete_ssh_host'