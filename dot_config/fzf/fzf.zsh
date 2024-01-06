# Use the CLI fd & rg to respect ignore files (like '.gitignore'),
# display hidden files, and exclude the '.git' directory.
export FZF_DEFAULT_COMMAND='fd . --hidden --color=always'
export FZF_DEFAULT_COMMAND='rg . --files --hidden'
export FZF_COMPLETION_TRIGGER='\'
export FZF_DEFAULT_OPTS="
    --bind='ctrl-r:reload(eval $FZF_DEFAULT_COMMAND)'
    --header='Press CTRL-R to reload'
    --height=90%
    --layout=reverse
    --info=inline
    --border=rounded
    --margin=1
    --padding=1
    --border-label='| Fuzzy Finder |'
    --preview 'bat --color=always {} --theme=Dracula --style=header-filename,header-filesize,changes' 
    --preview-window '~3' 
    --preview-label='[ Directory stats ]'
    --preview-label-pos='3:bottom'
    --color=fg:#f8f8f2,bg:#282a36,hl:#bd93f9
    --color=fg+:#f8f8f2,bg+:#44475a,hl+:#bd93f9
    --color=info:#ffb86c,prompt:#50fa7b,pointer:#ff79c6
    --color=marker:#ff79c6,spinner:#ffb86c,header:#6272a4
    --prompt='▶' 
    --pointer='→' 
    --marker='♡'
    "

source ~/.config/fzf/completion.zsh
source ~/.config/fzf/key-bindings.zsh