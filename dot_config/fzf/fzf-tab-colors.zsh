# Dracula theme colors for LS_COLORS
export LS_COLORS="di=1;34:ln=35:so=32:pi=33:ex=31:bd=34;46:cd=34;43:su=30;41:sg=30;46:tw=30;42:ow=30;43"

# LS_COLORS
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}

# fzf-tab Style configuration
zstyle ':fzf-tab:*' default-color $'\033[39m'
zstyle ':fzf-tab:*' prefix ''

# Dracula Color scheme
zstyle ':fzf-tab:*' fzf-flags \
    --color=fg:#f8f8f2,hl:#bd93f9 \
    --color=fg+:#f8f8f2,bg+:#44475a,hl+:#bd93f9 \
    --color=info:#ffb86c,prompt:#50fa7b,pointer:#ff79c6 \
    --color=marker:#ff79c6,spinner:#ffb86c,header:#6272a4\
    --pointer='▶'