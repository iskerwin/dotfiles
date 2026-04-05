cf::fzf() {
    local tmp=$(mktemp)

    local result

    result=$(
        fzf \
            --ansi \
            --cycle \
            --no-preview \
            --height=80% \
            --info=inline \
            --layout=reverse \
            --border double \
            --pointer '❯' \
            --marker '•' \
            --prompt '❯ ' \
            --header='ENTER: insert command' \
            --bind "enter:accept" \
            --delimiter='\t' \
            --color='fg:#f8f8f2,bg:#1e1e2e' \
            --color='hl:#ffb86c,hl+:#ffb86c:bold' \
            --color='pointer:#ff79c6,marker:#ff79c6' \
            --color='border:#6272a4,header:#bd93f9' \
            --color='bg+:#44475a'
    )

    print -r -- "$result"
}