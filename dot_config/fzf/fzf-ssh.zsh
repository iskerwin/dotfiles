# ZSH Plugin for SSH with FZF integration
# Global configurations with improved fzf preview
# export FZF_DEFAULT_OPTS="$FZF_DEFAULT_OPTS
#     --bind='ctrl-y:execute-silent(echo {+} | pbcopy)' \
#     --bind='ctrl-e:execute(${EDITOR:-vim} ~/.ssh/config)' \
#     --header='
# ╭──────────── Controls ──────────╮
# │ CTRL-E: edit   •  CTRL-Y: copy │
# ╰────────────────────────────────╯'
# "

# Base directory configurations with zsh style parameter expansion
: "${SSH_DIR:=$HOME/.ssh}"
: "${SSH_CONFIG_FILE:=$SSH_DIR/config}"
: "${SSH_BACKUP_DIR:=$SSH_DIR/backups}"
: "${SSH_KEY_DIR:=$SSH_DIR/keys}"
: "${SSH_KNOWN_HOSTS:=$SSH_DIR/known_hosts}"

# Setup SSH environment with proper permissions
setup_ssh_environment() {
    local -a dirs=("$SSH_DIR" "$SSH_BACKUP_DIR" "$SSH_KEY_DIR")
    local dir
    for dir in "${dirs[@]}"; do
        [[ ! -d "$dir" ]] && mkdir -p "$dir" && chmod 700 "$dir"
    done

    [[ ! -f "$SSH_CONFIG_FILE" ]] && touch "$SSH_CONFIG_FILE" && chmod 600 "$SSH_CONFIG_FILE"
    [[ ! -f "$SSH_KNOWN_HOSTS" ]] && touch "$SSH_KNOWN_HOSTS" && chmod 644 "$SSH_KNOWN_HOSTS"
}

