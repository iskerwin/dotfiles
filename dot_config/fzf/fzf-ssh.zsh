# ZSH Plugin for SSH with FZF integration
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

# Enhanced SSH completion with custom bindings and header
_fzf_complete_ssh() {
    _fzf_complete --ansi --border --cycle \
        --height 100% \
        --reverse \
        --header-lines=2 \
        --header='
╭──────────── Controls ──────────╮
│ CTRL-E: edit   •  CTRL-Y: copy │
╰────────────────────────────────╯' \
        --bind='ctrl-y:execute-silent(echo {+} | pbcopy)' \
        --bind='ctrl-e:execute(${EDITOR:-vim} ~/.ssh/config)' \
        --prompt="SSH Remote > " \
        --preview '
            host=$(echo {} | awk "{print \$1}")
            echo -e "\033[1;34m=== SSH Config ===\033[0m"
            ssh -G $host 2>/dev/null | 
            grep -i -E "^(hostname|port|user|identityfile|controlmaster|forwardagent|localforward|remoteforward|proxycommand|serveraliveinterval|serveralivecountmax|tcpkeepalive|compressioncontrolpath|controlpersist) " |
            sed -E '"'"'
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
                '"'"' | 
            column -t

            # Get SSH connection details
            ssh_config=$(ssh -G $host 2>/dev/null)
            key_file=$(echo "$ssh_config" | grep "^identityfile " | head -n1 | cut -d" " -f2)
            real_hostname=$(echo "$ssh_config" | grep "^hostname " | head -n1 | cut -d" " -f2)
            user=$(echo "$ssh_config" | grep "^user " | head -n1 | cut -d" " -f2)
            port=$(echo "$ssh_config" | grep "^port " | head -n1 | cut -d" " -f2)
            port=${port:-22}  # Default to port 22 if not specified

            echo -e "\n\033[1;34m=== CONNECTION INFO ===\033[0m"
            echo -e "Host:\t\t$real_hostname"
            echo -e "Port:\t\t${port:-22}"
            echo -e "User:\t\t${user:-$(whoami)}"
            if [ -n "$key_file" ]; then
                echo -e "Key File:\t$key_file"
            fi

            # Check SSH key if specified
            if [ -n "$key_file" ]; then
                echo -e "\n\033[1;34m=== KEY STATUS ===\033[0m"
                if [ -f "${key_file/#\~/$HOME}" ]; then
                    echo -e "\033[0;32m✓\033[0m Key exists: $key_file"
                    key_perms=$(stat -f "%Lp" "${key_file/#\~/$HOME}" 2>/dev/null)
                    if [ "$key_perms" = "600" ]; then
                        echo -e "\033[0;32m✓\033[0m Key permissions correct (600)"
                    else
                        echo -e "\033[0;31m✗\033[0m Key permissions incorrect: $key_perms (should be 600)"
                    fi
                    
                    # Verify key format
                    if ssh-keygen -l -f "${key_file/#\~/$HOME}" >/dev/null 2>&1; then
                        echo -e "\033[0;32m✓\033[0m SSH key is valid"
                        key_info=$(ssh-keygen -l -f "${key_file/#\~/$HOME}" 2>/dev/null)
                        echo -e "\033[0;90m$key_info\033[0m"
                    else
                        echo -e "\033[0;31m✗\033[0m Invalid SSH key format"
                    fi
                else
                    echo -e "\033[0;31m✗\033[0m Key not found: $key_file"
                fi
            fi

            echo -e "\n\033[1;34m=== CONNECTIVITY TEST ===\033[0m"
            if nc -z -w 2 $real_hostname $port >/dev/null 2>&1; then
                echo -e "\033[0;32m✓\033[0m Port $port is open on $real_hostname"
                
                if [[ $real_hostname == "github.com" ]]; then
                    echo -e "\n\033[1;34m=== GITHUB SSH TEST ===\033[0m"
                    ssh_output=$(ssh -T git@github.com -o ConnectTimeout=3 2>&1)
                    if [[ $ssh_output == *"successfully authenticated"* ]]; then
                        echo -e "\033[0;32m✓\033[0m GitHub SSH authentication successful"
                    else
                        echo -e "\033[0;31m✗\033[0m GitHub SSH authentication failed"
                        echo -e "\033[0;90m$ssh_output\033[0m"
                    fi
                else
                    # Get SSH banner and auth methods in one connection attempt
                    ssh_response=$(ssh -o PreferredAuthentications=none -o ConnectTimeout=3 "$host" 2>&1)
                    
                    # Extract and display auth methods
                    echo -e "\n\033[1;34m=== AUTH METHODS ===\033[0m"
                    auth_methods=$(echo "$ssh_response" | grep -i "authentication methods" | cut -d":" -f2-)
                    if [ -n "$auth_methods" ]; then
                        echo -e "Available methods:$auth_methods"
                    else
                        echo -e "\033[0;33m!\033[0m Unable to detect authentication methods"
                    fi
                    
                    # Try to detect if the server accepts password authentication
                    if ssh -o ConnectTimeout=3 -o BatchMode=yes "$host" true >/dev/null 2>&1; then
                        echo -e "\033[0;32m✓\033[0m Publickey authentication available"
                    elif [[ $auth_methods == *"password"* ]]; then
                        echo -e "\033[0;33m!\033[0m Password authentication required"
                    else
                        echo -e "\033[0;33m!\033[0m Authentication method unclear, try manual connection"
                    fi

                    # Extract and display banner/login notice
                    echo -e "\n\033[1;34m=== LOGIN NOTICE ===\033[0m"
                    # Filter out the "Permission denied" and "Please try again" messages
                    banner=$(echo "$ssh_response" | grep -v "Permission denied" | grep -v "Please try again" | grep -v "authentication methods" | head -n 10)
                    if [ -n "$banner" ]; then
                        echo -e "\033[0;90m$banner\033[0m"
                    else
                        echo "No login notice available"
                    fi
                fi
            else
                echo -e "\033[0;31m✗\033[0m Cannot reach $real_hostname:$port"
            fi

            echo -e "\n\033[1;34m=== DESCRIPTION ===\033[0m"
            desc=$(echo {} | awk "{print \$4}")
            echo "${desc:-No description available}"
        ' \
        --preview-window=right:50% \
        -- "$@" < <(__fzf_list_hosts)
}

