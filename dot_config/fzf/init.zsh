# ~/.config/fzf/init.zsh

# ===== 基础设置 =====
# Setup fzf path
if [[ ! "$PATH" == */opt/homebrew/opt/fzf/bin* ]]; then
    PATH="${PATH:+${PATH}:}/opt/homebrew/opt/fzf/bin"
fi

# Load fzf
source <(fzf --zsh)

# ===== 基础命令配置 =====
# 定义要排除的目录和文件
export FZF_IGNORE_DIRS=(
    .m2
    .npm
    .git
    .idea
    .cache
    .vscode
    .gradle
    .DS_Store
    dist
    build
    target
    vendor
    Public
    Library
    Library/Logs
    Applications
    node_modules
    __pycache__
)

# 构建 fd 命令的排除参数
FZF_FD_OPTS=()
for dir in "${FZF_IGNORE_DIRS[@]}"; do
    FZF_FD_OPTS+=(--exclude "$dir")
done

# 设置基础命令
if command -v fd > /dev/null; then
    export FZF_DEFAULT_COMMAND="fd --type f --hidden --follow --max-depth 8 ${FZF_FD_OPTS[@]}"
    export FZF_ALT_C_COMMAND="fd --type d --hidden --follow --max-depth 8 ${FZF_FD_OPTS[@]}"
else
    # 构建 rg 的排除参数
    RG_OPTS=()
    for dir in "${FZF_IGNORE_DIRS[@]}"; do
        RG_OPTS+=(--glob "!$dir/*")
    done
    export FZF_DEFAULT_COMMAND="rg --files --hidden --follow ${RG_OPTS[@]}"
fi

# 设置补全触发器为反斜杠
export FZF_COMPLETION_TRIGGER='\'

# ===== 预览配置 =====
# 定义预览命令
show_file_or_dir_preview="if [ -d {} ]; then eza --tree --color=always {} | head -200; else bat -n --color=always --line-range :500 {}; fi"

# 设置不同模式的预览选项
export FZF_DEFAULT_OPTS="--preview '$show_file_or_dir_preview'"
export FZF_CTRL_T_OPTS="--preview '$show_file_or_dir_preview'"
export FZF_ALT_C_OPTS="--preview 'eza --tree --color=always {} | head -200'"

# ===== 外观和功能配置 =====
export FZF_DEFAULT_OPTS="$FZF_DEFAULT_OPTS
    --height=90%
    --layout=reverse
    --border=rounded
    --margin=1
    --padding=1
    --info=inline
    --separator='─'
    --preview-window='right:60%:wrap'
    --bind='ctrl-/:toggle-preview'
    --border-label=' 🔍 Fuzzy Finder '
    --border-label-pos=3
    --prompt='  '
    --pointer='▶'
    --marker='✓'
    --bind='ctrl-d:half-page-down'
    --bind='ctrl-u:half-page-up'
    --bind='ctrl-a:select-all'
    --bind='ctrl-y:execute-silent(echo {+} | pbcopy)'
    --bind='ctrl-o:execute-silent(open -R {+})'
    --bind='ctrl-e:execute(code {+})'
    --color=fg:#f8f8f2,bg:#282a36,hl:#bd93f9
    --color=fg+:#f8f8f2,bg+:#44475a,hl+:#bd93f9
    --color=info:#ffb86c,prompt:#50fa7b,pointer:#ff79c6
    --color=marker:#ff79c6,spinner:#ffb86c,header:#6272a4
    --color=border:#6272a4,label:#6272a4
    --header='
╭───────────── Controls ──────────────╮
│ CTRL-R: reload   • CTRL-Y: copy     │
│ CTRL-O: open dir • CTRL-E: vscode   │
╰───────────────────────────────────--╯'
"

# 清理函数
fzfcleanup() {
    unset FZF_IGNORE_DIRS
    unset FZF_FD_EXCLUDE
    unset FZF_RG_EXCLUDE
}

trap fzfcleanup EXIT