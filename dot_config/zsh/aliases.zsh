##############################
# File Navigation
##############################

# Directory Navigation
alias home='cd ~'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'
alias icloud='cd ~/Library/Mobile\ Documents/com\~apple\~CloudDocs/'

# Directory Listing (using eza/exa)
alias ls='eza --group-directories-first --icons'
alias la='ls -a'                                # List all files including hidden
alias ll='ls -l'                                # Long format
alias l='ll -a'                                 # Long format, all files
alias lr='ll -T'                                # Long format, recursive as tree
alias lx='ll -sextension'                       # Sort by extension
alias lk='ll -ssize'                            # Sort by size
alias lt='ll -smodified'                        # Sort by modification time
alias lc='ll -schanged'                         # Sort by change time
alias l.='ls -d .*'                             # List only dotfiles
alias tree='eza --tree --group-directories-first --icons'

##############################
# File Operations
##############################

# Safe Remove Operations
if (( ${+commands[safe-rm]} && ! ${+commands[safe-rmdir]} )); then
    alias rm='safe-rm'
fi
alias clean-ds='fd -H -I -t f ".DS_Store" --exec rm -f {}'  # Remove .DS_Store files

##############################
# Git Operations
##############################

alias g='git'
alias ga='git add'
alias add='git add .'                                   # Add all changes
alias log='git log --oneline --graph --decorate --all'  # Pretty git log
alias pull='git pull origin'                            # Pull from origin
alias push='git push origin'                            # Push to origin
alias stat='git status'                                 # Show status
alias diff='git diff --name-only --diff-filter=d | xargs bat --diff'  # Show changes
alias fetch='git fetch'                                 # Fetch updates
alias clone='git clone'                                 # Clone repository
alias commit='git commit -m'                            # Commit with message
alias commitam='git commit -am'                         # Add and commit modified files
alias gb='git branch'                                   # List branches
alias gco='git checkout'                                # Checkout branch/commit
alias grb='git rebase'                                  # Rebase
alias gm='git merge'                                    # Merge

##############################
# System Operations
##############################

# Homebrew Package Management
alias update='brew update'                                    # Update Homebrew
alias upgrade='brew upgrade'                                  # Upgrade packages
alias cleanup='brew cleanup'                                  # Clean old versions
alias install='brew install'                                  # Install package
alias uninstall='brew uninstall'                              # Remove package
alias doctor='echo "\nDoctor? Doctor who?\n" && brew doctor'  # Check system
alias update-all='brew cu -a -f -v --no-brew-update -y'       # Update all casks
alias uud='update; upgrade; cleanup; doctor'                  # Full system update

# System Information
alias ip='ifconfig en0 | grep inet'                 # Show local IP
alias myip_in='curl http://ipecho.net/plain; echo'  # Internal IP
alias myip_out='curl -s http://checkip.dyndns.org/ | sed "s/[a-zA-Z<>/ :]//g"'  # External IP
alias speed='networkQuality'                        # Network speed test
alias weather='curl wttr.in/Guangzhou'              # Show weather
alias lsdev='ls /dev/cu.*'                          # List serial devices

##############################
# SSH Management
##############################

alias ssh='ct screen ssh'                         # SSH with screen support
alias sshls='grep "^Host " ~/.ssh/config'         # List SSH hosts
alias sshconf='vim ~/.ssh/config'                 # Edit SSH config

##############################
# Screen Management
##############################

alias sn='screen -S'                              # Create/attach screen session
alias sl='screen -ls'                             # List screen sessions
alias sr='screen -r'                              # Reattach to screen
alias sm='screen -DR main'                        # Main screen session
alias sk='killall screen'                         # Kill all screens
alias sd='screen -d'                              # Detach screen
alias snw='screen -X screen'                      # New window in current session
alias snd='screen -dm'                            # Create detached session

# Run command in new screen window
srun() {
    screen -dm bash -c "$*"
}

##############################
# Development Tools
##############################

# Package Management
alias backup='brew bundle dump --describe --force --file="./Brewfile"'  # Backup brew packages
alias restore-brewfile='brew bundle --file="$HOME/Library/Mobile Documents/com~apple~CloudDocs/AppList/Brewfile"'

# Alias management
alias af='source ~/.config/zsh/alias-fzf.zsh'

# Search and Grep
alias grep='grep --color=auto'                    # Colorized grep
alias egrep='egrep --color=auto'                  # Extended grep
alias fgrep='fgrep --color=auto'                  # Fixed grep

##############################
# Miscellaneous
##############################

alias rz='source ~/.zshrc'                        # Reload zsh config
alias path='echo; tr ":" "\n" <<< "$PATH"; echo;' # Pretty print PATH

##############################
# chezmoi
##############################

#
# Basic commands
#

# Basic operations
alias ch="chezmoi"                 # Base command shortcut
alias chcd="chezmoi cd"            # Navigate to chezmoi source directory
alias chst="chezmoi status"        # Show status of managed files
alias chdoc="chezmoi doctor"       # Check chezmoi installation and configuration

#
# Source file management
#

# Adding and editing files
alias cha="chezmoi add"            # Add a new file to chezmoi
alias chr="chezmoi re-add"         # Update source state from target
alias che="chezmoi edit"           # Edit a managed file
alias chea="chezmoi edit --apply"  # Edit and apply changes immediately

#
# Diff and sync commands
#

# View and apply changes
alias chd="chezmoi diff"           # Show pending changes
alias chap="chezmoi apply -v"      # Apply pending changes to target
alias chf="chezmoi apply --force"  # Force apply changes

# Update and upgrade
alias chup="chezmoi update"        # Update from source repo
alias chug="chezmoi upgrade"       # Upgrade chezmoi to latest version

#
# Git integration
#

# Check if git is available
if (( $+commands[git] )); then
    # Load git aliases from external file
    source <(alias | awk -F "='" -f "${0:h}/alias.awk")
    
    # Git operations
    alias chg="chezmoi git --"           # Execute git commands in chezmoi repo
    alias chgp="chezmoi git -- push"     # Push changes to remote
    alias chgl="chezmoi git -- pull"     # Pull changes from remote
    alias chgs="chezmoi git -- status"   # Git status in chezmoi repo
    alias chga="chezmoi git -- add"      # Stage changes in chezmoi repo
    alias chgc="chezmoi git -- commit"   # Commit changes in chezmoi repo
fi

#
# Additional helpful commands
#

# Show managed paths
alias chls="chezmoi managed"    # List managed files
alias chfg="chezmoi forgot"     # Show unmanaged files
alias chmrg="chezmoi merge"     # Merge changes from source to target

# Debug and information
alias chv="chezmoi verify"      # Verify chezmoi configuration
alias chdt="chezmoi data"       # Show template data