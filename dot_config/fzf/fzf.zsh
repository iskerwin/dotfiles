# ===== 基础命令配置 =====
# 定义要排除的目录和文件
export FZF_IGNORE_DIRS=(
    .git
    node_modules
    .idea
    .vscode
    __pycache__
    .npm
    .cache
    build
    dist
    target
    vendor
    .gradle
    .m2
    Library
    Library/Logs
    Applications
    Public
    .DS_Store
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
export FZF_COMPLETION_TRIGGER=']'

# ===== 外观和功能配置 =====
export FZF_DEFAULT_OPTS='
    --height=90%
    --layout=reverse
    --border=rounded
    --margin=1
    --padding=1
    --info=inline
    --separator="─"

    --preview "([[ -f {} ]] && (bat --style=numbers,changes --color=always {} || cat {})) || ([[ -d {} ]] && (tree -C {} | less)) || echo {} 2> /dev/null | head -200"
    --preview-window="right:60%:wrap"
    --bind="ctrl-/:toggle-preview"

    --border-label=" 🔍 Fuzzy Finder "
    --border-label-pos=3
    --prompt="  "
    --pointer="▶"
    --marker="✓"

    --bind="ctrl-d:half-page-down"
    --bind="ctrl-u:half-page-up"
    --bind="ctrl-a:select-all"
    --bind="ctrl-y:execute-silent(echo {+} | pbcopy)"
    --bind="ctrl-o:execute-silent(open -R {+})"
    --bind="ctrl-e:execute(code {+})"

    
    --color=fg:#f8f8f2,bg:#282a36,hl:#bd93f9
    --color=fg+:#f8f8f2,bg+:#44475a,hl+:#bd93f9
    --color=info:#ffb86c,prompt:#50fa7b,pointer:#ff79c6
    --color=marker:#ff79c6,spinner:#ffb86c,header:#6272a4
    --color=border:#6272a4,label:#6272a4
    
    --header="
╭───────────────── Controls ──────────────────╮
│ CTRL-R: reload   • CTRL-Y: copy             │
│ CTRL-O: open dir • CTRL-E: open with vscode │
╰─────────────────────────────────────────────╯"
'

# 确保目录存在
[ -d ~/.config/fzf ] || mkdir -p ~/.config/fzf
source ~/.config/fzf/type.zsh

# 清理函数
fzfcleanup() {
    unset FZF_IGNORE_DIRS
    unset FZF_FD_EXCLUDE
    unset FZF_RG_EXCLUDE
}

trap fzfcleanup EXIT