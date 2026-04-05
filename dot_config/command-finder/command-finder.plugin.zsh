source "${0:A:h}/utils.zsh"
source "${0:A:h}/parser.zsh"
source "${0:A:h}/ui.zsh"
source "${0:A:h}/core.zsh"

alias af='command_finder'

if [[ -n $ZLE ]]; then
    zle -N command_finder_widget command_finder
    bindkey '^F' command_finder_widget
fi