# Improved list hosts with zsh formatting
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
        user = hostname = alias = port = key = desc = ""
        
        for (i = 1; i <= NF; i++) {
            line = $i
            gsub(/^[ \t]+|[ \t]+$/, "", line)
            
            if (line ~ /^Host / && line !~ /[*?]/) {
                alias = substr(line, 6)
                gsub(/^[ \t]+|[ \t]+$/, "", alias)
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
            else if (line ~ /^IdentityFile /) {
                key = substr(line, 13)
                gsub(/^[ \t]+|[ \t]+$/, "", key)
                sub(".*/", "", key)
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
    }' "$SSH_CONFIG_FILE" 2>/dev/null | column -t -s "|"
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
            grep -i -E "^(hostname|port|user|identityfile|controlmaster|forwardagent|localforward|remoteforward|proxycommand|serveraliveinterval|serveralivecountmax|tcpkeepalive|compressioncontrolpath|controlpersist) " |
            sed -E '\''
                s/^hostname/HostName/
                s/^port/Port/
                s/^user/User/
                s/^identityfile/IdentityFile/
                s/^controlmaster/ControlMaster/
                s/^forwardagent/ForwardAgent/
                s/^localforward/LocalForward/
                s/^remoteforward/RemoteForward/
                s/^proxycommand/ProxyCommand/
                s/^serveraliveinterval/ServerAliveInterval/
                s/^serveralivecountmax/ServerAliveCountMax/
                s/^tcpkeepalive/TCPKeepAlive/
                s/^compression/Compression/
                s/^controlpath/ControlPath/
                s/^controlpersist/ControlPersist/
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

# Enhanced FZF completion for TELNET
_fzf_complete_telnet() {
    _fzf_complete --ansi --border --cycle \
        --height 80% \
        --reverse \
        --header-lines=2 \
        --prompt='Telnet Remote > ' \
        --preview 'echo "Port: 23\nProtocol: TELNET\nHost: {1}\nHostName: {2}"' \
        --preview-window=right:50% \
        -- "$@" < <(__fzf_list_hosts)
}

_fzf_complete_telnet_post() {
    awk '{print $1}'
}

# Improved backup with zsh features
backup_ssh_config() {
    local backup_file="${SSH_BACKUP_DIR}/config_$(date +%Y%m%d_%H%M%S)"
    cp "$SSH_CONFIG_FILE" "$backup_file" &&
        print -P "%F{green}Backup created:%f $backup_file"
}

# Add host with improved validation
add_host_entry() {
    local alias="$1" hostname="$2" user="$3" desc="$4" port="${5:-22}" key="$6"

    if [[ -z "$alias" || -z "$hostname" ]]; then
        print -P "%F{red}Error:%f Alias and hostname are required"
        return 1
    fi

    # Check if the port is correct
    if [[ -n "$port" ]] && ! [[ "$port" =~ '^[0-9]+$' && "$port" -ge 1 && "$port" -le 65535 ]]; then
        print -P "%F{red}Error:%f Invalid port number (must be between 1-65535)"
        return 1
    fi

    # Check if hostname already exists
    if grep -q "^Host[[:space:]]\+${alias}[[:space:]]*$" "$SSH_CONFIG_FILE"; then
        print -P "%F{red}Error:%f Host alias '$alias' already exists"
        return 1
    fi

    # Make sure to back up before adding a new bar
    backup_ssh_config
    [[ -s "$SSH_CONFIG_FILE" ]] && echo "" >>"$SSH_CONFIG_FILE"

    cat >>"$SSH_CONFIG_FILE" <<EOF
Host $alias
    HostName $hostname
    Port $port
    ${user:+User $user}
    ${key:+IdentityFile $SSH_KEY_DIR/$key}
    #_Desc ${desc:-No description provided}
    ServerAliveInterval 60
    ServerAliveCountMax 3
    TCPKeepAlive yes
    Compression yes
    ControlMaster auto
    ControlPath ~/.ssh/control-%C
    ControlPersist 1h
EOF

    chmod 600 "$SSH_CONFIG_FILE"
    print -P "%F{green}Host entry added successfully%f"
}

# Interactive host addition with improved UI
add_ssh_host() {
    print -P "\n%F{blue}Adding new SSH host configuration%f"
    print -P "────────────────────────────────────"

    local alias hostname user desc port key

    while true; do
        read "alias?Enter host alias: "
        [[ -n "$alias" ]] && break
        print -P "%F{red}Error:%f Alias cannot be empty"
    done

    while true; do
        read "hostname?Enter hostname: "
        [[ -n "$hostname" ]] && break
        print -P "%F{red}Error:%f Hostname cannot be empty"
    done

    read "port?Enter port [22]: "
    port=${port:-22}

    read "user?Enter username: "

    # List available SSH keys
    print -P "\n%F{blue}Available SSH keys:%f"
    local -a keys
    while IFS= read -r -d '' key; do
        [[ $key == *.pub ]] && continue
        keys+=("$(basename "$key")")
        print -P " - $(basename "$key")"
    done < <(find "$SSH_KEY_DIR" -type f -print0)

    read "key?Enter key name (press enter to skip): "

    read "desc?Enter description: "

    add_host_entry "$alias" "$hostname" "$user" "$desc" "$port" "$key"
}

# Improved host deletion
delete_host_entry() {
    local alias="$1"
    local temp_file="$(mktemp)"
    local in_host_block=0
    local deleted=0

    backup_ssh_config

    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$line" =~ ^[[:space:]]*Host[[:space:]]+("$alias"|$alias)[[:space:]]*$ ]]; then
            in_host_block=1
            deleted=1
            continue
        elif [[ "$line" =~ ^[[:space:]]*Host[[:space:]]+ ]] && [[ $in_host_block -eq 1 ]]; then
            in_host_block=0
        fi

        [[ $in_host_block -eq 0 ]] && echo "$line" >>"$temp_file"
    done <"$SSH_CONFIG_FILE"

    if [[ $deleted -eq 1 ]]; then
        mv "$temp_file" "$SSH_CONFIG_FILE"
        chmod 600 "$SSH_CONFIG_FILE"
        print -P "%F{green}Host '$alias' has been deleted%f"
    else
        rm "$temp_file"
        print -P "%F{yellow}Host '$alias' not found%f"
        return 1
    fi
}

# Interactive host deletion with improved FZF integration
delete_ssh_host() {
    print -P "%F{blue}Select a host to delete:%f"
    local selected=$(__fzf_list_hosts | fzf --header-lines=2 \
        --preview 'host=$(echo {} | awk "{print \$1}"); 
            echo -e "\033[1;31m=== Warning ===\033[0m"
            echo -e "You are about to delete this host configuration!\n"
            echo -e "Press Enter to confirm deletion, press ESC to cancel!\n"
            echo -e "\033[1;34m=== SSH Config ===\033[0m"
            ssh -G $host 2>/dev/null | 
            grep -i -E "^(hostname|port|user|identityfile|controlmaster|forwardagent|localforward|remoteforward|proxycommand) " |
            sed -E '\''
                s/^hostname/HostName/
                s/^port/Port/
                s/^user/User/
                s/^identityfile/IdentityFile/
                s/^controlmaster/ControlMaster/
                s/^forwardagent/ForwardAgent/
                s/^localforward/LocalForward/
                s/^remoteforward/RemoteForward/
                s/^proxycommand/ProxyCommand/
                '\'' | 
            column -t;
            echo -e "\n\033[1;34m=== DESCRIPTION ===\033[0m"
            desc=$(echo {} | awk "{print \$4}")
            echo "${desc:-No description available}"
            ' \
        --preview-window=right:50% \
        --prompt="Select host to delete > ")

    if [[ -n "$selected" ]]; then
        local alias=$(echo "$selected" | awk '{print $1}')
        read "confirm?Are you sure you want to delete host '$alias'? [y/N] "
        if [[ "${confirm:0:1}" =~ [Yy] ]]; then
            delete_host_entry "$alias"
        else
            print -P "%F{yellow}Deletion cancelled%f"
        fi
    else
        print -P "%F{yellow}No host selected%f"
    fi
}

# Improved menu with zsh theming
ssh_menu() {
    while true; do
        clear
        print -P "%F{blue}
╭───────────────────────────────╮
│      SSH Host Management      │
├───────────────────────────────┤
│ 1. List hosts                 │
│ 2. Add host                   │
│ 3. Delete host                │
│ 4. Edit config                │
│ 5. Backup config              │
│ 6. Exit                       │
╰───────────────────────────────╯%f"

        read "choice?Enter choice (1-6): "
        echo

        case $choice in
        1)
            print -P "%F{blue}Listing all configured SSH hosts...%f"
            echo
            __fzf_list_hosts
            ;;
        2)
            print -P "%F{blue}Starting new host configuration...%f"
            add_ssh_host
            ;;
        3)
            print -P "%F{blue}Starting host deletion...%f"
            delete_ssh_host
            ;;
        4)
            print -P "%F{blue}Opening SSH config in ${EDITOR:-vim}...%f"
            ${EDITOR:-vim} "$SSH_CONFIG_FILE"
            ;;
        5)
            print -P "%F{blue}Creating SSH config backup...%f"
            backup_ssh_config
            ;;
        6)
            print -P "%F{blue}Exiting SSH host management...%f"
            return
            ;;
        *)
            print -P "%F{red}Invalid choice. Please enter a number between 1 and 6.%f"
            ;;
        esac

        echo
        read "?Press Enter to continue..."
    done
}

# Aliases for quick access
alias ssm='ssh_menu'
alias ssha='add_ssh_host'
alias sshl='__fzf_list_hosts'
alias sshd='delete_ssh_host'

# Initialize environment
setup_ssh_environment
