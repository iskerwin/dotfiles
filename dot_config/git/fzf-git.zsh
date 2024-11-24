# fzf git log viewer
if (( $+commands[fzf] )); then
    __git_log () {
    git log \
        --color=always \
        --graph \
        --all \
        --date=short \
        --format="%C(bold blue)%h%C(reset) %C(green)%ad%C(reset) | %C(white)%s %C(red)[%an] %C(bold yellow)%d"
}

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

alias glf="fzf_git_log"
fi