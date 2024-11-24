#!/usr/bin/env zsh

# Check if fzf exists in path
if command -v fzf >/dev/null 2>&1; then

    # Format and display git log with colors and graph
    __git_log() {
        git log \
            --color=always \
            --graph \
            --all \
            --date=short \
            --format="%C(bold blue)%h%C(reset) %C(green)%ad%C(reset) | %C(white)%s %C(red)[%an] %C(bold yellow)%d"
    }

    # Enhanced git log viewer with preview
    function fzf_git_log() {
        __git_log |
            fzf --ansi \
                --no-sort \
                --reverse \
                --tiebreak=index \
                --preview "echo {} | grep -o '[a-f0-9]\{7\}' | head -1 |
                xargs -I % sh -c 'git show --color=always %'" \
                --bind "ctrl-m:execute:
                (grep -o '[a-f0-9]\{7\}' | head -1 |
                xargs -I % sh -c 'git show --color=always % | less -R') << 'FZF-EOF'
                {}
                FZF-EOF"
    }

    # Enhanced git command completion with fzf
    fzf_complete_git() {
        local ARGS="$@"
        local hash_commands=(
            'git cp'
            'git cherry-pick'
            'git co'
            'git checkout'
            'git reset'
            'git show'
            'git log'
            'git rebase'
            'git revert'
            'git diff'
        )

        # Check if current command needs commit hash completion
        for cmd in "${hash_commands[@]}"; do
            if [[ $ARGS == $cmd* ]]; then
                __git_log | fzf \
                    --reverse \
                    --multi \
                    --ansi \
                    --preview "echo {} | grep -o '[a-f0-9]\{7\}' | head -1 |
            xargs -I % sh -c 'git show --color=always %'" \
                    --preview-window=right:60% \
                    --bind 'ctrl-/:toggle-preview'
                return
            fi
        done

        # Fall back to default completion
        eval "zle ${fzf_default_completion:-expand-or-complete}"
    }

    # Post-process the selected git log entry
    fzf_complete_git_post() {
        sed -e 's/^[^a-z0-9]*//' | awk '{print $1}'
    }

    # Function to search git branches
    function fzf-git-branch-widget() {
        local result=$(git branch -a --color=always | grep -v '/HEAD\s' | sort |
            fzf --ansi --multi --tac --preview-window right:70% \
                --preview 'git log --oneline --graph --date=short --color=always --pretty="format:%C(auto)%cd %h%d %s" $(sed s/^..// <<< {} | cut -d" " -f1)' |
            sed 's/^..//' | cut -d' ' -f1)
        LBUFFER="${LBUFFER}${result}"
        zle reset-prompt
    }

    # Function to search git status files
    function fzf-git-status-widget() {
        local result=$(git -c color.status=always status --short |
            fzf --ansi --multi --preview 'git diff --color=always {+2}' |
            cut -c4- | sed 's/.* -> //')
        LBUFFER="${LBUFFER}${result}"
        zle reset-prompt
    }

    # Function for fuzzy add files
    git_fuzzy_add() {
        local files=$(git -c color.status=always status --short |
            fzf --ansi --multi --preview 'git diff --color=always {+2}' |
            cut -c4- | sed 's/.* -> //')
        if [[ -n "$files" ]]; then
            git add $(echo $files | tr '\n' ' ')
            git status
        fi
    }

    # Register widgets
    zle -N fzf-git-branch-widget
    zle -N fzf-git-status-widget

    # Set up aliases
    alias glf="fzf_git_log"           # Git log fuzzy search
    alias gbf="fzf-git-branch-widget" # Git branch fuzzy search
    alias gsf="fzf-git-status-widget" # Git status fuzzy search
    alias gfa="git_fuzzy_add"         # Git fuzzy add files

    # Key bindings for zsh
    if [[ -n "$ZSH_VERSION" ]]; then
        # Bind Ctrl-G + b to branch search
        bindkey '^Gb' fzf-git-branch-widget
        # Bind Ctrl-G + s to status search
        bindkey '^Gs' fzf-git-status-widget
    fi

fi
