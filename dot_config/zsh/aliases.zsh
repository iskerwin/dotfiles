##############################
# path Aliases  
##############################

alias tip='bat ~/.config/zsh/aliases.zsh'
alias home='cd ~'
alias path='echo; tr ":" "\n" <<< "$PATH"; echo;' # pretty print the PATH
alias github='cd ~/Dropbox/GitHub'
alias icloud='cd ~/Library/Mobile\ Documents/com\~apple\~CloudDocs/'
alias config='cd dotfiles/'

##############################
# git Aliases 
##############################

alias add='git add .'
alias log='git log --oneline --graph --decorate --all' # view commit history
alias pull='git pull origin'
alias push='git push origin'
alias stat='git status'                                # 'status' is protected name so using 'stat' instead
alias diff='git diff --name-only --diff-filter=d | xargs bat --diff'
alias fetch='git fetch'
alias clone='git clone'
alias commit='git commit -m'                           # commit all staging area files to the local repository
alias commitam='git commit -am'                        # commit all modified files to the local repository

##############################
# homebrew Stuffs 
##############################

alias update!='brew cu -a -f -v --no-brew-update -y'
alias update='brew update'
alias upgrade='brew upgrade'
alias cleanup='brew cleanup'
alias install='brew install'
alias uninstall='brew uninstall'
alias doctor="echo '\nDoctor? Doctor who?\n' && brew doctor"
alias uud='update; upgrade; cleanup; doctor'

##############################
# utilities Aliases 
##############################

alias q='exit'
alias c='clear'
alias ip='ifconfig en0 | grep inet'
alias ssh='ct ssh'
alias his='history | fzf'
# alias myip='curl -s http://checkip.dyndns.org/ | sed "s/[a-zA-Z<>/ :]//g"'

# Ensure dog is available
if (( ${+commands[dog]} )); then
    alias dig='dog'
else
    alias dig='dig'
fi
alias myip="dig +short myip.opendns.com @resolver1.opendns.com"
alias speed='networkQuality'
alias screen='ct screen'
alias telnet='ct telnet'
alias backup='brew bundle dump --describe --force --file="./Brewfile"'
alias clean!="find . -type f -name '*.DS_Store' -ls -delete"
alias restore!='brew bundle --file="$HOME/Library/Mobile Documents/com~apple~CloudDocs/AppList/Brewfile"'

##############################
# plugin Aliases 
##############################

alias o='open -R $(fd . --hidden --type=f | fzf)'
alias jo='joshuto'
alias sz='source ~/.zshrc'
alias zim='zimfw'
alias czm='chezmoi'
alias ccd='cd $(fd . --hidden --type=d | fzf)'
alias vim='vim $(fd . --hidden --type=f| fzf)'
alias code='code $(fd . --hidden --type=f| fzf)'
alias reload!='exec ${SHELL} -l'

##############################
# colorize grep output 
##############################

alias grep='grep --color=auto'
alias egrep='egrep --color=auto'
alias fgrep='fgrep --color=auto'

##############################
# exa 
##############################

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

##############################
# xxxx 
##############################

# not aliasing rm -i, but if safe-rm is available, use condom.
# if safe-rmdir is available, the OS is suse which has its own terrible 'safe-rm' which is not what we want
if (( ${+commands[safe-rm]} && ! ${+commands[safe-rmdir]} )); then
    alias rm=safe-rm
fi