# Core SSH functionality and configuration management
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