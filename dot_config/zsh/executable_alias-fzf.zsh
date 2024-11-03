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
    local header_text="${HEADER_STYLE}Controls │ ENTER: copy alias • CTRL-E: copy command${CMD_STYLE}"
    # Get system clipboard command
    local copy_cmd
    case "$(uname)" in
        "Darwin") copy_cmd="pbcopy" ;; # macOS
        "Linux") copy_cmd="xclip -selection clipboard 2>/dev/null || xsel -b 2>/dev/null || clipcopy 2>/dev/null" ;; # Linux with fallbacks
        *) copy_cmd="clip.exe" ;; # Windows
    esac

    # Process and display aliases using awk
    alias | awk -v name_style="$NAME_STYLE" -v arrow_style="$ARROW_STYLE" \
            -v cmd_style="$CMD_STYLE" -v type_style="$TYPE_STYLE" \
            -v separator_style="$SEPARATOR_STYLE" \
    '
    BEGIN {
        FS="="
        # 预定义所有分类的标题和顺序
        order[1] = "navigation"
        order[2] = "file-ops"
        order[3] = "git"
        order[4] = "system"
        order[5] = "ssh"
        order[6] = "screen"
        order[7] = "dev"
        order[8] = "chezmoi"
        order[9] = "misc"
        
        headers["navigation"] = "─────── 󰆓 File Navigation ───────"
        headers["file-ops"]   = "─────── 󰆓 File Operations ───────"
        headers["git"]        = "─────── 󰊢 Git Operations ────────"
        headers["system"]     = "────── 󰜫 System Operations ──────"
        headers["ssh"]        = "─────── 󰣀 SSH Management ────────"
        headers["screen"]     = "────── 󰄝 Screen Management ──────"
        headers["dev"]        = "────── 󰅨 Development Tools ──────"
        headers["chezmoi"]    = "─────────── 󰋊 Chezmoi ───────────"
        headers["misc"]       = "──────── 󰘓 Miscellaneous ────────"
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
        # 按照预定义顺序输出分类
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
        --bind "ctrl-e:execute-silent(echo -n {3..} | $copy_cmd)+abort" \
        --bind "enter:execute-silent(echo {1} | $copy_cmd)+abort" \
        --color 'fg:250,fg+:252,bg+:235,hl:110,hl+:110' \
        --color 'info:110,prompt:109,spinner:110,pointer:167,marker:215'
}

# Execute the main function
alias_finder