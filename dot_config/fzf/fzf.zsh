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

# CTRL-T 命令
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"

# 自定义补全触发器
export FZF_COMPLETION_TRIGGER='\\'

# ===== 文件类型搜索函数 =====
# 搜索指定扩展名的文件
# 按文件类型搜索的函数
fzf_type() {
    local type="$1"
    case "$type" in
        "code")
            echo "Searching for code files..."
            if command -v fd > /dev/null; then
                fd --type f -e py -e js -e ts -e java -e cpp -e c -e go -e rs -e rb -e php | fzf --multi
            else
                rg --files | grep -i "\.\(py\|js\|ts\|java\|cpp\|c\|go\|rs\|rb\|php\)$" | fzf --multi
            fi
            ;;
        "doc")
            echo "Searching for document files..."
            if command -v fd > /dev/null; then
                fd --type f -e md -e txt -e pdf -e doc -e docx -e xls -e xlsx -e ppt -e pptx | fzf --multi
            else
                rg --files | grep -i "\.\(md\|txt\|pdf\|doc\|docx\|xls\|xlsx\|ppt\|pptx\)$" | fzf --multi
            fi
            ;;
        "config")
            echo "Searching for config files..."
            if command -v fd > /dev/null; then
                fd --type f -e json -e yaml -e yml -e toml -e ini -e conf | fzf --multi
            else
                rg --files | grep -i "\.\(json\|yaml\|yml\|toml\|ini\|conf\)$" | fzf --multi
            fi
            ;;
        "image")
            echo "Searching for image files..."
            if command -v fd > /dev/null; then
                fd --type f -e jpg -e jpeg -e png -e gif -e svg -e webp | fzf --multi
            else
                rg --files | grep -i "\.\(jpg\|jpeg\|png\|gif\|svg\|webp\)$" | fzf --multi
            fi
            ;;
        "video")
            echo "Searching for video files..."
            if command -v fd > /dev/null; then
                fd --type f -e mp4 -e mkv -e avi -e mov -e wmv | fzf --multi
            else
                rg --files | grep -i "\.\(mp4\|mkv\|avi\|mov\|wmv\)$" | fzf --multi
            fi
            ;;
        "audio")
            echo "Searching for audio files..."
            if command -v fd > /dev/null; then
                fd --type f -e mp3 -e wav -e flac -e m4a -e ogg | fzf --multi
            else
                rg --files | grep -i "\.\(mp3\|wav\|flac\|m4a\|ogg\)$" | fzf --multi
            fi
            ;;
        *)
            echo "Usage: fzf_type <type>"
            echo "Available types: code, doc, config, image, video, audio"
            return 1
            ;;
    esac
}

# 搜索指定扩展名的文件
fzf_ext() {
    local ext="$1"
    if [[ -z "$ext" ]]; then
        echo "Usage: fzf_ext <extension>"
        return 1
    fi
    
    echo "Searching for .$ext files..."
    if command -v fd > /dev/null; then
        fd --type f -e "$ext" | fzf --multi
    else
        rg --files | grep -i "\.$ext$" | fzf --multi
    fi
}

# 创建常用别名
alias fzfc='fzf_type code'    # 搜索代码文件
alias fzfd='fzf_type doc'     # 搜索文档
alias fzfi='fzf_type image'   # 搜索图片
alias fzfv='fzf_type video'   # 搜索视频
alias fzfa='fzf_type audio'   # 搜索音频
alias fzfcf='fzf_type config' # 搜索配置文件

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
    
    --color=fg:#f8f8f2,bg:#282a36,hl:#bd93f9
    --color=fg+:#f8f8f2,bg+:#44475a,hl+:#bd93f9
    --color=info:#ffb86c,prompt:#50fa7b,pointer:#ff79c6
    --color=marker:#ff79c6,spinner:#ffb86c,header:#6272a4
    --color=border:#6272a4,label:#6272a4
    
    --header="╭──────────────── Controls ────────────────╮
│ CTRL-R: reload • CTRL-/: toggle preview  │
│ CTRL-A: select all • CTRL-Y: copy        │
╰──────────────────────────────────────────╯"
'

# ===== 补全和按键绑定 =====
# 确保目录存在
[ -d ~/.config/fzf ] || mkdir -p ~/.config/fzf

# 加载补全和按键绑定
[ -f ~/.config/fzf/completion.zsh ] && source ~/.config/fzf/completion.zsh
[ -f ~/.config/fzf/key-bindings.zsh ] && source ~/.config/fzf/key-bindings.zsh

# 清理函数
fzfcleanup() {
    unset FZF_IGNORE_DIRS
    unset FZF_FD_EXCLUDE
    unset FZF_RG_EXCLUDE
}

trap fzfcleanup EXIT