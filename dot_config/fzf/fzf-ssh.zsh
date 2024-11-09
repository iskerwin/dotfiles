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

            print_detail() {
                echo -e "${DETAIL_COLOR}$1\033[0m"
            }

            run_ssh_command() {
                timeout $ssh_timeout ssh -o BatchMode=yes -o ConnectTimeout=$connect_timeout "$@"
            }

            # Get host and basic info
            host=$(echo {} | awk "{print \$1}")
            ssh_config=$(ssh -G $host 2>/dev/null)
            real_hostname=$(echo "$ssh_config" | grep "^hostname " | head -n1 | cut -d" " -f2)
            port=$(echo "$ssh_config" | grep "^port " | head -n1 | cut -d" " -f2)
            port=${port:-22}
            key_file=$(echo "$ssh_config" | grep "^identityfile " | head -n1 | cut -d" " -f2)
            
            # Start with host summary
            print_header "HOST SUMMARY"
            {
                echo "Host: $host"
                echo "HostName: $real_hostname"
                echo "Port: $port"
                [ -n "$key_file" ] && echo "Key: $key_file"
            } | column -t
            
            desc=$(echo {} | awk "{print \$4}")
            [ -n "$desc" ] && print_detail "$desc"

            # Check connectivity first
            print_header "CONNECTIVITY"
            if ! nc -z -w $connect_timeout $real_hostname $port >/dev/null 2>&1; then
                echo -e "$ERROR_ICON Cannot reach $real_hostname:$port"
                exit 0
            fi
            echo -e "$SUCCESS_ICON Connected to $real_hostname:$port"

            # Check key status if exists
            if [ -n "$key_file" ]; then
                print_header "KEY STATUS"
                expanded_key="${key_file/#\~/$HOME}"
                
                if [ ! -f "$expanded_key" ]; then
                    echo -e "$ERROR_ICON Key not found: $key_file"
                else
                    echo -e "$SUCCESS_ICON Key exists: $key_file"
                    key_perms=$(stat -f "%Lp" "$expanded_key" 2>/dev/null)
                    [ "$key_perms" = "600" ] && \
                        echo -e "$SUCCESS_ICON Permissions OK (600)" || \
                        echo -e "$ERROR_ICON Invalid permissions: $key_perms (should be 600)"
                    
                    if ssh-keygen -l -f "$expanded_key" >/dev/null 2>&1; then
                        key_info=$(ssh-keygen -l -f "$expanded_key" 2>/dev/null)
                        echo -e "$SUCCESS_ICON Valid key format"
                        print_detail "$key_info"
                    else
                        echo -e "$ERROR_ICON Invalid key format"
                    fi
                fi
            fi

            # Authentication check
            print_header "AUTHENTICATION"
            if [[ $real_hostname == "github.com" ]]; then
                ssh_output=$(ssh -T git@github.com -o ConnectTimeout=$connect_timeout 2>&1)
                if [[ $ssh_output == *"successfully authenticated"* ]]; then
                    echo -e "$SUCCESS_ICON GitHub authentication successful"
                    print_detail "$ssh_output"
                else
                    echo -e "$ERROR_ICON GitHub authentication failed"
                    print_detail "$ssh_output"
                fi
            elif ssh -o BatchMode=yes -o ConnectTimeout=$connect_timeout "$host" exit 2>/dev/null; then
                echo -e "$SUCCESS_ICON Authentication successful"
                
                # Get system info more efficiently
                system_info=$(run_ssh_command "$host" '"'"'
                    echo "OS: $(uname -sr 2>/dev/null)"
                    echo "Load: $(uptime | sed '"'"'s/.*load average: //'"'"')"
                    echo "Memory: $(free -h 2>/dev/null | awk '"'"'/^Mem:/ {print "Total: " $2 " Used: " $3 " Free: " $4}'"'"')"
                '"'"' 2>/dev/null)
                
                if [ -n "$system_info" ]; then
                    print_detail "$system_info"
                    # Show last login only if system info was successful
                    last_login=$(run_ssh_command "$host" "last -1 2>/dev/null | head -n 1")
                    [ -n "$last_login" ] && print_detail "Last login: $last_login"
                fi
            else
                echo -e "$WARNING_ICON Authentication required"
                ssh_banner=$(ssh -o ConnectTimeout=$connect_timeout -o PreferredAuthentications=none "$host" 2>&1)
                auth_methods=$(echo "$ssh_banner" | grep -i "authentication methods" | cut -d":" -f2-)
                [ -n "$auth_methods" ] && echo -e "$INFO_ICON Available methods:$auth_methods"
                
                # Show clean banner message if available
                banner=$(echo "$ssh_banner" | grep -v -E "Permission denied|Please try again|authentication methods|Connection closed|Connection timed out" | head -n 10)
                [ -n "$banner" ] && print_detail "\n$banner"
            fi

            # Show relevant SSH config
            print_header "SSH CONFIG"
            echo "$ssh_config" | grep -i -E "^(hostname|port|user|identityfile|proxycommand|localforward|remoteforward)" | \
            sed -E '"'"'
                s/^hostname/HostName/
                s/^port/Port/
                s/^user/User/
                s/^identityfile/IdentityFile/
                s/^proxycommand/ProxyCommand/
                s/^localforward/LocalForward/
                s/^remoteforward/RemoteForward/
            '"'"' | column -t
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
        --preview '
            # Constants
            SUCCESS_ICON=$'\''\033[0;32m✓\033[0m'\''
            WARNING_ICON=$'\''\033[0;33m!\033[0m'\''
            ERROR_ICON=$'\''\033[0;31m✗\033[0m'\''
            INFO_ICON=$'\''\033[0;34mℹ\033[0m'\''
            HEADER_COLOR=$'\''\033[1;34m'\''
            DETAIL_COLOR=$'\''\033[0;90m'\''

            print_header() {
                echo -e "\n${HEADER_COLOR}=== $1 ===\033[0m"
            }

            print_detail() {
                echo -e "${DETAIL_COLOR}$1\033[0m"
            }

            host=$(echo {1})
            real_host=$(echo {2})
            port=23

            # Basic host info
            print_header "HOST INFO"
            {
                echo "Host: $host"
                echo "Hostname: $real_host"
                echo "Port: $port"
                echo "Protocol: TELNET"
            } | column -t

            # Connectivity test
            print_header "CONNECTIVITY TEST"
            if nc -z -w 2 $real_host $port >/dev/null 2>&1; then
                echo -e "$SUCCESS_ICON Port $port is open on $real_host"
                
                # Enhanced telnet probing with more details
                telnet_output=$(perl -e '\''
                    eval {
                        local $SIG{ALRM} = sub { die "timeout\n" };
                        alarm 5;  # Increased timeout for more reliable results
                        $output = `echo "help\nquit" | telnet $ARGV[0] $ARGV[1] 2>&1`;
                        alarm 0;
                        print $output;
                    };
                    if ($@ eq "timeout\n") {
                        exit 1;
                    }
                '\'' "$real_host" "$port" | grep -v "^Trying")
                telnet_status=$?
                
                if [ $telnet_status -eq 0 ] && [[ $telnet_output == *"Connected to"* ]]; then
                    echo -e "$SUCCESS_ICON Telnet connection successful"
                    print_detail "Connection Details:"
                    echo "$telnet_output" | head -n 5 | while read line; do
                        print_detail "  $line"
                    done
                else
                    echo -e "$ERROR_ICON Telnet connection failed"
                    print_detail "$telnet_output"
                fi
            else
                echo -e "$ERROR_ICON Cannot reach $real_host:$port"
            fi
            
            # Enhanced DNS information
            print_header "DNS RESOLUTION"
            if dig_output=$(dig +short $real_host); then
                if [ -n "$dig_output" ]; then
                    echo -e "$SUCCESS_ICON DNS Resolution successful"
                    echo "$dig_output" | while read ip; do
                        print_detail "IP: $ip"
                        # Try reverse DNS lookup
                        reverse=$(dig +short -x $ip)
                        [ -n "$reverse" ] && print_detail "PTR: $reverse"
                    done
                else
                    echo -e "$ERROR_ICON Could not resolve hostname"
                fi
            else
                echo -e "$ERROR_ICON DNS lookup failed"
            fi

            # Service Banner (if available)
            print_header "SERVICE INFORMATION"
            banner_output=$(perl -e '\''
                eval {
                    local $SIG{ALRM} = sub { die "timeout\n" };
                    alarm 3;
                    $output = `nc -w 3 $ARGV[0] $ARGV[1] 2>&1`;
                    alarm 0;
                    print $output;
                };
                if ($@ eq "timeout\n") {
                    exit 1;
                }
            '\'' "$real_host" "$port" | head -n 3)
            
            if [ -n "$banner_output" ]; then
                echo -e "$INFO_ICON Service banner detected:"
                print_detail "$banner_output"
            else
                echo -e "$WARNING_ICON No service banner available"
            fi

            # Response Time Test
            print_header "RESPONSE TIME"
            ping_result=$(ping -c 1 $real_host 2>/dev/null | grep "time=" | cut -d "=" -f 4)
            if [ -n "$ping_result" ]; then
                echo -e "$SUCCESS_ICON Response time: $ping_result"
            else
                echo -e "$WARNING_ICON Could not measure response time"
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