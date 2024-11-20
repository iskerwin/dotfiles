# ZSH Plugin for SSH with FZF integration
#######################################################
# Core SSH functionality and configuration management #
#######################################################
# Base directory configurations with zsh style parameter expansion
: "${SSH_DIR:=$HOME/.ssh}"
: "${SSH_CONFIG_FILE:=$SSH_DIR/config}"
: "${SSH_KNOWN_HOSTS:=$SSH_DIR/known_hosts}"

# Setup SSH environment with proper permissions
setup_ssh_environment() {
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
        print "Alias|Hostname|Port"
        print "─────|────────|────"
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
            printf "%s|%s|%s\n", 
                    alias, 
                    hostname, 
                    (port ? port : "22")
        }
    }' "$SSH_CONFIG_FILE" 2>/dev/null | column -t -s "|"
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
╭────────────── Controls ─────────────╮
│ CTRL-E: edit   •  CTRL-Y: copy host │
╰─────────────────────────────────────╯' \
        --bind='ctrl-y:execute-silent(echo {+} | pbcopy)' \
        --bind='ctrl-e:execute(${EDITOR:-nvim} ~/.ssh/config)' \
        --prompt="SSH Remote > " \
        --preview '
            # Constants
            SUCCESS_ICON=$'"'"'\033[0;32m✓\033[0m'"'"'
            WARNING_ICON=$'"'"'\033[0;33m!\033[0m'"'"'
            ERROR_ICON=$'"'"'\033[0;31m✗\033[0m'"'"'
            INFO_ICON=$'"'"'\033[0;34mℹ\033[0m'"'"'
            COLOR_HEADER=$'"'"'\033[1;34m'"'"'
            COLOR_DETAIL=$'"'"'\033[0;90m'"'"'
            COLOR_RESET=$'"'"'\033[0m'"'"'

            ssh_timeout=3
            connect_timeout=2

            # Helper functions
            print_header() {
                echo -e "\n${COLOR_HEADER}$1${COLOR_RESET}"
                echo -e "${COLOR_HEADER}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_RESET}"
            }

            print_detail() {
                echo -e "${COLOR_DETAIL}$1${COLOR_RESET}"
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
            user=$(echo "$ssh_config" | grep "^user " | head -n1 | cut -d" " -f2)

            # Get description from SSH config
            config_file="$HOME/.ssh/config"
            if [ -f "$config_file" ]; then
                desc=$(awk -v host="$host" '"'"'
                    $1 == "Host" { 
                        in_block = 0
                        if ($2 == host || host ~ "^"$2"$") {
                            in_block = 1
                        }
                    }
                    in_block && /^[[:space:]]*#_Desc[[:space:]]/ {
                        sub(/^[[:space:]]*#_Desc[[:space:]]*/, "")
                        desc = $0
                        gsub(/^[[:space:]]+|[[:space:]]+$/, "", desc)
                        print desc
                        exit
                    }
                '"'"' "$config_file")
            fi
            
            # Start with host summary
            print_header "🔖 HOST SUMMARY"
            {
                [ -n "$host" ] && echo "Host: $host"
                [ -n "$real_hostname" ] && echo "HostName: $real_hostname"
                [ -n "$user" ] && echo "User: $user"
                [ -n "$port" ] && echo "Port: $port"
                [ -n "$key_file" ] && echo "Key: $key_file"
            } | column -t
            
            print_detail "${desc:-No description}"

            # Check connectivity first
            print_header "🌐 CONNECTIVITY"
            if ! nc -z -G 2 $real_hostname $port >/dev/null 2>&1; then
                echo -e "$ERROR_ICON Cannot reach $real_hostname:$port"
                exit 0
            fi
            echo -e "$SUCCESS_ICON Connected to $real_hostname:$port"

            # Check key status if exists
            if [ -n "$key_file" ]; then
                print_header "🔑 KEY STATUS"
                expanded_key="${key_file/#\~/$HOME}"
                
                if [ ! -f "$expanded_key" ]; then
                    echo -e "$ERROR_ICON No identity file specified or found: $key_file"
                else
                    echo -e "$SUCCESS_ICON Key exists:  $key_file"
                    
                    # Check permissions
                    key_perms=$(stat -f "%Lp" "$expanded_key" 2>/dev/null)
                    [ "$key_perms" = "600" ] && \
                        echo -e "$SUCCESS_ICON Permissions: OK (600)" || \
                        echo -e "$ERROR_ICON Invalid permissions: $key_perms (should be 600)"
                    
                    # Check key format and display detailed information
                    if ssh-keygen -l -f "$expanded_key" >/dev/null 2>&1; then
                        echo -e "$SUCCESS_ICON Valid key format"
                        
                        # Get key details
                        key_info=$(ssh-keygen -l -f "$expanded_key" 2>/dev/null)
                        bits=$(echo "$key_info" | awk '"'"'{print $1}'"'"')
                        hash=$(echo "$key_info" | awk '"'"'{print $2}'"'"')
                        comment=$(echo "$key_info" | awk '"'"'{$1=$2=""; sub(/^[ \t]+/, ""); print}'"'"' | sed '"'"'s/ (.*)//'"'"')
                        type=$(echo "$key_info" | grep -o '"'"'([^)]*)'"'"')
                        
                        # Display structured information
                        echo -e "${COLOR_DETAIL}  [$comment]"
                        echo -e "  Type: $type"
                        echo -e "  Bits: $bits"
                        echo -e "  Hash: $hash${COLOR_RESET}"
                    else
                        echo -e "$ERROR_ICON Invalid key format"
                    fi
                fi
            fi

            # Authentication check
            print_header "🔐 AUTHENTICATION"
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
            else
                echo -e "$WARNING_ICON Authentication required"
                ssh_banner=$(ssh -o ConnectTimeout=$connect_timeout -o PreferredAuthentications=none "$host" 2>&1)
                auth_methods=$(echo "$ssh_banner" | grep -i "authentication methods" | cut -d":" -f2-)
                [ -n "$auth_methods" ] && echo -e "$INFO_ICON Available methods:$auth_methods"
                
                # Show clean banner message if available
                banner=$(echo "$ssh_banner" | grep -v -E "Permission denied|Please try again|authentication methods|Connection closed|Connection timed out" | head -n 10)
                [ -n "$banner" ] && print_detail "\n$banner"
            fi
            column -t
        ' \
        --preview-window=right:60% \
        -- "$@" < <(list_ssh_hosts)
}

_fzf_complete_ssh_post() {
    awk '{print $1}'
}