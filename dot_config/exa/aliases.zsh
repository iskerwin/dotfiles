# Ensure exa is available
if (( ${+commands[eza]} )); then
    alias ls='eza --group-directories-first --icons'
elif (( ${+commands[exa]} )); then
    alias ls='exa --group-directories-first --git --time-style long-iso --icons'
else
    return 1
fi

export EXA_COLORS='da=1;34:gm=1;34'

alias la='ls -a'
alias ll='ls -l'                                # Long format, git status
alias  l='ll -a'                                # Long format, all files
alias lr='ll -T'                                # Long format, recursive as a tree
alias lx='ll -sextension'                       # Long format, sort by extension
alias lk='ll -ssize'                            # Long format, largest file size last
alias lt='ll -smodified'                        # Long format, newest modification time last
alias lc='ll -schanged'                         # Long format, newest status change (ctime) last
alias l.='ls -d .*'                             # all dotfiles
alias tree='exa --tree --group-directories-first --icons'