##############################
# Path Aliases
##############################

alias tip='bat ~/.config/zsh/aliases.zsh'
alias home='cd ~'
alias path='echo; tr ":" "\n" <<< "$PATH"; echo;' # pretty print the PATH
alias icloud='cd ~/Library/Mobile\ Documents/com\~apple\~CloudDocs/'
alias config='chezmoi cd'
alias EC2='ssh -i "Ubuntu.pem" ubuntu@ec2-13-213-41-164.ap-southeast-1.compute.amazonaws.com'
alias snell='cat ../etc/snell/config.conf'
alias lsdev='ls /dev/cu.*'

##############################
# Git Aliases
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
# Homebrew Stuffs
##############################

alias update-all='brew cu -a -f -v --no-brew-update -y'
alias update='brew update'
alias upgrade='brew upgrade'
alias cleanup='brew cleanup'
alias install='brew install'
alias uninstall='brew uninstall'
alias doctor="echo '\nDoctor? Doctor who?\n' && brew doctor"
alias uud='update; upgrade; cleanup; doctor'

##############################
# Utilities Aliases
##############################

alias q='exit'
alias c='clear'
alias ip='ifconfig en0 | grep inet'
alias his='history | fzf'

alias myip='curl http://ipecho.net/plain; echo'
# alias myip='curl -s http://checkip.dyndns.org/ | sed "s/[a-zA-Z<>/ :]//g"'
alias speed='networkQuality'
alias weather='curl wttr.in'
alias backup='brew bundle dump --describe --force --file="./Brewfile"'
alias clean-DS_Store="find . -type f -name '*.DS_Store' -ls -delete"
alias restore-brewfile='brew bundle --file="$HOME/Library/Mobile Documents/com~apple~CloudDocs/AppList/Brewfile"'

##############################
# Plugin Aliases
##############################

alias o='open -R $(fd . --hidden --type=f | fzf)'
alias jo='joshuto'
alias sz='source ~/.zshrc'
alias zim='zimfw'
alias czm='chezmoi'
alias czmcd='/Users/kerwin/.local/share/chezmoi'
alias ccd='cd $(fd . --hidden --type=d | fzf)'
alias vim='vim $(fd . --hidden --type=f | fzf)'
alias code='code $(fd . --hidden --type=f | fzf)'

##############################
# Colorize Grep Output
##############################

alias grep='grep --color=auto'
alias egrep='egrep --color=auto'
alias fgrep='fgrep --color=auto'

##############################
# exa 
##############################

# Ensure exa is available

alias ls='eza --group-directories-first --icons'
alias la='ls -a'
alias ll='ls -l'                                # Long format, git status
alias l='ll -a'                                 # Long format, all files
alias lr='ll -T'                                # Long format, recursive as a tree
alias lx='ll -sextension'                       # Long format, sort by extension
alias lk='ll -ssize'                            # Long format, largest file size last
alias lt='ll -smodified'                        # Long format, newest modification time last
alias lc='ll -schanged'                         # Long format, newest status change (ctime) last
alias l.='ls -d .*'                             # all dotfiles
alias tree='exa --tree --group-directories-first --icons'

##############################
# Safe Remove
##############################

# Not aliasing rm -i, but if safe-rm is available, use it
if (( ${+commands[safe-rm]} && ! ${+commands[safe-rmdir]} )); then
    alias rm=safe-rm
fi