#!/usr/bin/env zsh

# Configuration for visual appearance and behavior
PREVIEW_WINDOW_SIZE="50%"
USE_ICONS=true
HEADER_STYLE=$(echo -e "\033[1;34m") # Bold Blue
NAME_STYLE=$(echo -e "\033[36m")     # Cyan
ARROW_STYLE=$(echo -e "\033[2m")     # Dim
CMD_STYLE=$(echo -e "\033[0m")       # Reset
TYPE_STYLE=$(echo -e "\033[2;3m")    # Dim Italic
SEPARATOR_STYLE=$(echo -e "\033[90m") # Gray

# Determine the type of alias based on its command
function get_alias_type() {
    local cmd=$1
    
    # File Navigation
    if [[ $cmd == "cd "* || $cmd == "ls"* || $cmd == "tree"* ]]; then
        echo " navigation"
    # File Operations
    elif [[ $cmd == "rm"* || $cmd == "clean"* ]]; then
        echo "󰆓 file-ops"
    # Git Operations
    elif [[ $cmd == "git "* || $cmd == "g"* ]]; then
        echo "󰊢 git"
    # System Operations
    elif [[ $cmd == "brew "* || $cmd == "ip"* || $cmd == "speed"* || $cmd == "weather"* ]]; then
        echo " system"
    # SSH Management
    elif [[ $cmd == "ssh"* ]]; then
        echo "󰣀 ssh"
    # Screen Management
    elif [[ $cmd == "screen "* ]]; then
        echo "󰄝 screen"
    # Development Tools
    elif [[ $cmd == "grep"* || $cmd == "backup"* || $cmd == "restore"* ]]; then
        echo "󰅨 dev"
    # Chezmoi
    elif [[ $cmd == "chezmoi "* || $cmd == "ch"* ]]; then
        echo "󰋊 chezmoi"
    # Miscellaneous
    else
        echo "󰘓 misc"
    fi
}

# Format command string with highlighting
function format_command() {
    local cmd=$1
    cmd=${cmd//|/${ARROW_STYLE}|${CMD_STYLE}}
    cmd=${cmd// -/${CMD_STYLE} -}
    echo -e "$cmd"
}

# Main function for the alias finder interface
function alias_finder() {
    local header_text="${HEADER_STYLE}Controls │ ENTER: copy alias • CTRL-E: copy command${CMD_STYLE}"

    # 获取当前系统的剪贴板命令
    local copy_cmd
    case "$(uname)" in
        "Darwin") copy_cmd="pbcopy" ;; # macOS
        "Linux") copy_cmd="xclip -selection clipboard 2>/dev/null || xsel -b 2>/dev/null || clipcopy 2>/dev/null" ;; # Linux with fallbacks
        *) copy_cmd="clip.exe" ;; # Windows
    esac

    # Process and display aliases using awk and sort them by type
    alias | awk -v name_style="$NAME_STYLE" -v arrow_style="$ARROW_STYLE" \
            -v cmd_style="$CMD_STYLE" -v type_style="$TYPE_STYLE" \
            -v separator_style="$SEPARATOR_STYLE" \
    '
    BEGIN {FS="="}
    function get_type(cmd) {
        if (cmd ~ /^(cd |ls|ll|tree|eza)/) return "navigation"
        if (cmd ~ /^(rm|clean)/) return "file-ops"
        if (cmd ~ /^git/) return "git"
        if (cmd ~ /^(brew |ip|speed|weather)/) return "system"
        if (cmd ~ /(ssh|.ssh)/) return "ssh"
        if (cmd ~ /screen/) return "screen"
        if (cmd ~ /^(grep|backup|restore)/) return "dev"
        if (cmd ~ /^(chezmoi |ch)/) return "chezmoi"
        return "misc"
    }
    !/^#/ {
        name=$1
        sub(/^alias /, "", name)
        command=$2
        gsub(/^[ '\''"]+|['\''"]+$/, "", command)
        
        type = get_type(command)
        
        entries[type] = entries[type] sprintf("%s%-25s%s =>%s %s\n", \
            name_style, name, \
            arrow_style, \
            cmd_style, command)
        
        types[type] = 1
    }
    END {
        # Print sections with headers
        if ("navigation" in types) {
            printf "%s%s%s\n%s", separator_style, "──────  File Navigation ──────", cmd_style, entries["navigation"]
        }
        if ("file-ops" in types) {
            printf "%s%s%s\n%s", separator_style, "────── 󰆓 File Operations ──────", cmd_style, entries["file-ops"]
        }
        if ("git" in types) {
            printf "%s%s%s\n%s", separator_style, "────── 󰊢 Git Operations ──────", cmd_style, entries["git"]
        }
        if ("system" in types) {
            printf "%s%s%s\n%s", separator_style, "──────  System Operations ──────", cmd_style, entries["system"]
        }
        if ("ssh" in types) {
            printf "%s%s%s\n%s", separator_style, "────── 󰣀 SSH Management ──────", cmd_style, entries["ssh"]
        }
        if ("screen" in types) {
            printf "%s%s%s\n%s", separator_style, "────── 󰄝 Screen Management ──────", cmd_style, entries["screen"]
        }
        if ("dev" in types) {
            printf "%s%s%s\n%s", separator_style, "────── 󰅨 Development Tools ──────", cmd_style, entries["dev"]
        }
        if ("chezmoi" in types) {
            printf "%s%s%s\n%s", separator_style, "────── 󰋊 Chezmoi ──────", cmd_style, entries["chezmoi"]
        }
        if ("misc" in types) {
            printf "%s%s%s\n%s", separator_style, "────── 󰘓 Miscellaneous ──────", cmd_style, entries["misc"]
        }
    }' | fzf \
        --ansi \
        --reverse \
        --border rounded \
        --prompt '󰘧 ' \
        --pointer '󰮺' \
        --marker '󰄲' \
        --header "$header_text" \
        --preview 'echo -e "'"$HEADER_STYLE"'Alias:'"$CMD_STYLE"' {1}\n\n'"$HEADER_STYLE"'Command:'"$CMD_STYLE"' {3..}\n\n'"$HEADER_STYLE"'Type:'"$CMD_STYLE"' $(echo {3..} | '"$(which alias_finder)"' get_alias_type)\n\n'"$HEADER_STYLE"'Description:'"$CMD_STYLE"' Auto-generated preview of the alias command"' \
        --preview-window "${PREVIEW_WINDOW_SIZE}:hidden" \
        --bind "ctrl-e:execute-silent(echo -n {3..} | $copy_cmd)+abort" \
        --bind "enter:execute-silent(echo {1} | $copy_cmd)+abort" \
        --color 'fg:250,fg+:252,bg+:235,hl:110,hl+:110' \
        --color 'info:110,prompt:109,spinner:110,pointer:167,marker:215'
}

# Execute the main function
alias_finder