# ZSH Plugin for SSH with FZF integration
#######################################################
# Core SSH functionality and configuration management #
#######################################################
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

# Basic list hosts function
list_ssh_hosts() {
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

# Core backup function
backup_ssh_config() {
    local backup_file="${SSH_BACKUP_DIR}/config_$(date +%Y%m%d_%H%M%S)"
    cp "$SSH_CONFIG_FILE" "$backup_file" &&
        print -P "%F{green}Backup created:%f $backup_file"
}

# Core host entry management functions
add_host_entry() {
    local alias="$1" hostname="$2" user="$3" desc="$4" port="${5:-22}" key="$6"

    if [[ -z "$alias" || -z "$hostname" ]]; then
        print -P "%F{red}Error:%f Alias and hostname are required"
        return 1
    fi

    if [[ -n "$port" ]] && ! [[ "$port" =~ '^[0-9]+$' && "$port" -ge 1 && "$port" -le 65535 ]]; then
        print -P "%F{red}Error:%f Invalid port number (must be between 1-65535)"
        return 1
    fi

    if grep -q "^Host[[:space:]]\+${alias}[[:space:]]*$" "$SSH_CONFIG_FILE"; then
        print -P "%F{red}Error:%f Host alias '$alias' already exists"
        return 1
    fi

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

# Initialize environment
setup_ssh_environment

#######################################################
# UI and interaction functionality for SSH management #
#######################################################
# FZF integration for SSH completions
_fzf_complete_ssh() {
    _fzf_complete --ansi --border --cycle \
        --height 100% \
        --reverse \
        --header-lines=2 \
        --header='
╭────────────── Controls ──────────────╮
│ CTRL-E: edit   •  CTRL-Y: copy host  │
╰────────────────────────────────────╯' \
        --bind='ctrl-y:execute-silent(echo {+} | pbcopy)' \
        --bind='ctrl-e:execute(${EDITOR:-vim} ~/.ssh/config)' \
        --prompt="SSH Remote > " \
        --preview '
            # Constants
            SUCCESS_ICON=$'"'"'\033[0;32m✓\033[0m'"'"'
            WARNING_ICON=$'"'"'\033[0;33m!\033[0m'"'"'
            ERROR_ICON=$'"'"'\033[0;31m✗\033[0m'"'"'
            INFO_ICON=$'"'"'\033[0;34mℹ\033[0m'"'"'
            HEADER_COLOR=$'"'"'\033[1;34m'"'"'
            DETAIL_COLOR=$'"'"'\033[0;90m'"'"'
            
            ssh_timeout=3
            connect_timeout=2

            # Helper functions
            print_header() {
                echo -e "\n${HEADER_COLOR}=== $1 ===\033[0m"
            }

            run_ssh_command() {
                timeout $ssh_timeout ssh -o BatchMode=yes -o ConnectTimeout=$connect_timeout "$@"
            }

            # Get host from selection
            host=$(echo {} | awk "{print \$1}")

            # Get all SSH config at once
            ssh_config=$(ssh -G $host 2>/dev/null)
            real_hostname=$(echo "$ssh_config" | grep "^hostname " | head -n1 | cut -d" " -f2)
            port=$(echo "$ssh_config" | grep "^port " | head -n1 | cut -d" " -f2)
            port=${port:-22}
            key_file=$(echo "$ssh_config" | grep "^identityfile " | head -n1 | cut -d" " -f2)

            print_header "SSH Config"
            echo "$ssh_config" | 
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

            # Check SSH key status
            if [ -n "$key_file" ]; then
                print_header "KEY STATUS"
                if [ -f "${key_file/#\~/$HOME}" ]; then
                    echo -e "$SUCCESS_ICON Key exists: $key_file"
                    key_perms=$(stat -f "%Lp" "${key_file/#\~/$HOME}" 2>/dev/null)
                    if [ "$key_perms" = "600" ]; then
                        echo -e "$SUCCESS_ICON Key permissions correct (600)"
                    else
                        echo -e "$ERROR_ICON Key permissions incorrect: $key_perms (should be 600)"
                    fi
                    
                    if ssh-keygen -l -f "${key_file/#\~/$HOME}" >/dev/null 2>&1; then
                        echo -e "$SUCCESS_ICON SSH key is valid"
                        key_info=$(ssh-keygen -l -f "${key_file/#\~/$HOME}" 2>/dev/null)
                        echo -e "$DETAIL_COLOR$key_info\033[0m"
                    else
                        echo -e "$ERROR_ICON Invalid SSH key format"
                    fi
                else
                    echo -e "$ERROR_ICON Key not found: $key_file"
                fi
            fi

            print_header "CONNECTIVITY TEST"
            if nc -z -w $connect_timeout $real_hostname $port >/dev/null 2>&1; then
                echo -e "$SUCCESS_ICON Port $port is open on $real_hostname"
                
                if [[ $real_hostname == "github.com" ]]; then
                    print_header "GITHUB SSH TEST"
                    ssh_output=$(ssh -T git@github.com -o ConnectTimeout=$connect_timeout 2>&1)
                    if [[ $ssh_output == *"successfully authenticated"* ]]; then
                        echo -e "$SUCCESS_ICON GitHub SSH authentication successful"
                        echo -e "$DETAIL_COLOR$ssh_output\033[0m"
                    else
                        echo -e "$ERROR_ICON GitHub SSH authentication failed"
                        echo -e "$DETAIL_COLOR$ssh_output\033[0m"
                    fi
                else
                    ssh_banner=$(ssh -o ConnectTimeout=$connect_timeout -o PreferredAuthentications=none "$host" 2>&1)
                    
                    print_header "AUTH STATUS"
                    if ssh -o BatchMode=yes -o ConnectTimeout=$connect_timeout "$host" exit 2>/dev/null; then
                        echo -e "$SUCCESS_ICON SSH authentication successful"
                        
                        # Get system information
                        system_info=$(run_ssh_command "$host" '"'"'
                            echo "System: $(uname -sr 2>/dev/null || echo Unknown)"
                            echo "Hostname: $(hostname -f 2>/dev/null || echo Unknown)"
                            echo "Uptime: $(uptime 2>/dev/null || echo Unknown)"
                            echo "Load: $(cat /proc/loadavg 2>/dev/null || echo Unknown)"
                            echo "Memory: $(free -h 2>/dev/null | grep "Mem:" | awk '"'"'"'"'"'"'"'"'{ print "Total: " $2 " Used: " $3 " Free: " $4 }'"'"'"'"'"'"'"'"' || echo Unknown)"
                        '"'"' 2>/dev/null)
                        
                        if [ -n "$system_info" ]; then
                            echo -e "$DETAIL_COLOR$system_info\033[0m"
                        fi
                        
                        # Get last login
                        last_login=$(run_ssh_command "$host" "last -1 2>/dev/null | head -n 1" 2>/dev/null)
                        if [ -n "$last_login" ]; then
                            echo -e "$DETAIL_COLOR\nLast login: $last_login\033[0m"
                        fi
                    else
                        echo -e "$WARNING_ICON Authentication required"
                        
                        auth_methods=$(echo "$ssh_banner" | grep -i "authentication methods" | cut -d":" -f2-)
                        if [ -n "$auth_methods" ]; then
                            echo -e "$INFO_ICON Available methods:$auth_methods"
                        fi
                    fi

                    print_header "LOGIN NOTICE"
                    banner=$(echo "$ssh_banner" | grep -v -E "Permission denied|Please try again|authentication methods|Connection closed|Connection timed out" | head -n 10)
                    if [ -n "$banner" ]; then
                        echo -e "$DETAIL_COLOR$banner\033[0m"
                    else
                        echo "No login notice available"
                    fi
                fi
            else
                echo -e "$ERROR_ICON Cannot reach $real_hostname:$port"
            fi

            print_header "DESCRIPTION"
            desc=$(echo {} | awk "{print \$4}")
            echo "${desc:-No description available}"
        ' \
        --preview-window=right:50% \
        -- "$@" < <(list_ssh_hosts)
}

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
        -- "$@" < <(list_ssh_hosts)
}

_fzf_complete_ssh_post() {
    awk '{print $1}'
}

_fzf_complete_telnet_post() {
    awk '{print $1}'
}

# Interactive host management functions
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

delete_ssh_host() {
    print -P "%F{blue}Select a host to delete:%f"
    local selected=$(list_ssh_hosts | fzf --header-lines=2 \
        --header='
╭──────────── Controls ──────────╮
│ CTRL-E: edit   •  CTRL-Y: copy │
╰────────────────────────────────╯' \
        --bind='ctrl-y:execute-silent(echo {+} | pbcopy)' \
        --bind='ctrl-e:execute(${EDITOR:-vim} ~/.ssh/config)' \
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

# Interactive menu function
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
            list_ssh_hosts
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
alias sshl='list_ssh_hosts'
alias sshd='delete_ssh_host'