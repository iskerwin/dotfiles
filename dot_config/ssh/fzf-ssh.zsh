# ZSH Plugin for SSH with FZF integration

#================================================#
# Core SSH functionality                         #
#================================================#
# Base directory configurations with zsh style parameter expansion
: "${SSH_DIR:=$HOME/.ssh}"
: "${SSH_CONFIG_FILE:=$SSH_DIR/config}"
: "${SSH_KNOWN_HOSTS:=$SSH_DIR/known_hosts}"

# Setup SSH environment with proper permissions
setup_ssh_environment() {
    # Check and create SSH directory with proper permissions
    [[ ! -d "$SSH_DIR" ]] && mkdir -p "$SSH_DIR" && chmod 700 "$SSH_DIR"
    [[ ! -f "$SSH_CONFIG_FILE" ]] && touch "$SSH_CONFIG_FILE" && chmod 600 "$SSH_CONFIG_FILE"
    [[ ! -f "$SSH_KNOWN_HOSTS" ]] && touch "$SSH_KNOWN_HOSTS" && chmod 644 "$SSH_KNOWN_HOSTS"
    
    # Validate SSH config file format
    if ! ssh -G localhost >/dev/null 2>&1; then
        echo "Warning: SSH config file format error detected" >&2
        return 1
    fi
}

