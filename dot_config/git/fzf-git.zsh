fzf_git_log() {
    local date_format="%Y-%m-%d %H:%M"
    local git_log_format="%C(auto)%h%d %s %C(black)%C(bold)%cr %C(auto)%an"
    local preview_cmd="echo {} | grep -o '[a-f0-9]\{7\}' | head -1 | xargs -I % sh -c 'git show --color=always % | diff-so-fancy'"
    local selected=$(
        git log --graph --color=always \
            --format="$git_log_format" \
            --date=format:"$date_format" \
            --all |
            fzf --ansi \
                --height 100% \
                --preview-window=right:60% \
                --preview="$preview_cmd" \
                --bind='ctrl-d:preview-page-down' \
                --bind='ctrl-u:preview-page-up' \
                --bind='?:toggle-preview-wrap' \
                --header='
    ╭────────── Controls ──────────╮
    │ CTRL-S: view commit          │
    │ Press ?: toggle preview wrap │
    ╰──────────────────────────────╯' \
                --bind='ctrl-s:execute(git show --color=always {1} | less -R)'
    )

    local commit_hash=$(echo "$selected" | grep -o '[a-f0-9]\{7\}' | head -1)

    if [[ -n "$commit_hash" ]]; then
        echo "$commit_hash"
    fi
}

alias glf='fzf_git_log'
