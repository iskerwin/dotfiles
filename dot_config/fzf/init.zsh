# ~/.config/fzf/init.zsh

#================================================#
# Basic settings                                 #
#================================================#

# Setup fzf path
if [[ ! "$PATH" == */opt/homebrew/opt/fzf/bin* ]]; then
    PATH="${PATH:+${PATH}:}/opt/homebrew/opt/fzf/bin"
fi

# Load fzf
source <(fzf --zsh)

#================================================#
# Basic command configuration                    #
#================================================#

# Create .rgignore file if it doesn't exist
RGIGNORE="$HOME/.config/fzf/.rgignore"
if [[ ! -f "$RGIGNORE" ]]; then
    cat >"$RGIGNORE" <<EOL
.m2/
.npm/
.git/
.idea/
.cache/
.vscode/
.gradle/
.DS_Store/
dist/
build/
target/
vendor/
Public/
Library/
Library/Logs/
Applications/
node_modules/
__pycache__/
EOL
fi

# Set basic commands
if command -v fd >/dev/null; then
    export FZF_DEFAULT_COMMAND="fd --type f --hidden --follow --max-depth 8 \
        --exclude .m2 \
        --exclude .npm \
        --exclude .git \
        --exclude .idea \
        --exclude .cache \
        --exclude .vscode \
        --exclude .gradle \
        --exclude .DS_Store \
        --exclude dist \
        --exclude build \
        --exclude target \
        --exclude vendor \
        --exclude Public \
        --exclude Library \
        --exclude Applications \
        --exclude node_modules \
        --exclude __pycache__"

    export FZF_ALT_C_COMMAND="fd --type d --hidden --follow --max-depth 8 \
        --exclude .m2 \
        --exclude .npm \
        --exclude .git \
        --exclude .idea \
        --exclude .cache \
        --exclude .vscode \
        --exclude .gradle \
        --exclude .DS_Store \
        --exclude dist \
        --exclude build \
        --exclude target \
        --exclude vendor \
        --exclude Public \
        --exclude Library \
        --exclude Applications \
        --exclude node_modules \
        --exclude __pycache__"
else
    # Use ripgrep with .rgignore file
    export FZF_DEFAULT_COMMAND="rg --files --hidden --follow"
fi

# Set completion trigger
export FZF_COMPLETION_TRIGGER='\'

#================================================#
# Preview configuration                          #
#================================================#

# Define preview commands
show_file_or_dir_preview="if [ -d {} ]; then eza --tree --color=always {} | head -200; else bat -n --color=always --line-range :500 {}; fi"

# Set preview options for different modes
export FZF_DEFAULT_OPTS="--preview '$show_file_or_dir_preview'"
export FZF_CTRL_T_OPTS="--preview '$show_file_or_dir_preview'"
export FZF_ALT_C_OPTS="--preview 'eza --tree --color=always {} | head -200'"
# Disable preview of CTRL-R history
export FZF_CTRL_R_OPTS="--preview-window=hidden"

#================================================#
# Appearance configuration                       #
#================================================#

export FZF_DEFAULT_OPTS="$FZF_DEFAULT_OPTS
    --height=90%
    --layout=reverse
    --border=rounded
    --margin=1
    --padding=1
    --info=inline
    --separator='─'
    --preview-window='right:60%:wrap'
    --border-label=' 🔍 Fuzzy Finder '
    --border-label-pos=3
    --prompt='  '
    --pointer='▶'
    --marker='✓'
    --bind='ctrl-/:toggle-preview'
    --bind='ctrl-d:half-page-down'
    --bind='ctrl-u:half-page-up'
    --bind='ctrl-y:execute-silent(echo {+} | pbcopy)'
    --bind='ctrl-o:execute-silent(open -R {+})'
    --bind='ctrl-e:execute(code {+})'
    --color=fg:#f8f8f2,hl:#bd93f9
    --color=fg+:#f8f8f2,bg+:#44475a,hl+:#bd93f9
    --color=info:#ffb86c,prompt:#50fa7b,pointer:#ff79c6
    --color=marker:#ff79c6,spinner:#ffb86c,header:#6272a4
    --color=border:#6272a4,label:#6272a4
    --header='
╭───────────── Controls ──────────────╮
│ CTRL-/: preview  • CTRL-Y: copy     │
│ CTRL-O: open dir • CTRL-E: vscode   │
╰─────────────────────────────────────╯'
"

[ -f ~/.config/ssh/fzf-ssh.zsh ] && source ~/.config/ssh/fzf-ssh.zsh               # Better completion for ssh in Zsh with FZF
[ -f ~/.config/ssh/fzf-ssh-agent.zsh ] && source ~/.config/ssh/fzf-ssh-agent.zsh   # SSH-agent configuration
[ -f ~/.config/fzf/fzf-tab-colors.zsh ] && source ~/.config/fzf/fzf-tab-colors.zsh # Dracula color scheme for fzf-tab

# Cleaning function
fzfcleanup() {
    unset FZF_IGNORE_DIRS
    unset FZF_FD_EXCLUDE
    unset FZF_RG_EXCLUDE
}

trap fzfcleanup EXIT
