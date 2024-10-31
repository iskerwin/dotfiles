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
    Pictures
    Movies
    Music
    Applications
    Public
)

# 构建 fd 命令的排除参数
FZF_FD_EXCLUDE=$(printf -- '--exclude %s ' "${FZF_IGNORE_DIRS[@]}")

# 设置基础命令
if command -v fd > /dev/null; then
    export FZF_DEFAULT_COMMAND="fd --type f --hidden --follow --exclude '.git' ${FZF_FD_EXCLUDE}"
    export FZF_ALT_C_COMMAND="fd --type d --hidden --follow --exclude '.git' ${FZF_FD_EXCLUDE}"
else
    # 构建 rg 的排除参数
    FZF_RG_EXCLUDE=$(printf -- '--glob "!%s/*" ' "${FZF_IGNORE_DIRS[@]}")
    export FZF_DEFAULT_COMMAND="rg --files --hidden --follow ${FZF_RG_EXCLUDE}"
fi

# CTRL-T 命令
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"

# 自定义补全触发器
export FZF_COMPLETION_TRIGGER='\\'

# ===== 外观和功能配置 =====
export FZF_DEFAULT_OPTS="
    # 基础布局
    --height=90%
    --layout=reverse
    --border=rounded
    --margin=1
    --padding=1
    --info=inline
    --separator='─'

    # 预览配置
    --preview '([[ -f {} ]] && (bat --style=numbers,changes --color=always {} || cat {})) || ([[ -d {} ]] && (tree -C {} | less)) || echo {} 2> /dev/null | head -200'
    --preview-window='right:60%:wrap'
    --bind='ctrl-/:toggle-preview'

    # 标签和提示
    --border-label=' 🔍 Fuzzy Finder '
    --border-label-pos='3'
    --prompt='  '
    --pointer='▶'
    --marker='✓'

    # 功能绑定
    --bind='ctrl-r:reload($FZF_DEFAULT_COMMAND)'
    --bind='ctrl-d:half-page-down'
    --bind='ctrl-u:half-page-up'
    --bind='ctrl-a:select-all'
    --bind='ctrl-y:execute-silent(echo {+} | pbcopy)'
    
    # Dracula 主题配色
    --color=fg:#f8f8f2,bg:#282a36,hl:#bd93f9
    --color=fg+:#f8f8f2,bg+:#44475a,hl+:#bd93f9
    --color=info:#ffb86c,prompt:#50fa7b,pointer:#ff79c6
    --color=marker:#ff79c6,spinner:#ffb86c,header:#6272a4
    --color=border:#6272a4,label:#6272a4
    
    # 状态栏
    --header='╭──────────────── Controls ────────────────╮
│ CTRL-R: reload • CTRL-/: toggle preview  │
│ CTRL-A: select all • CTRL-Y: copy        │
╰──────────────────────────────────────────╯'
"

# ===== 补全和按键绑定 =====
# 确保目录存在
mkdir -p ~/.config/fzf

# 加载补全和按键绑定
[ -f ~/.config/fzf/completion.zsh ] && source ~/.config/fzf/completion.zsh
[ -f ~/.config/fzf/key-bindings.zsh ] && source ~/.config/fzf/key-bindings.zsh

# ===== 自定义函数 =====
# 增强的文件搜索
fzf-file() {
    local file
    file=$(fzf --query="$1") && vim "$file"
}

# Git 分支切换
fzf-git-branch() {
    git rev-parse HEAD > /dev/null 2>&1 || return
    
    git branch --color=always --all --sort=-committerdate |
        grep -v HEAD |
        fzf --height 50% --ansi --no-multi --preview-window right:65% \
            --preview 'git log -n 50 --color=always --date=short --pretty="format:%C(auto)%cd %h%d %s" $(sed "s/.* //" <<< {})' |
        sed "s/.* //"
}

# ===== 添加自定义搜索函数 =====
# 在指定目录中搜索（排除系统目录）
fzf-search-dir() {
    local dir="${1:-.}"
    cd "$dir" && fzf
}

# 只搜索特定类型的文件
fzf-search-type() {
    local type="$1"
    case "$type" in
        "code")
            fd -t f -e py -e js -e jsx -e ts -e tsx -e go -e rs -e java -e cpp -e c -e h -e hpp \
               -e css -e scss -e html -e xml -e yaml -e yml -e json -e md -e sh \
               ${FZF_EXCLUDE_ARGS} | fzf
            ;;
        "doc")
            fd -t f -e pdf -e doc -e docx -e xls -e xlsx -e ppt -e pptx -e txt -e md \
               ${FZF_EXCLUDE_ARGS} | fzf
            ;;
        "media")
            fd -t f -e jpg -e jpeg -e png -e gif -e mp3 -e mp4 -e mov -e avi \
               ${FZF_EXCLUDE_ARGS} | fzf
            ;;
        *)
            echo "Unknown type. Use: code, doc, or media"
            ;;
    esac
}

# 添加别名
alias ff='fzf-file'
alias fb='fzf-git-branch'
alias fs='fzf-search-dir'
alias fsc='fzf-search-type code'
alias fsd='fzf-search-type doc'
alias fsm='fzf-search-type media'
