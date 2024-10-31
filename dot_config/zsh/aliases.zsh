##############################
# Path Aliases
##############################

alias tip='bat ~/.config/zsh/aliases.zsh'
alias home='cd ~'
alias path='echo; tr ":" "\n" <<< "$PATH"; echo;' # pretty print the PATH
alias icloud='cd ~/Library/Mobile\ Documents/com\~apple\~CloudDocs/'
alias snell='cat ../etc/snell/config.conf'
alias ssh='ct screen ssh'
# alias sshls='awk '/^Host / {print $2}' ~/.ssh/config'
alias sshls='grep "^Host " ~/.ssh/config'
alias sshconf='vim ~/.ssh/config'

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

alias myip_in='curl http://ipecho.net/plain; echo'
alias myip_out='curl -s http://checkip.dyndns.org/ | sed "s/[a-zA-Z<>/ :]//g"'
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
alias config='chezmoi cd'
alias ccd='cd $(fd . --hidden --type=d | fzf)'
alias f='fzf'
alias vf='vim $(fzf)'
alias cf='code $(fzf)'

##############################
# Colorize Grep Output
##############################

alias grep='grep --color=auto'
alias egrep='egrep --color=auto'
alias fgrep='fgrep --color=auto'

##############################
# Screen
##############################

alias sn='screen -S'          # 创建新的 screen 会话或附加到已存在的会话
alias sl='screen -ls'         # 列出所有 screen 会话
alias sr='screen -r'          # 重新连接到指定的 screen 会话
alias sm='screen -DR main'    # 创建或重新连接到名为"main"的会话
alias sk='killall screen'     # 终止所有 screen 会话
alias sd='screen -d'          # 分离当前 screen 会话
alias snw='screen -X screen'  # 在当前 screen 会话中创建新窗口并执行命令
alias snd='screen -dm'        # 创建新的 screen 会话，并立即分离
alias lsdev='ls /dev/cu.*'

# 在新的 screen 窗口中执行命令，并立即返回
srun() {
    screen -dm bash -c "$*"
}

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