# Basic list hosts function
list_ssh_hosts() {
    if [[ ! -r "$SSH_CONFIG_FILE" ]]; then
        echo "Error: Unable to read SSH config file" >&2
        return 1
    fi

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

#================================================#
# UI and interaction functionality               #
#================================================#
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
            # Dracula Theme Colors
            SUCCESS_ICON=$'"'"'\033[38;2;80;250;123m✓\033[0m'"'"'     # Green
            WARNING_ICON=$'"'"'\033[38;2;255;184;108m!\033[0m'"'"'    # Orange
            ERROR_ICON=$'"'"'\033[38;2;255;85;85m✗\033[0m'"'"'        # Red
            INFO_ICON=$'"'"'\033[38;2;139;233;253mℹ\033[0m'"'"'       # Cyan

            # Dracula theme-based colors
            COLOR_HEADER=$'"'"'\033[38;2;189;147;249m'"'"'            # Purple
            COLOR_SECTION=$'"'"'\033[38;2;255;121;198m'"'"'           # Pink
            COLOR_DIM=$'"'"'\033[38;2;98;114;164m'"'"'                # Comment
            COLOR_VALUE=$'"'"'\033[38;2;241;250;140m'"'"'             # Yellow
            COLOR_SUCCESS=$'"'"'\033[38;2;80;250;123m'"'"'            # Green
            COLOR_ERROR=$'"'"'\033[38;2;255;85;85m'"'"'               # Red
            COLOR_INFO=$'"'"'\033[38;2;139;233;253m'"'"'              # Cyan
            COLOR_RESET=$'"'"'\033[0m'"'"'

            # Connection timeouts
            CONNECT_TIMEOUT=2

            # Get the target host
            # Helper functions
            print_header() {
                echo -e "\n${COLOR_SECTION}$1${COLOR_RESET}"
                echo -e "${COLOR_HEADER}═════════════════════════════════════════════${COLOR_RESET}"
            }

            print_detail() {
                echo -e "${COLOR_DIM}$1${COLOR_RESET}"
            }

            print_value() {
                echo -e "${COLOR_VALUE}$1${COLOR_RESET}"
            }

            name=$(echo {} | awk "{print \$1}")
            
            # Get SSH config and extract info
            ssh_config=$(ssh -G "$name" 2>/dev/null)
            host=$(echo "$ssh_config" | grep "^hostname " | head -n1 | cut -d" " -f2)
            [[ -z "$host" ]] && host=$name  # Fallback to name if hostname not found
            
            user=$(echo "$ssh_config" | grep "^user " | head -n1 | cut -d" " -f2)
            port=$(echo "$ssh_config" | grep "^port " | head -n1 | cut -d" " -f2)
            [[ -z "$port" ]] && port=22
            key=$(echo "$ssh_config" | grep "^identityfile " | head -n1 | cut -d" " -f2)

            # Get description from SSH config
            if [ -f "$HOME/.ssh/config" ]; then
                desc=$(awk -v host="$name" '"'"'
                    $1 == "Host" { 
                        in_block = ($2 == host || host ~ "^"$2"$")
                    }
                    in_block && /^[[:space:]]*#_Desc[[:space:]]/ {
                        sub(/^[[:space:]]*#_Desc[[:space:]]*/, "")
                        desc = $0
                        gsub(/^[[:space:]]+|[[:space:]]+$/, "", desc)
                        print desc
                        exit
                    }
                '"'"' "$HOME/.ssh/config")
            fi

            # Print host summary
            print_header "🔖 HOST SUMMARY"
            {
                [[ -n "$name" ]] && echo "${COLOR_INFO}Name:${COLOR_RESET} ${COLOR_VALUE}$name${COLOR_RESET}"
                [[ -n "$host" ]] && echo "${COLOR_INFO}Host:${COLOR_RESET} ${COLOR_VALUE}$host${COLOR_RESET}"
                [[ -n "$user" ]] && echo "${COLOR_INFO}User:${COLOR_RESET} ${COLOR_VALUE}$user${COLOR_RESET}"
                [[ -n "$port" ]] && echo "${COLOR_INFO}Port:${COLOR_RESET} ${COLOR_VALUE}$port${COLOR_RESET}"
                [[ -n "$key" ]] && echo "${COLOR_INFO}Key:${COLOR_RESET} ${COLOR_VALUE}$key${COLOR_RESET}"
            } | column -t
            echo -e "${COLOR_DIM}${desc:-No description}${COLOR_RESET}"

            # Check connectivity
            print_header "🌐 CONNECTIVITY"
            
            if ! nc -z -G 2 "$host" "$port" >/dev/null 2>&1; then
                echo -e "$ERROR_ICON Cannot reach $host:$port"
                echo -e "$INFO_ICON Attempting DNS lookup..."
                if command -v host >/dev/null 2>&1; then
                    if host "$host" >/dev/null 2>&1; then
                        echo -e "$SUCCESS_ICON DNS resolution successful"
                        echo -e "$ERROR_ICON port is closed or filtered"
                    else
                        echo -e "$ERROR_ICON DNS resolution failed"
                    fi
                elif command -v dig >/dev/null 2>&1; then
                    if dig +short "$host" >/dev/null 2>&1; then
                        echo -e "$SUCCESS_ICON DNS resolution successful"
                        echo -e "$ERROR_ICON Port $port is closed or filtered"
                    else
                        echo -e "$ERROR_ICON DNS resolution failed"
                    fi
                fi
            else
                echo -e "$SUCCESS_ICON Connected to ${COLOR_VALUE}$host:$port${COLOR_RESET}"
                
                # Try quick version check
                if version=$(nc -w 1 "$host" "$port" 2>/dev/null | cut -d'"'"'-'"'"' -f1,2); then
                    if [ -n "$version" ]; then
                        echo -e "$INFO_ICON Server version: ${COLOR_VALUE}$version${COLOR_RESET}"
                    else
                        echo -e "$WARNING_ICON Unable to retrieve server version"
                    fi
                else
                    echo -e "$WARNING_ICON Unable to connect for version check"
                fi
            fi

            # Check key status
            if [[ -n "$key" ]]; then
                print_header "🔑 KEY STATUS"
                expanded_key="${key/#\~/$HOME}"
                
                if [[ ! -f "$expanded_key" ]]; then
                    echo -e "$ERROR_ICON No identity file found: ${COLOR_VALUE}$key${COLOR_RESET}"
                    # Check common key locations
                    for default_key in id_rsa id_ed25519 id_ecdsa; do
                        if [[ -f "$HOME/.ssh/$default_key" ]]; then
                            echo -e "$INFO_ICON Found alternative key: ${COLOR_VALUE}~/.ssh/$default_key${COLOR_RESET}"
                        fi
                    done
                else
                    echo -e "$SUCCESS_ICON Key exists: ${COLOR_VALUE}$key${COLOR_RESET}"
                    
                    # Check permissions
                    key_perms=$(stat -f "%Lp" "$expanded_key" 2>/dev/null)
                    if [[ "$key_perms" = "600" ]]; then
                        echo -e "$SUCCESS_ICON Permissions: ${COLOR_SUCCESS}OK (600)${COLOR_RESET}"
                    else
                        echo -e "$ERROR_ICON Invalid permissions: ${COLOR_ERROR}$key_perms (should be 600)${COLOR_RESET}"
                        echo -e "$INFO_ICON Fix with: ${COLOR_DIM}chmod 600 $expanded_key${COLOR_RESET}"
                    fi
                    
                    # Check key format
                    if key_info=$(ssh-keygen -l -f "$expanded_key" 2>/dev/null); then
                        echo -e "$SUCCESS_ICON Valid key format"
                        bits=$(echo "$key_info" | awk '"'"'{print $1}'"'"')
                        hash=$(echo "$key_info" | awk '"'"'{print $2}'"'"')
                        comment=$(echo "$key_info" | awk '"'"'{$1=$2=""; sub(/^[ \t]+/, ""); print}'"'"' | sed '"'"'s/ (.*)//'"'"') 
                        type=$(echo "$key_info" | grep -o '"'"'([^)]*)'"'"')
                        
                        echo -e "  ${COLOR_INFO}Comment:${COLOR_RESET} ${COLOR_VALUE}[$comment]${COLOR_RESET}"
                        echo -e "  ${COLOR_INFO}Type:${COLOR_RESET}    ${COLOR_VALUE}$type${COLOR_RESET}"
                        echo -e "  ${COLOR_INFO}Bits:${COLOR_RESET}    ${COLOR_VALUE}$bits${COLOR_RESET}"
                        echo -e "  ${COLOR_INFO}Hash:${COLOR_RESET}    ${COLOR_VALUE}$hash${COLOR_RESET}"
                        
                        # Check key expiry if supported
                        if echo "$key_info" | grep -q "valid until"; then
                            valid_until=$(echo "$key_info" | grep -o "valid until.*")
                            echo -e "$INFO_ICON Key $valid_until"
                        fi
                    else
                        echo -e "$ERROR_ICON Invalid key format"
                    fi
                fi
            fi

            # Authentication check
            print_header "🔐 AUTHENTICATION"
            
            if [[ $host == "github.com" ]]; then
                ssh_output=$(ssh -T git@github.com -o ConnectTimeout=$CONNECT_TIMEOUT 2>&1)
                if [[ $ssh_output == *"successfully authenticated"* ]]; then
                    echo -e "$SUCCESS_ICON GitHub authentication successful"
                    echo -e "${COLOR_DIM}$ssh_output${COLOR_RESET}"
                else
                    echo -e "$ERROR_ICON GitHub authentication failed"
                    echo -e "${COLOR_DIM}$ssh_output${COLOR_RESET}"
                fi
            else
                if ssh -o BatchMode=yes -o ConnectTimeout=$CONNECT_TIMEOUT "$name" exit 2>/dev/null; then
                    echo -e "$SUCCESS_ICON Authentication successful"
                    
                    # Check sudo access
                    if ssh -o BatchMode=yes -o ConnectTimeout=$CONNECT_TIMEOUT "$name" "sudo -n true" 2>/dev/null; then
                        echo -e "$SUCCESS_ICON Sudo access available without password"
                    fi
                    
                    # Try to get system info
                    if system_info=$(ssh -o ConnectTimeout=$CONNECT_TIMEOUT "$name" "uname -a" 2>/dev/null); then
                        echo -e "$INFO_ICON System: ${COLOR_VALUE}$system_info${COLOR_RESET}"
                    fi
                    
                    # Get SSH server version
                    if server_version=$(ssh -o ConnectTimeout=$CONNECT_TIMEOUT -v "$name" 2>&1 | grep "remote software version" | cut -d" " -f4-); then
                        echo -e "$INFO_ICON SSH Server: ${COLOR_VALUE}$server_version${COLOR_RESET}"
                    fi
                else
                    echo -e "$WARNING_ICON Authentication required"
                    ssh_banner=$(ssh -o ConnectTimeout=$CONNECT_TIMEOUT -o PreferredAuthentications=none "$name" 2>&1)
                    auth_methods=$(echo "$ssh_banner" | grep -i "authentication methods" | cut -d":" -f2-)
                    [[ -n "$auth_methods" ]] && echo -e "$INFO_ICON Available methods:${COLOR_VALUE}$auth_methods${COLOR_RESET}"
                    
                    # Show clean banner message
                    banner=$(echo "$ssh_banner" | grep -v -E "Permission denied|Please try again|authentication methods|Connection closed|Connection timed out" | head -n 10)
                    [[ -n "$banner" ]] && echo -e "${COLOR_DIM}\n$banner${COLOR_RESET}"
                fi
            fi
        ' \
        --preview-window=right:60% \
        -- "$@" < <(list_ssh_hosts)
}

_fzf_complete_ssh_post() {
    awk '{print $1}'
}
