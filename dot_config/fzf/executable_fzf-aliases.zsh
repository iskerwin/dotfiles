#!/usr/bin/env zsh
# Configuration for visual appearance and behavior
HEADER_STYLE=$(echo -e "\033[1;34m") # Bold Blue
NAME_STYLE=$(echo -e "\033[36m")     # Cyan
ARROW_STYLE=$(echo -e "\033[2m")     # Dim
CMD_STYLE=$(echo -e "\033[0m")       # Reset
TYPE_STYLE=$(echo -e "\033[2;3m")    # Dim Italic
SEPARATOR_STYLE=$(echo -e "\033[90m") # Gray

# Main function for the alias finder interface
function alias_finder() {
    local header_text="${HEADER_STYLE}Controls │ ENTER: input alias • CTRL-E: input command${CMD_STYLE}"
    
    # Process and display aliases using awk
    alias | awk -v name_style="$NAME_STYLE" -v arrow_style="$ARROW_STYLE" \
            -v cmd_style="$CMD_STYLE" -v type_style="$TYPE_STYLE" \
            -v separator_style="$SEPARATOR_STYLE" \
    '
    BEGIN {
        FS="="
        # Predefined titles and order for all categories
        order[1] = "navigation"
        order[2] = "file-ops"
        order[3] = "git"
        order[4] = "system"
        order[5] = "ssh"
        order[6] = "screen"
        order[7] = "dev"
        order[8] = "chezmoi"
        order[9] = "misc"
        
        headers["navigation"] = "=========== 󰇐 File Navigation ==========="
        headers["file-ops"]   = "===========  File Operations ==========="
        headers["git"]        = "=========== 󰊢 Git Operations ============"
        headers["system"]     = "========== 󰜫 System Operations =========="
        headers["ssh"]        = "=========== 󰣀 SSH Management ============"
        headers["screen"]     = "==========  Screen Management =========="
        headers["dev"]        = "========== 󰅨 Development Tools =========="
        headers["chezmoi"]    = "=============== 󰋊 Chezmoi ==============="
        headers["misc"]       = "============ 󰘓 Miscellaneous ============"
    }
    
    function classify_command(cmd) {
        if (cmd ~ /^(cd |ls|ll|tree|eza)/) return "navigation"
        if (cmd ~ /^(rm|clean)/) return "file-ops"
        if (cmd ~ /^git/) return "git"
        if (cmd ~ /(brew |ip|ifconfig|speed|weather)/) return "system"
        if (cmd ~ /(ssh|.ssh)/) return "ssh"
        if (cmd ~ /screen/) return "screen"
        if (cmd ~ /(grep|backup|restore)/) return "dev"
        if (cmd ~ /^(chezmoi |ch)/) return "chezmoi"
        return "misc"
    }
    
    !/^#/ {
        name=$1
        sub(/^alias /, "", name)
        command=$2
        gsub(/^[ '\''"]+|['\''"]+$/, "", command)
        
        type = classify_command(command)
        entries[type] = entries[type] sprintf("%s%-25s%s =>%s %s\n", \
            name_style, name, \
            arrow_style, \
            cmd_style, command)
        types[type] = 1
    }
    
    END {
        # Output categories in a predefined order
        for (i = 1; i <= length(order); i++) {
            type = order[i]
            if (types[type]) {
                printf "%s%s%s\n%s", \
                    separator_style, \
                    headers[type], \
                    cmd_style, \
                    entries[type]
            }
        }
    }' | fzf \
        --ansi \
        --reverse \
        --border rounded \
        --prompt '󰘧 ' \
        --pointer '󰮺' \
        --marker '󰄲' \
        --header "$header_text" \
        --preview-window "${PREVIEW_WINDOW_SIZE}:hidden" \
        --bind "ctrl-e:execute(echo -n {3..} | tr -d '\n' > $HOME/.fzf-alias-tmp)+abort" \
        --bind "enter:execute(echo {1} | tr -d '\n' > $HOME/.fzf-alias-tmp)+abort" \
        --color 'fg:250,fg+:252,bg+:235,hl:110,hl+:110' \
        --color 'info:110,prompt:109,spinner:110,pointer:167,marker:215'

    # If selected, read the temporary file and output to the command line
    if [ -f "$HOME/.fzf-alias-tmp" ]; then
        local result=$(cat "$HOME/.fzf-alias-tmp")
        rm "$HOME/.fzf-alias-tmp"
        print -z "$result"
    fi
}

# Execute the main function
alias_finder