#!/usr/bin/env zsh

# ━━━━━━━━━━━━━━━━━━━━━━ Style Configuration ━━━━━━━━━━━━━━━━━━━━━━
# Dracula color palette
HEADER_STYLE=$(echo -e "\033[1;38;5;141m")  # Purple
NAME_STYLE=$(echo -e "\033[38;5;84m")       # Green
ARROW_STYLE=$(echo -e "\033[38;5;212m")     # Pink
CMD_STYLE=$(echo -e "\033[0m")              # Reset
TYPE_STYLE=$(echo -e "\033[3;38;5;189m")    # Light Purple
SEPARATOR_STYLE=$(echo -e "\033[38;5;61m")  # Dark Purple

# ━━━━━━━━━━━━━━━━━━━━━━ Main Function ━━━━━━━━━━━━━━━━━━━━━━
function alias_finder() {
    local header_text="${HEADER_STYLE}
    ╭─────────────────────────────────────────────────╮
    │ Controls │ ENTER: input alias • CTRL-E: command │
    ╰─────────────────────────────────────────────────╯${CMD_STYLE}"
    
    # Process and display aliases using awk
    alias | awk -v name_style="$NAME_STYLE" \
                -v arrow_style="$ARROW_STYLE" \
                -v cmd_style="$CMD_STYLE" \
                -v type_style="$TYPE_STYLE" \
                -v separator_style="$SEPARATOR_STYLE" \
    '
    BEGIN {
        FS="="
        # Refined category titles with consistent styling
        order[1] = "navigation"
        order[2] = "file-ops"
        order[3] = "git"
        order[4] = "system"
        order[5] = "ssh"
        order[6] = "screen"
        order[7] = "dev"
        order[8] = "chezmoi"
        order[9] = "misc"
        
        # Enhanced headers with decorative borders
        headers["navigation"] = "╔═════════════════════════════════════════ 󰇐 File Navigation ═════════════════════════════════════════╗"
        headers["file-ops"]   = "╔═════════════════════════════════════════  File Operations ══════════════════════════════════════════╗"
        headers["git"]        = "╔═════════════════════════════════════════ 󰊢 Git Operations ══════════════════════════════════════════╗"
        headers["system"]     = "╔════════════════════════════════════════ 󰜫 System Operations ════════════════════════════════════════╗"
        headers["ssh"]        = "╔═════════════════════════════════════════ 󰣀 SSH Management ══════════════════════════════════════════╗"
        headers["screen"]     = "╔════════════════════════════════════════  Screen Management ═════════════════════════════════════════╗"
        headers["dev"]        = "╔════════════════════════════════════════ 󰅨 Development Tools ════════════════════════════════════════╗"
        headers["chezmoi"]    = "╔═════════════════════════════════════════════ 󰋊 Chezmoi ═════════════════════════════════════════════╗"
        headers["misc"]       = "╔════════════════════════════════════════ 󰘓 Miscellaneous ════════════════════════════════════════════╗"
    }
    
    function classify_command(cmd) {
        if (cmd ~ /^(cd |ls|ll|tree|eza)/) return "navigation"
        if (cmd ~ /^(rm|clean)/) return "file-ops"
        if (cmd ~ /^(git|g |ga|add|pull|push|stat|diff|fetch|clone|commit|gb|gco|grb|gm)/) return "git"
        if (cmd ~ /(brew |ip|ifconfig|speed|weather|update|upgrade|cleanup|install|uninstall|doctor)/) return "system"
        if (cmd ~ /(ssh|.ssh)/) return "ssh"
        if (cmd ~ /screen/) return "screen"
        if (cmd ~ /(grep|backup|restore)/) return "dev"
        if (cmd ~ /^(chezmoi |ch)/) return "chezmoi"
        return "misc"
    }
    
    function clean_quotes(str) {
        # Remove only the outermost quotes if they match
        if ((substr(str, 1, 1) == "\"" && substr(str, length(str), 1) == "\"") ||
            (substr(str, 1, 1) == "\047" && substr(str, length(str), 1) == "\047")) {
            return substr(str, 2, length(str) - 2)
        }
        return str
    }
    
    !/^#/ {
        # Get the alias name
        name = $1
        sub(/^alias /, "", name)
        
        # Get the command by joining all fields after the first =
        command = ""
        for(i=2; i<=NF; i++) {
            if(i>2) command = command "="
            command = command $i
        }
        
        # Only remove leading/trailing whitespace and outermost quotes
        gsub(/^[ \t]+|[ \t]+$/, "", command)
        command = clean_quotes(command)
        
        type = classify_command(command)
        entries[type] = entries[type] sprintf("%s%-20s%s ➜%s  %s\n", \
            name_style, name, \
            arrow_style, \
            cmd_style, command)
        types[type] = 1
    }
    
    END {
        # Output categories with bottom borders
        for (i = 1; i <= length(order); i++) {
            type = order[i]
            if (types[type]) {
                printf "%s%s%s\n%s%s╚═════════════════════════════════════════════════════════════════════════════════════════════════════╝%s\n", \
                    separator_style, \
                    headers[type], \
                    cmd_style, \
                    entries[type], \
                    separator_style, \
                    cmd_style
            }
        }
    }' | fzf \
        --ansi \
        --reverse \
        --border double \
        --prompt ' 󰘧 ' \
        --pointer ' 󰮺' \
        --marker ' 󰄲' \
        --header "$header_text" \
        --preview-window "${PREVIEW_WINDOW_SIZE}:hidden" \
        --bind "ctrl-e:execute(echo -n {3..} | tr -d '\n' > $HOME/.fzf-alias-tmp)+abort" \
        --bind "enter:execute(echo {1} | tr -d '\n' > $HOME/.fzf-alias-tmp)+abort" \
        --color='bg+:#44475a,fg+:#f8f8f2,hl:#50fa7b,hl+:#50fa7b,border:#6272a4' \
        --color='header:#bd93f9,info:#50fa7b,prompt:#bd93f9,pointer:#ff79c6,marker:#ff79c6'

    # Process selection
    if [ -f "$HOME/.fzf-alias-tmp" ]; then
        local result=$(cat "$HOME/.fzf-alias-tmp")
        rm "$HOME/.fzf-alias-tmp"
        print -z "$result"
    fi
}

# Execute the main function
alias_finder