# Enhanced TELNET completion with custom bindings and header
_fzf_complete_telnet() {
    _fzf_complete --ansi --border --cycle \
        --height 90% \
        --reverse \
        --header-lines=2 \
        --header='
╭──────────── Controls ──────────╮
│ CTRL-E: edit   •  CTRL-Y: copy │
╰────────────────────────────────╯' \
        --bind='ctrl-y:execute-silent(echo {+} | pbcopy)' \
        --bind='ctrl-e:execute(${EDITOR:-vim} ~/.ssh/config)' \
        --prompt='Telnet Remote > ' \
        --preview 'host=$(echo {1});
            real_host=$(echo {2});
            port=23;

            echo -e "\033[1;34m=== HOST INFO ===\033[0m"
            printf "%-12s %s\n" "Host:" "$host"
            printf "%-12s %s\n" "Hostname:" "$real_host"
            printf "%-12s %s\n" "Port:" "$port"
            printf "%-12s %s\n" "Protocol:" "TELNET"

            echo -e "\n\033[1;34m=== CONNECTIVITY TEST ===\033[0m"
            if nc -z -w 2 $real_host $port >/dev/null 2>&1; then
                echo -e "\033[0;32m✓\033[0m Port $port is open on $real_host"
                
                # Try telnet connection with perl-based timeout
                telnet_output=$(perl -e '\''
                    eval {
                        local $SIG{ALRM} = sub { die "timeout\n" };
                        alarm 3;
                        $output = `echo "quit" | telnet $ARGV[0] $ARGV[1] 2>&1`;
                        alarm 0;
                        print $output;
                    };
                    if ($@ eq "timeout\n") {
                        exit 1;
                    }
                '\'' "$real_host" "$port" | grep -v "^Trying" | head -n 3)
                telnet_status=$?
                
                if [ $telnet_status -eq 0 ] && [[ $telnet_output == *"Connected to"* ]]; then
                    echo -e "\033[0;32m✓\033[0m Telnet connection successful"
                    echo -e "\033[0;90m$telnet_output\033[0m"
                else
                    echo -e "\033[0;31m✗\033[0m Telnet connection failed"
                    echo -e "\033[0;90m$telnet_output\033[0m"
                fi
            else
                echo -e "\033[0;31m✗\033[0m Cannot reach $real_host:$port"
            fi
            
            # Try resolving hostname
            echo -e "\n\033[1;34m=== DNS RESOLUTION ===\033[0m"
            if ip=$(dig +short $real_host); then
                if [ -n "$ip" ]; then
                    echo -e "\033[0;32m✓\033[0m Resolves to: $ip"
                else
                    echo -e "\033[0;31m✗\033[0m Could not resolve hostname"
                fi
            else
                echo -e "\033[0;31m✗\033[0m DNS lookup failed"
            fi
            ' \
        --preview-window=right:50% \
        -- "$@" < <(__fzf_list_hosts)
}

_fzf_complete_ssh_post() {
    awk '{print $1}'
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
