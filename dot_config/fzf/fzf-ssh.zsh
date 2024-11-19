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
            HEADER_COLOR=$'"'"'\033[1;34m'"'"'
            DETAIL_COLOR=$'"'"'\033[0;90m'"'"'
            
            ssh_timeout=3
            connect_timeout=2

            # Helper functions
            print_header() {
                echo -e "\n${HEADER_COLOR}━━━━━━━━━━ $1 ━━━━━━━━━━\033[0m"
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
            print_header " HOST SUMMARY "
            {
                echo "Host: $host"
                echo "HostName: $real_hostname"
                echo "Port: $port"
                [ -n "$key_file" ] && echo "Key: $key_file"
            } | column -t
            
            desc=$(echo {} | awk "{print \$4}")
            [ -n "$desc" ] && print_detail "$desc"

            # Check connectivity first
            print_header " CONNECTIVITY "
            if ! nc -z -G 2 $real_hostname $port >/dev/null 2>&1; then
                echo -e "$ERROR_ICON Cannot reach $real_hostname:$port"
                exit 0
            fi
            echo -e "$SUCCESS_ICON Connected to $real_hostname:$port"

            # Check key status if exists
            if [ -n "$key_file" ]; then
                print_header "  KEY STATUS  "
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
            print_header "  SSH CONFIG  "
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
        --height "80%" \
        --reverse \
        --header-lines=2 \
        --header='
╭──────────── Controls ──────────╮
│ CTRL-E: edit   •  CTRL-Y: copy │
╰────────────────────────────────╯' \
        --bind='ctrl-y:execute-silent(echo {+} | pbcopy)' \
        --bind='ctrl-e:execute(${EDITOR:-nvim} ~/.ssh/config)' \
        --prompt="Telnet Remote > " \
        --preview '
            # Constants
            SUCCESS_ICON=$'"'"'\033[0;32m✓\033[0m'"'"'
            WARNING_ICON=$'"'"'\033[0;33m!\033[0m'"'"'
            ERROR_ICON=$'"'"'\033[0;31m✗\033[0m'"'"'
            INFO_ICON=$'"'"'\033[0;34mℹ\033[0m'"'"'
            HEADER_COLOR=$'"'"'\033[1;34m'"'"'
            DETAIL_COLOR=$'"'"'\033[0;90m'"'"'

            print_header() {
                echo -e "\n${HEADER_COLOR}━━━━━━━━━━ $1 ━━━━━━━━━━\033[0m"
            }

            print_detail() {
                echo -e "${DETAIL_COLOR}$1\033[0m"
            }

            host=$(echo {} | awk "{print \$1}")
            real_host=$(echo {} | awk "{print \$2}")
            port=23

            # Basic host info
            print_header "    HOST INFO    "
            {
                echo "Host: $host"
                echo "Hostname: $real_host"
                echo "Port: $port"
                echo "Protocol: TELNET"
            } | column -t

            # Connectivity test
            print_header "CONNECTIVITY TEST"
            
            # 使用 nc 快速测试端口
            if nc -z -G 2 $real_host $port 2>/dev/null; then
                echo -e "$SUCCESS_ICON Port $port is open on $real_host"
                
                # 使用 perl 进行有超时控制的 telnet 测试
                telnet_output=$(perl -e '\''
                    use Time::HiRes qw(alarm sleep);
                    my $timeout = 3;
                    eval {
                        local $SIG{ALRM} = sub { die "timeout\n" };
                        alarm $timeout;
                        open(my $telnet, "echo quit | telnet $ARGV[0] $ARGV[1] 2>&1 |") or die "Failed to execute telnet: $!";
                        while (<$telnet>) {
                            next if /^Trying/;
                            print $_;
                        }
                        close($telnet);
                        alarm 0;
                    };
                    if ($@) {
                        if ($@ eq "timeout\n") {
                            print "Connection timed out after ${timeout}s\n";
                            exit 2;
                        }
                    }
                '\'' "$real_host" "$port")
                
                if [[ $? -eq 2 ]]; then
                    echo -e "$WARNING_ICON Telnet connection timed out"
                elif [[ $telnet_output == *"Connected to"* ]]; then
                    echo -e "$SUCCESS_ICON Telnet connection successful"
                    print_detail "Connection Details:"
                    echo "$telnet_output" | head -n 5 | while read line; do
                        print_detail "  $line"
                    done
                else
                    echo -e "$WARNING_ICON Connection attempt failed"
                    print_detail "$(echo "$telnet_output" | head -n 3)"
                fi
            else
                echo -e "$ERROR_ICON Cannot reach $real_host:$port"
            fi

            # Response Time Test
            print_header "  RESPONSE TIME  "
            ping_result=$(ping -c 1 -t 2 $real_host 2>/dev/null | grep "time=" | cut -d "=" -f 4)
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